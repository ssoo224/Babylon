import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// قسم القصص (يشتغل بالشريط الأفقي القديم أو كشبكة ثلاثية داخل تبويب القصص)
class PinnedStoriesSection extends StatelessWidget {
  final String uid;
  final Json owner;
  final bool mine;
  final bool embedded;
  const PinnedStoriesSection({
    super.key,
    required this.uid,
    required this.owner,
    required this.mine,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return FutureBuilder<List<Json>>(
      future: context.read<ChatService>().pinnedStories(uid),
      builder: (context, s) {
        if (embedded && s.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final list = s.data ?? [];
        if (list.isEmpty) {
          if (!embedded) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.navActive.withOpacity(.12),
                ),
                child: Icon(Icons.auto_stories_outlined, color: p.navActive, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد قصص بعد',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'القصص المثبتة ستظهر هنا في ملفك الشخصي',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ]),
          );
        }

        if (embedded) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final st = list[i];
              final img = imageFromUrl(st['imageUrl'] as String?);
              final caption = (st['caption'] as String?) ?? '';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewer(
                      stories: list.sublist(i),
                      owner: owner,
                      mine: mine,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(fit: StackFit.expand, children: [
                    Container(
                      color: p.surface,
                      child: img == null
                          ? Center(child: Icon(Icons.play_circle_outline, color: p.gold, size: 28))
                          : Image(image: img, fit: BoxFit.cover),
                    ),
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.push_pin, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                    if (caption.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5),
                          ),
                        ),
                      ),
                  ]),
                ),
              );
            },
          );
        }

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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _sectionTab = 0; // 0 = الهدايا, 1 = القصص

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

    final borderCol = p.dark ? const Color(0x12FFFFFF) : p.border;

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
                context,
                (me['cover'] as String?) ?? 'babylon',
                (k) => auth.updateProfile({'cover': k}),
              ),
            ),
            QuickAction(biconName: 'camera', label: 'الصورة', onTap: () => _pickAvatar(context)),
            QuickAction(
              biconName: 'pencil',
              label: 'تعديل',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
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
            onTap: copyUser,
          ),
          PfRow(
            biconName: 'pin',
            value: province.isNotEmpty ? province : 'غير محدد',
            label: 'المحافظة',
            muted: province.isEmpty,
          ),
          if (joined.isNotEmpty) PfRow(biconName: 'calendar', value: joined, label: 'تاريخ الانضمام'),
          PfRow(
            biconName: 'mail',
            value: '${me['email'] ?? ''}',
            label: 'البريد الإلكتروني (ظاهر لك فقط)',
            ltr: true,
            last: true,
          ),
        ]),

        // ---------- تبويبا الهدايا والقصص بأسلوب تليجرام ----------
        if (auth.user != null) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.symmetric(horizontal: BorderSide(color: borderCol, width: .7)),
            ),
            child: Row(children: [
              Expanded(
                child: _ProfileSectionTab(
                  label: 'الهدايا',
                  selected: _sectionTab == 0,
                  onTap: () => setState(() => _sectionTab = 0),
                ),
              ),
              Expanded(
                child: _ProfileSectionTab(
                  label: 'القصص',
                  selected: _sectionTab == 1,
                  onTap: () => setState(() => _sectionTab = 1),
                ),
              ),
            ]),
          ),
          if (_sectionTab == 0)
            GiftsGrid(uid: auth.uid, mine: true)
          else
            PinnedStoriesSection(uid: auth.uid, owner: me, mine: true, embedded: true),
        ],

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
                  .map(
                    (u) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AvatarGallery(
                              images: [if (cur.isNotEmpty) cur, ...history],
                              mine: true,
                            ),
                          ),
                        ),
                        child: Avatar(url: u, name: name, size: 64),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ProfileSectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ProfileSectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? p.navActive : p.muted,
              ),
            ),
          ),
          if (selected)
            Container(
              height: 2.5,
              width: 72,
              decoration: BoxDecoration(
                color: p.navActive,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
        ],
      ),
    );
  }
}
