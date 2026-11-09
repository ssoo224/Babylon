import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class _Shell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Shell({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(radius: 1.0, colors: [p.authFrom, p.authTo]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.gold.withOpacity(.15),
                      border: Border.all(color: p.gold.withOpacity(.5)),
                    ),
                    child: Icon(icon, color: p.gold, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text(title,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 14),
                  child,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

mixin _Cooldown<T extends StatefulWidget> on State<T> {
  int cd = 0;
  Timer? _t;
  void startCooldown(int n) {
    _t?.cancel();
    setState(() => cd = n);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => cd--);
      if (cd <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

/// تأكيد البريد (رابط)
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with _Cooldown {
  String? _msg;
  bool _bad = false;
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final e = await context.read<AuthService>().checkVerified();
    if (mounted) {
      setState(() {
        _busy = false;
        _msg = e;
        _bad = true;
      });
    }
  }

  Future<void> _resend() async {
    final e = await context.read<AuthService>().sendVerification();
    if (!mounted) return;
    setState(() {
      _msg = e ?? 'أرسلنا الرابط من جديد إلى البريد (شيّك السبام)';
      _bad = e != null;
    });
    if (e == null) startCooldown(60);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final auth = context.watch<AuthService>();
    return _Shell(
      icon: Icons.mark_email_unread_outlined,
      title: 'فعّل بريدك',
      child: Column(children: [
        Text('أرسلنا رابط التحقق إلى',
            textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        const SizedBox(height: 4),
        Text(auth.user?.email ?? '',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.bold, color: p.text)),
        const SizedBox(height: 6),
        Text('افتح الرابط من بريدك ثم ارجع هنا واضغط الزر.',
            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 18),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_msg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _bad ? p.error : p.gold, fontSize: 13)),
          ),
        ElevatedButton(
          onPressed: _busy ? null : _check,
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('تحققت من البريد'),
        ),
        TextButton(
          onPressed: cd > 0 ? null : _resend,
          child: Text(cd > 0 ? 'إعادة الإرسال ($cd)' : 'إعادة إرسال الرابط',
              style: TextStyle(color: cd > 0 ? p.muted : p.gold)),
        ),
        TextButton(
          onPressed: () => auth.logout(),
          child: Text('تسجيل خروج', style: TextStyle(color: p.muted)),
        ),
      ]),
    );
  }
}

/// رمز الدخول (6 أرقام)
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with _Cooldown {
  final _c = TextEditingController();
  String? _msg;
  bool _bad = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  Future<void> _send() async {
    final r = await context.read<AuthService>().sendOtp();
    if (!mounted) return;
    setState(() {
      _msg = r.msg;
      _bad = !r.ok;
    });
    if (r.ok) startCooldown(60);
  }

  Future<void> _verify() async {
    final code = _c.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _busy) {
      if (code.length != 6) {
        setState(() {
          _msg = 'اكتب الرمز المكوّن من 6 أرقام';
          _bad = true;
        });
      }
      return;
    }
    setState(() => _busy = true);
    final e = await context.read<AuthService>().verifyOtp(code);
    if (mounted && e != null) {
      setState(() {
        _busy = false;
        _msg = e;
        _bad = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final auth = context.watch<AuthService>();
    return _Shell(
      icon: Icons.lock_outline,
      title: 'رمز التحقق',
      child: Column(children: [
        Text('أرسلنا رمز من 6 أرقام إلى',
            textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        const SizedBox(height: 4),
        Text(auth.user?.email ?? '',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.bold, color: p.text)),
        const SizedBox(height: 18),
        TextField(
          controller: _c,
          autofocus: true,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: 10),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_msg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _bad ? p.error : p.gold, fontSize: 13)),
          ),
        ElevatedButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('تأكيد'),
        ),
        TextButton(
          onPressed: cd > 0 ? null : _send,
          child: Text(cd > 0 ? 'إعادة الإرسال بعد $cd ثانية' : 'إعادة إرسال الرمز',
              style: TextStyle(color: cd > 0 ? p.muted : p.gold)),
        ),
        TextButton(
          onPressed: () => auth.logout(),
          child: Text('تسجيل خروج', style: TextStyle(color: p.muted)),
        ),
      ]),
    );
  }
}
