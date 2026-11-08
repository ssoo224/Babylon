import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../core/api.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';
import 'other_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherId;
  const ChatScreen({super.key, required this.chatId, required this.otherId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
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

  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    _svc = context.read<ChatService>();
    _auth = context.read<AuthService>();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        // تحميل رسائل أقدم
        if (mounted) setState(() => _limit += 50);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recTimer?.cancel();
    _svc.setTyping(widget.chatId, _auth.uid, false);
    _rec.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (!_typingSent && v.isNotEmpty) {
      _typingSent = true;
      _svc.setTyping(widget.chatId, _auth.uid, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _typingSent = false;
      _svc.setTyping(widget.chatId, _auth.uid, false);
    });
    setState(() {});
  }

  void _notify(String preview) {
    BabylonApi.notifyPeer(
      me: _auth.user!,
      recipientId: widget.otherId,
      chatId: widget.chatId,
      senderName: _auth.displayName,
      text: preview,
    );
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
    final reply = _reply;
    _text.clear();
    setState(() => _reply = null);
    await _svc.send(widget.chatId, _auth.uid, {'text': t}, replyTo: reply);
    _notify(t);
  }

  Future<void> _sendImage(ImageSource src) async {
    final x = await _picker.pickImage(
        source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _svc.send(widget.chatId, _auth.uid, {'imageUrl': toDataUrl(bytes)},
        replyTo: _reply);
    setState(() => _reply = null);
    _notify('📷 صورة');
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
    await _svc.send(
      widget.chatId,
      _auth.uid,
      {'audioUrl': toDataUrl(bytes, mime: 'audio/mp4'), 'duration': secs},
      replyTo: _reply,
    );
    setState(() => _reply = null);
    _notify('♬ بصمة صوتية');
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
          body: Center(
            child: InteractiveViewer(child: Image(image: imageFromUrl(url)!)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.uid;
    return StreamBuilder<Json?>(
      stream: _svc.userStream(widget.otherId),
      builder: (context, us) {
        final u = us.data ?? {};
        final name = (u['displayName'] as String?) ?? '...';
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OtherProfileScreen(uid: widget.otherId))),
              child: Row(children: [
                Avatar(url: u['avatarUrl'], name: name, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16)),
                        StreamBuilder<Json>(
                          stream: _svc.chatDoc(widget.chatId),
                          builder: (_, cs) {
                            final typing = cs.data?['typing_${widget.otherId}'] == true;
                            return Text(
                              typing ? 'يكتب الآن...' : formatLastSeen(u),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: typing
                                      ? Theme.of(context).colorScheme.primary
                                      : null),
                            );
                          },
                        ),
                      ]),
                ),
              ]),
            ),
            actions: [
              StreamBuilder<Set<String>>(
                stream: _svc.blocks(me),
                builder: (_, bs) {
                  final blocked = bs.data?.contains(widget.otherId) ?? false;
                  return PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'block') {
                        blocked
                            ? _svc.unblock(me, widget.otherId)
                            : _svc.block(me, widget.otherId);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'block',
                          child: Text(blocked ? 'إلغاء الحظر' : 'حظر المستخدم')),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<Msg>>(
                stream: _svc.messages(widget.chatId, limit: _limit),
                builder: (context, ms) {
                  if (!ms.hasData) return const Center(child: CircularProgressIndicator());
                  final list = ms.data!;
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _svc.markRead(widget.chatId, me, list));
                  if (list.isEmpty) {
                    return const Center(child: Text('ابدأ المحادثة بإرسال رسالة'));
                  }
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => MessageBubble(
                      msg: list[i],
                      mine: list[i].senderId == me,
                      onLongPress: () => _msgMenu(list[i]),
                      onImageTap: _viewImage,
                    ),
                  );
                },
              ),
            ),
            _composer(me),
          ]),
        );
      },
    );
  }

  Widget _composer(String me) {
    return StreamBuilder<Set<String>>(
      stream: _svc.blocks(me),
      builder: (context, mine) => StreamBuilder<bool>(
        stream: _svc.blockedBy(me, widget.otherId),
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
                ),
              ),
            );
          }
          final cs = Theme.of(context).colorScheme;
          final hasText = _text.text.trim().isNotEmpty;
          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_reply != null || _editing != null)
                Container(
                  color: cs.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    Icon(_editing != null ? Icons.edit : Icons.reply, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_editing ?? _reply)!.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        TextButton(
                            onPressed: () => _stopRec(send: false),
                            child: const Text('إلغاء')),
                        IconButton.filled(
                            onPressed: () => _stopRec(send: true),
                            icon: const Icon(Icons.send)),
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
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        hasText
                            ? IconButton.filled(
                                onPressed: _sendText,
                                icon: Icon(_editing != null ? Icons.check : Icons.send))
                            : IconButton.filled(
                                onPressed: _startRec, icon: const Icon(Icons.mic)),
                      ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
