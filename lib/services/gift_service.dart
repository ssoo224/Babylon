import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GiftService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // رابط السيرفر الخاص بك (Vercel) الذي يحتوي على api/gifts
  final String _apiBase = 'https://babyllon.vercel.app/api/gifts';

  // 1. جلب كتالوج الهدايا (الأنواع المتاحة في المتجر)
  Future<List<Map<String, dynamic>>> getCatalog() async {
    try {
      final snap = await _db.collection('giftCatalog').get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  // 2. جلب رصيد المحفظة (النجوم) كـ Stream يتحدث لحظياً
  Stream<int> getWallet(String uid) {
    return _db.collection('wallets').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return 0;
      return (doc.data()?['stars'] as num?)?.toInt() ?? 0;
    });
  }

  // 3. جلب هدايا المستخدم (للملف الشخصي)
  Stream<List<Map<String, dynamic>>> getUserGiftsStream(String uid, String kind) {
    // تحديد المجموعة بناءً على نوع الهدية
    String coll = 'gifts';
    if (kind == 'pepe') coll = 'pepes';
    if (kind == 'cat') coll = 'cats';

    return _db.collection('users').doc(uid).collection(coll).snapshots().map((snap) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  // 4. تثبيت/إلغاء تثبيت الهدية في البروفايل
  Future<void> togglePinGift(String uid, String kind, String giftId, bool pinned) async {
    String coll = 'gifts';
    if (kind == 'pepe') coll = 'pepes';
    if (kind == 'cat') coll = 'cats';

    await _db.collection('users').doc(uid).collection(coll).doc(giftId).update({
      'pinned': pinned,
    });
  }

  // 5. الاتصال بالسيرفر (محمي بـ Token) لعمليات الشراء والترقية
  Future<Map<String, dynamic>> _apiCall(String op, Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    try {
      final token = await user.getIdToken();
      final res = await http.post(
        Uri.parse(_apiBase),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'op': op, ...body}),
      );

      final data = jsonDecode(res.body);
      
      if (res.statusCode != 200 || data['error'] != null) {
        throw Exception(data['error'] ?? 'حدث خطأ في السيرفر');
      }
      return data;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 6. شراء هدية جديدة
  Future<int> buyGift(String kind) async {
    final res = await _apiCall('buy', {'kind': kind});
    return res['number'] as int; // يرجع رقم الهدية
  }

  // 7. ترقية الهدية (عشوائي آمن من السيرفر)
  Future<Map<String, dynamic>> upgradeGift(String kind, int number) async {
    final res = await _apiCall('upgrade', {'kind': kind, 'number': number});
    return res; // يرجع model, bg, sym
  }

  // 8. شراء هدية من السوق (Listing)
  Future<void> buyListing(String kind, int number) async {
    await _apiCall('buy-listing', {'kind': kind, 'number': number});
  }
}
