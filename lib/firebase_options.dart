import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return parent; 
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions parent = FirebaseOptions(
    apiKey: 'AIzaSyCRyS2d_Rr_tr6HJzrpXyTDA-6__LD9ZuY', 
    appId: '1:110632506055:android:3db751e05e1acc931b24e2',
    messagingSenderId: '110632506055',
    projectId: 'orbit-shield',
    storageBucket: 'orbit-shield.firebasestorage.app',
  );

  static const FirebaseOptions child = FirebaseOptions(
    apiKey: 'AIzaSyCRyS2d_Rr_tr6HJzrpXyTDA-6__LD9ZuY',
    appId: '1:110632506055:android:db016fa861bac2221b24e2', 
    messagingSenderId: '110632506055',
    projectId: 'orbit-shield',
    storageBucket: 'orbit-shield.firebasestorage.app',
  );
}