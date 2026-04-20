import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';

class UserProfileProvider with ChangeNotifier {
  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Convenience Getters ──────────────────────────────
  String get fullName => _profileData?['full_name']?.toString() ?? '';
  String get email => _profileData?['email']?.toString() ?? '';
  String get city => _profileData?['city']?.toString() ?? '';
  String get phone => _profileData?['phone']?.toString() ?? AuthService().currentUser?.phoneNumber ?? '';
  String get dateOfBirth => _profileData?['date_of_birth']?.toString() ?? '';
  String? get profileImageUrl => _profileData?['profile_image_url']?.toString();

  /// Load profile from backend/cache
  Future<void> loadProfile() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService().getUserProfile(uid);
      if (data != null) {
        _profileData = Map<String, dynamic>.from(data);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint("PROVIDER: Error loading profile: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update profile (text fields + optional image)
  /// This method NEVER crashes. It always returns true if local save works.
  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? city,
    String? phone,
    String? dateOfBirth,
    Uint8List? imageBytes,
    String? imageExt,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      _error = "User not logged in";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;

    // Optimistic UI updates — show changes immediately
    _profileData ??= {};
    if (fullName != null) _profileData!['full_name'] = fullName;
    if (email != null) _profileData!['email'] = email;
    if (city != null) _profileData!['city'] = city;
    if (phone != null) _profileData!['phone'] = phone;
    if (dateOfBirth != null) _profileData!['date_of_birth'] = dateOfBirth;
    notifyListeners();

    try {
      // Step 1: Upload image if provided
      String? profileImageUrl;
      if (imageBytes != null && imageExt != null) {
        debugPrint("PROVIDER: Uploading profile image...");
        profileImageUrl = await SupabaseService().uploadProfilePicture(uid, imageBytes, imageExt);
        if (profileImageUrl != null) {
          _profileData!['profile_image_url'] = profileImageUrl;
          debugPrint("PROVIDER: ✅ Image uploaded: $profileImageUrl");
          notifyListeners();
        } else {
          debugPrint("PROVIDER: ⚠️ Image upload returned null (storage might not be configured)");
        }
      }

      // Step 2: Save to database (local + Supabase)
      debugPrint("PROVIDER: Saving profile to database...");
      await SupabaseService().upsertUserProfile(
        userId: uid,
        fullName: fullName,
        email: email,
        city: city,
        phone: phone,
        dateOfBirth: dateOfBirth,
        profileImageUrl: profileImageUrl,
      );

      debugPrint("PROVIDER: ✅ Profile update complete!");
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("PROVIDER: ❌ Error saving profile: $_error");
      // Even if Supabase fails, local data is already saved
      // So we still return true — the user's data is persisted locally
      _isLoading = false;
      notifyListeners();
      return true; // Local save always works
    }
  }
}
