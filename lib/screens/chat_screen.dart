import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../core/api.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';
import 'group_screens.dart';
import 'other_profile_screen.dart';

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

  late final ChatService _svc;
  late final AuthService _auth;
  int _limit = 50;
  Msg? _reply;
  Msg? _editing;
  bool _typingSent = false;
  Timer? _typingTimer;
  bool _searching = false;
  String _q = '';

  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;

  final Map<String, Json> _users = {}; // أسماء المرسلين بالمجموعات
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
    await _svc.send(widget.chatId, _auth.uid, payload,
        replyTo: reply, group: widget.isGroup);
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
    final x = await _picker.pickImage(
        source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _sendPayload({'imageUrl': toDataUrl(bytes)}, '▧ صورة');
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

  Future<void> _stopRec({required bool send}) async {
    _recTimer?.cancel();
    final secs = _recSeconds;
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path == null) return;
    final f = File(path);
    if (!send || secs < 1) {
      f.delete().catchError((_) => f);
      return;
    }
    final bytes = await f.readAsBytes();
    f.delete().catchError((_) => f);
    await _sendPayload(
        {'audioUrl': toDataUrl(bytes, mime: 'audio/mp4'), 'duration': secs}, '♬ بصمة صوتية');
  }

  void _msgMenu(Msg m) {
    final mine = m.senderId == _auth.uid;
    final myReaction = m.reactions[_auth.uid] as String?;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '👍', '🔥'].map((e) {
                return InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    Navigator.pop(context);
                    _svc.react(widget.chatId, m.id, _auth.uid, myReaction == e ? null : e);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: myReaction == e
                          ? Theme.of(context).colorScheme.primary.withOpacity(.3)
                          : null,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('رد'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _reply = m;
                _editing = null;
              });
            },
          ),
          if (m.text.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.text));
                Navigator.pop(context);
                toast(context, 'تم النسخ');
              },
            ),
          if (mine && m.text.isNotEmpty && m.audioUrl == null && m.imageUrl == null)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _editing = m;
                  _reply = null;
                  _text.text = m.text;
                });
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _svc.deleteMessage(widget.chatId, m.id);
              },
            ),
        ]),
      ),
    );
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

  PreferredSizeWidget _appBar(BP pal, AppPrefs prefs, Json other, Json meta) {
    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _q = '';
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
    return AppBar(
      titleSpacing: 0,
      title: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isG
                ? GroupInfoScreen(chatId: widget.chatId)
                : OtherProfileScreen(uid: widget.otherId!),
          ),
        ),
        child: Row(children: [
          Avatar(url: photo, name: name, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
              Text(
                isG
                    ? '$count أعضاء'
                    : (meta['typing_${widget.otherId}'] == true ? 'يكتب الآن...' : statusOf(other)),
                style: TextStyle(
                    fontSize: 12,
                    color: (!isG && meta['typing_${widget.otherId}'] == true) ? pal.gold : pal.muted),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'mute') prefs.toggleMute(widget.chatId);
            if (v == 'block' && !isG) {
              _svc.blocks(_auth.uid).first.then((b) => b.contains(widget.otherId)
                  ? _svc.unblock(_auth.uid, widget.otherId!)
                  : _svc.block(_auth.uid, widget.otherId!));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'mute',
                child: Text(prefs.isMuted(widget.chatId) ? 'إلغاء كتم المحادثة' : 'كتم المحادثة')),
            if (!isG) const PopupMenuItem(value: 'block', child: Text('حظر / إلغاء الحظر')),
          ],
        ),
      ],
    );
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
            return Scaffold(
              backgroundColor: ct.chatBg,
              appBar: _appBar(pal, prefs, other, _meta),
              body: Column(children: [
                Expanded(
                  child: StreamBuilder<List<Msg>>(
                    stream: _svc.messages(widget.chatId, limit: _limit),
                    builder: (context, ms) {
                      if (!ms.hasData) return const Center(child: CircularProgressIndicator());
                      var list = ms.data!;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (widget.isGroup) {
                          _svc.markGroupRead(widget.chatId, me);
                        } else {
                          _svc.markRead(widget.chatId, me, list);
                        }
                      });
                      if (_q.isNotEmpty) {
                        list = list.where((m) => m.text.toLowerCase().contains(_q.toLowerCase())).toList();
                      }
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
                          return MessageBubble(
                            msg: m,
                            mine: m.senderId == me,
                            theme: ct,
                            font: prefs.font,
                            radius: prefs.radius,
                            isGroup: widget.isGroup,
                            senderName: _users[m.senderId]?['displayName'] as String?,
                            query: _q,
                            onLongPress: () => _msgMenu(m),
                            onImageTap: _viewImage,
                          );
                        },
                      );
                    },
                  ),
                ),
                if (!_searching) _composer(me, pal),
              ]),
            );
          },
        );
      },
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

  Widget _composerBox(BP pal) {
    final cs = Theme.of(context).colorScheme;
    final hasText = _text.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.dark ? const Color(0x33000000) : pal.border)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_reply != null || _editing != null)
            Container(
              color: pal.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(_editing != null ? Icons.edit : Icons.reply, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((_editing ?? _reply)!.text.isNotEmpty ? (_editing ?? _reply)!.text : '🎤 / 📷',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: _recording
                ? Row(children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}'),
                    const Spacer(),
                    TextButton(onPressed: () => _stopRec(send: false), child: const Text('إلغاء')),
                    IconButton.filled(onPressed: () => _stopRec(send: true), icon: const Icon(Icons.send)),
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    PopupMenuButton<ImageSource>(
                      icon: const Icon(Icons.attach_file),
                      onSelected: _sendImage,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: ImageSource.gallery, child: Text('معرض الصور')),
                        PopupMenuItem(value: ImageSource.camera, child: Text('الكاميرا')),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    hasText
                        ? IconButton.filled(
                            onPressed: _sendText,
                            icon: Icon(_editing != null ? Icons.check : Icons.send))
                        : IconButton.filled(onPressed: _startRec, icon: const Icon(Icons.mic)),
                  ]),
          ),
        ]),
      ),
    );
  }
}
