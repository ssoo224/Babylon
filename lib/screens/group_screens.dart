import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../core/theme.dart';
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
    try {
      final chats = await svc.chatsStream(me).first;
      final ids = <String>{};
      for (final c in chats) {
        final d = c.data();
        if (d['type'] == 'group') continue;
        final other = ((d['participants'] as List?) ?? []).cast<String>().firstWhere((x) => x != me, orElse: () => '');
        if (other.isNotEmpty && !widget.exclude.contains(other)) {
          ids.add(other);
        }
      }
      
      // جلب كل المستخدمين مرة واحدة بدلاً من واحد تلو الآخر
      final users = await Future.wait(ids.map((id) => svc.getUser(id)));
      for (int i = 0; i < ids.length; i++) {
        if (users[i] != null) _people[ids.elementAt(i)] = {...users[i]!, 'id': ids.elementAt(i)};
      }
    } catch (e) {
      // تجاهل الخطأ
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _find() async {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    final u = await context.read<ChatService>().findByUsername(q);
    if (!mounted) return;
    if (u == null) return toast(context, 'لا يوجد مستخدم بهذا اليوزر');
    final id = u['id'] as String;
    if (widget.exclude.contains(id)) return toast(context, 'هذا المستخدم موجود بالفعل');
    
    setState(() {
      _people[id] = u;
      widget.selected.add(id); // إضافة تلقائية عند البحث
    });
    _q.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return Column(children: [
      // البحث
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _q,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _find(),
          decoration: InputDecoration(
            hintText: 'ابحث عن عضو بيوزر...',
            prefixText: '@',
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: _find),
          ),
        ),
      ),
      // شريط الأعضاء المختارين
      if (widget.selected.isNotEmpty)
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: widget.selected.map((id) {
              final u = _people[id] ?? {};
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: InputChip(
                  avatar: Avatar(url: avatarOf(u), name: u['displayName'] ?? '?', size: 24),
                  label: Text(u['displayName'] ?? '...'),
                  onDeleted: () => setState(() => widget.selected.remove(id)),
                ),
              );
            }).toList(),
          ),
        ),
      // القائمة
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _people.isEmpty
                ? const Center(child: Text('ابحث عن عضو بيوزره لإضافته'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: _people.values.map((u) {
                      final id = u['id'] as String;
                      final sel = widget.selected.contains(id);
                      return CheckboxListTile(
                        value: sel,
                        activeColor: p.gold,
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

// =================== إنشاء مجموعة ===================
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
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(
        title: const Text('مجموعة جديدة'),
        actions: [
          if (_busy) 
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else 
            TextButton(
              onPressed: _create,
              child: const Text('إنشاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            GestureDetector(
              onTap: _pickPhoto, 
              child: Stack(children: [
                Avatar(url: _photo, name: _name.text.isEmpty ? '👥' : _name.text, size: 64),
                Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 12, backgroundColor: p.gold, child: const Icon(Icons.camera_alt, size: 14, color: Colors.black))),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _name, 
                onChanged: (_) => setState(() {}), 
                decoration: const InputDecoration(
                  hintText: 'اسم المجموعة',
                  border: UnderlineInputBorder(),
                )
              )
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _MemberPicker(exclude: {context.read<AuthService>().uid}, selected: _sel)),
      ]),
    );
  }
}

// =================== معلومات المجموعة ===================
class GroupInfoScreen extends StatelessWidget {
  final String chatId;
  const GroupInfoScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    final p = BP.of(context);

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('معلومات المجموعة')),
      body: StreamBuilder<Json>(
        stream: svc.chatDoc(chatId),
        builder: (context, s) {
          final meta = s.data ?? {};
          final members = ((meta['participants'] as List?) ?? []).cast<String>();
          final owner = meta['ownerId'] as String?;
          final iAmOwner = owner == me;
          
          if (s.connectionState == ConnectionState.waiting && meta.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<Json?>>(
            // جلب كل الأعضاء مرة واحدة
            future: Future.wait(members.map((id) => svc.getUser(id))),
            builder: (context, usersSnap) {
              final users = usersSnap.data ?? [];
              final loadingUsers = usersSnap.connectionState == ConnectionState.waiting;

              return ListView(
                padding: const EdgeInsets.only(bottom: 30), 
                children: [
                  // الهيدر (الصورة والاسم)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    color: p.surface,
                    child: Column(children: [
                      GestureDetector(
                        onTap: !iAmOwner ? null : () async {
                            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
                            if (x != null) svc.setGroupPhoto(chatId, toDataUrl(await x.readAsBytes()));
                          },
                        child: Stack(children: [
                          Avatar(url: meta['photo'] as String?, name: (meta['name'] as String?) ?? '👥', size: 104),
                          if (iAmOwner) Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 16, backgroundColor: p.gold, child: const Icon(Icons.camera_alt, size: 18, color: Colors.black))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text((meta['name'] as String?) ?? 'مجموعة', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$members.length أعضاء', style: TextStyle(fontSize: 14, color: p.muted)),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // الإعدادات (للمالك فقط)
                  if (iAmOwner) ...[
                    _SectionTitle(title: 'الإدارة', p: p),
                    Container(
                      color: p.surface,
                      child: Column(children: [
                        ListTile(
                          leading: Icon(Icons.edit_outlined, color: p.gold),
                          title: const Text('تغيير اسم المجموعة'),
                          onTap: () async {
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
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.person_add_outlined, color: p.gold),
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
                                    SafeArea(child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إضافة (${sel.length})')),
                                    )),
                                  ]),
                                ),
                              ),
                            );
                            if (ok == true && sel.isNotEmpty) svc.addMembers(chatId, me, sel.toList());
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // قائمة الأعضاء
                  _SectionTitle(title: 'الأعضاء', p: p),
                  Container(
                    color: p.surface,
                    child: loadingUsers
                        ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                        : Column(
                            children: members.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final id = entry.value;
                              
                              // 🔥 هنا تم إصلاح الخطأ (إجبار النوع ليكون Map<String, dynamic>)
                              final Map<String, dynamic> u = (idx < users.length && users[idx] != null) ? users[idx]! : <String, dynamic>{};
                              
                              return Column(children: [
                                ListTile(
                                  leading: Avatar(url: avatarOf(u), name: (u['displayName'] as String?) ?? '?'),
                                  title: Text((u['displayName'] as String?) ?? '...', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('@${u['username'] ?? ''}'),
                                  trailing: id == owner 
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: p.gold.withOpacity(.2), borderRadius: BorderRadius.circular(8)),
                                        child: Text('المالك', style: TextStyle(color: p.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ) 
                                    : null,
                                ),
                                if (idx < members.length - 1) const Divider(height: 1, indent: 70),
                              ]);
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // مغادرة المجموعة
                  Container(
                    color: p.surface,
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('مغادرة المجموعة', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('مغادرة المجموعة'),
                            content: const Text('هل أنت متأكد من مغادرة هذه المجموعة؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مغادرة', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await svc.leaveGroup(chatId, me, meta);
                          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                        }
                      },
                    ),
                  ),
                ],
              );
            }
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final BP p;
  const _SectionTitle({required this.title, required this.p});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(title, style: TextStyle(color: p.gold, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
