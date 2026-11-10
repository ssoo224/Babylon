import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/gift_service.dart'; // 🌟 جديد
import '../widgets/avatar.dart';
import '../widgets/pattern_layer.dart';
import '../widgets/profile_header.dart';
import '../widgets/gift_widgets.dart'; // 🌟 جديد
import 'avatar_gallery.dart';
import 'edit_profile_screen.dart';
import 'stories.dart';
import 'gift_store_screen.dart'; // 🌟 جديد

const _shareLink = 'https://babyllon.vercel.app';

String joinedLabel(Json u) {
  final c = (u['createdAt'] as num?)?.toInt();
  if (c == null) return '';
  return DateFormat('d MMMM yyyy', 'ar').format(DateTime.fromMillisecondsSinceEpoch(c));
}

// =================== قسم القصص المثبتة ===================
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

// =================== منتقي الغلاف ===================
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

// =================== الملف الشخصي (Profile) ===================
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
        
        if (auth.user != null) PinnedStoriesSection(uid: auth.uid, owner: me, mine: true),
        
        // 🌟 شبكة الهدايا في الملف الشخصي (تستدعي الويدجت الجديد)
        if (auth.user != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الهدايا', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftStoreScreen())),
                  child: Text('المتجر', style: TextStyle(color: p.gold, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const GiftGrid(kind: 'pepe', uid: ''),
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

// =================== الإعدادات (Settings) ===================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final auth = context.watch<AuthService>();
    final p = BP.of(context);
    final me = auth.me ?? {};
    final name = (me['displayName'] as String?) ?? '';

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        _SettingsHero(me: me, name: name, uid: auth.user?.uid),
        _label(p, 'التخصيص'),
        InfoCard(children: [
          SwitchListTile(
            secondary: _ic(Icons.dark_mode_outlined, const Color(0xFF6366F1)),
            title: const Text('مظهر التطبيق'),
            subtitle: Text(theme.mode == ThemeMode.dark ? 'ليلي' : 'الوضع النهاري مفعّل'),
            value: theme.mode == ThemeMode.dark,
            onChanged: (v) => theme.set(v ? ThemeMode.dark : ThemeMode.light),
          ),
          _item(context, Icons.palette_outlined, const Color(0xFFF59E0B), 'المظهر والمحادثات',
              const ChatSettingsPage()),
          _item(context, Icons.notifications_outlined, const Color(0xFFEF4444),
              'الإشعارات والأصوات', const NotifSettingsPage()),
        ]),
        _label(p, 'الهدايا والنجوم'),
        InfoCard(children: [
          ListTile(
            leading: _ic(Icons.star_outline, const Color(0xFFEAB308)),
            title: const Text('نجوم بابيلون'),
            subtitle: const Text('سجل النجوم والمحفظة'),
            onTap: () => toast(context, 'قريباً'),
          ),
          ListTile(
            leading: _ic(Icons.card_giftcard, const Color(0xFFEC4899)),
            title: const Text('متجر الهدايا'),
            subtitle: const Text('اشترِ وأهدِ الهدايا'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftStoreScreen())),
          ),
        ]),
        _label(p, 'مشاركة التطبيق'),
        InfoCard(children: [
          ListTile(
            leading: _ic(Icons.share_outlined, const Color(0xFF0EA5E9)),
            title: const Text('مشاركة رابط التحميل'),
            subtitle: const Text('رابط يفتح صفحة تحميل التطبيق في أي متصفح'),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _shareLink));
              toast(context, 'تم نسخ الرابط');
            },
          ),
        ]),
        _label(p, 'الأمان'),
        InfoCard(children: [
          _item(context, Icons.shield_outlined, const Color(0xFF10B981), 'الخصوصية والأمان',
              const PrivacyPage()),
        ]),
        _label(p, 'البيانات'),
        InfoCard(children: [
          ListTile(
            leading: _ic(Icons.cleaning_services_outlined, const Color(0xFF8B5CF6)),
            title: const Text('مسح البيانات المؤقتة'),
            onTap: () async {
              if (await _confirm(context, 'مسح الذاكرة المؤقتة؟ (ما يحذف حسابك ولا رسائلك)', 'مسح')) {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                if (context.mounted) toast(context, 'تم المسح ✓');
              }
            },
          ),
          ListTile(
            leading: _ic(Icons.delete_sweep_outlined, const Color(0xFFEF4444)),
            title: const Text('مسح جميع البيانات'),
            onTap: () async {
              final prefs = context.read<AppPrefs>();
              if (await _confirm(
                  context,
                  'سيتم مسح بيانات التطبيق من هذا الهاتف (الإعدادات المحلية والذاكرة المؤقتة) وتسجيل خروجك. حسابك ورسائلك على الخادم لا تُحذف.',
                  'مسح الكل')) {
                try {
                  await auth.logout();
                  await FirebaseFirestore.instance.terminate();
                  await FirebaseFirestore.instance.clearPersistence();
                } catch (_) {}
                await prefs.wipe();
                PaintingBinding.instance.imageCache.clear();
              }
            },
          ),
        ]),
        InfoCard(children: [
          ListTile(
            leading: _ic(Icons.info_outline, const Color(0xFF64748B)),
            title: const Text('حول Babylon Chat'),
            onTap: () => toast(context, 'Babylon Chat تطبيق محادثات بغدادي'),
          ),
        ]),
        const SizedBox(height: 8),
        InfoCard(children: [
          ListTile(
            leading: _ic(Icons.logout, p.error),
            title: Text('تسجيل الخروج', style: TextStyle(color: p.error)),
            onTap: () async {
              if (await _confirm(context, 'هل تريد تسجيل الخروج؟', 'خروج')) auth.logout();
            },
          ),
        ]),
      ]),
    );
  }
}

Widget _label(BP p, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Text(t, style: TextStyle(color: p.gold, fontWeight: FontWeight.w700, fontSize: 13)),
    );

Widget _ic(IconData i, Color c) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
      child: Icon(i, color: Colors.white, size: 20),
    );

Widget _item(BuildContext context, IconData i, Color c, String title, Widget page) => ListTile(
      leading: _ic(i, c),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );

Future<bool> _confirm(BuildContext context, String msg, String ok, {String? title}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

// =================== المظهر والمحادثات ===================
class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  void _sync(BuildContext context) {
    final prefs = context.read<AppPrefs>();
    context.read<AuthService>().updateProfile({'chatPrefs': prefs.toMap()}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    final p = BP.of(context);
    final ct = chatThemeFor(prefs.chatTheme, p.dark);
    Widget bubble(String t, bool mine) {
      final r = prefs.radius.toDouble();
      return Align(
        alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine && ct.mine.length > 1 ? null : (mine ? ct.mine.first : ct.other),
            gradient: mine && ct.mine.length > 1 ? LinearGradient(colors: ct.mine) : null,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
              bottomRight: Radius.circular(mine ? 4 : r),
              bottomLeft: Radius.circular(mine ? r : 4),
            ),
          ),
          child: Text(t,
              style: TextStyle(
                  color: mine ? ct.textMine : ct.textOther, fontSize: prefs.font.toDouble())),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('إعدادات المحادثات')),
      body: ListView(children: [
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: ct.chatBg, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            bubble('صباح الخير! شلونك اليوم؟', false),
            bubble('الحمدلله تمام، وانت شلونك ◉', true),
          ]),
        ),
        _label(p, 'ثيم وخلفية المحادثة'),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: chatThemeKeys.map((k) {
              final t = chatThemeFor(k, p.dark);
              final sel = prefs.chatTheme == k;
              return GestureDetector(
                onTap: () {
                  prefs.set(theme: k);
                  _sync(context);
                },
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.chatBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? p.gold : Colors.transparent, width: 2.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: t.mine.length > 1 ? t.mine : [t.mine.first, t.mine.first]),
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 5),
                    Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(color: t.other, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Text(t.name, style: TextStyle(fontSize: 11, color: t.textOther)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        _label(p, 'حجم خط الرسائل (${prefs.font})'),
        Slider(
          min: 12,
          max: 22,
          divisions: 10,
          value: prefs.font.toDouble(),
          onChanged: (v) => prefs.set(fontSize: v.round()),
          onChangeEnd: (_) => _sync(context),
        ),
        _label(p, 'زوايا الرسالة (${prefs.radius})'),
        Slider(
          min: 0,
          max: 20,
          divisions: 20,
          value: prefs.radius.toDouble(),
          onChanged: (v) => prefs.set(corner: v.round()),
          onChangeEnd: (_) => _sync(context),
        ),
      ]),
    );
  }
}

// =================== الإشعارات والأصوات ===================
class NotifSettingsPage extends StatelessWidget {
  const NotifSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('إعدادات الإشعارات')),
      body: ListView(children: [
        _label(p, 'إشعارات الرسائل'),
        InfoCard(children: [
          SwitchListTile(
            title: const Text('إشعارات الجهاز'),
            subtitle: const Text('استقبال تنبيهات الجهاز عند السماح بها.'),
            value: prefs.msgNotif,
            onChanged: (v) async {
              prefs.setNotif(messages: v);
              if (v) await FirebaseMessaging.instance.requestPermission();
            },
          ),
        ]),
        _label(p, 'الأصوات'),
        InfoCard(children: [
          SwitchListTile(
            title: const Text('صوت الرسائل الجديدة'),
            subtitle: const Text('تشغيل صوت قصير عند وصول رسالة جديدة داخل التطبيق.'),
            value: prefs.sound,
            onChanged: (v) => prefs.setNotif(snd: v),
          ),
        ]),
      ]),
    );
  }
}

// =================== الخصوصية والأمان ===================
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthService>();
    final em = auth.user?.email;
    if (em == null) return;
    if (!await _confirm(context, 'نرسل رابط تغيير كلمة المرور إلى $em ؟', 'إرسال الرابط',
        title: 'تغيير كلمة المرور')) {
      return;
    }
    try {
      await auth.resetPassword(em);
      if (context.mounted) toast(context, 'تم إرسال الرابط إلى $em (شيّك السبام)');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذر الإرسال، جرّب مرة ثانية');
    }
  }

  Future<void> _changeEmail(BuildContext context) async {
    final auth = context.read<AuthService>();
    final c = TextEditingController();
    final ne = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير الإيميل'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'الإيميل الجديد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('إرسال')),
        ],
      ),
    );
    if (ne == null || ne.isEmpty || auth.user == null) return;
    try {
      final r = await BabylonApi.post('/api/send-mail', {'type': 'email-change', 'newEmail': ne},
          user: auth.user);
      if (!context.mounted) return;
      toast(
        context,
        switch (r.status) {
          200 => 'أرسلنا رابط تأكيد إلى $ne — افتحه لإتمام التغيير',
          409 => 'هذا الإيميل مستخدم مسبقاً',
          429 => 'محاولات كثيرة، حاول لاحقاً',
          403 => 'سجّل خروج وادخل من جديد ثم جرّب',
          400 => 'صيغة الإيميل غير صحيحة',
          _ => 'تعذر الإرسال، جرّب مرة ثانية',
        },
      );
    } catch (_) {
      if (context.mounted) toast(context, 'تعذر الاتصال');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthService>();
    if (!await _confirm(
        context,
        'سيتم حذف حسابك وكل بياناتك نهائياً (محادثاتك، قصصك، اليوزر). سنرسل رمز تأكيد إلى بريدك. لا يمكن التراجع.',
        'متابعة',
        title: 'حذف الحساب')) {
      return;
    }
    final u = auth.user;
    if (u == null) return;
    final s = await BabylonApi.post('/api/account', {'type': 'delete-send'}, user: u);
    if (!context.mounted) return;
    if (s.status != 200) {
      return toast(
          context,
          s.status == 429
              ? 'انتظر دقيقة قبل طلب رمز جديد'
              : s.status == 403
                  ? 'سجّل خروج وادخل من جديد ثم جرّب'
                  : 'تعذر إرسال الرمز');
    }
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('أرسلنا رمز من 6 أرقام إلى بريدك.'),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('حذف نهائياً', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (code == null || code.length != 6 || !context.mounted) return;
    final r = await BabylonApi.post('/api/account', {'type': 'delete-confirm', 'code': code}, user: u);
    if (!context.mounted) return;
    if (r.status == 200) {
      toast(context, 'تم حذف حسابك. الله يوفقك 💛');
      await Future.delayed(const Duration(milliseconds: 1000));
      await auth.logout();
    } else {
      final e = r.data['error'];
      toast(
          context,
          e == 'invalid'
              ? 'الرمز غلط'
              : e == 'expired'
                  ? 'انتهت صلاحية الرمز'
                  : e == 'locked'
                      ? 'تجاوزت عدد المحاولات'
                      : 'تعذر الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.me ?? {};
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('الخصوصية والأمان')),
      body: ListView(children: [
        _label(p, 'من يستطيع رؤية معلوماتي'),
        InfoCard(children: [
          SwitchListTile(
            title: const Text('إخفاء آخر ظهور'),
            subtitle: const Text('إظهار أو إخفاء وقت آخر تواجدك'),
            value: me['hideLastSeen'] == true,
            onChanged: (v) => auth.updateProfile({'hideLastSeen': v}),
          ),
          SwitchListTile(
            title: const Text('إخفاء صورة الملف الشخصي'),
            subtitle: const Text('إظهار أو إخفاء صورتك للآخرين'),
            value: me['hideAvatar'] == true,
            onChanged: (v) => auth.updateProfile({'hideAvatar': v}),
          ),
        ]),
        _label(p, 'الأمان'),
        InfoCard(children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('تغيير كلمة المرور'),
            onTap: () => _changePassword(context),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('تغيير الإيميل'),
            onTap: () => _changeEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('المستخدمون المحظورون'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const BlockedScreen())),
          ),
        ]),
        const SizedBox(height: 8),
        InfoCard(children: [
          ListTile(
            leading: Icon(Icons.logout, color: p.error),
            title: Text('تسجيل الخروج', style: TextStyle(color: p.error)),
            onTap: () async {
              if (await _confirm(context, 'هل تريد تسجيل الخروج؟', 'خروج')) {
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                auth.logout();
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: p.error),
            title: Text('حذف الحساب', style: TextStyle(color: p.error)),
            onTap: () => _deleteAccount(context),
          ),
        ]),
      ]),
    );
  }
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    return Scaffold(
      backgroundColor: BP.of(context).chatListBg,
      appBar: AppBar(title: const Text('المحظورون')),
      body: StreamBuilder<Set<String>>(
        stream: svc.blocks(me),
        builder: (context, s) {
          final ids = (s.data ?? {}).toList();
          if (ids.isEmpty) return const Center(child: Text('لا يوجد مستخدمون محظورون'));
          return ListView(
            children: ids
                .map((id) => FutureBuilder<Json?>(
                      future: svc.getUser(id),
                      builder: (_, us) {
                        final u = us.data ?? {};
                        return ListTile(
                          leading: Avatar(url: avatarOf(u), name: u['displayName'] ?? '?'),
                          title: Text(u['displayName'] ?? id),
                          subtitle: Text('@${u['username'] ?? ''}'),
                          trailing: TextButton(
                            onPressed: () => svc.unblock(me, id),
                            child: const Text('إلغاء الحظر'),
                          ),
                        );
                      },
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

// =================== بطاقة الهيرو في الإعدادات ===================
class _SettingsHero extends StatelessWidget {
  final Map<String, dynamic> me;
  final String name;
  final String? uid;
  const _SettingsHero({required this.me, required this.name, this.uid});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final bio = (me['bio'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0x2ED4AF37), Color(0x1A2AABEE), Color(0x00000000)],
            stops: [0, .6, 1],
          ),
        ),
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0x8CD4AF37), spreadRadius: 3, blurRadius: 0),
                const BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Avatar(url: me['avatarUrl'] as String?, name: name, size: 92, seed: uid),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.dark ? Colors.white : p.text)),
          const SizedBox(height: 2),
          Text('@${me['username'] ?? ''}',
              textDirection: TextDirection.ltr, style: TextStyle(fontSize: 14, color: p.gold)),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.muted)),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: p.gold.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.gold.withOpacity(.5)),
              ),
              child: Text('تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.gold)),
            ),
          ),
        ]),
      ),
    );
  }
}
