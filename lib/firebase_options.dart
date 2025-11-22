import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return parent; // default
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ---- PARENT APP CONFIG ----
  static FirebaseOptions get parent {
    return FirebaseOptions(
      apiKey: dotenv.env['PARENT_API_KEY']!,
      appId: dotenv.env['PARENT_APP_ID']!,
      messagingSenderId: dotenv.env['PARENT_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['PARENT_PROJECT_ID']!,
      storageBucket: dotenv.env['PARENT_STORAGE_BUCKET']!,
    );
  }

  // ---- CHILD APP CONFIG ----
  static FirebaseOptions get child {
    return FirebaseOptions(
      apiKey: dotenv.env['CHILD_API_KEY']!,
      appId: dotenv.env['CHILD_APP_ID']!,
      messagingSenderId: dotenv.env['CHILD_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['CHILD_PROJECT_ID']!,
      storageBucket: dotenv.env['CHILD_STORAGE_BUCKET']!,
    );
  }
}
