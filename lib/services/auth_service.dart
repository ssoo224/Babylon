import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../core/api.dart';
import '../core/utils.dart';

enum Gate { loading, signedOut, verifyEmail, otp, ready }

class AuthService extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? user;
  Map<String, dynamic>? me; // بيانات users/{uid}
  Gate gate = Gate.loading;
  bool get ready => gate != Gate.loading;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _meSub;
  Timer? _heartbeat;

  AuthService() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  String get uid => user!.uid;
  String get displayName => (me?['displayName'] as String?) ?? 'مستخدم';

  void _onAuth(User? u) {
    user = u;
    _meSub?.cancel();
    _heartbeat?.cancel();
    me = null;
    if (u == null) {
      gate = Gate.signedOut;
      notifyListeners();
      return;
    }
    _evaluateGate();
  }

  /// نفس منطق الأصل: بريد مؤكَّد ثم رمز OTP (claim: otpAuthTime == auth_time)
  Future<void> _evaluateGate() async {
    var u = _auth.currentUser;
    if (u == null) return;
    try {
      if (!u.emailVerified) {
        await u.reload();
        u = _auth.currentUser;
        if (u == null) return;
      }
      if (!u.emailVerified) {
        gate = Gate.verifyEmail;
        notifyListeners();
        sendVerification(auto: true);
        return;
      }
      final r = await u.getIdTokenResult(true);
      final c = r.claims ?? {};
      final otp = c['otpAuthTime'];
      final at = c['auth_time'];
      if (otp != null && at != null && num.parse('$otp') == num.parse('$at')) {
        _startSession();
      } else {
        gate = Gate.otp;
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        _startSession(); // بدون إنترنت: مثل الأصل ندخل بالحساب المخزَّن
      } else {
        gate = Gate.otp;
        notifyListeners();
      }
    } catch (_) {
      gate = Gate.otp;
      notifyListeners();
    }
  }

  void _startSession() {
    final u = _auth.currentUser;
    if (u == null) return;
    _meSub?.cancel();
    _meSub = _db.collection('users').doc(u.uid).snapshots().listen((d) {
      me = d.data();
      notifyListeners();
    });
    gate = Gate.ready;
    notifyListeners();
    _setPresence(true);
    _heartbeat?.cancel();
    _heartbeat =
        Timer.periodic(const Duration(seconds: 20), (_) => _setPresence(true));
  }

  DateTime? _lastVerifySent;

  /// رابط تأكيد البريد (مرة كل 60 ثانية عند الإرسال التلقائي)
  Future<String?> sendVerification({bool auto = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final now = DateTime.now();
    if (auto &&
        _lastVerifySent != null &&
        now.difference(_lastVerifySent!).inSeconds < 60) {
      return null;
    }
    _lastVerifySent = now;
    try {
      final r = await BabylonApi.post('/api/send-mail', {'type': 'verify'}, user: u);
      if (r.status == 200) return null;
      if (r.status == 429) return 'انتظر دقيقة ثم أعد المحاولة';
      await u.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'too-many-requests'
          ? 'محاولات كثيرة، انتظر دقائق وجرّب مرة ثانية'
          : 'تعذر إرسال رابط التحقق (${e.code})';
    } catch (_) {
      return 'تعذر الاتصال، تأكد من الإنترنت';
    }
  }

  /// بعد ما يفتح المستخدم رابط التأكيد من بريده
  Future<String?> checkVerified() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      await u.reload();
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {
      return 'تعذر الفحص، حاول مرة ثانية';
    }
    if (_auth.currentUser?.emailVerified != true) {
      return 'لم يتم التحقق بعد، افتح الرابط من بريدك أولاً';
    }
    await _evaluateGate();
    return null;
  }

  /// إرسال رمز الدخول (6 أرقام) إلى البريد
  Future<({bool ok, String msg})> sendOtp() async {
    final u = _auth.currentUser;
    if (u == null) return (ok: false, msg: '');
    try {
      final r = await BabylonApi.post('/api/send-mail', {'type': 'login-send'}, user: u);
      if (r.status == 200) {
        return (ok: true, msg: 'تم إرسال الرمز، شيّك بريدك (وصندوق السبام)');
      }
      if (r.status == 429) {
        return (ok: true, msg: 'الرمز انرسل قبل شوي، شيّك بريدك أو انتظر قليلاً');
      }
      return (ok: false, msg: 'تعذر إرسال الرمز، جرّب مرة ثانية');
    } catch (_) {
      return (ok: false, msg: 'تعذر الاتصال، تأكد من الإنترنت');
    }
  }

  /// يرجع null عند النجاح، أو رسالة الخطأ
  Future<String?> verifyOtp(String code) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      final r = await BabylonApi.post(
          '/api/send-mail', {'type': 'login-verify', 'code': code}, user: u);
      if (r.status == 200) {
        await u.getIdToken(true);
        _startSession();
        return null;
      }
      final e = r.data['error'];
      if (e == 'invalid') {
        final left = r.data['left'];
        return 'الرمز غلط${left != null ? ' (باقي $left محاولات)' : ''}';
      }
      if (e == 'locked') return 'تجاوزت عدد المحاولات، اطلب رمز جديد';
      if (e == 'expired') return 'انتهت صلاحية الرمز، اطلب رمز جديد';
      return 'تعذر التحقق، جرّب مرة ثانية';
    } catch (_) {
      return 'تعذر الاتصال، جرّب مرة ثانية';
    }
  }

  Future<void> _setPresence(bool online) async {
    if (user == null) return;
    try {
      await _db.collection('users').doc(user!.uid).set(
        {'online': online, 'lastSeen': DateTime.now().millisecondsSinceEpoch},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _setPresence(true);
    } else if (s == AppLifecycleState.paused) {
      _setPresence(false);
    }
  }

  // ---------- تسجيل الدخول ----------
  /// يقبل بريد أو يوزر (مع أو بدون @) — مثل نسخة الويب تماماً
  Future<void> login(String input, String password) async {
    var v = input.trim();
    if (v.startsWith('@')) v = v.substring(1);
    String email = v;
    if (!v.contains('@')) {
      final resolved = await BabylonApi.resolveLogin(v.toLowerCase(), password);
      if (resolved == null) throw 'اسم المستخدم أو كلمة المرور غير صحيحة';
      email = resolved;
    }
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      throw 'البريد/اليوزر أو كلمة المرور غير صحيحة';
    }
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    username = username.trim().toLowerCase();
    if (name.trim().isEmpty) throw 'الرجاء إدخال اسم العرض';
    if (!isValidUsername(username)) {
      throw 'اليوزر مرفوض: لازم يكون 5 أحرف على الأقل ويبدأ بحرف';
    }
    if (password.length < 6) throw 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    if (!await BabylonApi.usernameAvailable(username)) {
      throw 'اسم المستخدم مستخدم بالفعل أو غير صالح!';
    }
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'email-already-in-use' => 'هذا البريد مسجل مسبقاً',
        'invalid-email' => 'البريد الإلكتروني غير صالح',
        'weak-password' => 'كلمة المرور ضعيفة',
        _ => e.message ?? 'تعذر إنشاء الحساب',
      };
    }
    final u = cred.user!;
    final data = {
      'id': u.uid,
      'displayName': name.trim(),
      'username': username,
      'email': email.trim(),
      'bio': '',
      'avatarUrl': '',
      'isVerified': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(u.uid), data);
    batch.set(_db.collection('usernames').doc(username),
        {'uid': u.uid, 'email': email.trim()});
    try {
      await batch.commit();
    } catch (_) {
      await u.delete().catchError((_) {});
      throw 'اسم المستخدم مستخدم بالفعل!';
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await BabylonApi.sendReset(email.trim());
    } catch (_) {
      await _auth.sendPasswordResetEmail(email: email.trim());
    }
  }

  Future<void> logout() async {
    await _setPresence(false);
    await _auth.signOut();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) =>
      _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _meSub?.cancel();
    _heartbeat?.cancel();
    super.dispose();
  }
}
