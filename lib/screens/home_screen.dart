import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/push_service.dart';
import '../widgets/avatar.dart';
import '../widgets/bicon.dart';
import 'chat_screen.dart';
import 'group_screens.dart';
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
  bool _prefsSynced = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthService>().uid;
    PushService.init(uid).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    // مزامنة ثيم المحادثة/الخط/الزوايا من السحابة مرة واحدة (users.chatPrefs)
    final me = context.watch<AuthService>().me;
    if (!_prefsSynced && me != null) {
      _prefsSynced = true;
      final c = me['chatPrefs'];
      if (c is Map) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<AppPrefs>().applyMap(Map<String, dynamic>.from(c)));
      }
    }
    final pages = const [_ChatsTab(), SettingsScreen(), ProfileScreen()];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: BIcon('chat'), label: 'المحادثات'),
          NavigationDestination(icon: BIcon('sliders'), label: 'الإعدادات'),
          NavigationDestination(icon: BIcon('user'), label: 'الملف الشخصي'),
        ],
      ),
    );
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final prefs = context.watch<AppPrefs>();
    final svc = context.read<ChatService>();
    final me = auth.uid;
    return Scaffold(
      backgroundColor: BP.of(context).chatListBg,
      appBar: AppBar(
        title: const Text('Babylon'),
        actions: [
          IconButton(
            tooltip: 'مجموعة جديدة',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const GroupCreateScreen())),
          ),
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
          if (snap.hasError) return const Center(child: Text('تعذر تحميل المحادثات'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snap.data!.toList()
            ..sort((a, b) {
              final pa = prefs.isPinned(a.id) ? 1 : 0, pb = prefs.isPinned(b.id) ? 1 : 0;
              if (pa != pb) return pb - pa;
              return ((b.data()['updatedAt'] ?? 0) as num).compareTo((a.data()['updatedAt'] ?? 0) as num);
            });
          final partnerIds = chats
              .where((d) => d.data()['type'] != 'group')
              .map((d) => ((d.data()['participants'] as List?) ?? [])
                  .cast<String>()
                  .firstWhere((x) => x != me, orElse: () => ''))
              .where((x) => x.isNotEmpty)
              .toList();
          return Column(children: [
            StoriesBar(partnerIds: partnerIds),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(children: [
                ChoiceChip(label: const Text('الكل'), selected: !_unreadOnly, onSelected: (_) => setState(() => _unreadOnly = false)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('غير المقروءة'), selected: _unreadOnly, onSelected: (_) => setState(() => _unreadOnly = true)),
              ]),
            ),
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
                      itemBuilder: (_, i) => chats[i].data()['type'] == 'group'
                          ? _GroupTile(chat: chats[i], me: me, unreadOnly: _unreadOnly)
                          : _ChatTile(chat: chats[i], me: me, unreadOnly: _unreadOnly),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

void _chatMenu(BuildContext context, String chatId) {
  final prefs = context.read<AppPrefs>();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(prefs.isPinned(chatId) ? Icons.push_pin : Icons.push_pin_outlined),
          title: Text(prefs.isPinned(chatId) ? 'إلغاء التثبيت' : 'تثبيت المحادثة'),
          onTap: () {
            Navigator.pop(context);
            prefs.togglePin(chatId);
          },
        ),
        ListTile(
          leading: Icon(prefs.isMuted(chatId) ? Icons.notifications_off : Icons.notifications_off_outlined),
          title: Text(prefs.isMuted(chatId) ? 'إلغاء الكتم' : 'كتم المحادثة'),
          onTap: () {
            Navigator.pop(context);
            prefs.toggleMute(chatId);
          },
        ),
      ]),
    ),
  );
}

Widget _tileShell(BuildContext context,
    {required Widget leading,
    required Widget title,
    required Widget subtitle,
    required String time,
    required String chatId,
    int unread = 0,
    required VoidCallback onTap}) {
  final pal = BP.of(context);
  final prefs = context.watch<AppPrefs>();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: ListTile(
      tileColor: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pal.dark ? const Color(0x0AFFFFFF) : pal.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(time, style: TextStyle(fontSize: 12, color: pal.muted)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (unread > 0)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: pal.gold, borderRadius: BorderRadius.circular(12)),
              child: Text(unread > 99 ? '99+' : '$unread', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pal.dark ? pal.bg : Colors.white)),
            ),
          if (prefs.isMuted(chatId)) Icon(Icons.notifications_off, size: 15, color: pal.muted),
          if (prefs.isPinned(chatId)) Icon(Icons.push_pin, size: 15, color: pal.gold),
        ]),
      ]),
      onTap: onTap,
      onLongPress: () => _chatMenu(context, chatId),
    ),
  );
}

class _GroupTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  const _GroupTile({required this.chat, required this.me, this.unreadOnly = false});

  @override
  Widget build(BuildContext context) {
    final d = chat.data();
    final name = (d['name'] as String?) ?? 'مجموعة';
    final last = d['lastMsg'] as Map?;
    final at = (last?['at'] as num?)?.toInt() ?? ((d['updatedAt'] as num?)?.toInt() ?? 0);
    final readAt = ((d['readAt'] as Map?)?[me] as num?)?.toInt() ?? 0;
    final unread = last != null && last['senderId'] != me && at > readAt;
    if (unreadOnly && !unread) return const SizedBox.shrink();
    return _tileShell(
      context,
      chatId: chat.id,
      unread: unread ? 1 : 0,
      leading: Avatar(size: 56, url: d['photo'] as String?, name: name),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
      subtitle: Text((last?['text'] as String?) ?? 'لا توجد رسائل بعد',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.bold : null)),
      time: at == 0 ? '' : formatChatTime(at),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  const _ChatTile({required this.chat, required this.me, this.unreadOnly = false});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final data = chat.data();
    final other = ((data['participants'] as List?) ?? [])
        .cast<String>()
        .firstWhere((x) => x != me, orElse: () => '');
    if (other.isEmpty) return const SizedBox.shrink();
    final updated = (data['updatedAt'] as num?)?.toInt() ?? 0;

    return StreamBuilder<int>(
      stream: svc.unreadCount(chat.id, me),
      builder: (context, un) {
        final unread = un.data ?? 0;
        if (unreadOnly && unread == 0) return const SizedBox.shrink();
        return StreamBuilder<Json?>(
      stream: svc.userStream(other),
      builder: (context, s) {
        final u = s.data ?? {};
        final name = (u['displayName'] as String?) ?? '...';
        final typing = data['typing_$other'] == true;
        final pal = BP.of(context);
        return _tileShell(
          context,
          chatId: chat.id,
          unread: unread,
          leading: Avatar(size: 56, url: avatarOf(u), name: name, online: isOnline(u)),
          title: Row(children: [
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5))),
            if (u['isVerified'] == true)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Icon(Icons.verified, size: 16, color: pal.gold),
              ),
          ]),
          subtitle: StreamBuilder<Msg?>(
            stream: svc.lastMessage(chat.id),
            builder: (_, ms) {
              if (typing) return Text('يكتب الآن...', style: TextStyle(color: pal.gold));
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
                      style: TextStyle(fontWeight: (!mine && !m.read) ? FontWeight.bold : null)),
                ),
              ]);
            },
          ),
          time: updated == 0 ? '' : formatChatTime(updated),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id, otherId: other)),
          ),
        );
      },
    );
      },
    );
  }
}
