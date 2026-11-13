import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/push_service.dart';
import '../services/update_service.dart';
import '../widgets/avatar.dart';
import '../widgets/bicon.dart';
import '../widgets/bottom_nav.dart';
import 'chat_screen.dart';
import 'group_screens.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stories.dart';
import 'update_screen.dart';

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
    final me = context.watch<AuthService>().me;
    if (!_prefsSynced && me != null) {
      _prefsSynced = true;
      final c = me['chatPrefs'];
      if (c is Map) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => context.read<AppPrefs>().applyMap(Map<String, dynamic>.from(c)));
      }
    }
    final up = context.watch<UpdateController>();
    if (up.optional && !up.promptShown) {
      up.promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
              MaterialPageRoute(fullscreenDialog: true, builder: (_) => const UpdateScreen(forced: false)));
        }
      });
    }
    final pages = const [_ChatsTab(), SettingsScreen(), ProfileScreen()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BBottomNav(index: _tab, onTap: (i) => setState(() => _tab = i)),
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
    final p = BP.of(context);
    final me = auth.uid;
    final goSearch = () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));

    return Scaffold(
      backgroundColor: p.chatListBg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: goSearch,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2D268), Color(0xFFC29D30)]),
              boxShadow: const [BoxShadow(color: Color(0x40C29D30), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Center(child: BIcon('pencil', size: 24, color: Color(0xFF17212B))),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<QueryDocumentSnapshot<Json>>>(
          stream: svc.chatsStream(me),
          builder: (context, snap) {
            final chats = (snap.data ?? []).toList()
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
              // ---------- الرأس ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(children: [
                  const MyStoryAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Babylon',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4,
                            color: p.dark ? Colors.white : p.text)),
                  ),
                  IconButton(
                    tooltip: 'مجموعة جديدة',
                    icon: Icon(Icons.group_add_outlined, color: p.muted),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreateScreen())),
                  ),
                ]),
              ),
              // ---------- البحث ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: GestureDetector(
                  onTap: goSearch,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.dark ? const Color(0xFF17212B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.dark ? const Color(0x0FFFFFFF) : p.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.search, size: 20, color: p.muted),
                      const SizedBox(width: 10),
                      Text('ابحث عن مستخدم بيوزره', style: TextStyle(fontSize: 14, color: p.muted)),
                    ]),
                  ),
                ),
              ),
              StoriesBar(partnerIds: partnerIds),
              // ---------- التبويبات ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Row(children: [
                  _Tab(label: 'الكل', selected: !_unreadOnly, onTap: () => setState(() => _unreadOnly = false)),
                  const SizedBox(width: 22),
                  _Tab(label: 'غير المقروءة', selected: _unreadOnly, onTap: () => setState(() => _unreadOnly = true)),
                ]),
              ),
              Divider(height: 1, thickness: .6, color: p.dark ? const Color(0x14FFFFFF) : p.border),
              // ---------- القائمة ----------
              Expanded(
                child: !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : chats.isEmpty
                        ? _Empty(onSearch: goSearch)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: chats.length,
                            itemBuilder: (_, i) => chats[i].data()['type'] == 'group'
                                ? _GroupTile(chat: chats[i], me: me, unreadOnly: _unreadOnly)
                                : _ChatTile(chat: chats[i], me: me, unreadOnly: _unreadOnly),
                          ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? p.gold : Colors.transparent, width: 2.2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? p.gold : p.muted)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onSearch;
  const _Empty({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.gold.withOpacity(.1)),
            child: Center(child: BIcon('chat', size: 38, color: p.gold)),
          ),
          const SizedBox(height: 18),
          const Text('لا توجد محادثات بعد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('ابحث عن صديق بيوزره وابدأ أول محادثة', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.gold,
              side: BorderSide(color: p.gold.withOpacity(.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(160, 44),
            ),
            child: const Text('بحث عن مستخدم'),
          ),
        ]),
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
          leading: BIcon('pin', color: BP.of(context).gold),
          title: Text(prefs.isPinned(chatId) ? 'إلغاء التثبيت' : 'تثبيت المحادثة'),
          onTap: () {
            Navigator.pop(context);
            prefs.togglePin(chatId);
          },
        ),
        ListTile(
          leading: BIcon(prefs.isMuted(chatId) ? 'bell' : 'bellOff', color: BP.of(context).gold),
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

/// صف محادثة مسطّح: أفاتار 54، اسم + وقت، معاينة + شارة، فاصل رفيع يبدأ بعد الأفاتار
Widget _chatRow(
  BuildContext context, {
  required Widget leading,
  required Widget nameRow,
  required Widget sub,
  required String time,
  required String chatId,
  int unread = 0,
  required VoidCallback onTap,
}) {
  final p = BP.of(context);
  final prefs = context.watch<AppPrefs>();
  final muted = prefs.isMuted(chatId);
  return Column(mainAxisSize: MainAxisSize.min, children: [
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _chatMenu(context, chatId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: nameRow),
                  if (prefs.isPinned(chatId) && unread == 0)
                    Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: BIcon('pin', size: 14, color: p.muted)),
                  Text(time,
                      style: TextStyle(
                          fontSize: 12, color: unread > 0 && !muted ? p.gold : p.muted, fontWeight: unread > 0 ? FontWeight.w600 : null)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: sub),
                  if (muted)
                    Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: BIcon('bellOff', size: 14, color: p.muted)),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: muted ? p.muted.withOpacity(.5) : p.gold, borderRadius: BorderRadius.circular(10)),
                      child: Text(unread > 99 ? '99+' : '$unread',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.dark ? p.bg : Colors.white)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsetsDirectional.only(start: 84),
      child: Divider(height: .6, thickness: .6, color: p.dark ? const Color(0x0FFFFFFF) : p.border),
    ),
  ]);
}

TextStyle _nameStyle(BP p) =>
    TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: p.dark ? const Color(0xFFF1F5F9) : const Color(0xFF17212B));

class _GroupTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  const _GroupTile({required this.chat, required this.me, this.unreadOnly = false});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final d = chat.data();
    final name = (d['name'] as String?) ?? 'مجموعة';
    final last = d['lastMsg'] as Map?;
    final at = (last?['at'] as num?)?.toInt() ?? ((d['updatedAt'] as num?)?.toInt() ?? 0);
    final readAt = ((d['readAt'] as Map?)?[me] as num?)?.toInt() ?? 0;
    final unread = last != null && last['senderId'] != me && at > readAt;
    if (unreadOnly && !unread) return const SizedBox.shrink();
    return _chatRow(
      context,
      chatId: chat.id,
      unread: unread ? 1 : 0,
      leading: Avatar(size: 54, url: d['photo'] as String?, name: name, seed: chat.id),
      nameRow: Row(children: [
        Icon(Icons.group, size: 16, color: p.muted),
        const SizedBox(width: 5),
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle(p))),
      ]),
      sub: Text((last?['text'] as String?) ?? 'لا توجد رسائل بعد',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: unread ? (p.dark ? Colors.white70 : p.text) : p.muted, fontWeight: unread ? FontWeight.w500 : null)),
      time: at == 0 ? '' : formatChatTime(at),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
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
            final p = BP.of(context);
            final loading = s.connectionState == ConnectionState.waiting;
            final u = s.data;
            final gone = !loading && (u == null || u.isEmpty);
            final name = gone ? 'مستخدم محذوف' : ((u?['displayName'] as String?) ?? '...');
            final typing = data['typing_$other'] == true;
            return _chatRow(
              context,
              chatId: chat.id,
              unread: unread,
              leading: Avatar(
                size: 54,
                url: gone ? null : avatarOf(u),
                name: name,
                seed: other,
                deleted: gone,
                online: gone ? null : isOnline(u ?? {}),
              ),
              nameRow: Row(children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gone ? _nameStyle(p).copyWith(color: p.muted) : _nameStyle(p)),
                ),
                if (u?['isVerified'] == true)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Icon(Icons.verified, size: 15, color: p.gold),
                  ),
              ]),
              sub: StreamBuilder<Msg?>(
                stream: svc.lastMessage(chat.id),
                builder: (_, ms) {
                  if (typing && !gone) {
                    return Text('يكتب الآن...', style: TextStyle(fontSize: 14, color: p.gold));
                  }
                  final m = ms.data;
                  if (m == null) {
                    return Text('لا توجد رسائل بعد', style: TextStyle(fontSize: 14, color: p.muted));
                  }
                  final mine = m.senderId == me;
                  final strong = !mine && !m.read;
                  return Row(children: [
                    if (mine)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4),
                        child: Icon(m.read ? Icons.done_all : Icons.done, size: 15, color: m.read ? p.gold : p.muted),
                      ),
                    Expanded(
                      child: Text(m.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              color: strong ? (p.dark ? Colors.white70 : p.text) : p.muted,
                              fontWeight: strong ? FontWeight.w500 : null)),
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
