import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/profile_header.dart';
import 'chat_screen.dart';
import 'gift_screens.dart';
import 'profile_screen.dart';

class OtherProfileScreen extends StatelessWidget {
  final String uid;
  const OtherProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: p.chatListBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, scrolledUnderElevation: 0),
      body: StreamBuilder<Json?>(
        stream: svc.userStream(uid),
        builder: (context, s) {
          final u = s.data;
          if (u == null) return const Center(child: CircularProgressIndicator());
          final name = (u['displayName'] as String?) ?? '';
          final av = avatarOf(u);
          final chatId = pairChatId(me, uid);
          final prefs = context.watch<AppPrefs>();
          return ListView(padding: EdgeInsets.zero, children: [
            ProfileHeader(
              avatarUrl: av,
              name: name,
              username: (u['username'] as String?) ?? '',
              status: statusOf(u),
              online: isOnline(u),
              verified: u['isVerified'] == true,
              coverKey: (u['cover'] as String?) ?? 'babylon',
              seed: uid,
              onAvatarTap: () {
                final img = imageFromUrl(av);
                if (img == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      body: Center(child: InteractiveViewer(child: Image(image: img))),
                    ),
                  ),
                );
              },
            ),
            StreamBuilder<Set<String>>(
              stream: svc.blocks(me),
              builder: (context, bs) {
                final blocked = bs.data?.contains(uid) ?? false;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    PfButton(
                      label: 'مراسلة',
                      icon: Icons.chat_bubble_outline,
                      primary: true,
                      onTap: () async {
                        final id = await svc.ensureChat(me, uid);
                        if (context.mounted) {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherId: uid)));
                        }
                      },
                    ),
                    PfButton(
                      label: 'إهداء هدية',
                      icon: Icons.card_giftcard,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SendGiftScreen(otherId: uid))),
                    ),
                    PfButton(
                      label: blocked ? 'إلغاء الحظر' : 'حظر',
                      icon: Icons.block,
                      danger: true,
                      onTap: () => blocked ? svc.unblock(me, uid) : svc.block(me, uid),
                    ),
                  ]),
                );
              },
            ),
            const SizedBox(height: 10),
            InfoCard(children: [
              if ((u['bio'] as String?)?.isNotEmpty == true)
                PfRow(biconName: 'text', value: u['bio'], label: 'النبذة التعريفية'),
              PfRow(
                  biconName: 'at',
                  value: '@${u['username'] ?? ''}',
                  label: 'اسم المستخدم',
                  ltr: true,
                  last: (u['province'] as String?)?.isNotEmpty != true && joinedLabel(u).isEmpty),
              if ((u['province'] as String?)?.isNotEmpty == true)
                PfRow(biconName: 'pin', value: u['province'], label: 'المحافظة', last: joinedLabel(u).isEmpty),
              if (joinedLabel(u).isNotEmpty)
                PfRow(biconName: 'calendar', value: joinedLabel(u), label: 'تاريخ الانضمام', last: true),
            ]),
            GiftsGrid(uid: uid, mine: false),
            PinnedStoriesSection(uid: uid, owner: u, mine: false),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
