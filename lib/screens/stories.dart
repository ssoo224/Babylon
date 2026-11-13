import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../core/cloudinary.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';

/// شريط القصص أعلى قائمة المحادثات: قصتي + قصص أصحاب المحادثات
class StoriesBar extends StatelessWidget {
  final List<String> partnerIds;
  const StoriesBar({super.key, required this.partnerIds});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final auth = context.watch<AuthService>();
    final me = auth.uid;
    return StreamBuilder<List<Json>>(
      stream: svc.activeStories(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final byUser = <String, List<Json>>{};
        for (final s in all) {
          final uid = s['userId'] as String?;
          if (uid == null) continue;
          if (uid == me || partnerIds.contains(uid)) byUser.putIfAbsent(uid, () => []).add(s);
        }
        final others = byUser.keys.where((k) => k != me).toList();
        if (others.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            children: [
              for (final uid in others)
                FutureBuilder<Json?>(
                  future: svc.getUser(uid),
                  builder: (_, us) {
                    final u = us.data ?? {};
                    return _Item(
                      label: (u['displayName'] as String?) ?? '',
                      child: Avatar(url: avatarOf(u), name: u['displayName'] ?? '?', size: 52, seed: uid, storyRing: true),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StoryViewer(stories: byUser[uid]!, owner: {...u, 'id': uid}, mine: false)),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// أفاتار قصتي بالرأس (hdrAvatarBtn): حلقة ذهبية إذا عندي قصة، و+ إذا ما عندي
class MyStoryAvatar extends StatelessWidget {
  const MyStoryAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final svc = context.read<ChatService>();
    final me = auth.uid;
    return StreamBuilder<List<Json>>(
      stream: svc.activeStories(),
      builder: (context, snap) {
        final mine = (snap.data ?? []).where((s) => s['userId'] == me).toList();
        final has = mine.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (has) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => StoryViewer(stories: mine, owner: auth.me ?? {}, mine: true)));
            } else {
              composeStory(context);
            }
          },
          onLongPress: () => composeStory(context),
          child: Stack(clipBehavior: Clip.none, children: [
            Avatar(url: auth.me?['avatarUrl'], name: auth.displayName, size: 38, seed: me, storyRing: has),
            if (!has)
              Positioned(
                bottom: -2,
                left: -2,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: BP.of(context).gold,
                  child: const Icon(Icons.add, size: 12, color: Colors.black),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// نشر قصة: صورة أو فيديو (حتى 30 ثانية)، مدة الظهور، تثبيت، وصف
Future<void> composeStory(BuildContext context) async {
  final picker = ImagePicker();
  final kind = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.image_outlined), title: const Text('صورة'), onTap: () => Navigator.pop(context, 'image')),
        ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('فيديو (حتى 30 ثانية)'), onTap: () => Navigator.pop(context, 'video')),
      ]),
    ),
  );
  if (kind == null || !context.mounted) return;
  XFile? x;
  if (kind == 'image') {
    x = await pickImageInApp(context);
  } else {
    x = await pickVideoInApp(context, maxSeconds: 30);
  }
  if (x == null || !context.mounted) return;
  final file = File(x.path);
  final cap = TextEditingController();
  int hours = 24;
  bool pin = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setS) => AlertDialog(
        title: const Text('نشر القصة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (kind == 'image')
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, height: 200, fit: BoxFit.cover))
            else
              const Icon(Icons.videocam, size: 64),
            const SizedBox(height: 10),
            TextField(controller: cap, decoration: const InputDecoration(hintText: 'أضف تعليقاً (اختياري)')),
            const SizedBox(height: 12),
            const Align(alignment: AlignmentDirectional.centerStart, child: Text('مدة ظهور القصة', style: TextStyle(fontWeight: FontWeight.w600))),
            Wrap(
              spacing: 8,
              children: [6, 12, 24, 48]
                  .map((h) => ChoiceChip(label: Text('$h ساعة'), selected: hours == h, onSelected: (_) => setS(() => hours = h)))
                  .toList(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تثبيت بالملف الشخصي'),
              value: pin,
              onChanged: (v) => setS(() => pin = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نشر')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  toast(context, 'جاري النشر...');
  final svc = context.read<ChatService>();
  final me = context.read<AuthService>().uid;
  String? err;
  if (kind == 'image') {
    var url = await Cloudinary.upload(file, video: false, folder: 'stories');
    url ??= toDataUrl(await file.readAsBytes());
    err = await svc.postStory(me, imageDataUrl: url, caption: cap.text.trim(), hours: hours, pinned: pin);
  } else {
    final url = await Cloudinary.upload(file, video: true, folder: 'stories');
    if (url == null) {
      if (context.mounted) toast(context, 'تعذر رفع الفيديو');
      return;
    }
    err = await svc.postStory(me,
        videoUrl: url, posterUrl: Cloudinary.posterOf(url), caption: cap.text.trim(), hours: hours, pinned: pin);
  }
  if (context.mounted) toast(context, err ?? 'تم نشر القصة ✓');
}

class _Item extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Item({required this.child, required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 64,
            child: Column(children: [
              child,
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
}

class StoryViewer extends StatefulWidget {
  final List<Json> stories;
  final Json owner;
  final bool mine;
  const StoryViewer({super.key, required this.stories, required this.owner, required this.mine});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  int _i = 0;
  double _progress = 0;
  Timer? _t;
  bool _paused = false;
  VideoPlayerController? _vc;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  static const _imgMs = 6000;

  Json get _s => widget.stories[_i];
  String get _ownerId => (_s['userId'] as String?) ?? (widget.owner['id'] as String? ?? '');

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() => setState(() => _paused = _replyFocus.hasFocus));
    _start();
  }

  Future<void> _start() async {
    _t?.cancel();
    await _vc?.dispose();
    _vc = null;
    _progress = 0;
    final s = _s;
    if (!widget.mine && s['id'] != null) {
      final auth = context.read<AuthService>();
      context.read<ChatService>().markStoryViewed(s['id'], auth.uid, auth.displayName);
    }
    final v = s['videoUrl'] as String?;
    if (v != null && v.isNotEmpty) {
      final c = VideoPlayerController.networkUrl(Uri.parse(v));
      _vc = c;
      await c.initialize();
      if (!mounted || _vc != c) return;
      c.play();
      setState(() {});
    }
    _t = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_paused) return;
      final c = _vc;
      if (c != null && c.value.isInitialized) {
        final d = c.value.duration.inMilliseconds;
        _progress = d == 0 ? 0 : c.value.position.inMilliseconds / d;
      } else {
        _progress += 50 / _imgMs;
      }
      setState(() {});
      if (_progress >= 1) _next();
    });
  }

  void _next() {
    if (_i < widget.stories.length - 1) {
      setState(() => _i++);
      _start();
    } else {
      _t?.cancel();
      if (mounted) Navigator.pop(context);
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
    _start();
  }

  @override
  void dispose() {
    _t?.cancel();
    _vc?.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _pause(bool v) {
    _paused = v;
    final c = _vc;
    if (c == null) return;
    if (v) {
      c.pause();
    } else {
      c.play();
    }
  }

  Future<void> _sendReply(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final me = context.read<AuthService>().uid;
    await context.read<ChatService>().replyToStory(me, _ownerId, t, _s);
    _reply.clear();
    _replyFocus.unfocus();
    if (mounted) toast(context, 'تم إرسال الرد');
  }

  Future<void> _heart() async {
    final me = context.read<AuthService>().uid;
    final svc = context.read<ChatService>();
    await svc.setStoryReaction(_s['id'], me, '❤️');
    await svc.replyToStory(me, _ownerId, '❤️', _s);
    if (mounted) toast(context, '❤️');
  }

  void _viewers() {
    _pause(true);
    final svc = context.read<ChatService>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => StreamBuilder<List<Json>>(
        stream: svc.storyViews(_s['id']),
        builder: (context, s) {
          final list = (s.data ?? []).where((v) => v['id'] != _ownerId).toList();
          return SafeArea(
            child: list.isEmpty
                ? const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('لا توجد مشاهدات بعد')))
                : ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(padding: const EdgeInsets.all(12), child: Text('${list.length} مشاهدة', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ...list.map((v) => FutureBuilder<Json?>(
                            future: svc.getUser(v['id']),
                            builder: (_, us) {
                              final u = us.data ?? {};
                              return ListTile(
                                leading: Avatar(url: avatarOf(u), name: (u['displayName'] as String?) ?? (v['name'] as String?) ?? '?'),
                                title: Text((u['displayName'] as String?) ?? (v['name'] as String?) ?? '...'),
                                trailing: v['react'] != null ? Text('${v['react']}', style: const TextStyle(fontSize: 22)) : null,
                              );
                            },
                          )),
                    ],
                  ),
          );
        },
      ),
    ).whenComplete(() => _pause(false));
  }

  Future<void> _edit() async {
    _pause(true);
    final c = TextEditingController(text: (_s['caption'] as String?) ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل الوصف'),
        content: TextField(controller: c, maxLength: 120),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (v != null) {
      await context.read<ChatService>().updateStory(_s['id'], {'caption': v});
      setState(() => _s['caption'] = v);
    }
    _pause(false);
  }

  Future<void> _togglePin() async {
    final now = !(_s['pinned'] == true);
    await context.read<ChatService>().updateStory(_s['id'], {'pinned': now});
    setState(() => _s['pinned'] = now);
    if (mounted) toast(context, now ? 'تم التثبيت بالملف الشخصي' : 'تم إلغاء التثبيت');
  }

  Future<void> _delete() async {
    _pause(true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف القصة'),
        content: const Text('هل تريد حذف هذه القصة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ChatService>().deleteStory(_s['id']);
      if (mounted) Navigator.pop(context);
    } else {
      _pause(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final img = imageFromUrl(s['imageUrl'] as String?);
    final isVideo = ((s['videoUrl'] as String?) ?? '').isNotEmpty;
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapUp: (d) {
          if (_replyFocus.hasFocus) {
            _replyFocus.unfocus();
            return;
          }
          final w = MediaQuery.of(context).size.width;
          d.localPosition.dx > w / 2 ? _prev() : _next();
        },
        onDoubleTap: widget.mine ? null : _heart,
        onLongPressStart: (_) => _pause(true),
        onLongPressEnd: (_) => _pause(false),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 500) Navigator.pop(context);
        },
        child: Stack(fit: StackFit.expand, children: [
          if (isVideo && _vc != null && _vc!.value.isInitialized)
            Center(child: AspectRatio(aspectRatio: _vc!.value.aspectRatio, child: VideoPlayer(_vc!)))
          else if (img != null)
            Image(image: img, fit: BoxFit.contain),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                    (k) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: k < _i ? 1 : (k == _i ? _progress.clamp(0, 1) : 0),
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Avatar(url: avatarOf(widget.owner), name: widget.owner['displayName'] ?? '?', size: 38),
                title: Text(widget.owner['displayName'] ?? '', style: const TextStyle(color: Colors.white)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.mine) ...[
                    IconButton(
                        icon: Icon(s['pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.white),
                        onPressed: _togglePin),
                    IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: _edit),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _delete),
                  ],
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              const Spacer(),
              if ((s['caption'] as String?)?.isNotEmpty == true)
                Container(
                  width: double.infinity,
                  color: Colors.black54,
                  padding: const EdgeInsets.all(16),
                  child: Text(s['caption'], style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                ),
              if (widget.mine)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: _viewers,
                      icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                      label: const Text('المشاهدون', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                )
              else
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          focusNode: _replyFocus,
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: _sendReply,
                          decoration: InputDecoration(
                            hintText: 'رد على القصة...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final e in const ['❤️', '😂', '🔥'])
                        IconButton(
                          onPressed: () async {
                            final me = context.read<AuthService>().uid;
                            await context.read<ChatService>().setStoryReaction(_s['id'], me, e);
                            await context.read<ChatService>().replyToStory(me, _ownerId, e, _s);
                            if (mounted) toast(context, e);
                          },
                          icon: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
