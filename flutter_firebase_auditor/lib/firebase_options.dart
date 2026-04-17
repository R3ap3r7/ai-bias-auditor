import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static bool get isConfigured => true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'Firebase options are configured for Flutter web in this MVP.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCqkdfSPyzryXFzyrIn_PAW1P9HEifWXrY',
    appId: '1:49788943765:web:b1682c0470abd4cab84a9c',
    messagingSenderId: '49788943765',
    projectId: 'ai-bias-auditor-2604171603',
    authDomain: 'ai-bias-auditor-2604171603.firebaseapp.com',
    storageBucket: 'ai-bias-auditor-2604171603.firebasestorage.app',
  );
}
