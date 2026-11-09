import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/prefs.dart';
import 'bicon.dart';

/// نقش الرموز البابلية خلف المحادثة والغلاف (renderPattern في الأصل)
class PatternLayer extends StatelessWidget {
  final ChatTheme theme;
  final double cell;
  const PatternLayer({super.key, required this.theme, this.cell = 74});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 400.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : 700.0;
        final cols = (w / cell).ceil() + 1;
        final rows = (h / cell).ceil() + 1;
        final n = theme.symbols.length;
        final rnd = math.Random(7);
        final children = <Widget>[];
        for (var r = 0; r < rows; r++) {
          for (var k = 0; k < cols; k++) {
            final idx = (r * 3 + k) % n;
            final off = (r.isOdd ? cell / 2 : 0);
            final jx = rnd.nextDouble() * 10 - 5, jy = rnd.nextDouble() * 10 - 5;
            children.add(Positioned(
              left: k * cell + off + jx,
              top: r * cell + jy,
              child: Transform.rotate(
                angle: (rnd.nextDouble() - .5) * .8,
                child: Opacity(
                  opacity: theme.patternOp * 2.2,
                  child: BIcon(theme.symbols[idx], size: 30, color: theme.pattern),
                ),
              ),
            ));
          }
        }
        return ClipRect(child: Stack(children: children));
      }),
    );
  }
}
