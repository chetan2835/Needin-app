import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_storage_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../../screens/login/login_page.dart';
import '../providers/user_profile_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SESSION MANAGER — MSG91 auth lifecycle
//
//  Firebase Phone Auth has been removed. Session validity is determined solely
//  by SecureStorage (needin_user_id + session expiry timestamp).
//
//  Decision tree:
//    1. No user_id in SecureStorage   → SessionState.notFound
//    2. Session past 90-day TTL       → SessionState.expired
//    3. All checks pass               → SessionState.valid
// ══════════════════════════════════════════════════════════════════════════════

/// Possible outcomes of a session validation attempt at startup.
enum SessionState {
  /// A valid, non-expired session was found.
  valid,

  /// A session record exists but the 90-day TTL has passed.
  expired,

  /// No session record exists (fresh install, reinstall, or after logout).
  notFound,
}

class SessionManager {
  SessionManager._();

  // ── Session Validation ─────────────────────────────────────────────────────

  /// Validates the locally stored session on app startup.
  static Future<SessionState> validateAndRestoreSession() async {
    try {
      // Step 1: Check SecureStorage for stored userId (phone number)
      final userId = await LocalStorageService.getUserId();
      if (userId == null || userId.isEmpty) {
        debugPrint('SESSION_MGR: No session record found → notFound');
        return SessionState.notFound;
      }

      // Step 2: Check session expiry (90-day TTL)
      final isExpired = await LocalStorageService.isSessionExpired();
      if (isExpired) {
        debugPrint('SESSION_MGR: Session TTL exceeded → expired');
        await LocalStorageService.clearSession();
        return SessionState.expired;
      }

      // Step 3: Restore in-memory user so AuthService().currentUser is non-null
      await AuthService().restoreSession();

      debugPrint('SESSION_MGR: ✅ Session valid — userId=$userId');
      return SessionState.valid;
    } catch (e) {
      debugPrint('SESSION_MGR: ❌ Validation error ($e) → treating as notFound');
      return SessionState.notFound;
    }
  }

  // ── Full Logout Sequence ───────────────────────────────────────────────────

  /// Performs a complete, production-safe logout.
  ///
  /// Sequence:
  ///   1. Deactivate FCM push token
  ///   2. Stop realtime Supabase subscription
  ///   3. Clear in-memory profile from provider
  ///   4. Sign out (clear SecureStorage)
  ///   5. Sign out from Supabase (best-effort)
  ///   6. Navigate to LoginPage
  static Future<void> performLogout({required BuildContext? context}) async {
    debugPrint('SESSION_MGR: 🚪 Starting full logout sequence...');

    // Capture context-dependent references BEFORE any async gaps.
    UserProfileProvider? profileProvider;
    NavigatorState? navigator;

    if (context != null && context.mounted) {
      try {
        profileProvider = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
      } catch (_) {}
      navigator = Navigator.of(context);
    }

    // 1. Deactivate FCM push token
    try {
      await NotificationService().removeDeviceToken();
      debugPrint('SESSION_MGR: ✅ Device push token deactivated');
    } catch (e) {
      debugPrint('SESSION_MGR: ⚠️ Device token removal failed (non-critical): $e');
    }

    // 2. Stop realtime Supabase subscription
    try {
      NotificationService().stopRealtimeSubscription();
      debugPrint('SESSION_MGR: ✅ Realtime subscription stopped');
    } catch (e) {
      debugPrint('SESSION_MGR: ⚠️ Realtime stop failed (non-critical): $e');
    }

    // 3. Clear in-memory profile data
    try {
      profileProvider?.clearProfile();
      debugPrint('SESSION_MGR: ✅ In-memory profile cleared');
    } catch (e) {
      debugPrint('SESSION_MGR: ⚠️ Profile provider clear failed: $e');
    }

    // 4. Sign out — clears SecureStorage session
    try {
      await AuthService().signOut();
      debugPrint('SESSION_MGR: ✅ Auth signed out');
    } catch (e) {
      debugPrint('SESSION_MGR: ⚠️ Auth signOut failed: $e');
    }

    // 5. Sign out from Supabase (best-effort — offline can cause this to fail)
    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint('SESSION_MGR: ✅ Supabase signed out');
    } catch (e) {
      debugPrint('SESSION_MGR: ⚠️ Supabase signOut failed (non-critical): $e');
    }

    debugPrint('SESSION_MGR: 🔒 Logout complete');

    // 6. Navigate to login — clear entire navigation stack.
    if (navigator != null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (navigator.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}
