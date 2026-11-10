import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';

/// صفحة التحديث (إجباري/اختياري) — تصميم نهاري دائماً مثل الأصل
class UpdateScreen extends StatefulWidget {
  final bool forced;
  const UpdateScreen({super.key, required this.forced});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  String _mb(int b) => (b / 1048576).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UpdateController>();
    const gold = Color(0xFFB8902A);
    const ink = Color(0xFF17212B);
    const muted = Color(0xFF68798D);
    final busy = up.status == UpStatus.downloading;
    final err = up.status == UpStatus.error;

    String btn;
    VoidCallback? action;
    switch (up.status) {
      case UpStatus.downloading:
        btn = 'جاري التنزيل ${(up.progress * 100).floor()}%';
        action = null;
        break;
      case UpStatus.installing:
        btn = 'تثبيت التحديث';
        action = up.install;
        break;
      case UpStatus.needPermission:
        btn = 'بانتظار السماح';
        action = up.install;
        break;
      default:
        btn = 'تحديث الآن';
        action = up.startUpdate;
    }

    return PopScope(
      canPop: !widget.forced && !busy,
      child: Theme(
        data: ThemeData(useMaterial3: true, brightness: Brightness.light, colorScheme: ColorScheme.fromSeed(seedColor: gold)),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF6DC), Colors.white]),
            ),
            child: SafeArea(
              child: Stack(children: [
                // نجوم خفيفة
                for (final s in const [
                  [.12, .10, 14.0], [.82, .16, 10.0], [.2, .34, 8.0], [.9, .42, 12.0], [.08, .62, 10.0], [.78, .72, 8.0]
                ])
                  Positioned(
                    left: MediaQuery.of(context).size.width * (s[0]),
                    top: MediaQuery.of(context).size.height * (s[1]),
                    child: Icon(Icons.star_rounded, size: s[2], color: gold.withOpacity(.25)),
                  ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // الأيقونة + توهج + حلقة التقدم
                        AnimatedBuilder(
                          animation: _glow,
                          builder: (_, child) => Container(
                            width: 150,
                            height: 150,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: gold.withOpacity(.18 + .22 * math.sin(_glow.value * math.pi)),
                                    blurRadius: 40 + 20 * _glow.value,
                                    spreadRadius: 4),
                              ],
                            ),
                            child: child,
                          ),
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox(
                              width: 128,
                              height: 128,
                              child: CircularProgressIndicator(
                                value: busy ? (up.progress == 0 ? null : up.progress) : (up.status == UpStatus.installing ? 1 : 0),
                                strokeWidth: 5,
                                color: gold,
                                backgroundColor: gold.withOpacity(.15),
                              ),
                            ),
                            Container(
                              width: 100,
                              height: 100,
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFD9B545), Color(0xFFB38F27)]),
                              ),
                              child: Image.asset('assets/logo.png', color: Colors.white),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 22),
                        Text(widget.forced ? 'تحديث مطلوب' : 'يوجد تحديث جديد',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
                        const SizedBox(height: 8),
                        Text(
                          widget.forced
                              ? 'لازم تحدّث التطبيق حتى يكمل يشتغل.'
                              : 'صدرت نسخة جديدة من Babylon Chat.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14.5, color: muted),
                        ),
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, children: [
                          _chip('نسختك ${up.cur}', muted),
                          _chip('الأحدث ${up.target}', gold),
                        ]),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE9DDB8)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Row(children: [
                              Icon(Icons.auto_awesome, size: 18, color: gold),
                              SizedBox(width: 6),
                              Text('شنو الجديد', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                            ]),
                            const SizedBox(height: 6),
                            Text(up.notes.isNotEmpty ? up.notes : 'تحسينات وإصلاحات.',
                                style: const TextStyle(height: 1.5, color: ink)),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        if (busy) ...[
                          Text(
                            up.totalBytes > 0
                                ? 'جاري التنزيل  ${(up.progress * 100).floor()}%  ·  ${_mb(up.gotBytes)} / ${_mb(up.totalBytes)} MB'
                                : 'جاري التنزيل  ${_mb(up.gotBytes)} MB',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
                          ),
                          const SizedBox(height: 4),
                          const Text('لا تطلع من التطبيق لحد ما يخلص التنزيل.',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: muted)),
                          const SizedBox(height: 12),
                        ] else if (up.message.isNotEmpty) ...[
                          Text(up.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.5, height: 1.5, color: err ? const Color(0xFFC0392B) : ink)),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: action,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: gold.withOpacity(.55),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            child: Text(btn),
                          ),
                        ),
                        if (err || up.status == UpStatus.needPermission) ...[
                          const SizedBox(height: 8),
                          const Text('إذا ما بدأ التنزيل، انسخ الرابط وافتحه بكروم:',
                              style: TextStyle(fontSize: 12.5, color: muted)),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            TextButton(
                              onPressed: () async {
                                await up.copyLink();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('تم النسخ')));
                                }
                              },
                              child: const Text('نسخ الرابط'),
                            ),
                            TextButton(onPressed: up.openInBrowser, child: const Text('فتح بالمتصفح')),
                          ]),
                        ],
                        if (!widget.forced && !busy)
                          TextButton(
                            onPressed: () {
                              up.later();
                              Navigator.of(context).maybePop();
                            },
                            child: const Text('لاحقاً', style: TextStyle(color: muted, fontSize: 15)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(.35)),
        ),
        child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
      );
}
