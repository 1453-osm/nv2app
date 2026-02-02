import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Minimal Firebase options for this project.
/// Generated manually from android/app/google-services.json
/// Web support added for daily content (Firestore)
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
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCL3QESV_CrDSiCExGWihJmVFj4X34TJpU',
    appId: '1:977812493931:web:ba2356cae4202a58b5032e',
    messagingSenderId: '977812493931',
    projectId: 'namazvaktim-1453',
    authDomain: 'namazvaktim-1453.firebaseapp.com',
    storageBucket: 'namazvaktim-1453.firebasestorage.app',
    measurementId: 'G-1M6PT2SB29',
  );

  static FirebaseOptions get android {
    final apiKey = dotenv.env['FIREBASE_ANDROID_API_KEY'];
    final appId = dotenv.env['FIREBASE_ANDROID_APP_ID'];
    final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'];
    final storageBucket = dotenv.env['FIREBASE_STORAGE_BUCKET'];

    if (apiKey == null || appId == null || messagingSenderId == null || projectId == null) {
      throw StateError(
        'Firebase environment variables are missing. '
        'Required: FIREBASE_ANDROID_API_KEY, FIREBASE_ANDROID_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID'
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCvEx_TYC4AvBHqazZOHPH0VprNC4uxIME',
    appId: '1:977812493931:ios:1b13d468cfe8f80fb5032e',
    messagingSenderId: '977812493931',
    projectId: 'namazvaktim-1453',
    storageBucket: 'namazvaktim-1453.firebasestorage.app',
    iosBundleId: 'com.osm.namazvaktim',
  );
}
