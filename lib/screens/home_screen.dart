import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/push_service.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stories.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthService>().uid;
    PushService.init(uid).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [_ChatsTab(), ProfileScreen(), SettingsScreen()];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'المحادثات'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'ملفي'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final svc = context.read<ChatService>();
    final me = auth.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text('بابيلون',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Json>>>(
        stream: svc.chatsStream(me),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('تعذر تحميل المحادثات'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snap.data!
              .where((d) => (d.data()['type'] ?? '') != 'group') // المجموعات: المرحلة 2
              .toList();
          final partnerIds = chats
              .map((d) => ((d.data()['participants'] as List?) ?? [])
                  .cast<String>()
                  .firstWhere((x) => x != me, orElse: () => ''))
              .where((x) => x.isNotEmpty)
              .toList();
          return Column(children: [
            StoriesBar(partnerIds: partnerIds),
            Expanded(
              child: chats.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'لا توجد محادثات في بابيلون بعد\nاضغط على البحث وابحث عن مستخدم بيوزر صالح',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (_, i) => _ChatTile(chat: chats[i], me: me),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  const _ChatTile({required this.chat, required this.me});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final data = chat.data();
    final other = ((data['participants'] as List?) ?? [])
        .cast<String>()
        .firstWhere((x) => x != me, orElse: () => '');
    if (other.isEmpty) return const SizedBox.shrink();
    final updated = (data['updatedAt'] as num?)?.toInt() ?? 0;

    return StreamBuilder<Json?>(
      stream: svc.userStream(other),
      builder: (context, s) {
        final u = s.data ?? {};
        final name = (u['displayName'] as String?) ?? '...';
        final typing = data['typing_$other'] == true;
        return ListTile(
          leading: Avatar(
            url: u['avatarUrl'],
            name: name,
            online: u['online'] == true &&
                DateTime.now().millisecondsSinceEpoch -
                        ((u['lastSeen'] as num?)?.toInt() ?? 0) <
                    60000,
          ),
          title: Row(children: [
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            if (u['isVerified'] == true)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Icon(Icons.verified,
                    size: 16, color: Theme.of(context).colorScheme.primary),
              ),
          ]),
          subtitle: StreamBuilder<Msg?>(
            stream: svc.lastMessage(chat.id),
            builder: (_, ms) {
              if (typing) {
                return Text('يكتب الآن...',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary));
              }
              final m = ms.data;
              if (m == null) return const Text('لا توجد رسائل بعد');
              final mine = m.senderId == me;
              return Row(children: [
                if (mine)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Icon(m.read ? Icons.done_all : Icons.done, size: 14),
                  ),
                Expanded(
                  child: Text(m.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: (!mine && !m.read) ? FontWeight.bold : null)),
                ),
              ]);
            },
          ),
          trailing: Text(updated == 0 ? '' : formatChatTime(updated),
              style: const TextStyle(fontSize: 12)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(chatId: chat.id, otherId: other)),
          ),
        );
      },
    );
  }
}
