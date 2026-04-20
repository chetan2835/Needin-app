import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase options.
/// You should generate this file using the FlutterFire CLI.
/// 
/// `flutterfire configure`
///
/// For now, these are placeholder values so the app compiles without error.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for linux.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_WEB', defaultValue: 'AIzaSyAtzbvRpLt9Tvk4wvuzAEqIo3h2M3zK3qE'),
    appId: '1:742766974365:web:7367a0f50cd48e4a6c8b74',
    messagingSenderId: '742766974365',
    projectId: 'needin-app',
    authDomain: 'needin-app.firebaseapp.com',
    storageBucket: 'needin-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_ANDROID', defaultValue: 'AIzaSyAtzbvRpLt9Tvk4wvuzAEqIo3h2M3zK3qE'),
    appId: '1:742766974365:android:fe53c26f12bbef026c8b74',
    messagingSenderId: '742766974365',
    projectId: 'needin-app',
    storageBucket: 'needin-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_IOS', defaultValue: 'AIzaSyAtzbvRpLt9Tvk4wvuzAEqIo3h2M3zK3qE'),
    appId: '1:742766974365:ios:d2ac451bf3fd22b56c8b74',
    messagingSenderId: '742766974365',
    projectId: 'needin-app',
    storageBucket: 'needin-app.firebasestorage.app',
    iosBundleId: 'com.example.needinApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_MACOS', defaultValue: 'AIzaSyAtzbvRpLt9Tvk4wvuzAEqIo3h2M3zK3qE'),
    appId: '1:742766974365:ios:d2ac451bf3fd22b56c8b74',
    messagingSenderId: '742766974365',
    projectId: 'needin-app',
    storageBucket: 'needin-app.firebasestorage.app',
    iosBundleId: 'com.example.needinApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_WINDOWS', defaultValue: 'AIzaSyAtzbvRpLt9Tvk4wvuzAEqIo3h2M3zK3qE'),
    appId: '1:742766974365:web:050d4d5dc4a6cc0c6c8b74',
    messagingSenderId: '742766974365',
    projectId: 'needin-app',
    authDomain: 'needin-app.firebaseapp.com',
    storageBucket: 'needin-app.firebasestorage.app',
  );

}