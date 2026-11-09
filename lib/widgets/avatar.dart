import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// مثل .telegram-avatar: خلفية ذهبية وحرف داكن
class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool? online;
  final bool storyRing;
  const Avatar({
    super.key,
    this.url,
    required this.name,
    this.size = 48,
    this.online,
    this.storyRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final img = imageFromUrl(url);
    Widget a = CircleAvatar(
      radius: size / 2,
      backgroundColor: p.gold,
      backgroundImage: img,
      child: img == null
          ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                  fontSize: size * .4, fontWeight: FontWeight.bold, color: p.dark ? p.bg : Colors.white))
          : null,
    );
    if (storyRing) {
      a = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: p.gold, width: 2)),
        child: a,
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
