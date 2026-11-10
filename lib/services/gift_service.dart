import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GiftService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final String _apiBase = 'https://babyllon.vercel.app/api/gifts'; // سيرفر Vercel

  // 1. جلب كتالوج الهدايا (الأنواع المتاحة في المتجر)
  Future<List<Map<String, dynamic>>> getCatalog() async {
    final snap = await _db.collection('giftCatalog').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // 2. جلب رصيد المحفظة (النجوم)
  Stream<int> getWallet(String uid) {
    return _db.collection('wallets').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return 0;
      return (doc.data()?['stars'] as num?)?.toInt() ?? 0;
    });
  }

  // 3. جلب هدايا المستخدم (اللي يملكها)
  Stream<List<Map<String, dynamic>>> getUserGifts(String uid, String coll) {
    return _db.collection('users').doc(uid).collection(coll).snapshots().map((snap) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  // 4. طلب من السيرفر (شراء / ترقية) - محمي
  Future<Map<String, dynamic>> _apiCall(String op, Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

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
  }

  // شراء هدية جديدة
  Future<int> buyGift(String kind) async {
    final res = await _apiCall('buy', {'kind': kind});
    return res['number'] as int; // يرجع رقم الهدية
  }

  // ترقية الهدية (عشوائي آمن من السيرفر)
  Future<Map<String, dynamic>> upgradeGift(String kind, int number) async {
    final res = await _apiCall('upgrade', {'kind': kind, 'number': number});
    return res; // يرجع model, bg, sym
  }

  // شراء هدية من السوق
  Future<void> buyListing(String kind, int number) async {
    await _apiCall('buy-listing', {'kind': kind, 'number': number});
  }
}
