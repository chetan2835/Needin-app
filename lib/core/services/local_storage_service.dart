import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-grade local storage service for session persistence.
///
/// Architecture:
///  - SharedPreferences: Non-sensitive flags (onboarding, profile completion)
///    Onboarding flag survives logout so returning users skip it.
///    Profile completion flag is CLEARED on logout so the DB is re-checked on
///    next login (Supabase is the source of truth for profile data).
///  - FlutterSecureStorage: Sensitive data (user_id, phone, session expiry)
///    These are always cleared on logout for security.
///
/// Session Expiry:
///  Sessions are valid for 90 days from the time they are issued.
///  Both session_issued_at and session_expires_at are stored in secure storage.
///  hasActiveSession() validates existence AND expiry before returning true.
class LocalStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Session maximum lifetime: 90 days.
  static const Duration sessionMaxAge = Duration(days: 90);

  // ═══════════════════════════════════════════════════════════
  //  ONBOARDING FLAG (SharedPreferences — survives logout & reinstall)
  // ═══════════════════════════════════════════════════════════

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('account_setup_complete', true);
    debugPrint('SESSION: ✅ Onboarding marked complete');
  }

  // ═══════════════════════════════════════════════════════════
  //  PROFILE COMPLETED FLAG (SharedPreferences)
  //
  //  IMPORTANT: This flag IS cleared on logout.
  //  After logout the next OTP success re-fetches from Supabase and
  //  re-sets this flag if the DB confirms the profile is complete.
  //  This prevents skipping profile setup after reinstall.
  // ═══════════════════════════════════════════════════════════

  static Future<bool> isProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('needin_profile_completed') ?? false;
  }

  static Future<void> setProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('needin_profile_completed', true);
    debugPrint('SESSION: ✅ Profile completion flag set (persisted)');
  }

  static Future<void> _clearProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('needin_profile_completed');
    debugPrint('SESSION: 🔒 Profile completion flag cleared on logout');
  }

  // ═══════════════════════════════════════════════════════════
  //  USER SESSION (SecureStorage — sensitive, encrypted)
  //  Keys stored:
  //    needin_user_id         — Firebase UID
  //    needin_user_name       — display name
  //    needin_user_phone      — phone number
  //    needin_user_photo      — avatar URL
  //    needin_user_role       — 'user' | 'driver' etc.
  //    needin_session_issued_at  — ISO8601 when session was created
  //    needin_session_expires_at — ISO8601 when session expires (issued + 90d)
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveUserSession({
    required String userId,
    required String fullName,
    required String phone,
    String? photoUrl,
    String role = 'user',
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(sessionMaxAge);

    await Future.wait([
      _storage.write(key: 'needin_user_id', value: userId),
      _storage.write(key: 'needin_user_name', value: fullName),
      _storage.write(key: 'needin_user_phone', value: phone),
      _storage.write(key: 'needin_user_photo', value: photoUrl ?? ''),
      _storage.write(key: 'needin_user_role', value: role),
      _storage.write(
        key: 'needin_session_issued_at',
        value: now.toIso8601String(),
      ),
      _storage.write(
        key: 'needin_session_expires_at',
        value: expiresAt.toIso8601String(),
      ),
    ]);

    // SECURITY: Do NOT log userId or tokens in production.
    debugPrint('SESSION: ✅ Session saved. Expires: ${expiresAt.toLocal()}');
  }

  static Future<String?> getUserId() async =>
      await _storage.read(key: 'needin_user_id');

  static Future<String?> getUserName() async =>
      await _storage.read(key: 'needin_user_name');

  static Future<String?> getUserPhone() async =>
      await _storage.read(key: 'needin_user_phone');

  static Future<String?> getUserPhoto() async =>
      await _storage.read(key: 'needin_user_photo');

  // ═══════════════════════════════════════════════════════════
  //  SESSION EXPIRY CHECKS
  // ═══════════════════════════════════════════════════════════

  /// Returns the UTC DateTime when the current session expires.
  /// Returns null if no expiry value is stored.
  static Future<DateTime?> getSessionExpiresAt() async {
    final raw = await _storage.read(key: 'needin_session_expires_at');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Returns true if the stored session has passed its expiry timestamp.
  /// Returns false (not expired) if no expiry timestamp is found — to handle
  /// legacy sessions that pre-date this implementation (they will be valid until
  /// they expire naturally via logout or reinstall).
  static Future<bool> isSessionExpired() async {
    final expiresAt = await getSessionExpiresAt();
    if (expiresAt == null) {
      // Legacy session — no expiry stored. Write a forward-compatible expiry
      // so this session gets a 90-day window from now.
      debugPrint('SESSION: ⚠️ Legacy session — writing expiry from now');
      final legacy = DateTime.now().toUtc().add(sessionMaxAge);
      await _storage.write(
        key: 'needin_session_expires_at',
        value: legacy.toIso8601String(),
      );
      return false;
    }
    final isExpired = DateTime.now().toUtc().isAfter(expiresAt);
    if (isExpired) {
      debugPrint('SESSION: ⏰ Session EXPIRED at $expiresAt');
    }
    return isExpired;
  }

  // ═══════════════════════════════════════════════════════════
  //  SESSION VALIDITY CHECK (primary public API)
  // ═══════════════════════════════════════════════════════════

  /// Returns true ONLY if:
  ///   1. A non-empty user_id is stored in secure storage, AND
  ///   2. The session has NOT expired (expiry timestamp check).
  ///
  /// This is the single gate for "should we skip OTP?" at startup.
  static Future<bool> hasActiveSession() async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('SESSION: No user_id found — no active session');
      return false;
    }

    final expired = await isSessionExpired();
    if (expired) {
      debugPrint('SESSION: Session expired — treating as no active session');
      return false;
    }

    debugPrint('SESSION: ✅ Active valid session found');
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  //  LOGOUT (Clear session — profile flag ALSO cleared)
  // ═══════════════════════════════════════════════════════════

  /// Clears all secure session data and the profile completion cache.
  ///
  /// Preserved across logout:
  ///   - onboarding_complete (SharedPreferences) — first-run flag, not user data
  ///
  /// Cleared on logout:
  ///   - All secure storage keys (user_id, name, phone, photo, role, expiry)
  ///   - needin_profile_completed (SharedPreferences) — DB is source of truth,
  ///     re-fetched on next login
  static Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: 'needin_user_id'),
      _storage.delete(key: 'needin_user_name'),
      _storage.delete(key: 'needin_user_phone'),
      _storage.delete(key: 'needin_user_photo'),
      _storage.delete(key: 'needin_user_role'),
      _storage.delete(key: 'needin_session_issued_at'),
      _storage.delete(key: 'needin_session_expires_at'),
      // Legacy key — clean up if present
      _storage.delete(key: 'needin_last_login'),
    ]);

    // Clear profile completion cache so the DB is re-checked on next login
    await _clearProfileCompleted();

    debugPrint('SESSION: 🔒 Session fully cleared (onboarding flag preserved)');
  }

  // ═══════════════════════════════════════════════════════════
  //  FULL RESET (Testing / Account Deletion only)
  // ═══════════════════════════════════════════════════════════

  /// Deletes ALL local data including onboarding flag.
  /// Use only for account deletion or test reset — NOT for normal logout.
  static Future<void> fullReset() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('SESSION: 🗑️ Full reset complete');
  }
}
