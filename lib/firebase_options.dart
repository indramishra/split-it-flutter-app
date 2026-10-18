import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCYOkJJbR2kAOp_78n7GSIbiJPw8Cp6mBo',
    appId: '1:236349691458:web:b366ec8064c185fdf0bfdb',
    messagingSenderId: '236349691458',
    projectId: 'splitwise-app-cd9933',
    authDomain: 'splitwise-app-cd9933.firebaseapp.com',
    storageBucket: 'splitwise-app-cd9933.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCe1QJC64eEDf_D5j0gbUmlzoGZ3o4ouvo',
    appId: '1:236349691458:android:b457f6520d22ed5ff0bfdb',
    messagingSenderId: '236349691458',
    projectId: 'splitwise-app-cd9933',
    storageBucket: 'splitwise-app-cd9933.firebasestorage.app',
  );
}
