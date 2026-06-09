import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/local_storage_service.dart';

class UserProfileProvider with ChangeNotifier {
  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Convenience Getters ──────────────────────────────
  String get fullName => _profileData?['full_name']?.toString() ?? '';
  String get firstName {
    final name = fullName;
    if (name.isEmpty) return '';
    return name.split(' ').first;
  }
  String get email => _profileData?['email']?.toString() ?? '';
  String get city => _profileData?['city']?.toString() ?? '';
  String get phone => _profileData?['phone']?.toString() ?? '';
  int? get age => _profileData?['age'] != null ? int.tryParse(_profileData!['age'].toString()) : null;
  bool get isEmailVerified => _profileData?['email_verified'] == true;
  String? get profileImageUrl {
    final url = _profileData?['profile_image_url']?.toString();
    if (url != null && url.isNotEmpty) return url;
    final avatar = _profileData?['avatar_url']?.toString();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    return null;
  }

  /// Whether the user has completed their profile (name, email, city minimum)
  bool get isProfileComplete {
    if (_profileData?['is_profile_complete'] == true) return true;
    final name = fullName.trim();
    final mail = email.trim();
    final userCity = city.trim();
    return name.isNotEmpty && mail.isNotEmpty && userCity.isNotEmpty;
  }

  /// Whether the user's identity is verified via DigiLocker
  bool get isIdentityVerified {
    return _profileData?['is_identity_verified'] == true;
  }

  /// Instantly update email verification state in-memory and notify listeners.
  /// Also persists to local cache so a cold-restart still shows verified state
  /// even before the backend round-trip completes.
  void markEmailVerified(String updatedEmail) {
    _profileData ??= {};
    _profileData!['email'] = updatedEmail;
    _profileData!['email_verified'] = true;
    _profileData!['email_verified_at'] = DateTime.now().toUtc().toIso8601String();
    notifyListeners();
    // Write to local cache immediately — survives cold restarts
    _persistVerifiedStateLocally(updatedEmail);
  }

  Future<void> _persistVerifiedStateLocally(String email) async {
    try {
      String? uid = await LocalStorageService.getUserId();
      if (uid == null) return;
      await SupabaseService().persistEmailVerifiedLocally(
        userId: uid,
        email: email,
        verifiedAt: _profileData!['email_verified_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      );
      debugPrint('PROVIDER: ✅ email_verified=true persisted to local cache');
    } catch (e) {
      debugPrint('PROVIDER: ⚠️ Could not persist to local cache: $e');
    }
  }

  /// Clear in-memory profile data on logout.
  /// Called by SessionManager.performLogout() to wipe stale user state.
  void clearProfile() {
    _profileData = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
    debugPrint('PROVIDER: 🔒 Profile data cleared on logout');
  }

  /// Load profile from backend/cache
  Future<void> loadProfile() async {
    String? uid = await LocalStorageService.getUserId();
    
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    // Snapshot the current in-memory verified state BEFORE the fetch.
    // If the user just verified (markEmailVerified was called), we preserve
    // that state even if the DB response is still returning false due to
    // propagation lag. This prevents the verified badge from flickering away.
    final wasAlreadyVerifiedInMemory = _profileData?['email_verified'] == true;

    try {
      final data = await SupabaseService().getUserProfile(uid);
      if (data != null) {
        _profileData = Map<String, dynamic>.from(data);

        // CRITICAL: If the user just completed verification, the in-memory state
        // is the source of truth. Preserve email_verified=true even if the DB
        // response is lagging behind (race condition).
        if (wasAlreadyVerifiedInMemory && _profileData!['email_verified'] != true) {
          _profileData!['email_verified'] = true;
          debugPrint('PROVIDER: ✅ Preserved in-memory email_verified=true (DB propagation lag)');
        }
        
        // Synchronize database completion flag to local storage
        if (_profileData!['is_profile_complete'] == true) {
          await LocalStorageService.setProfileCompleted();
        } else {
          if (isProfileComplete) {
            await LocalStorageService.setProfileCompleted();
          }
        }
      } else {
        // Fallback check
        if (await LocalStorageService.isProfileCompleted()) {
          _profileData ??= {};
          _profileData!['is_profile_complete'] = true;
        }
        // Restore verified flag if it was set in memory
        if (wasAlreadyVerifiedInMemory) {
          _profileData ??= {};
          _profileData!['email_verified'] = true;
        }
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
    int? age,
    Uint8List? imageBytes,
    String? imageExt,
  }) async {
    String? uid = await LocalStorageService.getUserId();

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
    if (age != null) _profileData!['age'] = age;
    notifyListeners();

    try {
      // Step 1: Upload image if provided
      String? profileImageUrl;
      if (imageBytes != null && imageExt != null) {
        debugPrint("PROVIDER: Uploading profile image...");
        profileImageUrl = await SupabaseService().uploadProfilePicture(uid, imageBytes, imageExt);
        if (profileImageUrl != null) {
          _profileData!['profile_image_url'] = profileImageUrl;
          _profileData!['avatar_url'] = profileImageUrl;
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
        age: age,
        profileImageUrl: profileImageUrl,
      );

      // Step 3: Update local cache
      await LocalStorageService.saveUserSession(
        userId: uid,
        fullName: fullName ?? _profileData!['full_name']?.toString() ?? '',
        phone: phone ?? _profileData!['phone']?.toString() ?? '',
        photoUrl: _profileData!['profile_image_url']?.toString(),
      );

      debugPrint("PROVIDER: ✅ Profile update complete!");
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("PROVIDER: ❌ Error saving profile: $_error");
      _isLoading = false;
      notifyListeners();
      return false; // Return false on error so UI can show failure
    }
  }
}
