import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ─── Onboarding ───────────────────────────────────────────────────
  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('account_setup_complete', true);
  }

  // ─── User Session ─────────────────────────────────────────────────
  static Future<void> saveUserSession({
    required String userId,
    required String fullName,
    required String phone,
    String? photoUrl,
    String role = 'user',
  }) async {
    await _storage.write(key: 'needin_user_id', value: userId);
    await _storage.write(key: 'needin_user_name', value: fullName);
    await _storage.write(key: 'needin_user_phone', value: phone);
    await _storage.write(key: 'needin_user_photo', value: photoUrl ?? '');
    await _storage.write(key: 'needin_user_role', value: role);
  }

  static Future<String?> getUserId() async =>
    await _storage.read(key: 'needin_user_id');

  static Future<String?> getUserName() async =>
    await _storage.read(key: 'needin_user_name');

  static Future<String?> getUserPhone() async =>
    await _storage.read(key: 'needin_user_phone');

  static Future<String?> getUserPhoto() async =>
    await _storage.read(key: 'needin_user_photo');

  static Future<bool> hasActiveSession() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }

  // ─── Logout / Reset ───────────────────────────────────────────────
  static Future<void> clearSession() async {
    await _storage.delete(key: 'needin_user_id');
    await _storage.delete(key: 'needin_user_name');
    await _storage.delete(key: 'needin_user_phone');
    await _storage.delete(key: 'needin_user_photo');
    await _storage.delete(key: 'needin_user_role');
    // NOTE: Do NOT clear onboarding_complete on logout —
    // it must survive logout so onboarding doesn't repeat
  }

  // ─── Full Reset (for testing / account deletion only) ─────────────
  static Future<void> fullReset() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
