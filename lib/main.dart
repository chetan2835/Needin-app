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
import 'core/services/language_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding1.dart';
import 'screens/login/login_page.dart';
import 'core/services/local_storage_service.dart';
import 'screens/auth/mpin_screen.dart';
import 'screens/needin_express/verification_success_screen.dart';
import 'screens/needin_express/verification_failed_screen.dart';

// IMPORTANT: Replace these with your actual Supabase URL and Anon Key.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ghiydlxlvrfkgzngnonk.supabase.co');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR_KEY');

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
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize language service
  await LanguageService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..loadProfile()),
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
  bool isChecking = true;
  bool isFirstTime = true;
  bool isLoggedIn = false;
  String? savedPhone;

  // Deep link handling
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    checkFirstTime();
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

  // ── Startup logic ─────────────────────────────────
  void checkFirstTime() async {
    bool seen = await LocalStorageService.isOnboardingComplete();
    
    // Fallback for previous users
    if (!seen) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool("seenOnboarding") ?? false;
      if (seen) await LocalStorageService.setOnboardingComplete();
    }

    bool hasSession = await LocalStorageService.hasActiveSession();

    if (mounted) {
      setState(() {
        isFirstTime = !seen;
        isLoggedIn = hasSession;
        isChecking = false;
      });
    }
  }

  Widget _getDestination() {
    if (isFirstTime) return const Onboarding1();
    if (isLoggedIn) return const MpinScreen();
    // They finished onboarding but are not logged in
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Needin",
      theme: ThemeData(
        fontFamily: "Plus Jakarta Sans",
      ),
      home: isChecking
          // Show splash while checking auth state — the splash
          // handles its own animation timing, so the user never
          // sees a blank screen even if auth check is fast.
          ? SplashScreen(destination: _getDestination())
          : SplashScreen(destination: _getDestination()),
    );
  }
}