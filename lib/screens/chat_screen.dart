import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../core/api.dart';
import '../core/cloudinary.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../widgets/emoji_panel.dart';
import '../widgets/message_bubble.dart';
import '../widgets/pattern_layer.dart';
import '../widgets/voice_player.dart';
import 'forward_screen.dart';
import 'group_screens.dart';
import 'other_profile_screen.dart';
import 'video_screen.dart';

const _selEmojis = ['😂', '❤️', '👍🏻', '😭', '✨'];

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherId; // null = مجموعة
  const ChatScreen({super.key, required this.chatId, this.otherId});
  bool get isGroup => otherId == null;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _rec = AudioRecorder();
  final _picker = ImagePicker();
  final _focus = FocusNode();

  late final ChatService _svc;
  late final AuthService _auth;
  int _limit = 50;
  Msg? _reply;
  Msg? _editing;
  bool _typingSent = false;
  Timer? _typingTimer;

  bool _searching = false;
  String _q = '';
  String _filter = 'all'; // all | mine | others

  bool _selecting = false;
  final Set<String> _selected = {};
  List<Msg> _current = [];

  bool _emojiOpen = false;
  bool _uploading = false;

  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _voiceData; // معاينة الصوت قبل الإرسال
  int _voiceSecs = 0;

  final Map<String, Json> _users = {};
  final Set<String> _fetching = {};
  Json _meta = {};

  @override
  void initState() {
    super.initState();
    _svc = context.read<ChatService>();
    _auth = context.read<AuthService>();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 && mounted) {
        setState(() => _limit += 50);
      }
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recTimer?.cancel();
    if (!widget.isGroup) _svc.setTyping(widget.chatId, _auth.uid, false);
    _rec.dispose();
    _text.dispose();
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _loadUser(String uid) {
    if (_users.containsKey(uid) || _fetching.contains(uid)) return;
    _fetching.add(uid);
    _svc.getUser(uid).then((u) {
      if (mounted) setState(() => _users[uid] = u ?? {});
    });
  }

  void _onChanged(String v) {
    if (!widget.isGroup) {
      if (!_typingSent && v.isNotEmpty) {
        _typingSent = true;
        _svc.setTyping(widget.chatId, _auth.uid, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _typingSent = false;
        _svc.setTyping(widget.chatId, _auth.uid, false);
      });
    }
    setState(() {});
  }

  void _notify(String preview) {
    final others = widget.isGroup
        ? ((_meta['participants'] as List?) ?? []).cast<String>().where((x) => x != _auth.uid)
        : [widget.otherId!];
    for (final id in others) {
      BabylonApi.notifyPeer(
        me: _auth.user!,
        recipientId: id,
        chatId: widget.chatId,
        senderName: _auth.displayName,
        text: preview,
      );
    }
  }

  Future<void> _sendPayload(Json payload, String preview) async {
    final reply = _reply;
    setState(() => _reply = null);
    await _svc.send(widget.chatId, _auth.uid, payload, replyTo: reply, group: widget.isGroup);
    _notify(preview);
  }

  Future<void> _sendText() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    if (_editing != null) {
      await _svc.editMessage(widget.chatId, _editing!.id, t);
      setState(() => _editing = null);
      _text.clear();
      return;
    }
    _text.clear();
    await _sendPayload({'text': t}, t);
  }

  Future<void> _sendImage(ImageSource src) async {
    final x = await _picker.pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 78);
    if (x == null) return;
    setState(() => _uploading = true);
    try {
      var url = await Cloudinary.upload(File(x.path), video: false);
      url ??= toDataUrl(await x.readAsBytes());
      await _sendPayload({'imageUrl': url}, '▧ صورة');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _sendVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (x == null) return;
    final f = File(x.path);
    if (await f.length() > 100 * 1024 * 1024) {
      if (mounted) toast(context, 'الفيديو أكبر من 100MB');
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await Cloudinary.upload(f, video: true);
      if (url == null) {
        if (mounted) toast(context, 'تعذر رفع الفيديو');
        return;
      }
      await _sendPayload({'videoUrl': url, 'posterUrl': Cloudinary.posterOf(url)}, '▶ فيديو');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _startRec() async {
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, 'يلزم السماح باستخدام المايكروفون');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/v_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000), path: path);
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _recSeconds = 0;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recSeconds++);
    });
  }

  /// يوقف التسجيل ويعرض معاينة قبل الإرسال
  Future<void> _stopRec({required bool keep}) async {
    _recTimer?.cancel();
    final secs = _recSeconds;
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path == null) return;
    final f = File(path);
    if (!keep || secs < 1) {
      f.delete().catchError((_) => f);
      return;
    }
    final bytes = await f.readAsBytes();
    f.delete().catchError((_) => f);
    setState(() {
      _voiceData = toDataUrl(bytes, mime: 'audio/mp4');
      _voiceSecs = secs;
    });
  }

  Future<void> _sendVoice() async {
    final d = _voiceData;
    if (d == null) return;
    final secs = _voiceSecs;
    setState(() => _voiceData = null);
    await _sendPayload({'audioUrl': d, 'duration': secs}, '♬ بصمة صوتية');
  }

  // ---------------- التحديد والإجراءات ----------------
  void _enterSel(Msg m) {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(m.id);
    });
  }

  void _toggleSel(Msg m) {
    setState(() {
      _selected.contains(m.id) ? _selected.remove(m.id) : _selected.add(m.id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _exitSel() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  List<Msg> get _selMsgs =>
      _current.where((m) => _selected.contains(m.id)).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> _react(Msg m, String emoji) async {
    final cur = m.reactions[_auth.uid] as String?;
    await _svc.react(widget.chatId, m.id, _auth.uid, cur == emoji ? null : emoji);
  }

  void _fullEmojiForReaction(Msg m) {
    showModalBottomSheet(
      context: context,
      builder: (_) => EmojiPanel(
        height: 340,
        onPick: (e) {
          Navigator.pop(context);
          _react(m, e);
          _exitSel();
        },
      ),
    );
  }

  void _reactors(Msg m) {
    final entries = m.reactions.entries.where((e) => e.value is String).toList();
    for (final e in entries) {
      _loadUser(e.key);
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: entries.map((e) {
            final u = _users[e.key] ?? {};
            final isMe = e.key == _auth.uid;
            return ListTile(
              leading: Avatar(url: avatarOf(u), name: (u['displayName'] as String?) ?? '?'),
              title: Text(isMe ? 'أنت' : ((u['displayName'] as String?) ?? '...')),
              subtitle: isMe ? const Text('اضغط لإزالة تفاعلك') : null,
              trailing: Text(e.value as String, style: const TextStyle(fontSize: 24)),
              onTap: isMe
                  ? () {
                      Navigator.pop(context);
                      _svc.react(widget.chatId, m.id, _auth.uid, null);
                    }
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _replySel() {
    final m = _selMsgs.first;
    setState(() {
      _reply = m;
      _editing = null;
    });
    _exitSel();
    _focus.requestFocus();
  }

  void _copySel() {
    final t = _selMsgs.map((m) => m.text).where((t) => t.isNotEmpty).join('\n');
    if (t.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: t));
      toast(context, 'تم النسخ');
    }
    _exitSel();
  }

  void _editSel() {
    final m = _selMsgs.first;
    setState(() {
      _editing = m;
      _reply = null;
      _text.text = m.text;
    });
    _exitSel();
    _focus.requestFocus();
  }

  Future<void> _forwardSel() async {
    final msgs = _selMsgs;
    final targets = await Navigator.push<List<ForwardTarget>>(
        context, MaterialPageRoute(builder: (_) => const ForwardScreen()));
    if (targets == null || targets.isEmpty) return;
    for (final t in targets) {
      await _svc.forward(t.chatId, _auth.uid, msgs, group: t.group);
    }
    if (mounted) toast(context, 'تمت إعادة التوجيه ✓');
    _exitSel();
  }

  Future<void> _deleteSel() async {
    final msgs = _selMsgs;
    final allMine = msgs.every((m) => m.senderId == _auth.uid);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(msgs.length > 1 ? 'حذف ${msgs.length} رسائل' : 'حذف الرسالة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('حذف لدي فقط'),
            onTap: () => Navigator.pop(context, 'me'),
          ),
          if (allMine)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('حذف لدى الكل', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ListTile(title: const Center(child: Text('إلغاء')), onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
    if (choice == null) return;
    for (final m in msgs) {
      if (choice == 'all') {
        await _svc.deleteMessage(widget.chatId, m.id);
      } else {
        await _svc.deleteForMe(widget.chatId, m.id, _auth.uid);
      }
    }
    _exitSel();
  }

  void _viewImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(child: Image(image: imageFromUrl(url)!))),
        ),
      ),
    );
  }

  void _openVideo(String url) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(url: url)));

  // ---------------- الواجهة ----------------
  PreferredSizeWidget _appBar(BP pal, AppPrefs prefs, Json other, Json meta) {
    if (_selecting) {
      final one = _selected.length == 1 && _selMsgs.isNotEmpty;
      final m = one ? _selMsgs.first : null;
      final mine = m != null && m.senderId == _auth.uid;
      return AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _exitSel),
        title: Text('${_selected.length}'),
        actions: [
          if (one) IconButton(icon: const Icon(Icons.reply), tooltip: 'رد', onPressed: _replySel),
          if (_selMsgs.any((x) => x.text.isNotEmpty))
            IconButton(icon: const Icon(Icons.copy), tooltip: 'نسخ', onPressed: _copySel),
          if (one && mine && m.text.isNotEmpty && !m.isMedia)
            IconButton(icon: const Icon(Icons.edit), tooltip: 'تعديل', onPressed: _editSel),
          IconButton(icon: const Icon(Icons.shortcut), tooltip: 'إعادة توجيه', onPressed: _forwardSel),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: _deleteSel),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _q = '';
            _filter = 'all';
            _search.clear();
          }),
        ),
        title: TextField(
          controller: _search,
          autofocus: true,
          onChanged: (v) => setState(() {
            _q = v.trim();
            if (_q.isNotEmpty && _limit < 500) _limit = 500;
          }),
          decoration: const InputDecoration(
            hintText: 'ابحث في المحادثة...',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      );
    }
    final isG = widget.isGroup;
    final name = isG ? ((meta['name'] as String?) ?? 'مجموعة') : ((other['displayName'] as String?) ?? '...');
    final photo = isG ? meta['photo'] as String? : avatarOf(other);
    final count = ((meta['participants'] as List?) ?? []).length;
    final typing = !isG && meta['typing_${widget.otherId}'] == true;
    return AppBar(
      toolbarHeight: 60,
      titleSpacing: 0,
      title: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isG ? GroupInfoScreen(chatId: widget.chatId) : OtherProfileScreen(uid: widget.otherId!),
          ),
        ),
        child: Row(children: [
          Avatar(url: photo, name: name, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text(isG ? '$count أعضاء' : (typing ? 'يكتب الآن...' : statusOf(other)),
                  style: TextStyle(fontSize: 12, color: typing ? pal.gold : pal.muted)),
            ]),
          ),
        ]),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _searching = true)),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'mute') prefs.toggleMute(widget.chatId);
            if (v == 'clear') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('مسح المحادثة'),
                  content: const Text('سيتم مسح الرسائل الحالية من عندك فقط. الطرف الآخر ما يتأثر.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مسح')),
                  ],
                ),
              );
              if (ok == true) prefs.clearChat(widget.chatId);
            }
            if (v == 'block' && !isG) {
              _svc.blocks(_auth.uid).first.then((b) => b.contains(widget.otherId)
                  ? _svc.unblock(_auth.uid, widget.otherId!)
                  : _svc.block(_auth.uid, widget.otherId!));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'mute', child: Text(prefs.isMuted(widget.chatId) ? 'إلغاء كتم المحادثة' : 'كتم المحادثة')),
            const PopupMenuItem(value: 'clear', child: Text('مسح المحادثة')),
            if (!isG) const PopupMenuItem(value: 'block', child: Text('حظر / إلغاء الحظر')),
          ],
        ),
      ],
    );
  }

  bool _sameDay(int a, int b) {
    final x = DateTime.fromMillisecondsSinceEpoch(a), y = DateTime.fromMillisecondsSinceEpoch(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    return DateFormat('EEEE d MMMM yyyy', 'ar').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.uid;
    final prefs = context.watch<AppPrefs>();
    final pal = BP.of(context);
    final ct = chatThemeFor(prefs.chatTheme, pal.dark);

    return StreamBuilder<Json>(
      stream: _svc.chatDoc(widget.chatId),
      builder: (context, cs) {
        _meta = cs.data ?? {};
        return StreamBuilder<Json?>(
          stream: widget.isGroup ? Stream<Json?>.empty() : _svc.userStream(widget.otherId!),
          builder: (context, us) {
            final other = us.data ?? {};
            return PopScope(
              canPop: !_selecting && !_emojiOpen,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (_selecting) _exitSel();
                if (_emojiOpen) setState(() => _emojiOpen = false);
              },
              child: Scaffold(
                backgroundColor: ct.chatBg,
                appBar: _appBar(pal, prefs, other, _meta),
                body: Column(children: [
                  if (_searching)
                    Container(
                      color: pal.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(children: [
                        for (final f in const [['all', 'الكل'], ['mine', 'رسائلي'], ['others', 'من الآخرين']])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(f[1]),
                              selected: _filter == f[0],
                              onSelected: (_) => setState(() => _filter = f[0]),
                            ),
                          ),
                      ]),
                    ),
                  Expanded(
                    child: Stack(children: [
                      Positioned.fill(child: PatternLayer(theme: ct)),
                      StreamBuilder<List<Msg>>(
                        stream: _svc.messages(widget.chatId, limit: _limit),
                        builder: (context, ms) {
                          if (!ms.hasData) return const Center(child: CircularProgressIndicator());
                          final all = ms.data!;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (widget.isGroup) {
                              _svc.markGroupRead(widget.chatId, me);
                            } else {
                              _svc.markRead(widget.chatId, me, all);
                            }
                          });
                          final clearedAt = prefs.cleared[widget.chatId] ?? 0;
                          var list = all.where((m) => !m.deletedFor.contains(me) && m.createdAt > clearedAt).toList();
                          _current = list;
                          if (_q.isNotEmpty) {
                            list = list.where((m) => m.text.toLowerCase().contains(_q.toLowerCase())).toList();
                          }
                          if (_searching && _filter == 'mine') list = list.where((m) => m.senderId == me).toList();
                          if (_searching && _filter == 'others') list = list.where((m) => m.senderId != me).toList();
                          if (list.isEmpty) {
                            return Center(
                                child: Text(_q.isNotEmpty ? 'لا توجد نتائج' : 'ابدأ المحادثة بإرسال رسالة',
                                    style: TextStyle(color: ct.textOther)));
                          }
                          return ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final m = list[i];
                              if (widget.isGroup && !m.system && m.senderId != me) _loadUser(m.senderId);
                              final older = i + 1 < list.length ? list[i + 1] : null;
                              final newDay = older == null || !_sameDay(m.createdAt, older.createdAt);
                              final bubble = MessageBubble(
                                msg: m,
                                mine: m.senderId == me,
                                myUid: me,
                                theme: ct,
                                font: prefs.font,
                                radius: prefs.radius,
                                isGroup: widget.isGroup,
                                senderName: _users[m.senderId]?['displayName'] as String?,
                                query: _q,
                                selected: _selected.contains(m.id),
                                selecting: _selecting,
                                onLongPress: () => _selecting ? _toggleSel(m) : _enterSel(m),
                                onTap: () => _toggleSel(m),
                                onDoubleTap: () => _react(m, '❤️'),
                                onReactionsTap: () => _reactors(m),
                                onImageTap: _viewImage,
                                onVideoTap: _openVideo,
                              );
                              if (!newDay) return bubble;
                              return Column(children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: ct.other.withOpacity(.75), borderRadius: BorderRadius.circular(12)),
                                  child: Text(_dayLabel(m.createdAt),
                                      style: TextStyle(fontSize: 12, color: ct.textOther)),
                                ),
                                bubble,
                              ]);
                            },
                          );
                        },
                      ),
                    ]),
                  ),
                  if (_selecting && _selected.length == 1 && _selMsgs.isNotEmpty) _selEmojiBar(pal),
                  if (!_searching && !_selecting) _composer(me, pal),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _selEmojiBar(BP pal) {
    final m = _selMsgs.first;
    final cur = m.reactions[_auth.uid] as String?;
    return Container(
      color: pal.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final e in _selEmojis)
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                _react(m, e);
                _exitSel();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: cur == e ? pal.gold.withOpacity(.3) : null),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _fullEmojiForReaction(m)),
        ]),
      ),
    );
  }

  Widget _composer(String me, BP pal) {
    if (widget.isGroup) {
      final parts = ((_meta['participants'] as List?) ?? []).cast<String>();
      if (_meta.isNotEmpty && !parts.contains(me)) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('لم تعد عضواً في هذه المجموعة', textAlign: TextAlign.center, style: TextStyle(color: pal.muted)),
          ),
        );
      }
      return _composerBox(pal);
    }
    return StreamBuilder<Set<String>>(
      stream: _svc.blocks(me),
      builder: (context, mine) => StreamBuilder<bool>(
        stream: _svc.blockedBy(me, widget.otherId!),
        builder: (context, theirs) {
          final iBlocked = mine.data?.contains(widget.otherId) ?? false;
          final blockedMe = theirs.data ?? false;
          if (iBlocked || blockedMe) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  iBlocked ? 'لقد حظرت هذا المستخدم' : 'لا يمكنك مراسلة هذا المستخدم',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted),
                ),
              ),
            );
          }
          return _composerBox(pal);
        },
      ),
    );
  }

  void _insertEmoji(String e) {
    final sel = _text.selection;
    final t = _text.text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(
      text: t.replaceRange(start, end, e),
      selection: TextSelection.collapsed(offset: start + e.length),
    );
    setState(() {});
  }

  Widget _composerBox(BP pal) {
    final cs = Theme.of(context).colorScheme;
    final hasText = _text.text.trim().isNotEmpty;
    Widget row;
    if (_voiceData != null) {
      row = Row(children: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _voiceData = null)),
        Expanded(child: VoicePlayer(key: ValueKey(_voiceData.hashCode), url: _voiceData!, seconds: _voiceSecs)),
        IconButton.filled(onPressed: _sendVoice, icon: const Icon(Icons.send)),
      ]);
    } else if (_recording) {
      row = Row(children: [
        const Icon(Icons.fiber_manual_record, color: Colors.red),
        const SizedBox(width: 8),
        Text('${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}'),
        const Spacer(),
        TextButton(onPressed: () => _stopRec(keep: false), child: const Text('إلغاء')),
        IconButton.filled(onPressed: () => _stopRec(keep: true), icon: const Icon(Icons.stop)),
      ]);
    } else {
      row = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.attach_file),
          onSelected: (v) {
            if (v == 'gallery') _sendImage(ImageSource.gallery);
            if (v == 'camera') _sendImage(ImageSource.camera);
            if (v == 'video') _sendVideo();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'gallery', child: Text('معرض الصور')),
            PopupMenuItem(value: 'camera', child: Text('الكاميرا')),
            PopupMenuItem(value: 'video', child: Text('فيديو')),
          ],
        ),
        IconButton(
          icon: Icon(_emojiOpen ? Icons.keyboard : Icons.emoji_emotions_outlined),
          onPressed: () {
            if (_emojiOpen) {
              setState(() => _emojiOpen = false);
              _focus.requestFocus();
            } else {
              _focus.unfocus();
              setState(() => _emojiOpen = true);
            }
          },
        ),
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            onChanged: _onChanged,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'اكتب رسالة...',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        hasText
            ? IconButton.filled(onPressed: _sendText, icon: Icon(_editing != null ? Icons.check : Icons.send))
            : IconButton.filled(onPressed: _startRec, icon: const Icon(Icons.mic)),
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.dark ? const Color(0x33000000) : pal.border)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_uploading) const LinearProgressIndicator(minHeight: 2),
          if (_reply != null || _editing != null)
            Container(
              color: pal.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(_editing != null ? Icons.edit : Icons.reply, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((_editing ?? _reply)!.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _reply = null;
                    if (_editing != null) _text.clear();
                    _editing = null;
                  }),
                ),
              ]),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 6, 8, 6), child: row),
          if (_emojiOpen) EmojiPanel(onPick: _insertEmoji),
        ]),
      ),
    );
  }
}
