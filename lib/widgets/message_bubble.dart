import 'package:flutter/material.dart';
import '../core/utils.dart';
import '../services/chat_service.dart';
import 'voice_player.dart';

class MessageBubble extends StatelessWidget {
  final Msg msg;
  final bool mine;
  final VoidCallback onLongPress;
  final void Function(String url) onImageTap;
  const MessageBubble({
    super.key,
    required this.msg,
    required this.mine,
    required this.onLongPress,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = mine
        ? cs.primary.withOpacity(dark ? .88 : .95)
        : (dark ? const Color(0xFF1F2937) : Colors.white);
    final fg = mine
        ? (dark ? Colors.black : Colors.white)
        : (dark ? Colors.white : Colors.black87);
    final reactions = msg.reactions.values.whereType<String>().toList();

    Widget content;
    if (msg.audioUrl != null) {
      content = VoicePlayer(url: msg.audioUrl!, seconds: msg.duration);
    } else if (msg.imageUrl != null && msg.type != 'sticker') {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => onImageTap(msg.imageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
                image: imageFromUrl(msg.imageUrl)!,
                width: 230,
                fit: BoxFit.cover,
                gaplessPlayback: true),
          ),
        ),
        if ((msg.caption ?? '').isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(msg.caption!, style: TextStyle(color: fg))),
      ]);
    } else if (msg.type == 'sticker' && msg.imageUrl != null) {
      content = Image(image: imageFromUrl(msg.imageUrl)!, width: 120);
    } else {
      content = Text(msg.text, style: TextStyle(color: fg, fontSize: 16, height: 1.35));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((msg.replyTo ?? '').isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                        right: BorderSide(color: fg.withOpacity(.6), width: 3)),
                    color: fg.withOpacity(.1),
                  ),
                  child: Text(msg.replyTo!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.withOpacity(.85), fontSize: 13)),
                ),
              content,
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Text(reactions.join(' '), style: const TextStyle(fontSize: 13)),
                  ),
                Text(formatTime(msg.createdAt),
                    style: TextStyle(fontSize: 11, color: fg.withOpacity(.7))),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(msg.read ? Icons.done_all : Icons.done,
                      size: 14, color: fg.withOpacity(.8)),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
