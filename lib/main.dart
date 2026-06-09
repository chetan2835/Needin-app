import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

import 'core/providers/app_provider.dart';
import 'core/providers/user_profile_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/journey_draft_provider.dart';

import 'core/services/language_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_manager.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/msg91_otp_service.dart';
import 'screens/splash/splash_screen.dart';
import 'core/widgets/in_app_notification_overlay.dart';
import 'screens/needin_express/verification_success_screen.dart';
import 'screens/needin_express/verification_failed_screen.dart';
import 'screens/onboarding/onboarding1.dart';
import 'screens/login/login_page.dart';
import 'screens/login/service_selection_page.dart';
import 'screens/login/profile_setup_page.dart';

// IMPORTANT: Replace these with your actual Supabase URL and Anon Key.
const String supabaseUrl = '';
const String supabaseAnonKey = '';

/// Global navigator key for deep link navigation from outside widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
    // In production, send to crash reporting service
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Platform Error: $error');
    return true; // handled
  };

  // Load environment variables (.env)
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? supabaseUrl,
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? supabaseAnonKey,
  );

  // Initialize language service
  await LanguageService().init();

  // Initialize MSG91 OTP service
  Msg91OtpService().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..loadProfile()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => JourneyDraftProvider()),
        ChangeNotifierProvider.value(value: LanguageService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _onboardingDone = false;
  bool _hasSession = false;
  bool _profileComplete = false;

  // Deep link handling
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  // ── Deep link initialization ──────────────────────────────
  void _initDeepLinks() {
    _appLinks = AppLinks();
    _handleInitialLink(); // cold start
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingLink(uri);
    } catch (_) {}
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme != 'needin' || uri.host != 'verification') return;

    final status = uri.queryParameters['status'];
    final name = uri.queryParameters['name'];
    final reason = uri.queryParameters['reason'];

    if (status == 'success') {
      // Replace entire stack — user cannot go back from success screen
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => VerificationSuccessScreen(
            userName: Uri.decodeComponent(name ?? ''),
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VerificationFailedScreen(
            reason: reason ?? 'unknown',
          ),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  STARTUP AUTH CHECK — Single source of truth via SessionManager
  //
  //  Decision tree (handled by SessionManager.validateAndRestoreSession):
  //   SessionState.valid          → restore silently → Home or ProfileSetup
  //   SessionState.expired        → LoginPage (session too old, need OTP)
  //   SessionState.notFound       → LoginPage or Onboarding (no session)
  //   SessionState.firebaseInvalid → LoginPage (Firebase token gone)
  //
  //  Onboarding is checked independently from session state.
  //  A fresh install shows onboarding regardless of session state.
  // ══════════════════════════════════════════════════════════════

  Future<void> _checkAuthState() async {
    try {
      // Run onboarding check and session validation concurrently for speed.
      final sessionStateFuture = SessionManager.validateAndRestoreSession();
      final onboardingFuture = LocalStorageService.isOnboardingComplete();

      final sessionState = await sessionStateFuture;
      bool onboardingDone = await onboardingFuture;

      // Legacy migration: check old "seenOnboarding" key from older app versions
      if (!onboardingDone) {
        final prefs = await SharedPreferences.getInstance();
        final legacySeen = prefs.getBool("seenOnboarding") ?? false;
        if (legacySeen) {
          await LocalStorageService.setOnboardingComplete();
          onboardingDone = true;
        }
      }

      bool hasValidSession = false;
      bool profileComplete = false;

      switch (sessionState) {
        case SessionState.valid:
          hasValidSession = true;
          profileComplete = await LocalStorageService.isProfileCompleted();
          if (!onboardingDone) {
            await LocalStorageService.setOnboardingComplete();
            onboardingDone = true;
          }
          debugPrint('AUTH_CHECK: ✅ Valid session — routing to home');
          break;

        case SessionState.expired:
          hasValidSession = false;
          profileComplete = false;
          debugPrint('AUTH_CHECK: ⏰ Session expired — routing to login');
          break;

        case SessionState.notFound:
          hasValidSession = false;
          profileComplete = false;
          debugPrint('AUTH_CHECK: No session — routing to onboarding/login');
          break;
      }

      debugPrint(
        'AUTH_CHECK: onboarding=$onboardingDone, '
        'session=$hasValidSession, profile=$profileComplete',
      );

      if (mounted) {
        setState(() {
          _onboardingDone = onboardingDone;
          _hasSession = hasValidSession;
          _profileComplete = profileComplete;
        });
      }
    } catch (e) {
      debugPrint('AUTH_CHECK: ❌ Error: $e');
      // On any error, fall back safely to login — never show a blank screen.
      if (mounted) {
        setState(() {
          _onboardingDone = true; // Skip onboarding on error to avoid confusion
          _hasSession = false;
          _profileComplete = false;
        });
      }
    }
  }

  /// Determines which screen to show after the splash animation completes.
  Widget _getDestination() {
    if (!_onboardingDone) {
      // Brand new user: show premium onboarding → login flow
      return const Onboarding1();
    }
    if (!_hasSession) {
      // Logged out / expired / fresh install after onboarding
      return const LoginPage();
    }
    if (!_profileComplete) {
      // User is logged in but profile is incomplete (e.g. interrupted setup)
      return const ProfileSetupPage();
    }

    // ★ RETURNING USER: valid session + complete profile → home screen
    return const ServiceSelectionPage();
  }

  @override
  Widget build(BuildContext context) {
    // The SplashScreen runs a ~4.8s animation. The auth check (SessionManager)
    // completes in <100ms. By the time the splash finishes, _getDestination()
    // returns the correct screen — no race condition.
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Needin",
      theme: ThemeData(
        fontFamily: "Plus Jakarta Sans",
      ),
      builder: (context, child) {
        return InAppNotificationOverlay(child: child ?? const SizedBox.shrink());
      },
      home: SplashScreen(destination: _getDestination()),
    );
  }
}