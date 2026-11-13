import 'package:flutter/material.dart';
import '../core/prefs.dart';
import '../core/utils.dart';
import '../services/chat_service.dart';
import '../services/sticker_service.dart';
import 'sticker_view.dart';
import 'gift_art.dart';
import '../screens/gift_screens.dart';
import '../services/gift_service.dart';
import 'package:provider/provider.dart';
import 'voice_player.dart';

/// عدد الإيموجي إذا كانت الرسالة إيموجي فقط (حتى 3)، وإلا 0
int bigEmojiCount(String t) {
  t = t.trim();
  if (t.isEmpty || t.length > 40) return 0;
  var units = 0;
  var afterZwj = false;
  for (final r in t.runes) {
    if (r == 0x200D) {
      afterZwj = true;
      continue;
    }
    if (r == 0xFE0F || (r >= 0x1F3FB && r <= 0x1F3FF) || (r >= 0xE0020 && r <= 0xE007F)) continue;
    final emoji = (r >= 0x1F300 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x1F1E6 && r <= 0x1F1FF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x231A && r <= 0x23FF) ||
        r == 0x2764 ||
        r == 0x3030;
    if (!emoji) return 0;
    if (!afterZwj) units++;
    afterZwj = false;
  }
  // أعلام: رمزان إقليميان = وحدة واحدة
  final flags = t.runes.where((r) => r >= 0x1F1E6 && r <= 0x1F1FF).length;
  units -= flags ~/ 2;
  return units > 3 ? 0 : units;
}

class MessageBubble extends StatelessWidget {
  final Msg msg;
  final bool mine;
  final ChatTheme theme;
  final int font;
  final int radius;
  final bool isGroup;
  final String? senderName;
  final String query;
  final bool selected;
  final bool selecting;
  final String myUid;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onReactionsTap;
  final void Function(String url) onImageTap;
  final void Function(String url) onVideoTap;
  const MessageBubble({
    super.key,
    required this.msg,
    required this.mine,
    required this.theme,
    required this.font,
    required this.radius,
    required this.myUid,
    required this.onLongPress,
    required this.onTap,
    required this.onDoubleTap,
    required this.onReactionsTap,
    required this.onImageTap,
    required this.onVideoTap,
    this.isGroup = false,
    this.senderName,
    this.query = '',
    this.selected = false,
    this.selecting = false,
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

    // تجميع التفاعلات: emoji -> عدد
    final counts = <String, int>{};
    for (final v in msg.reactions.values) {
      if (v is String && v.isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    final myReact = msg.reactions[myUid];
    final matched = query.isNotEmpty && msg.text.toLowerCase().contains(query.toLowerCase());
    final big = (msg.audioUrl == null && msg.imageUrl == null && msg.videoUrl == null && !msg.forwarded && !msg.storyReply)
        ? bigEmojiCount(msg.text)
        : 0;

    final stk = msg.type == 'sticker' ? Sticker.fromMessage(msg.d['sticker']) : null;
    Widget content;
    if (msg.type == 'gift') {
      final gs = context.read<GiftService>();
      final K = gs.kindOf(msg.d['k'] as String?);
      final gno = (msg.d['number'] as num?)?.toInt() ?? 0;
      final up = msg.d['upgraded'] == true;
      final gi = GiftItem(
        k: K.key,
        number: gno,
        upgraded: up,
        model: (msg.d['model'] as num?)?.toInt() ?? 0,
        bg: (msg.d['bg'] as num?)?.toInt() ?? 0,
        sym: (msg.d['sym'] as num?)?.toInt() ?? 0,
      );
      content = GestureDetector(
        onTap: selecting
            ? onTap
            : () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GiftPageScreen(kind: K, number: gno, owner: msg.d['to'] as String?))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GiftArt(kind: K, gift: gi, size: 170, ribbon: true),
          const SizedBox(height: 6),
          Text('🎁 ${mine ? 'أرسلت' : 'استلمت'} هدية ${K.name}',
              style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ]),
      );
    } else if (stk != null) {
      content = GestureDetector(
        onTap: selecting ? onTap : null,
        child: StickerView(st: stk, size: 150),
      );
    } else if (msg.audioUrl != null) {
      content = VoicePlayer(url: msg.audioUrl!, seconds: msg.duration);
    } else if (msg.videoUrl != null) {
      final poster = msg.posterUrl ?? '';
      content = GestureDetector(
        onTap: () => selecting ? onTap() : onVideoTap(msg.videoUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.clamp(4.0, 16.0).toDouble()),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 230,
              height: 160,
              color: Colors.black,
              child: poster.isNotEmpty
                  ? Image(image: imageFromUrl(poster)!, fit: BoxFit.cover, gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox())
                  : null,
            ),
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ]),
        ),
      );
    } else if (msg.imageUrl != null) {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => selecting ? onTap() : onImageTap(msg.imageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.clamp(4.0, 16.0).toDouble()),
            child: Image(
                image: imageFromUrl(msg.imageUrl)!, width: 230, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        if ((msg.caption ?? '').isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(msg.caption!, style: TextStyle(color: fg, fontSize: font.toDouble()))),
      ]);
    } else if (big > 0) {
      content = Text(msg.text.trim(),
          style: TextStyle(fontSize: big == 1 ? 56 : (big == 2 ? 44 : 36), height: 1.15));
    } else {
      content = Text(msg.text, style: TextStyle(color: fg, fontSize: font.toDouble(), height: 1.4));
    }

    final bg = mine ? theme.mine.first : theme.other;
    final bare = big > 0 || stk != null; // الإيموجي الكبير والملصقات بدون فقاعة
    final sr = msg.storyReplyData;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      padding: bare ? const EdgeInsets.fromLTRB(6, 2, 6, 2) : const EdgeInsets.fromLTRB(10, 6, 10, 5),
      decoration: bare
          ? null
          : BoxDecoration(
              color: theme.mine.length > 1 && mine ? null : bg,
              gradient: mine && theme.mine.length > 1
                  ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.mine)
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r),
                topRight: Radius.circular(r),
                bottomRight: Radius.circular(mine ? 4 : r),
                bottomLeft: Radius.circular(mine ? r : 4),
              ),
              border: matched ? Border.all(color: theme.accent, width: 2) : null,
              boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGroup && !mine && (senderName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(senderName!,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: theme.accent)),
            ),
          if (msg.forwarded)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shortcut, size: 13, color: metaC),
                const SizedBox(width: 4),
                Text('معاد توجيهها', style: TextStyle(fontSize: 11.5, color: metaC)),
              ]),
            ),
          if (msg.storyReply && sr != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: fg.withOpacity(.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(right: BorderSide(color: fg.withOpacity(.6), width: 3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (imageFromUrl(sr['imageUrl'] as String?) != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image(image: imageFromUrl(sr['imageUrl'] as String?)!, width: 36, height: 36, fit: BoxFit.cover),
                    ),
                  ),
                Flexible(
                  child: Text('رد على قصة${(sr['caption'] as String?)?.isNotEmpty == true ? ': ${sr['caption']}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.withOpacity(.85), fontSize: 12.5)),
                ),
              ]),
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
            Text(formatTime(msg.createdAt), style: TextStyle(fontSize: 11, color: bare ? theme.metaOther : metaC)),
            if (mine && !isGroup) ...[
              const SizedBox(width: 4),
              Icon(msg.read ? Icons.done_all : Icons.done, size: 14, color: bare ? theme.metaOther : metaC),
            ],
          ]),
          if (counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: GestureDetector(
                onTap: onReactionsTap,
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: counts.entries.map((e) {
                    final mineR = myReact == e.key;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (mineR ? theme.accent : theme.chatBg).withOpacity(.55),
                        borderRadius: BorderRadius.circular(14),
                        border: mineR ? Border.all(color: theme.accent) : null,
                      ),
                      child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key,
                          style: TextStyle(fontSize: 15, color: theme.textOther)),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: selecting ? onTap : null,
      onLongPress: onLongPress,
      onDoubleTap: selecting ? null : onDoubleTap,
      child: Container(
        color: selected ? theme.accent.withOpacity(.25) : Colors.transparent,
        child: Align(
          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: bubble,
        ),
      ),
    );
  }
}
