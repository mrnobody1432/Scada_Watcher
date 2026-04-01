// Firebase configuration for scadadataserver project
// Generated automatically - DO NOT edit manually

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
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBvGqq5JDjVb-b2sdP1kqCgX2d858X4E2k',
    appId: '1:932777127221:web:94b95413180801325b707c', // Standardized with android suffix for consistency
    messagingSenderId: '932777127221',
    projectId: 'scadadataserver',
    authDomain: 'scadadataserver.firebaseapp.com',
    storageBucket: 'scadadataserver.firebasestorage.app',
    measurementId: 'G-932777127221',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBvGqq5JDjVb-b2sdP1kqCgX2d858X4E2k',
    appId: '1:932777127221:android:94b95413180801325b707c',
    messagingSenderId: '932777127221',
    projectId: 'scadadataserver',
    storageBucket: 'scadadataserver.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBvGqq5JDjVb-b2sdP1kqCgX2d858X4E2k',
    appId: '1:932777127221:android:94b95413180801325b707c',
    messagingSenderId: '932777127221',
    projectId: 'scadadataserver',
    storageBucket: 'scadadataserver.firebasestorage.app',
  );
}
