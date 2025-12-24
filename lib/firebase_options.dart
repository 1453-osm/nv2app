import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Minimal Firebase options for this project.
/// Generated manually from android/app/google-services.json
/// Android only for now; other platforms will throw at runtime if used.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions have not been configured for Web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0nhOhZcUlOsLPkoau6HvP3Tsl9vmBwUU',
    appId: '1:977812493931:android:686759747b5989d2b5032e',
    messagingSenderId: '977812493931',
    projectId: 'namazvaktim-1453',
    storageBucket: 'namazvaktim-1453.firebasestorage.app',
  );

}
