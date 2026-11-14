import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../firebase_options.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

/// مفتاح التنقل العام (لفتح المحادثة من الإشعار)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// يُستدعى من خيط الخلفية عند ضغط زر (رد / مقروءة) والتطبيق مغلق
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse r) {
  NotificationService.handleResponse(r, background: true);
}

/// رسائل FCM بالخلفية (التطبيق مغلق أو بالخلفية)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage m) async {
  await NotificationService.handleMessage(m, background: true);
}

String pairId(String a, String b) => ([a, b]..sort()).join('__');

int _notifId(String chatId) {
  var h = 2166136261;
  for (final c in chatId.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7FFFFFFF;
  }
  return h;
}

/// إشعارات بابيلون: صورة المرسل + رد مباشر + «مقروءة» + فتح المحادثة وإخفاء الإشعار
class NotificationService {
  /// المحادثة المفتوحة حالياً أمام المستخدم (لا نعرض إشعارها)
  static String? activeChatId;

  /// محادثة مطلوب فتحها (من ضغطة إشعار)
  static Map<String, dynamic>? pendingOpen;
  static void Function(Map<String, dynamic>)? onOpenChat;

  static bool _inited = false;

  static Future<void> init({bool main = true}) async {
    if (_inited) return;
    _inited = true;
    const android = AndroidInitializationSettings('ic_stat_notify');
    await _fln.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (r) => handleResponse(r, background: false),
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
    final a = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.createNotificationChannel(const AndroidNotificationChannel(
      'messages',
      'الرسائل',
      description: 'إشعارات المحادثات وإشعارات المطوّر',
      importance: Importance.high,
    ));
    if (main) {
      await a?.requestNotificationsPermission();
      // ضغط الإشعار والتطبيق مغلق
      final launch = await _fln.getNotificationAppLaunchDetails();
      final r = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && r != null && r.actionId == null && r.payload != null) {
        try {
          pendingOpen = Map<String, dynamic>.from(jsonDecode(r.payload!));
        } catch (_) {}
      }
    }
  }

  static Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  }

  static Future<User?> _user() async {
    final a = FirebaseAuth.instance;
    var u = a.currentUser;
    u ??= await a.authStateChanges().first.timeout(const Duration(seconds: 6), onTimeout: () => null);
    return u;
  }

  // ---------------- استقبال FCM ----------------
  static Future<void> handleMessage(RemoteMessage m, {required bool background}) async {
    if (background) {
      DartPluginRegistrant.ensureInitialized();
      await init(main: false);
    }
    final d = m.data;
    final type = d['type'];
    if (type == 'msg') {
      await _showChat(d, background: background);
    } else if (type == 'broadcast' && !background) {
      // بالواجهة: النظام لا يعرض إشعار FCM، نعرضه نحن
      final n = m.notification;
      if (n != null) {
        await _fln.show(
          DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('messages', 'الرسائل',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_notify',
                color: Color(0xFFC9961F),
                styleInformation: BigTextStyleInformation('')),
          ),
        );
      }
    }
  }

  static Future<Uint8List?> _avatarBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
      if (r.statusCode == 200 && r.bodyBytes.length > 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  static Future<void> _showChat(Map<String, dynamic> d, {required bool background}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('babylon_msg_notif') ?? true)) return;
    final chatId = (d['chatId'] as String?) ?? '';
    if (chatId.isEmpty) return;
    if ((prefs.getStringList('babylon_muted') ?? []).contains(chatId)) return;
    if (!background && activeChatId == chatId) return;
    final sender = (d['senderId'] as String?) ?? '';
    final title = (d['title'] as String?) ?? 'رسالة جديدة';
    final body = (d['body'] as String?) ?? '';

    final key = 'notif_conv_$chatId';
    final list = prefs.getStringList(key) ?? [];
    list.add(jsonEncode({'t': body, 'at': DateTime.now().millisecondsSinceEpoch, 'm': 0, 'n': title}));
    while (list.length > 8) {
      list.removeAt(0);
    }
    await prefs.setStringList(key, list);

    final senderIcon = await _avatarBytes(d['avatar'] as String?);
    final meIcon = await _avatarBytes(d['meAvatar'] as String?);
    await _post(chatId, sender, list, senderIcon, meIcon, sound: prefs.getBool('babylon_sound') ?? true);
  }

  static Future<void> _post(
    String chatId,
    String sender,
    List<String> convo,
    Uint8List? senderIcon,
    Uint8List? meIcon, {
    bool sound = true,
    bool quiet = false,
  }) async {
    final me = Person(
        name: 'أنا', key: 'me', icon: meIcon == null ? null : ByteArrayAndroidIcon(meIcon));
    final persons = <String, Person>{};
    final msgs = <Message>[];
    String lastTitle = 'رسالة جديدة';
    String lastBody = '';
    for (final raw in convo) {
      final e = jsonDecode(raw) as Map<String, dynamic>;
      final mine = e['m'] == 1;
      final name = (e['n'] as String?) ?? '';
      final person = mine
          ? me
          : persons.putIfAbsent(
              name, () => Person(name: name, key: 'u_$name', icon: senderIcon == null ? null : ByteArrayAndroidIcon(senderIcon)));
      msgs.add(Message((e['t'] as String?) ?? '', DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()), person));
      if (!mine) lastTitle = name;
      lastBody = (e['t'] as String?) ?? '';
    }
    final style = MessagingStyleInformation(me, groupConversation: false, messages: msgs);
    final details = AndroidNotificationDetails(
      'messages',
      'الرسائل',
      channelDescription: 'إشعارات المحادثات',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: style,
      playSound: sound && !quiet,
      onlyAlertOnce: quiet,
      icon: 'ic_stat_notify',
      color: const Color(0xFFC9961F),
      autoCancel: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('reply', 'رد',
            showsUserInterface: false,
            cancelNotification: false,
            allowGeneratedReplies: true,
            inputs: <AndroidNotificationActionInput>[AndroidNotificationActionInput(label: 'اكتب رداً...')]),
        AndroidNotificationAction('read', 'تحديد كمقروءة', showsUserInterface: false, cancelNotification: true),
      ],
    );
    await _fln.show(
      _notifId(chatId),
      lastTitle,
      lastBody,
      NotificationDetails(android: details),
      payload: jsonEncode({'chatId': chatId, 'senderId': sender}),
    );
  }

  // ---------------- ضغطات الإشعار والأزرار ----------------
  static Future<void> handleResponse(NotificationResponse r, {required bool background}) async {
    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(jsonDecode(r.payload ?? '{}'));
    } catch (_) {}
    if (background) {
      DartPluginRegistrant.ensureInitialized();
      await init(main: false);
    }
    if (r.actionId == 'reply') {
      await _reply(data, r.input);
    } else if (r.actionId == 'read') {
      await _markRead(data);
    } else if (data['chatId'] != null) {
      // ضغط على الإشعار نفسه => افتح المحادثة
      pendingOpen = data;
      onOpenChat?.call(data);
    }
  }

  static Future<void> clearChat(String chatId) async {
    try {
      await _fln.cancel(_notifId(chatId));
      final p = await SharedPreferences.getInstance();
      await p.remove('notif_conv_$chatId');
    } catch (_) {}
  }

  static Future<void> _markRead(Map<String, dynamic> data) async {
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;
    try {
      await _ensureFirebase();
      final u = await _user();
      if (u != null) {
        final db = FirebaseFirestore.instance;
        final q = await db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('read', isEqualTo: false)
            .limit(100)
            .get();
        final batch = db.batch();
        var n = 0;
        for (final d in q.docs) {
          final m = d.data();
          if (m['senderId'] != u.uid && m['system'] != true) {
            batch.update(d.reference, {'read': true});
            n++;
          }
        }
        if (n > 0) await batch.commit();
        // مجموعة: readAt
        final sender = data['senderId'] as String? ?? '';
        if (chatId != pairId(u.uid, sender)) {
          await db.collection('chats').doc(chatId).update({'readAt.${u.uid}': DateTime.now().millisecondsSinceEpoch}).catchError((_) {});
        }
      }
    } catch (_) {}
    await clearChat(chatId);
  }

  static Future<void> _reply(Map<String, dynamic> data, String? text) async {
    final t = (text ?? '').trim();
    final chatId = data['chatId'] as String?;
    final sender = data['senderId'] as String? ?? '';
    if (t.isEmpty || chatId == null) return;
    try {
      await _ensureFirebase();
      final u = await _user();
      if (u == null) return;
      final db = FirebaseFirestore.instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isGroup = chatId != pairId(u.uid, sender);
      final ref = db.collection('chats').doc(chatId);
      await ref.collection('messages').add({'senderId': u.uid, 'text': t, 'read': false, 'createdAt': now});
      await ref.set({
        'updatedAt': now,
        'typing_${u.uid}': false,
        if (isGroup) 'lastMsg': {'text': t, 'senderId': u.uid, 'at': now},
        if (isGroup) 'readAt': {u.uid: now},
      }, SetOptions(merge: true));

      // إشعار للطرف الآخر
      final meDoc = await db.collection('users').doc(u.uid).get();
      final myName = (meDoc.data()?['displayName'] as String?) ?? '';
      List<String> to = [sender];
      if (isGroup) {
        final c = await ref.get();
        to = ((c.data()?['participants'] as List?) ?? []).cast<String>().where((x) => x != u.uid).toList();
      }
      for (final r in to) {
        if (r.isEmpty) continue;
        BabylonApi.notifyPeer(me: u, recipientId: r, chatId: chatId, senderName: myName, text: t);
      }

      await _markRead(data);

      // نعيد عرض الإشعار مع ردّي (بدون صوت)
      final p = await SharedPreferences.getInstance();
      final key = 'notif_conv_$chatId';
      final list = p.getStringList(key) ?? [];
      list.add(jsonEncode({'t': t, 'at': now, 'm': 1, 'n': 'أنا'}));
      await p.setStringList(key, list);
      await _post(chatId, sender, list, null, null, quiet: true);
      // نخفيه بعد ثانيتين مثل تليجرام حتى لا يبقى عالقاً
      Future.delayed(const Duration(seconds: 2), () => clearChat(chatId));
    } catch (_) {}
  }
}
