import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

}
