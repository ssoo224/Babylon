import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../core/media.dart';
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
import 'gift_screens.dart';
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
    final x = await pickImageInApp(context);
    if (x == null) return;
    final url = toDataUrl(await compressImage(x, 512, 75));
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
    final bio = (me['bio'] as String?) ?? '';
    void copyUser() {
      Clipboard.setData(ClipboardData(text: '@${me['username'] ?? ''}'));
      toast(context, 'تم نسخ اليوزر');
    }

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
          seed: auth.user?.uid,
          onAvatarTap: () {
            final imgs = [if (cur.isNotEmpty) cur, ...history];
            if (imgs.isEmpty) {
              _pickAvatar(context);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarGallery(images: imgs, mine: true)));
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(children: [
            QuickAction(
                biconName: 'palette',
                label: 'الأغلفة',
                onTap: () => showCoverPicker(
                    context, (me['cover'] as String?) ?? 'babylon', (k) => auth.updateProfile({'cover': k}))),
            QuickAction(biconName: 'camera', label: 'الصورة', onTap: () => _pickAvatar(context)),
            QuickAction(
                biconName: 'pencil',
                label: 'تعديل',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
          ]),
        ),
        const SizedBox(height: 10),
        InfoCard(children: [
          PfRow(
            biconName: 'text',
            value: bio.isNotEmpty ? bio : 'أضف نبذة تعريفية',
            label: 'النبذة التعريفية',
            muted: bio.isEmpty,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          PfRow(
              biconName: 'at',
              value: '@${me['username'] ?? ''}',
              label: 'اسم المستخدم (اضغط للنسخ)',
              ltr: true,
              onTap: copyUser),
          PfRow(
              biconName: 'pin',
              value: province.isNotEmpty ? province : 'غير محدد',
              label: 'المحافظة',
              muted: province.isEmpty),
          if (joined.isNotEmpty) PfRow(biconName: 'calendar', value: joined, label: 'تاريخ الانضمام'),
          PfRow(
              biconName: 'mail',
              value: '${me['email'] ?? ''}',
              label: 'البريد الإلكتروني (ظاهر لك فقط)',
              ltr: true,
              last: true),
        ]),
        if (auth.user != null) GiftsGrid(uid: auth.uid, mine: true),
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
    );
  }
}
