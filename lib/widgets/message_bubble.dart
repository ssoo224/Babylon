import 'package:flutter/material.dart';
import '../core/prefs.dart';
import '../core/utils.dart';
import '../services/chat_service.dart';
import 'voice_player.dart';

class MessageBubble extends StatelessWidget {
  final Msg msg;
  final bool mine;
  final ChatTheme theme;
  final int font;
  final int radius;
  final bool isGroup;
  final String? senderName;
  final String query;
  final VoidCallback onLongPress;
  final void Function(String url) onImageTap;
  const MessageBubble({
    super.key,
    required this.msg,
    required this.mine,
    required this.theme,
    required this.font,
    required this.radius,
    required this.onLongPress,
    required this.onImageTap,
    this.isGroup = false,
    this.senderName,
    this.query = '',
  });

  @override
  Widget build(BuildContext context) {
    final fg = mine ? theme.textMine : theme.textOther;
    final metaC = mine ? theme.tick : theme.metaOther;
    final r = radius.toDouble();

    if (msg.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: theme.other.withOpacity(.7), borderRadius: BorderRadius.circular(12)),
          child: Text(msg.text, style: TextStyle(fontSize: 12, color: theme.textOther)),
        ),
      );
    }

    final reactions = msg.reactions.values.whereType<String>().toList();
    final matched = query.isNotEmpty && msg.text.toLowerCase().contains(query.toLowerCase());

    Widget content;
    if (msg.audioUrl != null) {
      content = VoicePlayer(url: msg.audioUrl!, seconds: msg.duration);
    } else if (msg.type == 'sticker' && msg.imageUrl != null) {
      content = Image(image: imageFromUrl(msg.imageUrl)!, width: 120);
    } else if (msg.imageUrl != null) {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => onImageTap(msg.imageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.clamp(4.0, 16.0).toDouble()),
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
              child: Text(msg.caption!, style: TextStyle(color: fg, fontSize: font.toDouble()))),
      ]);
    } else {
      content = Text(msg.text,
          style: TextStyle(color: fg, fontSize: font.toDouble(), height: 1.4));
    }

    final bg = mine ? theme.mine.first : theme.other;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          decoration: BoxDecoration(
            color: theme.mine.length > 1 && mine ? null : bg,
            gradient: mine && theme.mine.length > 1
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.mine)
                : null,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
              bottomRight: Radius.circular(mine ? 4 : r),
              bottomLeft: Radius.circular(mine ? r : 4),
            ),
            border: matched ? Border.all(color: theme.accent, width: 2) : null,
            boxShadow: const [
              BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGroup && !mine && (senderName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(senderName!,
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold, color: theme.accent)),
                ),
              if ((msg.replyTo ?? '').isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: fg.withOpacity(.6), width: 3)),
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
                    style: TextStyle(fontSize: 11, color: metaC)),
                if (mine && !isGroup) ...[
                  const SizedBox(width: 4),
                  Icon(msg.read ? Icons.done_all : Icons.done, size: 14, color: metaC),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
