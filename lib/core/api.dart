import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// نفس خادم Vercel الحالي — لا يتغيّر شيء في الباك إند.
class BabylonApi {
  static const base = 'https://babyllon.vercel.app';

  static Future<({int status, Map<String, dynamic> data})> post(
    String path,
    Map<String, dynamic> body, {
    User? user,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (user != null) {
      final t = await user.getIdToken();
      headers['Authorization'] = 'Bearer $t';
    }
    final r = await http
        .post(Uri.parse('$base$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return (status: r.statusCode, data: j);
  }

  static Future<String?> resolveLogin(String username, String password) async {
    final r = await post('/api/auth',
        {'type': 'resolve-login', 'username': username, 'password': password});
    if (r.status == 429) throw 'محاولات كثيرة، حاول بعد شوي';
    return r.status == 200 ? r.data['email'] as String? : null;
  }

  static Future<bool> usernameAvailable(String username) async {
    final r = await post(
        '/api/auth', {'type': 'username-available', 'username': username});
    if (r.status == 429) throw 'محاولات كثيرة، انتظر شوي';
    if (r.status != 200) throw 'تعذر التحقق من اسم المستخدم';
    return r.data['available'] == true;
  }

  static Future<void> sendReset(String email) =>
      post('/api/send-mail', {'type': 'reset', 'email': email});

  /// إشعار Push للمستلم (يرسله الخادم عبر FCM)
  static Future<void> notifyPeer({
    required User me,
    required String recipientId,
    required String chatId,
    required String senderName,
    required String text,
  }) async {
    try {
      await post(
        '/api/index',
        {
          'recipientId': recipientId,
          'chatId': chatId,
          'senderName': senderName,
          'messageText': text,
        },
        user: me,
      );
    } catch (_) {}
  }
}
