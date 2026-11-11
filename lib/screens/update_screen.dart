import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';

const _svgUp =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V4"/><path d="M7 9l5-5 5 5"/><path d="M5 20h14"/></svg>';
const _svgOk =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
const _svgWarn =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8v5"/><circle cx="12" cy="16.5" r=".6" fill="#fff"/><path d="M10.3 3.9L2.4 17.6a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>';

const _ink = Color(0xFF16202B);

/// حلقة التقدم: مسار + تعبئة متدرجة (نفس SVG الأصلي r=62 من 150)
class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  _RingPainter(this.progress);
  @override
  void paint(Canvas c, Size s) {
    final r = s.width * 62 / 150;
    final center = Offset(s.width / 2, s.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
        center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0x38D6AA32));
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final grad = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF3C4), Color(0xFFCBA843)],
    ).createShader(Rect.fromLTWH(0, 0, s.width, s.height));
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x73C99A1C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    c.drawArc(rect, -math.pi / 2, sweep, false, glow);
    c.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = grad);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

/// صفحة التحديث الأصلية (v2): نهارية دائماً، توهّج متحرك، حلقتان نابضتان، حلقة تقدم، بطاقة "شنو الجديد"، زر لامع
class UpdateScreen extends StatefulWidget {
  final bool forced;
  const UpdateScreen({super.key, required this.forced});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> with TickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat(reverse: true);
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  String _copyLabel = 'نسخ الرابط';

  @override
  void dispose() {
    _breath.dispose();
    _ring.dispose();
    _shine.dispose();
    super.dispose();
  }

  Widget _expandingRing(double phase) {
    return AnimatedBuilder(
      animation: _ring,
      builder: (_, __) {
        final t = (_ring.value + phase) % 1.0;
        final eased = Curves.easeOut.transform(t);
        return Opacity(
          opacity: (0.8 * (1 - eased)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.72 + (1.32 - 0.72) * eased,
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x80C99A1C), width: 1.5),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UpdateController>();
    final st = up.status;
    final busy = st == UpStatus.downloading;
    final err = st == UpStatus.error;
    final ready = st == UpStatus.installing;
    final perm = st == UpStatus.needPermission;
    final pct = (up.progress * 100).round();
    final size = MediaQuery.of(context).size;

    String msg;
    if (busy) {
      msg = 'لا تطلع من التطبيق لحد ما يخلص التنزيل.';
    } else if (ready) {
      msg = 'اكتمل التنزيل. اضغط تثبيت بالنافذة اللي طلعت، وبعدها افتح التطبيق.';
    } else if (perm) {
      msg = 'فعّل خيار (السماح بالتثبيت من هذا المصدر) لبابل ثم ارجع للتطبيق، وسيبدأ التنزيل تلقائياً.';
    } else if (err) {
      const base = 'تعذر التنزيل داخل التطبيق. انسخ الرابط وافتحه بكروم.';
      msg = (up.message.isNotEmpty && !up.message.startsWith('تعذر التنزيل داخل')) ? '$base\n${up.message}' : base;
    } else {
      msg = widget.forced ? 'لازم تحدّث التطبيق حتى يكمل يشتغل.' : 'صدرت نسخة جديدة من Babylon Chat.';
    }

    final coreColors = err
        ? const [Color(0xFFFF9A8F), Color(0xFFE0443E), Color(0xFFA42A26)]
        : const [Color(0xFFFFF1B0), Color(0xFFF4D56A), Color(0xFFE8BF45), Color(0xFFD9A830)];
    final coreStops = err ? const [0.0, .6, 1.0] : const [0.0, .28, .62, 1.0];

    Widget coreChild;
    if (busy) {
      coreChild = Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$pct', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))])),
          const Text('%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
      );
    } else if (ready) {
      coreChild = SvgPicture.string(_svgOk, width: 50, height: 50);
    } else if (err) {
      coreChild = SvgPicture.string(_svgWarn, width: 46, height: 46);
    } else {
      coreChild = SvgPicture.string(_svgUp, width: 46, height: 46);
    }

    String btn;
    VoidCallback? action;
    if (busy) {
      btn = 'جاري التنزيل…';
    } else if (ready) {
      btn = 'تثبيت التحديث';
      action = up.install;
    } else if (perm) {
      btn = 'بانتظار السماح…';
    } else {
      btn = 'تحديث الآن';
      action = up.startUpdate;
    }
    final enabled = action != null;

    return PopScope(
      canPop: !widget.forced && !busy,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.15),
              radius: 1.45,
              colors: [Color(0xFFFFF6DC), Color(0xFFFFFFFF), Color(0xFFEDF2F8)],
              stops: [0, .46, 1],
            ),
          ),
          child: Stack(children: [
            // توهّج متحرك خلف الأيقونة
            Positioned(
              top: size.height * .18,
              left: (size.width - 340) / 2,
              child: AnimatedBuilder(
                animation: _breath,
                builder: (_, __) {
                  final v = Curves.easeInOut.transform(_breath.value);
                  return Opacity(
                    opacity: .75 + .25 * v,
                    child: Transform.scale(
                      scale: 1 + .08 * v,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                              colors: [Color(0x4DE8BE46), Color(0x00E8BE46)], stops: [0, .68]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // الأيقونة + الحلقتان + حلقة التقدم
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(alignment: Alignment.center, children: [
                          _expandingRing(0),
                          _expandingRing(.5),
                          CustomPaint(
                            size: const Size(150, 150),
                            painter: _RingPainter(ready ? 1 : (busy ? up.progress : 0)),
                          ),
                          Container(
                            width: 104,
                            height: 104,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: coreColors,
                                  stops: coreStops),
                              border: Border.all(
                                  color: err ? const Color(0xFFFFD0CB) : const Color(0xFFFFF6CF), width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: err ? const Color(0x66E0443E) : const Color(0x73E8BE46),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10)),
                              ],
                            ),
                            child: coreChild,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      // شريحة النسخة (ltr): v62 → v70
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x1FC99A1C),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x66C99A1C)),
                          ),
                          child: Text(
                            '${up.cur > 0 ? 'v${up.cur} → ' : ''}v${up.target}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .4, color: Color(0xFF8A6200)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE3AE2C), Color(0xFFB47F00)],
                          stops: [0, .75],
                        ).createShader(r),
                        child: Text(widget.forced ? 'تحديث مطلوب' : 'يوجد تحديث جديد',
                            style: const TextStyle(
                                fontSize: 27, fontWeight: FontWeight.w900, height: 1.25, color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(msg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14.5, height: 1.95, color: Color(0xB816202B))),
                      ),
                      const SizedBox(height: 20),
                      if (up.notes.trim().isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x1416202B)),
                            boxShadow: const [BoxShadow(color: Color(0x0F16202B), blurRadius: 20, offset: Offset(0, 6))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Row(children: [
                              Icon(Icons.auto_awesome, size: 14, color: Color(0xFFA8790F)),
                              SizedBox(width: 6),
                              Text('شنو الجديد',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFA8790F))),
                            ]),
                            const SizedBox(height: 8),
                            Text(up.notes.trim(), style: const TextStyle(fontSize: 13.5, height: 1.9, color: _ink)),
                          ]),
                        ),
                      // الزر الذهبي اللامع
                      Opacity(
                        opacity: enabled ? 1 : .7,
                        child: GestureDetector(
                          onTap: action,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 58),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF6DD83), Color(0xFFCBA843), Color(0xFFB38A22)],
                                stops: [0, .6, 1],
                              ),
                              boxShadow: const [BoxShadow(color: Color(0x61CBA843), blurRadius: 30, offset: Offset(0, 12))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(alignment: Alignment.center, children: [
                                if (enabled)
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _shine,
                                      builder: (_, __) {
                                        final t = const Interval(0, .55, curve: Curves.easeInOut)
                                            .transform(_shine.value);
                                        return LayoutBuilder(builder: (context, c) {
                                          final w = c.maxWidth;
                                          return Transform.translate(
                                            offset: Offset(-80 + (w + 160) * t, 0),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Transform(
                                                transform: Matrix4.skewX(-.32),
                                                child: Container(
                                                  width: 60,
                                                  decoration: const BoxDecoration(
                                                    gradient: LinearGradient(colors: [
                                                      Color(0x00FFFFFF),
                                                      Color(0x8CFFFFFF),
                                                      Color(0x00FFFFFF)
                                                    ]),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 17),
                                  child: Text(btn,
                                      style: const TextStyle(
                                          fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF2A1D06))),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      if (err) ...[
                        const SizedBox(height: 18),
                        const Text('إذا ما بدأ التنزيل، انسخ الرابط وافتحه بكروم:',
                            style: TextStyle(fontSize: 12.5, height: 1.8, color: Color(0x8C16202B))),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x0D16202B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1A16202B)),
                          ),
                          child: SelectableText(up.apkUrl,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(fontSize: 12, color: _ink)),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              await up.copyLink();
                              if (mounted) setState(() => _copyLabel = 'تم النسخ ✓');
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF8A6200),
                              side: const BorderSide(color: Color(0x8CC99A1C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            child: Text(_copyLabel),
                          ),
                        ),
                        TextButton(onPressed: up.openInBrowser, child: const Text('فتح بالمتصفح')),
                      ],
                      if (!widget.forced && !busy)
                        TextButton(
                          onPressed: () {
                            up.later();
                            Navigator.of(context).maybePop();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                            child: Text('لاحقاً', style: TextStyle(fontSize: 14.5, color: Color(0x8C16202B))),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
