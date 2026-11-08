import 'package:flutter/material.dart';
import '../core/utils.dart';

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
    final gold = Theme.of(context).colorScheme.primary;
    final img = imageFromUrl(url);
    Widget a = CircleAvatar(
      radius: size / 2,
      backgroundColor: gold.withOpacity(.25),
      backgroundImage: img,
      child: img == null
          ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                  fontSize: size * .4, fontWeight: FontWeight.bold, color: gold))
          : null,
    );
    if (storyRing) {
      a = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: gold, width: 2)),
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
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
          ),
        ),
      ]);
    }
    return a;
  }
}
