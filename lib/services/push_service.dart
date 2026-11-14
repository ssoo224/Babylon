import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// يحفظ توكن FCM في users/{uid} بنفس حقول نسخة الويب (fcmToken + fcmTokens)
class PushService {
  static Future<void> init(String uid) async {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    Future<void> save(String? t) async {
      if (t == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': t,
        'fcmTokens': FieldValue.arrayUnion([t]),
      }, SetOptions(merge: true));
    }

    await save(await fm.getToken());
    fm.onTokenRefresh.listen(save);
  }
}
