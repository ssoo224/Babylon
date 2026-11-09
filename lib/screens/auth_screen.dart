import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
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
    final p = BP.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.0,
            colors: [p.authFrom, p.authTo],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  Container(
                    width: 90,
                    height: 90,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFC29D30), Color(0xFFB38F27)],
                      ),
                      border: Border.all(color: const Color(0xFFFFF5C0), width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x4DD4AF37),
                            blurRadius: 25,
                            offset: Offset(0, 10)),
                      ],
                    ),
                    child: Image.asset('assets/logo.png',
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 20),
                  Text('Babylon Chat',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, color: p.gold)),
                  const SizedBox(height: 6),
                  Text('تواصل عبر البريد أو اسم المستخدم بنكهة بابلية أصيلة',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: p.muted)),
                  const SizedBox(height: 24),
                  _tabs(p),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    _field(p, 'اسم العرض (الاسم الشخصي)', _name, 'Your Name'),
                    _field(p, 'اسم المستخدم (5 أحرف فأكثر)', _user, 'ali', ltr: true),
                    _field(p, 'البريد الإلكتروني', _email, 'name@domain.com',
                        ltr: true, type: TextInputType.emailAddress),
                  ] else
                    _field(p, 'البريد الإلكتروني أو اسم المستخدم (@)', _id,
                        'name@domain.com أو ali'),
                  _field(p, 'كلمة المرور', _pass, '••••••••',
                      ltr: true,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!,
                          style: TextStyle(color: p.error, fontSize: 12)),
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
                    TextButton(
                      onPressed: _forgot,
                      child: Text('نسيت كلمة المرور؟',
                          style: TextStyle(color: p.gold, fontSize: 13)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs(BP p) {
    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? p.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: active ? (p.dark ? p.bg : Colors.white) : p.muted)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(children: [
        tab('تسجيل الدخول', !_register, () => setState(() {
              _register = false;
              _error = null;
            })),
        tab('إنشاء حساب', _register, () => setState(() {
              _register = true;
              _error = null;
            })),
      ]),
    );
  }

  Widget _field(BP p, String label, TextEditingController c, String hint,
      {bool ltr = false, bool obscure = false, Widget? suffix, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.gold)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          autocorrect: false,
          style: const TextStyle(fontSize: 14),
          textDirection: ltr ? TextDirection.ltr : null,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ]),
    );
  }
}
