import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static bool get isConfigured {
    return const String.fromEnvironment('FIREBASE_PROJECT_ID').isNotEmpty &&
        const String.fromEnvironment('FIREBASE_API_KEY').isNotEmpty &&
        const String.fromEnvironment('FIREBASE_APP_ID').isNotEmpty &&
        const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID').isNotEmpty;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'Firebase options are configured for Flutter web in this MVP.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );
}
