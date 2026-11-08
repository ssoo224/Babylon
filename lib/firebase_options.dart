import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// القيم مأخوذة من مشروعك الحالي (aj-chat-df534) ومن app/google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // iOS: شغّل `flutterfire configure` لتوليد القيم الصحيحة
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxQZCL4OawmPLKLRdQdbrQOHN7vl3p5EQ',
    appId: '1:1022301130899:web:171184929244a979b6bd66',
    messagingSenderId: '1022301130899',
    projectId: 'aj-chat-df534',
    authDomain: 'aj-chat-df534.firebaseapp.com',
    storageBucket: 'aj-chat-df534.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNl4rxtMyStQ2_OihJGONJZzlIBwzQCos',
    appId: '1:1022301130899:android:f384a37f10cb49efb6bd66',
    messagingSenderId: '1022301130899',
    projectId: 'aj-chat-df534',
    storageBucket: 'aj-chat-df534.firebasestorage.app',
  );
}
