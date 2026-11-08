import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../core/api.dart';
import '../core/utils.dart';

class AuthService extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? user;
  Map<String, dynamic>? me; // بيانات users/{uid}
  bool ready = false;

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
      ready = true;
      notifyListeners();
      return;
    }
    _meSub = _db.collection('users').doc(u.uid).snapshots().listen((d) {
      me = d.data();
      ready = true;
      notifyListeners();
    });
    _setPresence(true);
    _heartbeat = Timer.periodic(
        const Duration(seconds: 20), (_) => _setPresence(true));
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
    try {
      await u.sendEmailVerification();
    } catch (_) {}
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
