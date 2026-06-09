import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'msg91_otp_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  AUTH SERVICE — MSG91 OTP Authentication
//
//  Firebase Phone Auth has been fully removed.
//  Firebase Core and Firebase Messaging remain intact for FCM push notifications.
//
//  The mobile number is the permanent identity key.
//  After OTP verification, the phone number formatted as '916XXXXXXXXX'
//  is stored as the userId in SecureStorage.
//
//  BACKWARD COMPATIBILITY:
//  Many screens use AuthService().currentUser?.uid and .phoneNumber.
//  We provide a [NeedinUser] object that mimics the Firebase User API surface
//  so all existing screen code continues to work without changes.
// ══════════════════════════════════════════════════════════════════════════════

/// Lightweight user object that replaces the Firebase `User` type.
/// All screens using `AuthService().currentUser?.uid`, `.phoneNumber`, or `.email`
/// will work without modification.
class NeedinUser {
  /// The userId — formatted phone number '916XXXXXXXXX'
  final String uid;

  /// The phone number in '+91XXXXXXXXXX' format
  final String phoneNumber;

  /// Optional email (from profile data — not part of phone auth identity)
  final String? email;

  const NeedinUser({
    required this.uid,
    required this.phoneNumber,
    this.email,
  });
}

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // In-memory cache of the current user — populated after OTP verification
  // and restored at startup from SecureStorage.
  NeedinUser? _currentUser;

  // Stores the reqId returned by MSG91 after sendOTP
  String? _currentReqId;

  // ── Current User (sync getter for backward compat) ────────────────────────
  /// Returns the in-memory cached user, or null if not loaded yet.
  /// Use [restoreSession()] at startup to populate this from SecureStorage.
  NeedinUser? get currentUser => _currentUser;

  // ── Restore session from SecureStorage ───────────────────────────────────
  /// Call once at startup (e.g. in SessionManager or main.dart).
  /// Reads stored userId+phone from SecureStorage and populates [currentUser].
  Future<void> restoreSession() async {
    try {
      final userId = await LocalStorageService.getUserId();
      final phone = await LocalStorageService.getUserPhone();
      if (userId != null && userId.isNotEmpty) {
        _currentUser = NeedinUser(
          uid: userId,
          phoneNumber: phone ?? '+91${userId.replaceFirst('91', '')}',
        );
        debugPrint('AUTH: ✅ Session restored for uid=${userId.substring(0, 6)}...');
      }
    } catch (e) {
      debugPrint('AUTH: ⚠️ Session restore failed: $e');
    }
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  /// [phone10] is a 10-digit Indian number (no country code, no +).
  Future<OtpSendResult> sendOTP(String phone10) async {
    final result = await Msg91OtpService().sendOTP(phone10);
    if (result.success) {
      _currentReqId = result.reqId;
      // Log only first 8 chars of reqId — never the full value
      final safeReqId = (result.reqId?.length ?? 0) > 8
          ? '${result.reqId!.substring(0, 8)}...'
          : result.reqId ?? '';
      debugPrint('AUTH: OTP sent. reqId=$safeReqId');
    }
    return result;
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  /// Returns the formatted phone as userId (e.g. '916367445454') on success,
  /// or null on failure.
  Future<String?> verifyOTP({
    required String reqId,
    required String otp,
    required String phone10,
  }) async {
    final success = await Msg91OtpService().verifyOTP(reqId, phone10, otp);
    if (success) {
      final userId = '91${phone10.trim()}';
      final formattedPhone = '+91${phone10.trim()}';
      _currentUser = NeedinUser(uid: userId, phoneNumber: formattedPhone);
      // Log last 4 digits of phone only — never the full number
      final tail = phone10.length >= 4
          ? phone10.substring(phone10.length - 4)
          : phone10;
      debugPrint('AUTH: ✅ OTP verified. userId=91******$tail');
      return userId;
    }
    debugPrint('AUTH: ❌ OTP verification failed');
    return null;
  }

  // ── Retry OTP ─────────────────────────────────────────────────────────────
  Future<OtpSendResult> retryOTP(String phone10, {String? reqId}) async {
    final id = reqId ?? _currentReqId ?? '';
    if (id.isEmpty) {
      debugPrint('AUTH: No reqId for retry — re-sending OTP');
      return sendOTP(phone10);
    }
    final result = await Msg91OtpService().retryOTP(id);
    if (result.success && result.reqId != null && result.reqId!.isNotEmpty) {
      _currentReqId = result.reqId;
    }
    return result;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _currentUser = null;
    _currentReqId = null;
    await LocalStorageService.clearSession();
    debugPrint('AUTH: ✅ Signed out');
  }

  // ── Async getters ─────────────────────────────────────────────────────────
  Future<String?> getCurrentUserId() async {
    return _currentUser?.uid ?? LocalStorageService.getUserId();
  }

  Future<String?> getCurrentUserPhone() async {
    return _currentUser?.phoneNumber ?? LocalStorageService.getUserPhone();
  }
}
