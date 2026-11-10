import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../widgets/pattern_layer.dart';
import '../widgets/profile_header.dart';
import 'avatar_gallery.dart';
import 'edit_profile_screen.dart';
import 'stories.dart';

/// قسم القصص المثبتة (تبقى بالملف بعد انتهاء المدة)
class PinnedStoriesSection extends StatelessWidget {
  final String uid;
  final Json owner;
  final bool mine;
  const PinnedStoriesSection({super.key, required this.uid, required this.owner, required this.mine});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return FutureBuilder<List<Json>>(
      future: context.read<ChatService>().pinnedStories(uid),
      builder: (context, s) {
        final list = s.data ?? [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text('القصص المثبتة', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: list.map((st) {
                final img = imageFromUrl(st['imageUrl'] as String?);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StoryViewer(stories: [st], owner: owner, mine: mine)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 80,
                        color: p.surface,
                        child: img == null
                            ? Icon(Icons.play_circle_outline, color: p.gold)
                            : Image(image: img, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ]);
      },
    );
  }
}

void showCoverPicker(BuildContext context, String current, void Function(String) onPick) {
  final p = BP.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اختر غلاف الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: chatThemeKeys.map((k) {
              final t = chatThemeBase(k);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onPick(k);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: t.cover),
                    border: Border.all(color: current == k ? p.gold : Colors.transparent, width: 3),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: PatternLayer(theme: t, cell: 44))),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    ),
  );
}

String joinedLabel(Json u) {
  final c = (u['createdAt'] as num?)?.toInt();
  if (c == null) return '';
  return DateFormat('d MMMM yyyy', 'ar').format(DateTime.fromMillisecondsSinceEpoch(c));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final auth = context.read<AuthService>();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    if (x == null) return;
    final url = toDataUrl(await x.readAsBytes());
    final history = List<String>.from((auth.me?['avatarHistory'] as List?) ?? []);
    final old = (auth.me?['avatarUrl'] as String?) ?? '';
    if (old.isNotEmpty) history.insert(0, old);
    await auth.updateProfile({'avatarUrl': url, 'avatarHistory': history.take(5).toList()});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.me ?? {};
    final p = BP.of(context);
    final name = (me['displayName'] as String?) ?? '';
    final history = ((me['avatarHistory'] as List?) ?? []).cast<String>();
    final cur = (me['avatarUrl'] as String?) ?? '';
    final province = (me['province'] as String?) ?? '';
    final joined = joinedLabel(me);
    return Scaffold(
      backgroundColor: p.chatListBg,
      body: ListView(padding: EdgeInsets.zero, children: [
        ProfileHeader(
          avatarUrl: cur,
          name: name,
          username: (me['username'] as String?) ?? '',
          status: 'متصل الآن',
          online: true,
          verified: me['isVerified'] == true,
          coverKey: (me['cover'] as String?) ?? 'babylon',
          onCoverTap: () => showCoverPicker(context, (me['cover'] as String?) ?? 'babylon', (k) => auth.updateProfile({'cover': k})),
          onAvatarTap: () {
            final imgs = [if (cur.isNotEmpty) cur, ...history];
            if (imgs.isEmpty) {
              _pickAvatar(context);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarGallery(images: imgs, mine: true)));
            }
          },
        ),
        Transform.translate(
          offset: const Offset(0, -46),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                QuickAction(icon: Icons.camera_alt_outlined, label: 'الصورة', onTap: () => _pickAvatar(context)),
                QuickAction(
                    icon: Icons.edit_outlined,
                    label: 'تعديل',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                QuickAction(
                    icon: Icons.copy,
                    label: 'نسخ اليوزر',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '@${me['username'] ?? ''}'));
                      toast(context, 'تم نسخ اليوزر');
                    }),
              ]),
            ),
            const SizedBox(height: 8),
            InfoCard(children: [
              ListTile(
                leading: Icon(Icons.alternate_email, color: p.gold),
                title: const Text('اسم المستخدم'),
                subtitle: Text('@${me['username'] ?? ''}', textDirection: TextDirection.ltr),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '@${me['username'] ?? ''}'));
                  toast(context, 'تم نسخ اليوزر');
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: p.gold),
                title: const Text('النبذة'),
                subtitle: Text((me['bio'] as String?)?.isNotEmpty == true ? me['bio'] : 'أضف نبذة عنك'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
              if (province.isNotEmpty)
                ListTile(leading: Icon(Icons.location_on_outlined, color: p.gold), title: const Text('المحافظة'), subtitle: Text(province)),
              if (joined.isNotEmpty)
                ListTile(leading: Icon(Icons.calendar_today_outlined, color: p.gold), title: const Text('تاريخ الانضمام'), subtitle: Text(joined)),
              ListTile(
                leading: Icon(Icons.mail_outline, color: p.gold),
                title: const Text('البريد'),
                subtitle: Text('${me['email'] ?? ''}', textDirection: TextDirection.ltr),
              ),
            ]),
            if (auth.user != null) PinnedStoriesSection(uid: auth.uid, owner: me, mine: true),
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
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AvatarGallery(images: [if (cur.isNotEmpty) cur, ...history], mine: true))),
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
