import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/gift_data.dart';
import '../services/gift_service.dart';
import '../services/sticker_service.dart';
import 'sticker_view.dart';

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

final Map<int, String> _patCache = {};

/// شبكة الرموز حول الهدية (patInner الأصلية): 4 حلقات من الرمز بدوران وشفافية
String patternSvg(int si) {
  return _patCache.putIfAbsent(si, () {
    final sym = giftSyms[si.clamp(0, giftSyms.length - 1)];
    const rings = [
      [29, 7, 7.6, .24],
      [42, 10, 6.4, .17],
      [55, 13, 5.4, .12],
      [68, 16, 4.6, .085],
    ];
    final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">');
    for (var ri = 0; ri < rings.length; ri++) {
      final r = rings[ri];
      final n = (r[1] as num).toInt();
      for (var k = 0; k < n; k++) {
        final a = 2 * math.pi * k / n + (ri % 2) * math.pi / n - math.pi / 2;
        final x = 50 + (r[0] as num) * math.cos(a);
        final y = 44 + (r[0] as num) * math.sin(a) * 1.02;
        final rot = ((k * 47 + ri * 23) % 50) - 25;
        b.write('<g transform="translate(${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)}) rotate($rot) scale(${((r[2] as num) / 24).toStringAsFixed(3)}) translate(-12 -12)" opacity="${r[3]}"><path d="${sym.d}"${sym.evenOdd ? ' fill-rule="evenodd"' : ''} fill="#fff"/></g>');
      }
    }
    b.write('</svg>');
    return b.toString();
  });
}

/// ألوان الخلفية (bgCss): غير مرقّاة = رمادي داكن
(Color, Color) giftColors(GiftItem? g) {
  if (g != null && g.upgraded) {
    final b = giftBgs[g.bg.clamp(0, giftBgs.length - 1)];
    return (_hex(b.a), _hex(b.b));
  }
  return (_hex('#3b414d'), _hex('#12151b'));
}

/// رسم الهدية: خلفية شعاعية + رموز + أنيميشن/صورة النموذج + شريط الرقم
class GiftArt extends StatelessWidget {
  final GiftKind kind;
  final GiftItem? gift; // null = معاينة المتجر (الشكل الأصلي)
  final double size;
  final bool animate;
  final bool ribbon;
  final bool rounded;
  const GiftArt({
    super.key,
    required this.kind,
    this.gift,
    this.size = 120,
    this.animate = false,
    this.ribbon = false,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final up = gift != null && gift!.upgraded;
    final mi = up ? gift!.model : -1;
    final (a, b) = giftColors(gift);
    final art = animate
        ? StickerView(
            st: Sticker(s: '', i: '', u: kind.tgsUrl(mi), k: 'animated', e: '🎁'),
            size: size * .72,
            play: true,
          )
        : Image.network(
            kind.pngUrl(mi),
            width: size * .72,
            height: size * .72,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => StickerView(
              st: Sticker(s: '', i: '', u: kind.tgsUrl(mi), k: 'animated', e: '🎁'),
              size: size * .72,
              play: false,
            ),
          );
    final colors = up ? [a, b] : [a, b];
    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? size * .12 : 0),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(0, -.12), radius: .8, colors: colors),
            ),
          ),
          if (up) Positioned.fill(child: SvgPicture.string(patternSvg(gift!.sym), fit: BoxFit.cover)),
          Padding(padding: EdgeInsets.only(bottom: size * .04), child: art),
          if (ribbon && gift != null)
            Positioned(
              top: size * .05,
              right: size * .05,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * .06, vertical: size * .02),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .08),
                  gradient: LinearGradient(colors: [a.withOpacity(.95), b.withOpacity(.95)]),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text('#${gift!.number}',
                    style: TextStyle(fontSize: math.max(9, size * .1), fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}
