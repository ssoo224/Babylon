import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/api.dart';

/// ملصق واحد (نفس toSt في الأصل): s=اسم الحزمة، i=المعرّف، u=الرابط، k=النوع، e=الإيموجي
class Sticker {
  final String s, i, u, k, e;
  final int w, h;
  const Sticker({
    required this.s,
    required this.i,
    required this.u,
    required this.k,
    required this.e,
    this.w = 512,
    this.h = 512,
  });

  Map<String, dynamic> toMap() => {'s': s, 'i': i, 'u': u, 'k': k, 'e': e, 'w': w, 'h': h};

  /// الحقل sticker داخل الرسالة
  Map<String, dynamic> toMessage() =>
      {'set': s, 'id': i, 'url': u, 'kind': k, 'emoji': e, 'w': w, 'h': h};

  bool same(Sticker o) => o.s == s && o.i == i;

  static Sticker? fromMap(dynamic m) {
    if (m is! Map) return null;
    final s = m['s'], i = m['i'], u = m['u'];
    if (s is! String || i is! String || u is! String) return null;
    return Sticker(
      s: s,
      i: i,
      u: u,
      k: (m['k'] as String?) ?? 'static',
      e: (m['e'] as String?) ?? '🙂',
      w: (m['w'] as num?)?.toInt() ?? 512,
      h: (m['h'] as num?)?.toInt() ?? 512,
    );
  }

  static Sticker? fromMessage(dynamic m) {
    if (m is! Map) return null;
    final s = m['set'], i = m['id'], u = m['url'];
    if (u is! String) return null;
    return Sticker(
      s: (s as String?) ?? '',
      i: (i as String?) ?? '',
      u: u,
      k: (m['kind'] as String?) ?? 'static',
      e: (m['emoji'] as String?) ?? '🙂',
      w: (m['w'] as num?)?.toInt() ?? 512,
      h: (m['h'] as num?)?.toInt() ?? 512,
    );
  }
}

class StickerSet {
  final Map<String, dynamic> meta;
  final List<Sticker> stickers;
  StickerSet(this.meta, this.stickers);
  String get name => (meta['name'] as String?) ?? '';
  String get title => (meta['title'] as String?) ?? '';
  String get ownerId => (meta['ownerId'] as String?) ?? '';
  String get ownerName => (meta['ownerName'] as String?) ?? '';
  String get kind => (meta['kind'] as String?) ?? 'static';
  int get updatedAt => (meta['updatedAt'] as num?)?.toInt() ?? 0;
  bool get hidden => meta['hidden'] == true;
}

class StickerError implements Exception {
  final String code;
  final String message;
  StickerError(this.code, this.message);
  @override
  String toString() => message;
}

const _err = {
  'name': 'الاسم غير صالح: من 5 إلى 32 حرفاً إنجليزياً صغيراً وأرقاماً و _',
  'taken': 'هذا الاسم محجوز، جرّب اسماً آخر',
  'title': 'العنوان مطلوب (حتى 40 حرفاً)',
  'emoji': 'اختر إيموجي للملصق',
  'size': 'حجم الملف أكبر من المسموح',
  'dimensions': 'الأبعاد غير مناسبة: يجب أن يكون أحد الضلعين 512 بكسل',
  'format': 'صيغة الملف غير مدعومة',
  'duration': 'مدة الحركة أطول من 3 ثوانٍ',
  'expressions': 'ملف الحركة يحتوي تعابير غير مسموحة',
  'layers': 'ملف الحركة يحتوي نصوصاً أو صوراً غير مسموحة',
  'assets': 'ملف الحركة يحتوي صوراً خارجية',
  'complex': 'ملف الحركة معقّد جداً',
  'full': 'الحزمة ممتلئة (120 ملصق)',
  'setlimit': 'وصلت الحد الأقصى من الحزم',
  'rate': 'محاولات كثيرة، انتظر قليلاً',
  'owner': 'هذه ليست حزمتك',
  'last': 'هذا آخر ملصق، احذف الحزمة بدلاً منه',
  'url': 'تعذر قراءة الملف المرفوع',
  'file': 'تعذر قراءة الملف المرفوع',
  'noset': 'الحزمة غير موجودة',
  'own': 'لا يمكنك الإبلاغ عن حزمتك',
  'unverified': 'أكّد بريدك أولاً',
  'otp': 'سجّل الدخول من جديد',
};

/// ملصقات بابل (على طريقة تليجرام): بيانات المستخدم + تحميل الحزم + العمليات عبر /api/stickers
class StickerService extends ChangeNotifier {
  static const maxRecent = 30, maxFaves = 5;
  final _db = FirebaseFirestore.instance;
  String? _uid;
  Timer? _t;

  List<String> installed = [];
  List<Sticker> recent = [];
  List<Sticker> faves = [];
  bool loaded = false;
  final Map<String, StickerSet> sets = {};

  DocumentReference<Map<String, dynamic>> _dataRef(String uid) =>
      _db.collection('users').doc(uid).collection('stickerData').doc('main');

  /// users/{uid}/stickerData/main => installed / recent / faves
  Future<void> ensure(String uid) async {
    if (_uid == uid && loaded) return;
    if (_uid != uid) {
      _uid = uid;
      loaded = false;
      installed = [];
      recent = [];
      faves = [];
      sets.clear();
    }
    try {
      final d = await _dataRef(uid).get();
      final v = d.data() ?? {};
      installed = ((v['installed'] as List?) ?? []).whereType<String>().take(100).toList();
      recent = ((v['recent'] as List?) ?? []).map(Sticker.fromMap).whereType<Sticker>().take(maxRecent).toList();
      faves = ((v['faves'] as List?) ?? []).map(Sticker.fromMap).whereType<Sticker>().take(maxFaves).toList();
      loaded = true;
      notifyListeners();
    } catch (_) {
      // لا نكتب فوق بياناتنا لو فشلت القراءة
    }
  }

  void _save() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 600), () {
      final u = _uid;
      if (u == null || !loaded) return;
      _dataRef(u).set({
        'installed': installed,
        'recent': recent.map((x) => x.toMap()).toList(),
        'faves': faves.map((x) => x.toMap()).toList(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).catchError((_) {});
    });
  }

  bool isInstalled(String n) => installed.contains(n);

  void install(String n) {
    if (isInstalled(n)) return;
    installed.insert(0, n);
    _save();
    notifyListeners();
  }

  void uninstall(String n) {
    installed.remove(n);
    _save();
    notifyListeners();
  }

  void pushRecent(Sticker st) {
    recent.removeWhere(st.same);
    recent.insert(0, st);
    if (recent.length > maxRecent) recent = recent.sublist(0, maxRecent);
    _save();
    notifyListeners();
  }

  bool isFave(Sticker st) => faves.any(st.same);

  /// يرجع رسالة للمستخدم
  String toggleFave(Sticker st) {
    if (isFave(st)) {
      faves.removeWhere(st.same);
      _save();
      notifyListeners();
      return 'أُزيل من المفضلة';
    }
    if (faves.length >= maxFaves) return 'المفضلة تتسع لـ $maxFaves ملصقات فقط';
    faves.insert(0, st);
    _save();
    notifyListeners();
    return 'أُضيف للمفضلة';
  }

  /// null = الحزمة غير موجودة/مخفية، ويرمي استثناء عند فشل مؤقت
  Future<StickerSet?> loadSet(String name, {bool isDev = false}) async {
    final d = await _db.collection('stickerSets').doc(name).get();
    if (!d.exists) return null;
    final m = d.data()!;
    if (m['hidden'] == true && m['ownerId'] != _uid && !isDev) return null;
    final cached = sets[name];
    if (cached != null && cached.updatedAt == ((m['updatedAt'] as num?)?.toInt() ?? 0)) return cached;
    final q = await d.reference.collection('stickers').orderBy('order').get();
    final st = q.docs
        .map((x) => Sticker(
              s: name,
              i: x.id,
              u: (x.data()['url'] as String?) ?? '',
              k: (x.data()['kind'] as String?) ?? 'static',
              e: (x.data()['emoji'] as String?) ?? '🙂',
              w: (x.data()['w'] as num?)?.toInt() ?? 512,
              h: (x.data()['h'] as num?)?.toInt() ?? 512,
            ))
        .where((x) => x.u.isNotEmpty)
        .toList();
    final set = StickerSet({...m, 'name': m['name'] ?? name}, st);
    sets[name] = set;
    return set;
  }

  Future<List<StickerSet>> loadInstalled() async {
    final names = List<String>.from(installed);
    final res = await Future.wait(names.map((n) async {
      try {
        return (n, await loadSet(n), false);
      } catch (_) {
        return (n, null as StickerSet?, true);
      }
    }));
    final gone = [for (final r in res) if (r.$2 == null && !r.$3) r.$1];
    if (gone.isNotEmpty) {
      installed.removeWhere(gone.contains);
      _save();
    }
    return [for (final r in res) if (r.$2 != null) r.$2!];
  }

  /// كل الملصقات المثبتة المطابقة لإيموجي (اقتراح عند كتابة إيموجي)
  List<Sticker> suggestFor(String emoji) {
    final q = emoji.replaceAll('\uFE0F', '');
    if (q.isEmpty) return [];
    final out = <Sticker>[];
    for (final n in installed) {
      final s = sets[n];
      if (s == null) continue;
      for (final st in s.stickers) {
        if (st.e.replaceAll('\uFE0F', '').contains(q)) out.add(st);
      }
    }
    return out.take(20).toList();
  }

  // ---------------- العمليات عبر /api/stickers ----------------
  Future<Map<String, dynamic>> api(String op, Map<String, dynamic> body, User user) async {
    final r = await BabylonApi.post('/api/stickers', {'op': op, ...body}, user: user);
    if (r.status >= 200 && r.status < 300 && r.data['ok'] == true) return r.data;
    final code = (r.data['error'] as String?) ?? 'http${r.status}';
    throw StickerError(code, _err[code] ?? 'تعذر إكمال العملية');
  }

  /// null = متاح، وإلا رسالة السبب
  Future<String?> checkName(String name, User user) async {
    try {
      final r = await BabylonApi.post('/api/stickers', {'op': 'check', 'name': name}, user: user);
      if (r.data['ok'] == true) return null;
      final reason = r.data['reason'] ?? r.data['error'];
      return reason == 'taken' ? _err['taken'] : _err['name'];
    } catch (_) {
      return 'تعذر التحقق من الاسم';
    }
  }

  Future<List<StickerSet>> myPacks(String uid) async {
    final q = await _db.collection('stickerSets').where('ownerId', isEqualTo: uid).get();
    return q.docs.map((d) => StickerSet({...d.data(), 'name': d.data()['name'] ?? d.id}, [])).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void invalidate(String name) => sets.remove(name);

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}
