import 'package:flutter/material.dart';
import '../core/emoji_data.dart';
import '../core/theme.dart';

/// لوحة إيموجي كاملة (1651 رمز، 8 أقسام) — نفس بيانات تطبيق الويب
class EmojiPanel extends StatefulWidget {
  final void Function(String emoji) onPick;
  final double height;
  const EmojiPanel({super.key, required this.onPick, this.height = 300});
  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  String _cat = 'smileys';

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final items = emojiData[_cat] ?? const [];
    return Container(
      height: widget.height,
      color: p.surface,
      child: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: emojiData.keys.map((k) {
              final sel = k == _cat;
              return GestureDetector(
                onTap: () => setState(() => _cat = k),
                child: Container(
                  width: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: sel ? p.gold : Colors.transparent, width: 2.5)),
                  ),
                  child: Text(emojiTabIcons[k] ?? '', style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(emojiTitles[_cat] ?? '',
                style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 46),
            itemCount: items.length,
            itemBuilder: (_, i) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onPick(items[i]),
              child: Center(child: Text(items[i], style: const TextStyle(fontSize: 26))),
            ),
          ),
        ),
      ]),
    );
  }
}
