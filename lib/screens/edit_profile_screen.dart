import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/governorates.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';

/// شاشة تعديل البيانات الكاملة: الاسم، اليوزر، النبذة، المحافظة
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name, _user, _bio;
  String? _prov;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthService>().me ?? {};
    _name = TextEditingController(text: (me['displayName'] as String?) ?? '');
    _user = TextEditingController(text: (me['username'] as String?) ?? '');
    _bio = TextEditingController(text: (me['bio'] as String?) ?? '');
    final pv = me['province'] as String?;
    _prov = governorates.contains(pv) ? pv : null;
  }

  Future<void> _save() async {
    final auth = context.read<AuthService>();
    final me = auth.me ?? {};
    final name = _name.text.trim();
    final newU = _user.text.trim().toLowerCase().replaceFirst('@', '');
    final oldU = (me['username'] as String?) ?? '';
    if (name.isEmpty) return setState(() => _err = 'اكتب اسم العرض');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final upd = <String, dynamic>{
        'displayName': name,
        'bio': _bio.text.trim(),
        'province': _prov ?? '',
      };
      if (newU != oldU) {
        if (!isValidUsername(newU)) throw 'اليوزر مرفوض: 5 أحرف على الأقل ويبدأ بحرف';
        if (!await BabylonApi.usernameAvailable(newU)) throw 'اسم المستخدم مستخدم بالفعل';
        final db = FirebaseFirestore.instance;
        final b = db.batch();
        b.set(db.collection('usernames').doc(newU), {'uid': auth.uid, 'email': me['email'] ?? auth.user?.email ?? ''});
        if (oldU.isNotEmpty) b.delete(db.collection('usernames').doc(oldU));
        b.set(db.collection('users').doc(auth.uid), {...upd, 'username': newU}, SetOptions(merge: true));
        await b.commit();
      } else {
        await auth.updateProfile(upd);
      }
      if (mounted) {
        toast(context, 'تم الحفظ ✓');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e is String ? e : 'تعذر الحفظ، جرّب مرة ثانية';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
          child: Text(t, style: TextStyle(color: p.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        );
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('تعديل البيانات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        label('اسم العرض'),
        TextField(controller: _name, maxLength: 40),
        label('اسم المستخدم'),
        TextField(
          controller: _user,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: const InputDecoration(prefixText: '@'),
        ),
        label('النبذة'),
        TextField(controller: _bio, maxLength: 150, maxLines: 3),
        label('المحافظة'),
        DropdownButtonFormField<String>(
          value: _prov,
          hint: const Text('اختر محافظتك'),
          items: governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _prov = v),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_err!, style: TextStyle(color: p.error)),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ]),
    );
  }
}
