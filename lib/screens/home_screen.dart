import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // مزامنة ثيم المحادثة/الخط/الزوايا من السحابة مرة واحدة (users.chatPrefs)
    final me = context.watch<AuthService>().me;
    if (!_prefsSynced && me != null) {
      _prefsSynced = true;
      final c = me['chatPrefs'];
      if (c is Map) {
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            context.read<AppPrefs>().applyMap(Map<String, dynamic>.from(c)));
      }
    }
    final up = context.watch<UpdateController>();
    if (up.optional && !up.promptShown) {
      up.promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true, builder: (_) => const UpdateScreen(forced: false)));
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

    return Scaffold(
      backgroundColor: p.chatListBg,
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
              return ((b.data()['updatedAt'] ?? 0) as num)
                  .compareTo((a.data()['updatedAt'] ?? 0) as num);
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
                _FilterChip(
                    label: 'الكل',
                    selected: !_unreadOnly,
                    onTap: () => setState(() => _unreadOnly = false)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'غير المقروءة',
                    selected: _unreadOnly,
                    onTap: () => setState(() => _unreadOnly = true)),
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
                      padding: const EdgeInsets.only(bottom: 12),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.gold.withOpacity(.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? p.gold.withOpacity(.5) : p.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? p.gold : p.muted)),
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

/// بطاقة المحادثة (.chat-item): هامش 10، حشوة 12/14، زوايا 18، حد أبيض شفاف
Widget _chatCard(
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
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.dark ? const Color(0x0AFFFFFF) : const Color(0xFFEDF0F5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _chatMenu(context, chatId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: nameRow),
                  if (prefs.isPinned(chatId) && unread == 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: BIcon('pin', size: 16, color: p.gold),
                    ),
                  Text(time, style: TextStyle(fontSize: 12, color: p.muted)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(child: sub),
                  if (prefs.isMuted(chatId))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: BIcon('bellOff', size: 15, color: p.muted),
                    ),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: p.gold, borderRadius: BorderRadius.circular(12)),
                      child: Text(unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: p.dark ? p.bg : Colors.white)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

TextStyle _nameStyle(BP p) => TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16.5,
    color: p.dark ? Colors.white : const Color(0xFF17212B));

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
    return _chatCard(
      context,
      chatId: chat.id,
      unread: unread ? 1 : 0,
      leading: Avatar(size: 56, url: d['photo'] as String?, name: name, seed: chat.id),
      nameRow: Text(name,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle(p)),
      sub: Text((last?['text'] as String?) ?? 'لا توجد رسائل بعد',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13.5, color: p.muted, fontWeight: unread ? FontWeight.bold : null)),
      time: at == 0 ? '' : formatChatTime(at),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
    );
  }
}

// =======================================================
// 🚀 المحادثة الفردية (مُحسنة جداً للأداء)
// =======================================================
class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  const _ChatTile({required this.chat, required this.me, this.unreadOnly = false});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final svc = context.read<ChatService>();
    final data = chat.data();
    
    final other = ((data['participants'] as List?) ?? [])
        .cast<String>()
        .firstWhere((x) => x != me, orElse: () => '');
        
    if (other.isEmpty) return const SizedBox.shrink();
    
    final updated = (data['updatedAt'] as num?)?.toInt() ?? 0;
    final typing = data['typing_$other'] == true;

    // استخدام StreamBuilder واحد فقط لعدد الرسائل غير المقروءة (إذا كانت الدالة موجودة بكودك)
    return StreamBuilder<int>(
      stream: svc.unreadCount(chat.id, me),
      builder: (context, un) {
        final unread = un.data ?? 0;
        if (unreadOnly && unread == 0) return const SizedBox.shrink();

        // استخدام FutureBuilder للمستخدم (أخف وأسرع بكثير من Stream لأن بيانات المستخدم لا تتحدث كل ثانية)
        return FutureBuilder<Json?>(
          future: FirebaseFirestore.instance.collection('users').doc(other).get().then((v) => v.data()),
          builder: (context, s) {
            final loading = s.connectionState == ConnectionState.waiting;
            final u = s.data;
            final gone = !loading && (u == null || u.isEmpty);
            final name = gone ? 'مستخدم محذوف' : ((u?['displayName'] as String?) ?? '...');

            return _chatCard(
              context,
              chatId: chat.id,
              unread: unread,
              leading: Avatar(
                size: 56,
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
                    child: Icon(Icons.verified, size: 16, color: p.gold),
                  ),
              ]),
              sub: _buildSubtitle(context, svc, typing, gone, me, data, p),
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

  // دالة مساعدة لبناء نص الرسالة الأخيرة بدون ما نفتح Stream جديد لكل محادثة
  Widget _buildSubtitle(BuildContext context, ChatService svc, bool typing, bool gone, String me, Json data, BP p) {
    if (typing && !gone) {
      return Text('يكتب الآن...', style: TextStyle(fontSize: 13.5, color: p.gold));
    }
    
    // نقرأ آخر رسالة من دوكومنت المحادثة مباشرة (بدون اتصال جديد)
    final last = data['lastMsg'] as Map?;
    final lastText = (last?['text'] as String?) ?? 'لا توجد رسائل بعد';
    final isMine = last?['senderId'] == me;
    final isRead = last?['read'] == true; // تأكد إن الـ Backend يحدث هذا الحقل

    return Row(children: [
      if (isMine)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Icon(isRead ? Icons.done_all : Icons.done,
              size: 15, color: isRead ? p.gold : p.muted),
        ),
      Expanded(
        child: Text(lastText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13.5,
                color: p.muted,
                fontWeight: (!isMine && (data['unreadCounts']?[me] ?? 0) > 0) ? FontWeight.bold : null)),
      ),
    ]);
  }
}
