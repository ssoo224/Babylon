import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/governorates.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';
import '../widgets/pattern_layer.dart';
import 'profile_screen.dart' show showCoverPicker;

/// شاشة تعديل الملف الشخصي الحديثة بأسلوب تليجرام
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name, _user, _bio;
  String? _prov;
  late String _cover;
  late String _avatarUrl;
  bool _avatarCleared = false;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthService>().me ?? {};
    _name = TextEditingController(text: (me['displayName'] as String?) ?? '');
    _user = TextEditingController(text: (me['username'] as String?) ?? '');
    _bio = TextEditingController(text: (me['bio'] as String?) ?? '');
    final pv = me['province'] as String?;
    _prov = governorates.contains(pv) ? pv : null;
    _cover = (me['cover'] as String?) ?? 'babylon';
    _avatarUrl = (me['avatarUrl'] as String?) ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await pickImageInApp(context);
    if (x == null) return;
    final url = toDataUrl(await compressImage(x, 512, 75));
    if (mounted) {
      setState(() {
        _avatarUrl = url;
        _avatarCleared = false;
      });
    }
  }

  void _openProvinceSheet() {
    final p = BP.of(context);
    final dividerCol = p.dark ? const Color(0x12FFFFFF) : p.border;
    var q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = governorates.where((g) => g.contains(q.trim())).toList();
          return DraggableScrollableSheet(
            initialChildSize: .65,
            minChildSize: .4,
            maxChildSize: .9,
            expand: false,
            builder: (_, sc) => SafeArea(
              child: Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.muted.withOpacity(.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(children: [
                    const Expanded(
                      child: Text(
                        'اختر المحافظة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setSheet(() => q = v),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن المحافظة...',
                      prefixIcon: Icon(Icons.search, size: 19, color: p.muted),
                      fillColor: p.chatListBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: dividerCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: dividerCol),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      ListTile(
                        title: Text('غير محدد', style: TextStyle(color: p.muted)),
                        trailing: _prov == null
                            ? Icon(Icons.check, color: p.navActive, size: 18)
                            : null,
                        onTap: () {
                          setState(() => _prov = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      for (final g in filtered)
                        ListTile(
                          title: Text(g, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: _prov == g
                              ? Icon(Icons.check, color: p.navActive, size: 18)
                              : null,
                          onTap: () {
                            setState(() => _prov = g);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final auth = context.read<AuthService>();
    final me = auth.me ?? {};
    final name = _name.text.trim();
    final newU = _user.text.trim().toLowerCase().replaceFirst('@', '');
    final oldU = (me['username'] as String?) ?? '';
    if (name.isEmpty) return setState(() => _err = 'اكتب اسم العرض');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final oldAvatar = (me['avatarUrl'] as String?) ?? '';
      final history = List<String>.from((me['avatarHistory'] as List?) ?? []);
      if (_avatarUrl.isNotEmpty && _avatarUrl != oldAvatar && oldAvatar.isNotEmpty) {
        history.insert(0, oldAvatar);
      }

      final upd = <String, dynamic>{
        'displayName': name,
        'bio': _bio.text.trim(),
        'province': _prov ?? '',
        'cover': _cover,
        if (_avatarCleared)
          'avatarUrl': ''
        else if (_avatarUrl != oldAvatar) ...{
          'avatarUrl': _avatarUrl,
          'avatarHistory': history.take(5).toList(),
        },
      };

      if (newU != oldU) {
        if (!isValidUsername(newU)) {
          throw 'اليوزر مرفوض: 5 أحرف على الأقل ويبدأ بحرف';
        }
        if (!await BabylonApi.usernameAvailable(newU)) {
          throw 'اسم المستخدم مستخدم بالفعل';
        }
        final db = FirebaseFirestore.instance;
        final b = db.batch();
        b.set(db.collection('usernames').doc(newU), {
          'uid': auth.uid,
          'email': me['email'] ?? auth.user?.email ?? '',
        });
        if (oldU.isNotEmpty) b.delete(db.collection('usernames').doc(oldU));
        b.set(
          db.collection('users').doc(auth.uid),
          {...upd, 'username': newU},
          SetOptions(merge: true),
        );
        await b.commit();
      } else {
        await auth.updateProfile(upd);
      }
      if (mounted) {
        toast(context, 'تم حفظ التعديلات ✓');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e is String ? e : 'تعذر الحفظ، جرّب مرة ثانية';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final auth = context.watch<AuthService>();
    final me = auth.me ?? {};
    final coverTheme = chatThemeFor(_cover, p.dark);
    final dividerCol = p.dark ? const Color(0x12FFFFFF) : p.border;
    final cleanUser = _user.text.trim().replaceFirst('@', '').toLowerCase();
    final oldUser = ((me['username'] as String?) ?? '').toLowerCase();
    final userValid = cleanUser.isNotEmpty && isValidUsername(cleanUser);

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.navActive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(86, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 16),
                label: const Text('حفظ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---------- معاينة الغلاف والصورة الشخصية ----------
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 126,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: coverTheme.cover),
                ),
                child: Stack(children: [
                  Positioned.fill(child: PatternLayer(theme: coverTheme, cell: 48)),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => showCoverPicker(
                        context,
                        _cover,
                        (k) => setState(() => _cover = k),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.palette_outlined, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'تغيير الغلاف',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              Positioned(
                bottom: -44,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: p.chatListBg,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Avatar(
                          url: _avatarUrl.isEmpty ? null : _avatarUrl,
                          name: _name.text.trim().isEmpty
                              ? ((me['displayName'] as String?) ?? '')
                              : _name.text.trim(),
                          size: 86,
                          seed: auth.uid,
                        ),
                        Container(
                          width: 86,
                          height: 86,
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 52),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Text(
                'تعيين صورة جديدة',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.navActive),
              ),
            ),
            if (_avatarUrl.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('•', style: TextStyle(color: p.muted)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _avatarUrl = '';
                  _avatarCleared = true;
                }),
                child: Text(
                  'إزالة الصورة',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.error),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 18),

          // ---------- بطاقة 1: الاسم والنبذة ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerCol),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('الاسم الشخصي',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.navActive)),
                        const Spacer(),
                        Text('${_name.text.length}/40',
                            style: TextStyle(fontSize: 11, color: p.muted)),
                      ]),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _name,
                        maxLength: 40,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'أدخل اسمك...',
                          hintStyle: TextStyle(color: p.muted.withOpacity(.6)),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16),
                    child: Divider(height: .7, thickness: .7, color: dividerCol),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('النبذة التعريفية',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.navActive)),
                        const Spacer(),
                        Text('${_bio.text.length}/150',
                            style: TextStyle(fontSize: 11, color: p.muted)),
                      ]),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _bio,
                        maxLength: 150,
                        maxLines: 3,
                        minLines: 2,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 14.5, color: p.text),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'أضف نبذة عنك (العمل، الاهتمامات، المدينة...)',
                          hintStyle: TextStyle(color: p.muted.withOpacity(.6)),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                child: Text(
                  'أي تفاصيل تكتبها هنا تظهر في ملفك الشخصي لجميع المستخدمين.',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ),

              // ---------- بطاقة 2: اسم المستخدم ----------
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerCol),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('اسم المستخدم',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.navActive)),
                    const Spacer(),
                    if (cleanUser.isNotEmpty)
                      Text(
                        !userValid
                            ? '5 أحرف إنجليزية على الأقل'
                            : (cleanUser == oldUser ? 'اليوزر الحالي' : 'صالح للتحقق ✓'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !userValid ? p.error : const Color(0xFF22C55E),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _user,
                      autocorrect: false,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        prefixText: '@',
                        prefixStyle: TextStyle(fontSize: 15, color: p.muted, fontWeight: FontWeight.w600),
                        hintText: 'username',
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                child: Text(
                  'يمكن للأصدقاء العثور عليك عبر @${cleanUser.isEmpty ? 'username' : cleanUser}',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ),

              // ---------- بطاقة 3: المحافظة والغلاف ----------
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerCol),
                ),
                child: Column(children: [
                  ListTile(
                    onTap: _openProvinceSheet,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.navActive.withOpacity(.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on_outlined, color: p.navActive, size: 19),
                    ),
                    title: const Text('المحافظة', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(_prov ?? 'غير محدد', style: TextStyle(fontSize: 12, color: p.muted)),
                    trailing: Icon(Icons.chevron_left, color: p.muted),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 68),
                    child: Divider(height: .7, thickness: .7, color: dividerCol),
                  ),
                  ListTile(
                    onTap: () => showCoverPicker(
                      context,
                      _cover,
                      (k) => setState(() => _cover = k),
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: coverTheme.cover),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.palette_outlined, color: Colors.white, size: 18),
                    ),
                    title: const Text('غلاف الملف الشخصي', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(coverTheme.name, style: TextStyle(fontSize: 12, color: p.muted)),
                    trailing: Icon(Icons.chevron_left, color: p.muted),
                  ),
                ]),
              ),

              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 6, left: 6),
                  child: Text(
                    _err!,
                    style: TextStyle(color: p.error, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
