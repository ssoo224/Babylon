import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// نفس toneOf في الأصل: FNV hash للمعرّف => gold أو blue
bool toneIsBlue(String id) {
  if (id.isEmpty) return false;
  var h = 2166136261;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  h ^= h >> 15;
  h = (h * 2246822507) & 0xFFFFFFFF;
  h ^= h >> 13;
  return ((h >> 7) & 1) == 1;
}

/// أفاتار بنفس تصميم الأصل: تدرج ذهبي/أزرق مع حرف أبيض، حلقة قصة متدرجة
class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool? online;
  final bool storyRing;
  final bool storySeen;
  final String? seed;
  final bool deleted;
  const Avatar({
    super.key,
    this.url,
    required this.name,
    this.size = 48,
    this.online,
    this.storyRing = false,
    this.storySeen = false,
    this.seed,
    this.deleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final img = deleted ? null : imageFromUrl(url);
    final blue = toneIsBlue(seed ?? name);
    final colors = deleted
        ? const [Color(0xFF64748B), Color(0xFF475569)]
        : (blue
            ? const [Color(0xFF59CDF8), Color(0xFF1F63D8)]
            : const [Color(0xFFF2D268), Color(0xFFB8861B)]);
    Widget a = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: img == null
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
            : null,
        image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
        boxShadow: img == null
            ? [BoxShadow(color: colors.last.withOpacity(.14), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: img != null
          ? null
          : (deleted
              ? Icon(Icons.person_off_outlined, color: Colors.white, size: size * .5)
              : Text(
                  name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
                  style: TextStyle(fontSize: size * .4, fontWeight: FontWeight.w700, color: Colors.white),
                )),
    );
    if (storyRing) {
      a = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: storySeen ? const Color(0xFF4B5A6B) : null,
          gradient: storySeen
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8F6810), Color(0xFFF8E7A0), Color(0xFFC29D30),
                    Color(0xFFFFF1A8), Color(0xFFC69A20), Color(0xFFF5DC7A)
                  ],
                  stops: [0, .18, .38, .52, .72, 1],
                ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.chatListBg),
          child: a,
        ),
      );
    }
    if (online == true) {
      a = Stack(children: [
        a,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size * .26,
            height: size * .26,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80),
              shape: BoxShape.circle,
              border: Border.all(color: p.surface, width: 2),
            ),
          ),
        ),
      ]);
    }
    return a;
  }
}
