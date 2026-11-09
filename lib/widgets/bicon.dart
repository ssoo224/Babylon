import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/bicons_data.dart';

/// أيقونات بابيلون المخصصة (SVG من التطبيق الأصلي، stroke 1.8)
class BIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const BIcon(this.name, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final inner = bIconData[name];
    if (inner == null) return SizedBox(width: size, height: size);
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}
