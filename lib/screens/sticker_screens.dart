import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../core/cloudinary.dart';
import '../core/dev.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/sticker_service.dart';
import '../widgets/emoji_panel.dart';
import '../widgets/profile_header.dart';
import '../widgets/sticker_view.dart';

const _shareBase = 'https://babyllon.vercel.app/addstickers/';

/// معاينة ملصق (ضغطة مطوّلة): إرسال / مفضلة / فتح الحزمة
void showStickerPreview(BuildContext context, Sticker st, {void Function(Sticker)? onSend}) {
  final svc = context.read<StickerService>();
  showDialog(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (c, setS) {
        final fav = svc.isFave(st);
        final p = BP.of(c);
        return Dialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              StickerView(st: st, size: 210),
              const SizedBox(height: 6),
              Text(st.e, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                if (onSend != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
                    onPressed: () {
                      Navigator.pop(d);
                      onSend(st);
                    },
                    child: const Text('إرسال'),
                  ),
                OutlinedButton(
                  onPressed: () {
                    final m = svc.toggleFave(st);
                    toast(c, m);
                    setS(() {});
                  },
                  child: Text(fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
                ),
                if (st.s.isNotEmpty)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(d);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StickerPackScreen(name: st.s)));
                    },
                    child: const Text('فتح الحزمة'),
                  ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}

Future<String?> pickStickerEmoji(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      builder: (c) => EmojiPanel(height: 340, onPick: (e) => Navigator.pop(c, e)),
    );

/// يجهّز صورة ثابتة: PNG بضلع 512 (شرط الخادم) ثم يرفعها على Cloudinary
Future<String?> pickAndUploadStaticSticker(BuildContext context) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  if (context.mounted) toast(context, 'جاري تجهيز الملصق...');
  try {
    final im = img.decodeImage(await x.readAsBytes());
    if (im == null) throw 'decode';
    final wide = im.width >= im.height;
    final big = wide ? im.width : im.height;
    final small = ((wide ? im.height : im.width) * 512 / big).round().clamp(16, 512);
    final r = img.copyResize(im,
        width: wide ? 512 : small, height: wide ? small : 512, interpolation: img.Interpolation.cubic);
    final png = img.encodePng(r, level: 6);
    if (png.length > 512 * 1024) {
      if (context.mounted) toast(context, 'حجم الملصق كبير، جرّب صورة أبسط');
      return null;
    }
    final f = File('${(await getTemporaryDirectory()).path}/stk_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(png);
    final url = await Cloudinary.upload(f, video: false, folder: 'stickers');
    if (url == null && context.mounted) toast(context, 'تعذر رفع الصورة');
    return url;
  } catch (_) {
    if (context.mounted) toast(context, 'تعذر تجهيز الصورة');
    return null;
  }
}

const _reasons = {
  'spam': 'سبام',
  'abuse': 'إساءة',
  'adult': 'محتوى للبالغين',
  'copyright': 'حقوق الملكية',
  'other': 'أخرى',
};

// =============== شاشة الحزمة ===============
class StickerPackScreen extends StatefulWidget {
  final String name;
  const StickerPackScreen({super.key, required this.name});
  @override
  State<StickerPackScreen> createState() => _StickerPackScreenState();
}

class _StickerPackScreenState extends State<StickerPackScreen> {
  StickerSet? _set;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final svc = context.read<StickerService>();
    final auth = context.read<AuthService>();
    if (force) svc.invalidate(widget.name);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await svc.ensure(auth.uid);
      final s = await svc.loadSet(widget.name, isDev: isDevUser(auth.user));
      if (!mounted) return;
      setState(() {
        _set = s;
        _loading = false;
        if (s == null) _error = 'الحزمة غير موجودة';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل الحزمة';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() job, {String? ok}) async {
    try {
      await job();
      if (ok != null && mounted) toast(context, ok);
      await _load(force: true);
    } on StickerError catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'تعذر إكمال العملية');
    }
  }

  Future<void> _addSticker() async {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    final url = await pickAndUploadStaticSticker(context);
    if (url == null || !mounted) return;
    final emoji = await pickStickerEmoji(context);
    if (emoji == null) return;
    await _run(() => svc.api('add', {'set': widget.name, 'url': url, 'emoji': emoji}, user), ok: 'تمت الإضافة ✓');
  }

  void _stickerMenu(Sticker st) {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.emoji_emotions_outlined),
            title: const Text('تغيير الإيموجي'),
            onTap: () async {
              Navigator.pop(c);
              final e = await pickStickerEmoji(context);
              if (e != null) {
                await _run(() => svc.api('update', {'set': widget.name, 'id': st.i, 'emoji': e}, user));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('حذف الملصق', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(c);
              await _run(() => svc.api('remove', {'set': widget.name, 'id': st.i}, user), ok: 'تم الحذف');
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _rename() async {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    final c = TextEditingController(text: _set?.title ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('عنوان الحزمة'),
        content: TextField(controller: c, maxLength: 40),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      await _run(() => svc.api('rename', {'set': widget.name, 'title': v}, user), ok: 'تم الحفظ');
    }
  }

  Future<void> _deletePack() async {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحزمة'),
        content: const Text('سيتم حذف الحزمة وكل ملصقاتها نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await svc.api('delete', {'set': widget.name}, user);
      svc.uninstall(widget.name);
      if (mounted) Navigator.pop(context);
    } on StickerError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _report() async {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
              padding: EdgeInsets.all(8), child: Text('سبب الإبلاغ', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final e in _reasons.entries)
            ListTile(title: Text(e.value), onTap: () => Navigator.pop(c, e.key)),
        ]),
      ),
    );
    if (r == null) return;
    try {
      await svc.api('report', {'set': widget.name, 'reason': r}, user);
      if (mounted) toast(context, 'تم إرسال البلاغ، شكراً');
    } on StickerError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<StickerService>();
    final auth = context.read<AuthService>();
    final p = BP.of(context);
    final set = _set;
    final mine = set != null && set.ownerId == auth.uid;
    final installed = svc.isInstalled(widget.name);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(
        title: Text(set?.title.isNotEmpty == true ? set!.title : widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'نسخ رابط الحزمة',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$_shareBase${widget.name}'));
              toast(context, 'تم نسخ رابط الحزمة');
            },
          ),
          if (set != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'report') _report();
                if (v == 'rename') _rename();
                if (v == 'delete') _deletePack();
              },
              itemBuilder: (_) => [
                if (!mine) const PopupMenuItem(value: 'report', child: Text('إبلاغ عن الحزمة')),
                if (mine) const PopupMenuItem(value: 'rename', child: Text('تغيير العنوان')),
                if (mine || isDevUser(auth.user)) const PopupMenuItem(value: 'delete', child: Text('حذف الحزمة')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : set == null
              ? Center(child: Text(_error ?? 'الحزمة غير موجودة'))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  Row(children: [
                    if (set.stickers.isNotEmpty) StickerView(st: set.stickers.first, size: 72, play: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(set.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('@${set.name}', textDirection: TextDirection.ltr, style: TextStyle(color: p.gold)),
                        Text('${set.stickers.length} ملصق${set.ownerName.isNotEmpty ? ' · ${set.ownerName}' : ''}',
                            style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    PfButton(
                      label: installed ? 'إزالة الحزمة' : 'إضافة الملصقات',
                      icon: installed ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      primary: !installed,
                      danger: installed,
                      onTap: () {
                        installed ? svc.uninstall(widget.name) : svc.install(widget.name);
                        toast(context, installed ? 'تمت إزالة الحزمة' : 'تمت إضافة الحزمة ✓');
                      },
                    ),
                    if (mine) PfButton(label: 'إضافة ملصق', icon: Icons.add_photo_alternate_outlined, onTap: _addSticker),
                  ]),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 90),
                    itemCount: set.stickers.length,
                    itemBuilder: (_, i) {
                      final st = set.stickers[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => showStickerPreview(context, st),
                        onLongPress: mine ? () => _stickerMenu(st) : null,
                        child: Padding(padding: const EdgeInsets.all(4), child: StickerView(st: st, size: 76, play: false)),
                      );
                    },
                  ),
                  if (mine)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('اضغط مطولاً على ملصق لتغيير إيموجيه أو حذفه.',
                          textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ),
                ]),
    );
  }
}

// =============== مدير الملصقات ===============
class StickerManagerScreen extends StatefulWidget {
  const StickerManagerScreen({super.key});
  @override
  State<StickerManagerScreen> createState() => _StickerManagerScreenState();
}

class _StickerManagerScreenState extends State<StickerManagerScreen> {
  final _find = TextEditingController();
  List<StickerSet> _installed = [];
  List<StickerSet> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = context.read<StickerService>();
    final uid = context.read<AuthService>().uid;
    await svc.ensure(uid);
    final a = await svc.loadInstalled();
    List<StickerSet> b = [];
    try {
      b = await svc.myPacks(uid);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _installed = a;
        _mine = b;
        _loading = false;
      });
    }
  }

  void _open(String name) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => StickerPackScreen(name: name)));
    if (mounted) _load();
  }

  void _openTyped() {
    var t = _find.text.trim();
    if (t.isEmpty) return;
    if (t.contains('/')) t = t.split('/').where((e) => e.isNotEmpty).last;
    _open(t.toLowerCase());
  }

  Widget _row(StickerSet s, {Widget? trailing}) => ListTile(
        leading: s.stickers.isNotEmpty
            ? StickerView(st: s.stickers.first, size: 44, play: false)
            : (s.meta['thumb'] is Map
                ? StickerView(
                    st: Sticker(
                        s: s.name,
                        i: '',
                        u: (s.meta['thumb']['url'] as String?) ?? '',
                        k: (s.meta['thumb']['kind'] as String?) ?? 'static',
                        e: '🙂'),
                    size: 44,
                    play: false)
                : const SizedBox(width: 44, height: 44)),
        title: Text(s.title.isNotEmpty ? s.title : s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('@${s.name} · ${s.stickers.isNotEmpty ? s.stickers.length : (s.meta['count'] ?? 0)} ملصق',
            textDirection: TextDirection.ltr),
        trailing: trailing,
        onTap: () => _open(s.name),
      );

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final svc = context.read<StickerService>();
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('الملصقات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _find,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _openTyped(),
                  decoration: InputDecoration(
                    hintText: 'افتح حزمة بالاسم أو الرابط',
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _openTyped),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text('حزمي', style: TextStyle(color: p.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              InfoCard(children: [
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.gold.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
                    child: Icon(Icons.add, color: p.gold),
                  ),
                  title: const Text('إنشاء حزمة جديدة'),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StickerCreateScreen()));
                    if (mounted) _load();
                  },
                ),
                for (final s in _mine) _row(s),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text('المثبتة', style: TextStyle(color: p.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              if (_installed.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('ما عندك حزم مثبتة. افتح حزمة بالاسم من الأعلى.',
                      textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                )
              else
                InfoCard(children: [
                  for (final s in _installed)
                    _row(
                      s,
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          svc.uninstall(s.name);
                          setState(() => _installed.remove(s));
                        },
                      ),
                    ),
                ]),
            ]),
    );
  }
}

// =============== إنشاء حزمة ===============
class StickerCreateScreen extends StatefulWidget {
  const StickerCreateScreen({super.key});
  @override
  State<StickerCreateScreen> createState() => _StickerCreateScreenState();
}

class _StickerCreateScreenState extends State<StickerCreateScreen> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  String? _url;
  String? _emoji;
  bool _busy = false;
  String? _err;

  Future<void> _create() async {
    final svc = context.read<StickerService>();
    final user = context.read<AuthService>().user!;
    final name = _name.text.trim().toLowerCase();
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _err = 'اكتب عنوان الحزمة');
    if (_url == null) return setState(() => _err = 'اختر صورة الملصق الأول');
    if (_emoji == null) return setState(() => _err = 'اختر إيموجي للملصق');
    setState(() {
      _busy = true;
      _err = null;
    });
    final bad = await svc.checkName(name, user);
    if (bad != null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = bad;
        });
      }
      return;
    }
    try {
      await svc.api('create', {'name': name, 'title': title, 'emoji': _emoji, 'kind': 'static', 'url': _url}, user);
      svc.install(name);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StickerPackScreen(name: name)));
    } on StickerError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'تعذر إنشاء الحزمة';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
          child: Text(t, style: TextStyle(color: p.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        );
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('حزمة ملصقات جديدة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        label('اسم الحزمة (إنجليزي صغير، 5 أحرف فأكثر)'),
        TextField(
          controller: _name,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'my_stickers'),
        ),
        label('عنوان الحزمة'),
        TextField(controller: _title, maxLength: 40),
        label('الملصق الأول'),
        Row(children: [
          GestureDetector(
            onTap: () async {
              final u = await pickAndUploadStaticSticker(context);
              if (u != null) setState(() => _url = u);
            },
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: _url == null
                  ? Icon(Icons.add_photo_alternate_outlined, color: p.gold, size: 32)
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.network(_url!, fit: BoxFit.contain),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () async {
              final e = await pickStickerEmoji(context);
              if (e != null) setState(() => _emoji = e);
            },
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: _emoji == null
                  ? Icon(Icons.emoji_emotions_outlined, color: p.gold)
                  : Text(_emoji!, style: const TextStyle(fontSize: 30)),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('صورة ثابتة (PNG/JPG) تتحول تلقائياً إلى 512 بكسل. بعد الإنشاء تكدر تضيف باقي الملصقات.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
        ),
        if (_err != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err!, style: TextStyle(color: p.error))),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إنشاء الحزمة'),
        ),
      ]),
    );
  }
}
