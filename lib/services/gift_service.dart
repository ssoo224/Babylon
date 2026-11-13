import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../core/gift_data.dart';
import 'chat_service.dart' show Json;


const giftsCdn = 'https://cdn.changes.tg/gifts/models/';
const giftFeePct = 5;
int netOf(int price) => (price * (100 - giftFeePct) / 100).floor();

class GiftKind {
  final String key, name, coll, sales;
  final bool gen, orig;
  final int max, price;
  final List<GiftModelDef> models;
  const GiftKind({
    required this.key,
    required this.name,
    required this.coll,
    required this.sales,
    required this.gen,
    required this.orig,
    required this.max,
    required this.price,
    required this.models,
  });

  String get dir => key == 'pepe' ? 'Plush Pepe' : (key == 'cat' ? 'Scared Cat' : name);

  /// i < 0 = الشكل الأصلي (غير مرقّى)
  String modelName(int i) =>
      i < 0 ? (gen && !orig ? models.first.n : 'Original') : models[i.clamp(0, models.length - 1)].n;

  String tgsUrl(int i) => '$giftsCdn${Uri.encodeComponent(dir)}/${Uri.encodeComponent(modelName(i))}.tgs';
  String pngUrl(int i) => '$giftsCdn${Uri.encodeComponent(dir)}/png/${Uri.encodeComponent(modelName(i))}.png';

  String rarePct(int mi) {
    final total = models.fold<int>(0, (a, x) => a + x.p);
    final p = models[mi.clamp(0, models.length - 1)].p;
    final v = (p / (total == 0 ? 1 : total) * 100);
    return v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }
}

class GiftItem {
  final String k;
  final int number;
  final bool upgraded;
  final int model, bg, sym, at;
  final String? ownerId;
  const GiftItem({
    required this.k,
    required this.number,
    this.upgraded = false,
    this.model = 0,
    this.bg = 0,
    this.sym = 0,
    this.at = 0,
    this.ownerId,
  });

  String get id => '${k}_$number';

  factory GiftItem.fromMap(Json x, String key, {String? owner}) => GiftItem(
        k: key,
        number: (x['number'] as num?)?.toInt() ?? 0,
        upgraded: x['upgraded'] == true,
        model: (x['model'] as num?)?.toInt() ?? 0,
        bg: (x['bg'] as num?)?.toInt() ?? 0,
        sym: (x['sym'] as num?)?.toInt() ?? 0,
        at: (x['at'] as num?)?.toInt() ?? 0,
        ownerId: owner,
      );
}

class GiftError implements Exception {
  final String code;
  final String message;
  GiftError(this.code, this.message);
  @override
  String toString() => message;
}

const _errs = {
  'soldout': 'نفدت الكمية',
  'funds': 'رصيدك غير كافٍ ⭐',
  'otp': 'سجّل خروج وادخل من جديد',
  'auth': 'سجّل خروج وادخل من جديد',
  'taken': 'ممكن أحد سبقك، حاول مرة ثانية',
  'gone': 'هالعرض ما عاد موجود',
  'nogift': 'الهدية غير موجودة',
  'already': 'الهدية مرقّاة مسبقاً',
  'rate': 'انتظر شوي وجرّب مرة ثانية',
  'blocked': 'ما تكدر ترسل لهذا المستخدم',
  'nouser': 'المستخدم غير موجود',
  'bad': 'قيمة غير صالحة',
  'dev': 'هذا الخيار للمطوّر فقط',
};

/// خدمة الهدايا والنجوم — نفس نموذج بيانات تطبيق الويب وواجهة /api/gifts
class GiftService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final Map<String, GiftKind> kinds = {};
  bool ready = false;
  Set<String> _pins = {};
  Set<String> _hidden = {};
  String? _prefUid;

  GiftService() {
    load();
  }

  Future<void> load() async {
    if (ready) return;
    kinds['pepe'] = GiftKind(
        key: 'pepe', name: 'Plush Pepe', coll: 'pepes', sales: 'pepeSales', gen: false, orig: true, max: 30, price: 1000, models: pepeModels);
    kinds['cat'] = GiftKind(
        key: 'cat', name: 'Scared Cat', coll: 'cats', sales: 'catSales', gen: false, orig: true, max: 30, price: 500, models: catModels);
    for (final path in ['/manifest.json', '/gifts/manifest.json']) {
      try {
        final r = await http.get(Uri.parse('${BabylonApi.base}$path?v=1')).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue;
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is! Map || j['gifts'] is! List) continue;
        for (final g in (j['gifts'] as List).whereType<Map>()) {
          final name = (g['name'] as String?) ?? '';
          final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
          final ms = ((g['models'] as List?) ?? []).whereType<String>().toList();
          if (key.isEmpty || kinds.containsKey(key) || RegExp(r'^(plush pepe|scared cat)$', caseSensitive: false).hasMatch(name) || ms.isEmpty) {
            continue;
          }
          final names = ms.where((n) => n != 'Original').toList();
          if (names.isEmpty) continue;
          kinds[key] = GiftKind(
            key: key,
            name: name,
            coll: 'gifts',
            sales: 'giftSales',
            gen: true,
            orig: names.length < ms.length,
            max: (g['max'] as num?)?.toInt() ?? 30,
            price: (g['price'] as num?)?.toInt() ?? 500,
            models: [for (final n in names) GiftModelDef(n, 1, '')],
          );
        }
        break;
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
  }

  GiftKind kindOf(String? k) => kinds[k ?? 'pepe'] ?? kinds['pepe']!;
  List<GiftKind> get allKinds => kinds.values.toList();

  // ---------------- المحفظة والسجل ----------------
  Stream<int> stars(String uid) =>
      _db.collection('wallets').doc(uid).snapshots().map((d) => (d.data()?['stars'] as num?)?.toInt() ?? 0);

  Stream<List<Json>> txs(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('txs')
      .orderBy('at', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  // ---------------- API ----------------
  Future<Json> api(String op, Json body, User user) async {
    final r = await BabylonApi.post('/api/gifts', {'op': op, ...body}, user: user);
    if (r.status == 200) return r.data;
    final code = (r.data['error'] as String?) ?? 'http${r.status}';
    throw GiftError(code, _errs[code] ?? 'تعذر إكمال العملية');
  }

  Future<Json> buy(GiftKind k, User u) => api('buy', {'kind': k.key}, u);
  Future<Json> upgrade(GiftKind k, int number, User u) => api('upgrade', {'kind': k.key, 'number': number}, u);
  Future<Json> buyListing(GiftKind k, int number, User u) => api('buy-listing', {'kind': k.key, 'number': number}, u);
  Future<Json> sendStars(String to, int amount, User u) => api('send-stars', {'to': to, 'amount': amount}, u);
  Future<Json> devStars(String to, int amount, User u) => api('dev-stars', {'to': to, 'amount': amount}, u);

  // ---------------- الهدايا ----------------
  /// هدايا مستخدم (من المجموعات الثلاث)
  Future<List<GiftItem>> myGifts(String uid) async {
    await load();
    final out = <GiftItem>[];
    final colls = kinds.values.map((k) => k.coll).toSet();
    final snaps = await Future.wait(colls.map((c) => _db.collection('users').doc(uid).collection(c).get()));
    var i = 0;
    for (final c in colls) {
      final sn = snaps[i++];
      final legacy = kinds.values.where((k) => k.coll == c && !k.gen).toList();
      for (final d in sn.docs) {
        final x = d.data();
        final key = c == 'gifts' ? x['k'] as String? : (legacy.isEmpty ? null : legacy.first.key);
        if (key != null && kinds.containsKey(key)) out.add(GiftItem.fromMap(x, key, owner: uid));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<String?> ownerOf(GiftKind k, int number) async {
    final id = k.gen ? '${k.key}_$number' : '$number';
    final d = await _db.collection(k.sales).doc(id).get();
    return d.data()?['ownerId'] as String?;
  }

  Future<GiftItem?> loadGift(GiftKind k, int number, String owner) async {
    final id = k.gen ? '${k.key}_$number' : '$number';
    final d = await _db.collection('users').doc(owner).collection(k.coll).doc(id).get();
    if (!d.exists) return null;
    return GiftItem.fromMap(d.data()!, k.key, owner: owner);
  }

  Future<int> issued(GiftKind k) async {
    final q = k.gen ? _db.collection('giftSales').where('k', isEqualTo: k.key) : _db.collection(k.sales);
    final c = await q.count().get();
    return c.count ?? 0;
  }

  // ---------------- السوق ----------------
  List<Json>? _lc;
  int _lcAt = 0;
  Future<List<Json>> listings({bool force = false}) async {
    if (!force && _lc != null && DateTime.now().millisecondsSinceEpoch - _lcAt < 45000) return _lc!;
    final s = await _db.collection('giftListings').orderBy('at', descending: true).limit(200).get();
    _lc = s.docs.map((d) => d.data()).toList();
    _lcAt = DateTime.now().millisecondsSinceEpoch;
    return _lc!;
  }

  Future<int?> floorFor(GiftKind k) async {
    final l = await listings();
    int? m;
    for (final x in l) {
      if (x['k'] != k.key) continue;
      final p = (x['price'] as num?)?.toInt();
      if (p != null && (m == null || p < m)) m = p;
    }
    return m;
  }

  Future<Json?> listingOf(GiftKind k, int number) async {
    final d = await _db.collection('giftListings').doc('${k.key}_$number').get();
    return d.data();
  }

  Future<void> sell(GiftKind k, GiftItem g, int price, String me, {bool update = false}) async {
    final ref = _db.collection('giftListings').doc('${k.key}_${g.number}');
    if (update) {
      await ref.update({'price': price});
    } else {
      await ref.set({
        'k': k.key,
        'number': g.number,
        'coll': k.coll,
        'sellerId': me,
        'price': price,
        'at': DateTime.now().millisecondsSinceEpoch,
        'giftAt': g.at,
        'model': g.model,
        'bg': g.bg,
        'sym': g.sym,
        'name': k.name,
      });
    }
    _lc = null;
  }

  Future<void> unlist(GiftKind k, int number) async {
    await _db.collection('giftListings').doc('${k.key}_$number').delete();
    _lc = null;
  }

  // ---------------- الإهداء (نقل ملكية + رسالة بالمحادثة) ----------------
  Future<void> transfer(GiftKind k, GiftItem g, String to, String me) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = k.gen ? '${k.key}_${g.number}' : '${g.number}';
    final pair = ([me, to]..sort()).join('__');
    final cref = _db.collection('chats').doc(pair);
    final cs = await cref.get();
    if (cs.exists) {
      await cref.update({'updatedAt': now});
    } else {
      await cref.set({'participants': [me, to], 'updatedAt': now});
    }
    final doc = <String, dynamic>{'number': g.number, 'upgraded': g.upgraded, 'at': g.at == 0 ? now : g.at};
    if (k.gen) doc['k'] = k.key;
    final msg = <String, dynamic>{
      'senderId': me,
      'type': 'gift',
      'k': k.key,
      'number': g.number,
      'upgraded': g.upgraded,
      'to': to,
      'text': '🎁 هدية ${k.name} #${g.number}',
      'createdAt': now,
      'read': false,
    };
    if (g.upgraded) {
      doc['model'] = g.model;
      doc['bg'] = g.bg;
      doc['sym'] = g.sym;
      msg['model'] = g.model;
      msg['bg'] = g.bg;
      msg['sym'] = g.sym;
    }
    final b = _db.batch();
    b.delete(_db.collection('users').doc(me).collection(k.coll).doc(id));
    b.set(_db.collection('users').doc(to).collection(k.coll).doc(id), doc);
    b.update(_db.collection(k.sales).doc(id), {'ownerId': to});
    b.set(_db.collection('giftEvents').doc('${k.key}_${g.number}').collection('log').doc(),
        {'k': k.key, 'number': g.number, 'coll': k.coll, 'type': 'send', 'from': me, 'to': to, 'at': now});
    b.set(cref.collection('messages').doc(), msg);
    await b.commit();
  }

  // ---------------- تثبيت/إخفاء (محلي) ----------------
  Future<void> loadPrefs(String uid) async {
    if (_prefUid == uid) return;
    _prefUid = uid;
    final p = await SharedPreferences.getInstance();
    _pins = (p.getStringList('gift_pins_$uid') ?? []).toSet();
    _hidden = (p.getStringList('gift_hidden_$uid') ?? []).toSet();
    notifyListeners();
  }

  bool isPinned(GiftItem g) => _pins.contains(g.id);
  bool isHidden(GiftItem g) => _hidden.contains(g.id);

  Future<void> togglePin(GiftItem g) async {
    _pins.contains(g.id) ? _pins.remove(g.id) : _pins.add(g.id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('gift_pins_$_prefUid', _pins.toList());
    notifyListeners();
  }

  Future<void> toggleHidden(GiftItem g) async {
    _hidden.contains(g.id) ? _hidden.remove(g.id) : _hidden.add(g.id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('gift_hidden_$_prefUid', _hidden.toList());
    notifyListeners();
  }
}
