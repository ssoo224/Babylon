import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

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
    final me = context.watch<AuthService>().me ?? {};
    final name = (me['displayName'] as String?) ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickAvatar(context),
            child: Stack(children: [
              Avatar(url: me['avatarUrl'], name: name, size: 110),
              Positioned(
                bottom: 0,
                left: 0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('اسم العرض'),
              subtitle: Text(name),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _edit(context, 'اسم العرض', 'displayName'),
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('اسم المستخدم'),
              subtitle: Text('@${me['username'] ?? ''}', textDirection: TextDirection.ltr),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('النبذة'),
              subtitle: Text((me['bio'] as String?)?.isNotEmpty == true ? me['bio'] : 'أضف نبذة عنك'),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _edit(context, 'النبذة', 'bio', max: 150),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('البريد'),
              subtitle: Text('${me['email'] ?? ''}', textDirection: TextDirection.ltr),
            ),
          ]),
        ),
      ]),
    );
  }
}
