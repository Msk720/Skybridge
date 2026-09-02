import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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

      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBAz_ie-D-gdUx1vUQVHVn6gKiGqM2YYyQ',
    appId: '1:129758844450:web:4515a5f0b77e49bec01c7b',
    messagingSenderId: '129758844450',
    projectId: 'sdp1-b91a6',
    authDomain: 'sdp1-b91a6.firebaseapp.com',
    storageBucket: 'sdp1-b91a6.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSUdOoF5eY3-1ByRgv1UhQfYvWv1y9Sls',
    appId: '1:129758844450:android:2d14fcebfbe6382bc01c7b',
    messagingSenderId: '129758844450',
    projectId: 'sdp1-b91a6',
    storageBucket: 'sdp1-b91a6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArMvKMUuiWCREryTkMgVzDUPmTZKUj07E',
    appId: '1:129758844450:ios:4ba6f381d9ef9b78c01c7b',
    messagingSenderId: '129758844450',
    projectId: 'sdp1-b91a6',
    storageBucket: 'sdp1-b91a6.firebasestorage.app',
    iosBundleId: 'com.example.skybridge02',
  );
}
