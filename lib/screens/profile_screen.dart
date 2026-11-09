import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final auth = context.read<AuthService>();
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    if (x == null) return;
    final url = toDataUrl(await x.readAsBytes());
    final history = List<String>.from((auth.me?['avatarHistory'] as List?) ?? []);
    final old = (auth.me?['avatarUrl'] as String?) ?? '';
    if (old.isNotEmpty) history.insert(0, old);
    await auth.updateProfile({'avatarUrl': url, 'avatarHistory': history.take(5).toList()});
  }

  Future<void> _edit(BuildContext context, String title, String field, {int max = 60}) async {
    final auth = context.read<AuthService>();
    final c = TextEditingController(text: (auth.me?[field] as String?) ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLength: max, maxLines: field == 'bio' ? 3 : 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null || (field == 'displayName' && v.isEmpty)) return;
    await auth.updateProfile({field: v});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.me ?? {};
    final p = BP.of(context);
    final name = (me['displayName'] as String?) ?? '';
    final history = ((me['avatarHistory'] as List?) ?? []).cast<String>();
    return Scaffold(
      backgroundColor: p.chatListBg,
      body: ListView(padding: EdgeInsets.zero, children: [
        ProfileHeader(
          avatarUrl: me['avatarUrl'] as String?,
          name: name,
          username: (me['username'] as String?) ?? '',
          status: 'متصل الآن',
          online: true,
          verified: me['isVerified'] == true,
          onAvatarTap: () => _pickAvatar(context),
        ),
        Transform.translate(
          offset: const Offset(0, -46),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                QuickAction(icon: Icons.camera_alt_outlined, label: 'الصورة', onTap: () => _pickAvatar(context)),
                QuickAction(icon: Icons.edit_outlined, label: 'الاسم', onTap: () => _edit(context, 'اسم العرض', 'displayName')),
                QuickAction(icon: Icons.info_outline, label: 'النبذة', onTap: () => _edit(context, 'النبذة', 'bio', max: 150)),
              ]),
            ),
            const SizedBox(height: 8),
            InfoCard(children: [
              ListTile(
                leading: Icon(Icons.alternate_email, color: p.gold),
                title: const Text('اسم المستخدم'),
                subtitle: Text('@${me['username'] ?? ''}', textDirection: TextDirection.ltr),
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: p.gold),
                title: const Text('النبذة'),
                subtitle: Text((me['bio'] as String?)?.isNotEmpty == true ? me['bio'] : 'أضف نبذة عنك'),
                onTap: () => _edit(context, 'النبذة', 'bio', max: 150),
              ),
              ListTile(
                leading: Icon(Icons.mail_outline, color: p.gold),
                title: const Text('البريد'),
                subtitle: Text('${me['email'] ?? ''}', textDirection: TextDirection.ltr),
              ),
            ]),
            if (history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('صور سابقة', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(
                height: 74,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: history
                      .map((u) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () async {
                                final cur = (me['avatarUrl'] as String?) ?? '';
                                final h = history.where((e) => e != u).toList();
                                if (cur.isNotEmpty) h.insert(0, cur);
                                await auth.updateProfile({'avatarUrl': u, 'avatarHistory': h.take(5).toList()});
                              },
                              child: Avatar(url: u, name: name, size: 64),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}
