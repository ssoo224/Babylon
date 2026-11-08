import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
          if (uid == me || partnerIds.contains(uid)) {
            byUser.putIfAbsent(uid, () => []).add(s);
          }
        }
        final others = byUser.keys.where((k) => k != me).toList();
        return SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            children: [
              _Item(
                label: 'قصتي',
                child: Stack(children: [
                  Avatar(
                    url: auth.me?['avatarUrl'],
                    name: auth.displayName,
                    size: 56,
                    storyRing: byUser.containsKey(me),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.add, size: 14, color: Colors.black),
                    ),
                  ),
                ]),
                onTap: () {
                  if (byUser.containsKey(me)) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => StoryViewer(stories: byUser[me]!, owner: auth.me ?? {}, mine: true)));
                  } else {
                    _compose(context);
                  }
                },
                onLongPress: () => _compose(context),
              ),
              for (final uid in others)
                FutureBuilder<Json?>(
                  future: svc.getUser(uid),
                  builder: (_, us) {
                    final u = us.data ?? {};
                    return _Item(
                      label: (u['displayName'] as String?) ?? '',
                      child: Avatar(url: u['avatarUrl'], name: u['displayName'] ?? '?', size: 56, storyRing: true),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StoryViewer(stories: byUser[uid]!, owner: u, mine: false)),
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

  Future<void> _compose(BuildContext context) async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1920, imageQuality: 72);
    if (x == null || !context.mounted) return;
    final bytes = await x.readAsBytes();
    if (!context.mounted) return;
    final cap = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, height: 260, fit: BoxFit.cover)),
          const SizedBox(height: 10),
          TextField(controller: cap, decoration: const InputDecoration(hintText: 'أضف تعليقاً (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نشر القصة')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await context.read<ChatService>().postStory(
        context.read<AuthService>().uid,
        imageDataUrl: toDataUrl(bytes),
        caption: cap.text.trim());
    if (context.mounted) toast(context, err ?? 'تم نشر القصة');
  }
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
  static const _dur = 6000;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _t?.cancel();
    _progress = 0;
    final s = widget.stories[_i];
    if (!widget.mine && s['id'] != null) {
      final auth = context.read<AuthService>();
      context.read<ChatService>().markStoryViewed(s['id'], auth.uid, auth.displayName);
    }
    _t = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _progress += 50 / _dur);
      if (_progress >= 1) _next();
    });
  }

  void _next() {
    if (_i < widget.stories.length - 1) {
      setState(() => _i++);
      _start();
    } else {
      _t?.cancel();
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
    _start();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stories[_i];
    final img = imageFromUrl(s['imageUrl']);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          // RTL: الجهة اليمنى = السابق
          d.localPosition.dx > w / 2 ? _prev() : _next();
        },
        onLongPressStart: (_) => _t?.cancel(),
        onLongPressEnd: (_) => _start(),
        child: Stack(fit: StackFit.expand, children: [
          if (img != null) Image(image: img, fit: BoxFit.contain),
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
                leading: Avatar(url: widget.owner['avatarUrl'], name: widget.owner['displayName'] ?? '?', size: 38),
                title: Text(widget.owner['displayName'] ?? '', style: const TextStyle(color: Colors.white)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.mine)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: () async {
                        await context.read<ChatService>().deleteStory(s['id']);
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
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
            ]),
          ),
        ]),
      ),
    );
  }
}
