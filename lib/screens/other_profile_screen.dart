import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/profile_header.dart';
import 'chat_screen.dart';
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
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
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
            Transform.translate(
              offset: const Offset(0, -46),
              child: Column(children: [
                StreamBuilder<Set<String>>(
                  stream: svc.blocks(me),
                  builder: (context, bs) {
                    final blocked = bs.data?.contains(uid) ?? false;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Row(children: [
                        QuickAction(
                          icon: Icons.chat_bubble_outline,
                          label: 'مراسلة',
                          onTap: () async {
                            final id = await svc.ensureChat(me, uid);
                            if (context.mounted) {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherId: uid)));
                            }
                          },
                        ),
                        QuickAction(
                          icon: prefs.isMuted(chatId) ? Icons.notifications_off : Icons.notifications_none,
                          label: prefs.isMuted(chatId) ? 'إلغاء الكتم' : 'كتم',
                          onTap: () => prefs.toggleMute(chatId),
                        ),
                        QuickAction(
                          icon: Icons.block,
                          label: blocked ? 'إلغاء الحظر' : 'حظر',
                          color: p.error,
                          onTap: () => blocked ? svc.unblock(me, uid) : svc.block(me, uid),
                        ),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 8),
                InfoCard(children: [
                  ListTile(
                    leading: Icon(Icons.alternate_email, color: p.gold),
                    title: const Text('اسم المستخدم'),
                    subtitle: Text('@${u['username'] ?? ''}', textDirection: TextDirection.ltr),
                  ),
                  if ((u['bio'] as String?)?.isNotEmpty == true)
                    ListTile(
                      leading: Icon(Icons.info_outline, color: p.gold),
                      title: const Text('النبذة'),
                      subtitle: Text(u['bio']),
                    ),
                  if ((u['province'] as String?)?.isNotEmpty == true)
                    ListTile(leading: Icon(Icons.location_on_outlined, color: p.gold), title: const Text('المحافظة'), subtitle: Text(u['province'])),
                  if (joinedLabel(u).isNotEmpty)
                    ListTile(leading: Icon(Icons.calendar_today_outlined, color: p.gold), title: const Text('تاريخ الانضمام'), subtitle: Text(joinedLabel(u))),
                ]),
                PinnedStoriesSection(uid: uid, owner: u, mine: false),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
