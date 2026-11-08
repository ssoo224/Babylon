import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  final _id = TextEditingController(); // بريد أو يوزر (للدخول)
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await auth.register(
          name: _name.text,
          username: _user.text,
          email: _email.text,
          password: _pass.text,
        );
      } else {
        if (_id.text.trim().isEmpty) throw 'الرجاء أدخل البريد أو اسم المستخدم';
        if (_pass.text.isEmpty) throw 'الرجاء أدخل كلمة المرور';
        await auth.login(_id.text, _pass.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _id.text.contains('@') ? _id.text : '');
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استعادة كلمة المرور'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'البريد الإلكتروني'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('إرسال')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;
    try {
      await context.read<AuthService>().resetPassword(email);
      if (mounted) toast(context, 'تم إرسال رابط الاستعادة إلى بريدك');
    } catch (_) {
      if (mounted) toast(context, 'تعذر الإرسال، تأكد من البريد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(children: [
                Text('بابيلون',
                    style: TextStyle(
                        fontSize: 44, fontWeight: FontWeight.bold, color: gold)),
                const SizedBox(height: 6),
                Text(_register ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 28),
                if (_register) ...[
                  _field(_name, 'اسم العرض', Icons.person_outline),
                  _field(_user, 'اسم المستخدم (5 أحرف على الأقل)', Icons.alternate_email,
                      ltr: true),
                  _field(_email, 'البريد الإلكتروني', Icons.mail_outline,
                      ltr: true, type: TextInputType.emailAddress),
                ] else
                  _field(_id, 'البريد أو اسم المستخدم', Icons.person_outline, ltr: true),
                _field(_pass, 'كلمة المرور', Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_register ? 'إنشاء الحساب' : 'دخول'),
                ),
                if (!_register)
                  TextButton(onPressed: _forgot, child: const Text('نسيت كلمة المرور؟')),
                TextButton(
                  onPressed: () => setState(() {
                    _register = !_register;
                    _error = null;
                  }),
                  child: Text(_register
                      ? 'لدي حساب — تسجيل الدخول'
                      : 'ليس لديك حساب؟ أنشئ حساباً'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool ltr = false,
      bool obscure = false,
      Widget? suffix,
      TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        autocorrect: false,
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
