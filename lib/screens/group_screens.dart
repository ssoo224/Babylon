import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

/// اختيار الأعضاء: من أصحاب محادثاتك + البحث بيوزر
class _MemberPicker extends StatefulWidget {
  final Set<String> exclude;
  final Set<String> selected;
  const _MemberPicker({required this.exclude, required this.selected});
  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final Map<String, Json> _people = {};
  final _q = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    final chats = await svc.chatsStream(me).first;
    for (final c in chats) {
      final d = c.data();
      if (d['type'] == 'group') continue;
      final other = ((d['participants'] as List?) ?? []).cast<String>().firstWhere((x) => x != me, orElse: () => '');
      if (other.isEmpty || widget.exclude.contains(other)) continue;
      final u = await svc.getUser(other);
      if (u != null) _people[other] = {...u, 'id': other};
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _find() async {
    final u = await context.read<ChatService>().findByUsername(_q.text);
    if (!mounted) return;
    if (u == null) return toast(context, 'لا يوجد مستخدم بهذا اليوزر');
    final id = u['id'] as String;
    if (widget.exclude.contains(id)) return toast(context, 'هذا المستخدم موجود بالفعل');
    setState(() {
      _people[id] = u;
      widget.selected.add(id);
    });
    _q.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _q,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _find(),
          decoration: InputDecoration(
            hintText: 'أضف عضواً بيوزره',
            prefixText: '@',
            suffixIcon: IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: _find),
          ),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _people.isEmpty
                ? const Center(child: Text('ابحث عن عضو بيوزره'))
                : ListView(
                    children: _people.values.map((u) {
                      final id = u['id'] as String;
                      final sel = widget.selected.contains(id);
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) => setState(() => v == true ? widget.selected.add(id) : widget.selected.remove(id)),
                        secondary: Avatar(url: avatarOf(u), name: u['displayName'] ?? '?'),
                        title: Text(u['displayName'] ?? ''),
                        subtitle: Text('@${u['username'] ?? ''}'),
                      );
                    }).toList(),
                  ),
      ),
    ]);
  }
}

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _name = TextEditingController();
  final Set<String> _sel = {};
  String _photo = '';
  bool _busy = false;

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _photo = toDataUrl(bytes));
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'اكتب اسم المجموعة');
    if (_sel.isEmpty) return toast(context, 'اختر عضواً واحداً على الأقل');
    setState(() => _busy = true);
    try {
      final me = context.read<AuthService>().uid;
      final id = await context.read<ChatService>().createGroup(me, name, _photo, _sel.toList());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id)));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'تعذر إنشاء المجموعة');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مجموعة جديدة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            GestureDetector(onTap: _pickPhoto, child: Avatar(url: _photo, name: _name.text.isEmpty ? '👥' : _name.text, size: 56)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'اسم المجموعة'))),
          ]),
        ),
        Expanded(child: _MemberPicker(exclude: {context.read<AuthService>().uid}, selected: _sel)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _busy ? null : _create,
              child: Text('إنشاء المجموعة (${_sel.length})'),
            ),
          ),
        ),
      ]),
    );
  }
}

class GroupInfoScreen extends StatelessWidget {
  final String chatId;
  const GroupInfoScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    return StreamBuilder<Json>(
      stream: svc.chatDoc(chatId),
      builder: (context, s) {
        final meta = s.data ?? {};
        final members = ((meta['participants'] as List?) ?? []).cast<String>();
        final owner = meta['ownerId'] as String?;
        final iAmOwner = owner == me;
        return Scaffold(
          appBar: AppBar(title: const Text('معلومات المجموعة')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: GestureDetector(
                onTap: !iAmOwner
                    ? null
                    : () async {
                        final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
                        if (x != null) svc.setGroupPhoto(chatId, toDataUrl(await x.readAsBytes()));
                      },
                child: Avatar(url: meta['photo'] as String?, name: (meta['name'] as String?) ?? '👥', size: 96),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text((meta['name'] as String?) ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            if (iAmOwner)
              TextButton(
                onPressed: () async {
                  final c = TextEditingController(text: (meta['name'] as String?) ?? '');
                  final v = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('اسم المجموعة'),
                      content: TextField(controller: c, maxLength: 40),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                        TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('حفظ')),
                      ],
                    ),
                  );
                  if (v != null && v.isNotEmpty) svc.renameGroup(chatId, v);
                },
                child: const Text('تغيير الاسم'),
              ),
            const SizedBox(height: 8),
            Text('${members.length} أعضاء', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (iAmOwner)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add)),
                title: const Text('إضافة أعضاء'),
                onTap: () async {
                  final sel = <String>{};
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('إضافة أعضاء')),
                        body: Column(children: [
                          Expanded(child: _MemberPicker(exclude: members.toSet(), selected: sel)),
                          Builder(
                            builder: (c) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('إضافة')),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                  if (ok == true && sel.isNotEmpty) svc.addMembers(chatId, me, sel.toList());
                },
              ),
            ...members.map((id) => FutureBuilder<Json?>(
                  future: svc.getUser(id),
                  builder: (_, us) {
                    final u = us.data ?? {};
                    return ListTile(
                      leading: Avatar(url: avatarOf(u), name: (u['displayName'] as String?) ?? '?'),
                      title: Text((u['displayName'] as String?) ?? '...'),
                      subtitle: Text('@${u['username'] ?? ''}'),
                      trailing: id == owner ? const Chip(label: Text('المالك')) : null,
                    );
                  },
                )),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('مغادرة المجموعة', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('مغادرة المجموعة'),
                    content: const Text('هل تريد مغادرة هذه المجموعة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مغادرة')),
                    ],
                  ),
                );
                if (ok == true) {
                  await svc.leaveGroup(chatId, me, meta);
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
          ]),
        );
      },
    );
  }
}
