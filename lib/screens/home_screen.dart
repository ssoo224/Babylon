import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
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
    NotificationService.onOpenChat = _openFromNotification;
    // ضغطة إشعار والتطبيق كان مغلقاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final d = NotificationService.pendingOpen;
      if (d != null) _openFromNotification(d);
    });
  }

  @override
  void dispose() {
    if (NotificationService.onOpenChat == _openFromNotification) {
      NotificationService.onOpenChat = null;
    }
    super.dispose();
  }

  void _openFromNotification(Map<String, dynamic> d) {
    NotificationService.pendingOpen = null;
    final chatId = d['chatId'] as String?;
    if (chatId == null || !mounted) return;
    final sender = d['senderId'] as String?;
    final me = context.read<AuthService>().uid;
    final other = (sender != null && sender.isNotEmpty && chatId == pairChatId(me, sender))
        ? sender
        : null;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherId: other)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().me;
    if (!_prefsSynced && me != null) {
      _prefsSynced = true;
      final c = me['chatPrefs'];
      if (c is Map) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<AppPrefs>().applyMap(Map<String, dynamic>.from(c)),
        );
      }
    }
    final up = context.watch<UpdateController>();
    if (up.optional && !up.promptShown) {
      up.promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const UpdateScreen(forced: false),
            ),
          );
        }
      });
    }
    const pages = [_ChatsTab(), SettingsScreen(), ProfileScreen()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BBottomNav(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

enum _ChatFolder { all, unread, direct, groups, pinned }

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  _ChatFolder _folder = _ChatFolder.all;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final prefs = context.watch<AppPrefs>();
    final svc = context.read<ChatService>();
    final p = BP.of(context);
    final me = auth.uid;
    void goSearch() =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));

    return Scaffold(
      backgroundColor: p.chatListBg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: goSearch,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6DA78), Color(0xFFD9B243), Color(0xFFB89024)],
              ),
              border: Border.all(color: Colors.white.withOpacity(.28), width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x48D4AF37), blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: const Center(child: BIcon('pencil', size: 23, color: Color(0xFF17212B))),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<QueryDocumentSnapshot<Json>>>(
          stream: svc.chatsStream(me),
          builder: (context, snap) {
            final allChats = (snap.data ?? []).toList()
              ..sort((a, b) {
                final pa = prefs.isPinned(a.id) ? 1 : 0;
                final pb = prefs.isPinned(b.id) ? 1 : 0;
                if (pa != pb) return pb - pa;
                return ((b.data()['updatedAt'] ?? 0) as num)
                    .compareTo((a.data()['updatedAt'] ?? 0) as num);
              });

            final partnerIds = allChats
                .where((d) => d.data()['type'] != 'group')
                .map((d) => ((d.data()['participants'] as List?) ?? [])
                    .cast<String>()
                    .firstWhere((x) => x != me, orElse: () => ''))
                .where((x) => x.isNotEmpty)
                .toList();

            final folderChats = allChats.where((d) {
              final isGroup = d.data()['type'] == 'group';
              if (_folder == _ChatFolder.direct && isGroup) return false;
              if (_folder == _ChatFolder.groups && !isGroup) return false;
              if (_folder == _ChatFolder.pinned && !prefs.isPinned(d.id)) return false;
              return true;
            }).toList();

            return Column(children: [
              // ---------- الرأس بأسلوب تليجرام ----------
              Container(
                color: p.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                      child: Row(children: [
                        const MyStoryAvatar(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Babylon',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .3,
                              color: p.dark ? Colors.white : p.text,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'مجموعة جديدة',
                          icon: Icon(Icons.group_add_outlined, color: p.muted),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
                          ),
                        ),
                      ]),
                    ),

                    // ---------- حقل البحث الفوري المدمج ----------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: p.dark ? const Color(0xFF0F1824) : const Color(0xFFF2F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: p.dark ? const Color(0x17FFFFFF) : const Color(0xFFDCE3EC),
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.search, size: 19, color: p.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                              style: TextStyle(fontSize: 13.5, color: p.text),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'بحث في المحادثات أو @يوزر...',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  color: p.muted.withOpacity(.75),
                                ),
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 17, color: p.muted),
                              ),
                            ),
                        ]),
                      ),
                    ),

                    // ---------- شريط القصص ----------
                    StoriesBar(partnerIds: partnerIds),

                    // ---------- تبويبات مجلدات تليجرام ----------
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: [
                        _Tab(
                          label: 'الكل',
                          selected: _folder == _ChatFolder.all,
                          onTap: () => setState(() => _folder = _ChatFolder.all),
                        ),
                        _Tab(
                          label: 'غير المقروءة',
                          selected: _folder == _ChatFolder.unread,
                          onTap: () => setState(() => _folder = _ChatFolder.unread),
                        ),
                        _Tab(
                          label: 'خاص',
                          selected: _folder == _ChatFolder.direct,
                          onTap: () => setState(() => _folder = _ChatFolder.direct),
                        ),
                        _Tab(
                          label: 'المجموعات',
                          selected: _folder == _ChatFolder.groups,
                          onTap: () => setState(() => _folder = _ChatFolder.groups),
                        ),
                        _Tab(
                          label: 'المثبتة',
                          selected: _folder == _ChatFolder.pinned,
                          onTap: () => setState(() => _folder = _ChatFolder.pinned),
                        ),
                      ]),
                    ),
                    Divider(
                      height: 1,
                      thickness: .6,
                      color: p.dark ? const Color(0x14FFFFFF) : p.border,
                    ),
                  ],
                ),
              ),

              // ---------- رابط البحث العام عند الكتابة ----------
              if (_query.isNotEmpty)
                InkWell(
                  onTap: goSearch,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.navActive.withOpacity(.08),
                      border: Border(
                        bottom: BorderSide(
                          color: p.dark ? const Color(0x10FFFFFF) : p.border,
                          width: .6,
                        ),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          'البحث عن مستخدمين جدد في Babylon...',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.navActive,
                          ),
                        ),
                      ),
                      Icon(Icons.person_search_outlined, size: 17, color: p.navActive),
                    ]),
                  ),
                ),

              // ---------- قائمة المحادثات ----------
              Expanded(
                child: !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : folderChats.isEmpty
                        ? _Empty(folder: _folder, onSearch: goSearch)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: folderChats.length,
                            itemBuilder: (_, i) => folderChats[i].data()['type'] == 'group'
                                ? _GroupTile(
                                    chat: folderChats[i],
                                    me: me,
                                    unreadOnly: _folder == _ChatFolder.unread,
                                    query: _query,
                                  )
                                : _ChatTile(
                                    chat: folderChats[i],
                                    me: me,
                                    unreadOnly: _folder == _ChatFolder.unread,
                                    query: _query,
                                  ),
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
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? p.navActive : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.navActive : p.muted,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final _ChatFolder folder;
  final VoidCallback onSearch;
  const _Empty({required this.folder, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final title = switch (folder) {
      _ChatFolder.unread => 'لا توجد رسائل غير مقروءة',
      _ChatFolder.groups => 'لا توجد مجموعات بعد',
      _ChatFolder.pinned => 'لا توجد محادثات مثبتة',
      _ => 'لا توجد محادثات بعد',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.navActive.withOpacity(.12),
            ),
            child: Center(child: BIcon('chat', size: 36, color: p.navActive)),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'ابحث عن صديق بيوزره وابدأ أول محادثة',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.navActive,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              minimumSize: const Size(170, 42),
            ),
            child: const Text('بحث عن مستخدمين'),
          ),
        ]),
      ),
    );
  }
}

void _chatMenu(BuildContext context, String chatId) {
  final prefs = context.read<AppPrefs>();
  final p = BP.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: BIcon('pin', color: p.navActive),
          title: Text(prefs.isPinned(chatId) ? 'إلغاء التثبيت' : 'تثبيت المحادثة'),
          onTap: () {
            Navigator.pop(context);
            prefs.togglePin(chatId);
          },
        ),
        ListTile(
          leading: BIcon(prefs.isMuted(chatId) ? 'bell' : 'bellOff', color: p.navActive),
          title: Text(prefs.isMuted(chatId) ? 'إلغاء الكتم' : 'كتم الإشعارات'),
          onTap: () {
            Navigator.pop(context);
            prefs.toggleMute(chatId);
          },
        ),
      ]),
    ),
  );
}

/// صف محادثة بأسلوب تليجرام:
/// السطر الأول: الاسم + التوثيق + أيقونة الكتم | صحّين القراءة + الوقت
/// السطر الثاني: معاينة الرسالة | أيقونة التثبيت أو شارة غير المقروء
Widget _chatRow(
  BuildContext context, {
  required Widget leading,
  required Widget nameRow,
  required Widget sub,
  required String time,
  required String chatId,
  Widget? readStatus,
  int unread = 0,
  required VoidCallback onTap,
}) {
  final p = BP.of(context);
  final prefs = context.watch<AppPrefs>();
  final muted = prefs.isMuted(chatId);
  final pinned = prefs.isPinned(chatId);

  return Column(mainAxisSize: MainAxisSize.min, children: [
    Material(
      color: pinned
          ? (p.dark ? const Color(0x07FFFFFF) : const Color(0x081E6FD9))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _chatMenu(context, chatId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Row(children: [
                      Flexible(child: nameRow),
                      if (muted)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 5),
                          child: Icon(Icons.volume_off_rounded, size: 14, color: p.muted),
                        ),
                    ]),
                  ),
                  if (readStatus != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: readStatus,
                    ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: unread > 0 && !muted ? p.navActive : p.muted,
                      fontWeight: unread > 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(child: sub),
                  if (pinned && unread == 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: BIcon('pin', size: 14, color: p.muted),
                    ),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: muted
                            ? (p.dark ? const Color(0xFF4A5969) : const Color(0xFF9AA8B8))
                            : p.navActive,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsetsDirectional.only(start: 80),
      child: Divider(
        height: .6,
        thickness: .6,
        color: p.dark ? const Color(0x0FFFFFFF) : p.border,
      ),
    ),
  ]);
}

TextStyle _nameStyle(BP p) => TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 15.5,
      color: p.dark ? const Color(0xFFF1F5F9) : const Color(0xFF17212B),
    );

class _GroupTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  final String query;
  const _GroupTile({
    required this.chat,
    required this.me,
    this.unreadOnly = false,
    this.query = '',
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final d = chat.data();
    final name = (d['name'] as String?) ?? 'مجموعة';
    final last = d['lastMsg'] as Map?;
    final lastText = (last?['text'] as String?) ?? 'لا توجد رسائل بعد';
    final at = (last?['at'] as num?)?.toInt() ?? ((d['updatedAt'] as num?)?.toInt() ?? 0);
    final readAt = ((d['readAt'] as Map?)?[me] as num?)?.toInt() ?? 0;
    final unread = last != null && last['senderId'] != me && at > readAt;

    if (unreadOnly && !unread) return const SizedBox.shrink();
    if (query.isNotEmpty &&
        !name.toLowerCase().contains(query) &&
        !lastText.toLowerCase().contains(query)) {
      return const SizedBox.shrink();
    }

    return _chatRow(
      context,
      chatId: chat.id,
      unread: unread ? 1 : 0,
      leading: Avatar(size: 54, url: d['photo'] as String?, name: name, seed: chat.id),
      nameRow: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.group, size: 15, color: p.muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle(p)),
        ),
      ]),
      sub: Text(
        lastText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          color: unread ? (p.dark ? Colors.white70 : p.text) : p.muted,
          fontWeight: unread ? FontWeight.w500 : null,
        ),
      ),
      time: at == 0 ? '' : formatChatTime(at),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot<Json> chat;
  final String me;
  final bool unreadOnly;
  final String query;
  const _ChatTile({
    required this.chat,
    required this.me,
    this.unreadOnly = false,
    this.query = '',
  });

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
            final username = ((u?['username'] as String?) ?? '').toLowerCase();
            final typing = data['typing_$other'] == true;

            if (query.isNotEmpty &&
                !name.toLowerCase().contains(query) &&
                !username.contains(query)) {
              return const SizedBox.shrink();
            }

            return StreamBuilder<Msg?>(
              stream: svc.lastMessage(chat.id),
              builder: (_, ms) {
                final m = ms.data;
                final mine = m != null && m.senderId == me;
                final strong = m != null && !mine && !m.read;

                final Widget? readStatus = (m != null && mine)
                    ? Icon(
                        m.read ? Icons.done_all : Icons.done,
                        size: 15,
                        color: m.read ? p.navActive : p.muted,
                      )
                    : null;

                final Widget subWidget;
                if (typing && !gone) {
                  subWidget = Text(
                    'يكتب الآن...',
                    style: TextStyle(fontSize: 13.5, color: p.navActive, fontWeight: FontWeight.w500),
                  );
                } else if (m == null) {
                  subWidget = Text(
                    'لا توجد رسائل بعد',
                    style: TextStyle(fontSize: 13.5, color: p.muted),
                  );
                } else {
                  subWidget = Text.rich(
                    TextSpan(children: [
                      if (mine)
                        TextSpan(
                          text: 'أنت: ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.navActive,
                          ),
                        ),
                      TextSpan(
                        text: m.preview,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: strong ? (p.dark ? Colors.white70 : p.text) : p.muted,
                          fontWeight: strong ? FontWeight.w500 : null,
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }

                return _chatRow(
                  context,
                  chatId: chat.id,
                  unread: unread,
                  readStatus: readStatus,
                  leading: Avatar(
                    size: 54,
                    url: gone ? null : avatarOf(u),
                    name: name,
                    seed: other,
                    deleted: gone,
                    online: gone ? null : isOnline(u ?? {}),
                  ),
                  nameRow: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gone ? _nameStyle(p).copyWith(color: p.muted) : _nameStyle(p),
                      ),
                    ),
                    if (u?['isVerified'] == true)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Icon(Icons.verified, size: 15, color: p.navActive),
                      ),
                  ]),
                  sub: subWidget,
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
      },
    );
  }
}
