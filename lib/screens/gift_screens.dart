import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart';
import '../core/dev.dart';
import '../core/gift_data.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/gift_service.dart';
import '../widgets/avatar.dart';
import '../widgets/gift_art.dart';
import '../widgets/profile_header.dart';
import 'other_profile_screen.dart';

String fmtN(num n) => NumberFormat('#,###').format(n);

Widget _starText(BP p, num n, {double size = 14, bool bold = true, Color? color}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: size + 3, color: const Color(0xFFFFC53D)),
      const SizedBox(width: 3),
      Text(fmtN(n),
          style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? p.text)),
    ]);

// ===================== النجوم =====================
class StarsScreen extends StatelessWidget {
  const StarsScreen({super.key});

  Future<void> _sendStars(BuildContext context, {bool dev = false}) async {
    final auth = context.read<AuthService>();
    final gifts = context.read<GiftService>();
    final chat = context.read<ChatService>();
    final u = TextEditingController();
    final a = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dev ? 'نجوم مطوّر' : 'إرسال نجوم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: u, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'يوزر المستلم', prefixText: '@')),
          const SizedBox(height: 10),
          TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'عدد النجوم')),
          if (!dev) const Padding(padding: EdgeInsets.only(top: 8), child: Text('عمولة التحويل $giftFeePct%', style: TextStyle(fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final amount = int.tryParse(a.text.trim()) ?? 0;
    if (amount < 1) return toast(context, 'اكتب عدد النجوم');
    final user = await chat.findByUsername(u.text);
    if (user == null) {
      if (context.mounted) toast(context, 'ما لكيت المستخدم');
      return;
    }
    try {
      final to = user['id'] as String;
      dev ? await gifts.devStars(to, amount, auth.user!) : await gifts.sendStars(to, amount, auth.user!);
      if (context.mounted) toast(context, 'تم ✓');
    } on GiftError catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final auth = context.read<AuthService>();
    final gifts = context.read<GiftService>();
    final dev = isDevUser(auth.user);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('نجوم بابيلون')),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
                begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0x33FFC53D), Color(0x14D4AF37), Color(0x00000000)]),
            border: Border.all(color: p.dark ? const Color(0x22FFFFFF) : p.border),
          ),
          child: Column(children: [
            const Icon(Icons.star_rounded, size: 54, color: Color(0xFFFFC53D)),
            StreamBuilder<int>(
              stream: gifts.stars(auth.uid),
              builder: (_, s) => Text(dev ? '∞' : fmtN(s.data ?? 0),
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: p.dark ? Colors.white : p.text)),
            ),
            Text('رصيدك من النجوم', style: TextStyle(color: p.muted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(children: [
            QuickAction(icon: Icons.send_outlined, label: 'إرسال نجوم', onTap: () => _sendStars(context)),
            QuickAction(
                icon: Icons.card_giftcard,
                label: 'المتجر',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftStoreScreen()))),
            if (dev) QuickAction(icon: Icons.add_circle_outline, label: 'نجوم مطوّر', onTap: () => _sendStars(context, dev: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('السجل', style: TextStyle(color: p.gold, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        StreamBuilder<List<Json>>(
          stream: gifts.txs(auth.uid),
          builder: (context, s) {
            final list = s.data ?? [];
            if (list.isEmpty) {
              return Padding(
                  padding: const EdgeInsets.all(30), child: Center(child: Text('ما اكو عمليات بعد', style: TextStyle(color: p.muted))));
            }
            return InfoCard(children: [
              for (var i = 0; i < list.length; i++) _txRow(context, p, gifts, list[i], i == list.length - 1),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _txRow(BuildContext context, BP p, GiftService gifts, Json x, bool last) {
    final type = x['type'] as String? ?? '';
    final stars = (x['stars'] as num?)?.toInt() ?? 0;
    final plus = type == 'sell' || type == 'in';
    final k = gifts.kinds[x['kind']];
    String title;
    switch (type) {
      case 'buy':
        title = 'شراء ${k?.name ?? 'هدية'} #${x['gift'] ?? ''}';
        break;
      case 'sell':
        title = 'بيع ${k?.name ?? 'هدية'} #${x['gift'] ?? ''}${x['buyerName'] != null ? ' إلى ${x['buyerName']}' : ''}';
        break;
      case 'in':
        title = 'نجوم من ${x['fromName'] ?? ''}';
        break;
      case 'out':
        title = 'نجوم إلى ${x['toName'] ?? ''}';
        break;
      default:
        title = type;
    }
    final at = (x['at'] as num?)?.toInt();
    return Container(
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.dark ? const Color(0x0DFFFFFF) : p.border))),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (plus ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withOpacity(.15),
          child: Icon(plus ? Icons.south_west : Icons.north_east, color: plus ? const Color(0xFF4ADE80) : const Color(0xFFF87171), size: 20),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
        subtitle: at == null ? null : Text(DateFormat('d MMM yyyy، h:mm a', 'ar').format(DateTime.fromMillisecondsSinceEpoch(at)), style: TextStyle(fontSize: 11.5, color: p.muted)),
        trailing: _starText(p, stars, color: plus ? const Color(0xFF4ADE80) : const Color(0xFFF87171)),
      ),
    );
  }
}

// ===================== المتجر =====================
class GiftStoreScreen extends StatefulWidget {
  const GiftStoreScreen({super.key});
  @override
  State<GiftStoreScreen> createState() => _GiftStoreScreenState();
}

class _GiftStoreScreenState extends State<GiftStoreScreen> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);
  String _sort = 'new'; // new | cheap
  List<Json> _market = [];
  bool _mLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarket();
  }

  Future<void> _loadMarket({bool force = false}) async {
    try {
      final l = await context.read<GiftService>().listings(force: force);
      if (mounted) setState(() => _market = l);
    } catch (_) {}
    if (mounted) setState(() => _mLoading = false);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final gifts = context.watch<GiftService>();
    final auth = context.read<AuthService>();
    final kinds = gifts.allKinds;
    final market = List<Json>.of(_market);
    if (_sort == 'cheap') {
      market.sort((a, b) => ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));
    }
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(
        title: const Text('الهدايا'),
        actions: [
          StreamBuilder<int>(
            stream: gifts.stars(auth.uid),
            builder: (_, s) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StarsScreen())),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: p.gold.withOpacity(.14), borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: _starText(p, isDevUser(auth.user) ? 0 : (s.data ?? 0), size: 13),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tc,
          indicatorColor: p.gold,
          labelColor: p.gold,
          unselectedLabelColor: p.muted,
          tabs: const [Tab(text: 'هدايا جديدة'), Tab(text: 'هدايا مطوّرة')],
        ),
      ),
      body: TabBarView(controller: _tc, children: [
        !gifts.ready
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .82),
                itemCount: kinds.length,
                itemBuilder: (_, i) {
                  final k = kinds[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiftKindScreen(kind: k))),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.dark ? const Color(0x14FFFFFF) : p.border),
                      ),
                      child: Column(children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: LayoutBuilder(builder: (_, c) => GiftArt(kind: k, size: c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight)),
                          ),
                        ),
                        Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(color: p.gold, borderRadius: BorderRadius.circular(14)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFF17212B)),
                            const SizedBox(width: 3),
                            Text(fmtN(k.price), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF17212B))),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
        // السوق
        _mLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(children: [
                    for (final s in const [['new', 'الأحدث'], ['cheap', 'الأرخص']])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(label: Text(s[1]), selected: _sort == s[0], onSelected: (_) => setState(() => _sort = s[0])),
                      ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadMarket(force: true)),
                  ]),
                ),
                Expanded(
                  child: market.isEmpty
                      ? Center(child: Text('ما اكو هدايا معروضة للبيع هسة', style: TextStyle(color: p.muted)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .82),
                          itemCount: market.length,
                          itemBuilder: (_, i) {
                            final l = market[i];
                            final k = gifts.kindOf(l['k'] as String?);
                            final g = GiftItem(
                                k: k.key,
                                number: (l['number'] as num?)?.toInt() ?? 0,
                                upgraded: true,
                                model: (l['model'] as num?)?.toInt() ?? 0,
                                bg: (l['bg'] as num?)?.toInt() ?? 0,
                                sym: (l['sym'] as num?)?.toInt() ?? 0,
                                ownerId: l['sellerId'] as String?);
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => GiftPageScreen(kind: k, number: g.number, owner: g.ownerId))),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: p.dark ? const Color(0x14FFFFFF) : p.border),
                                ),
                                child: Column(children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: LayoutBuilder(
                                          builder: (_, c) => GiftArt(kind: k, gift: g, ribbon: true, size: c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight)),
                                    ),
                                  ),
                                  Text('${k.name} #${g.number}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(color: p.gold, borderRadius: BorderRadius.circular(14)),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFF17212B)),
                                      const SizedBox(width: 3),
                                      Text(fmtN((l['price'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF17212B))),
                                    ]),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ]),
      ]),
    );
  }
}

// ===================== صفحة نوع الهدية (الشراء) =====================
class GiftKindScreen extends StatefulWidget {
  final GiftKind kind;
  const GiftKindScreen({super.key, required this.kind});
  @override
  State<GiftKindScreen> createState() => _GiftKindScreenState();
}

class _GiftKindScreenState extends State<GiftKindScreen> {
  int? _issued;
  int? _floor;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final g = context.read<GiftService>();
    g.issued(widget.kind).then((v) => mounted ? setState(() => _issued = v) : null).catchError((_) {});
    g.floorFor(widget.kind).then((v) => mounted ? setState(() => _floor = v) : null).catchError((_) {});
  }

  Future<void> _buy() async {
    final auth = context.read<AuthService>();
    final gifts = context.read<GiftService>();
    final K = widget.kind;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('شراء ${K.name}'),
        content: Text('سيتم خصم ${fmtN(K.price)} ⭐ من رصيدك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('شراء')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await gifts.buy(K, auth.user!);
      final n = (r['number'] as num?)?.toInt();
      if (!mounted) return;
      toast(context, '🎁 اشتريت ${K.name}${n != null ? ' #$n' : ''}');
      if (n != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GiftPageScreen(kind: K, number: n, owner: auth.uid)));
      }
    } on GiftError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final K = widget.kind;
    final gifts = context.read<GiftService>();
    final auth = context.read<AuthService>();
    final left = _issued == null ? null : K.max - _issued!;
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: Text(K.name)),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Center(child: GiftArt(kind: K, size: MediaQuery.of(context).size.width - 90, animate: true)),
        ),
        Center(child: Text(K.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        const SizedBox(height: 6),
        Center(child: Text(left == null ? '' : (left <= 0 ? 'نفدت الكمية' : 'المتبقي $left من ${K.max}'), style: TextStyle(color: left != null && left <= 0 ? p.error : p.muted))),
        const SizedBox(height: 14),
        InfoCard(children: [
          PfRow(icon: Icons.star_rounded, value: fmtN(K.price), label: 'السعر بالنجوم'),
          if (_floor != null) PfRow(icon: Icons.sell_outlined, value: fmtN(_floor!), label: 'أرخص نسخة مرقّاة معروضة'),
          PfRow(icon: Icons.auto_awesome, value: 'تكدر ترقّيها لنسخة فريدة بنموذج ورمز وخلفية', label: 'الترقية', last: true),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text('النماذج المحتملة بعد الترقية', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < K.models.length && i < 40; i++)
                Container(
                  width: 92,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    Image.network(K.pngUrl(i), width: 72, height: 72, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72)),
                    Text(K.models[i].n, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    Text('${K.rarePct(i)}%', style: TextStyle(fontSize: 11, color: p.muted)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<int>(
            stream: gifts.stars(auth.uid),
            builder: (_, s) => Column(children: [
              ElevatedButton(
                onPressed: (_busy || (left != null && left <= 0)) ? null : _buy,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('شراء بـ ${fmtN(K.price)}'),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 18),
                      ]),
              ),
              const SizedBox(height: 8),
              Text('رصيدك: ${isDevUser(auth.user) ? '∞' : fmtN(s.data ?? 0)} ⭐', style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ===================== صفحة الهدية =====================
class GiftPageScreen extends StatefulWidget {
  final GiftKind kind;
  final int number;
  final String? owner;
  const GiftPageScreen({super.key, required this.kind, required this.number, this.owner});
  @override
  State<GiftPageScreen> createState() => _GiftPageScreenState();
}

class _GiftPageScreenState extends State<GiftPageScreen> {
  GiftItem? _g;
  String? _owner;
  Json? _listing;
  Json? _ownerUser;
  int _issued = 0;
  bool _loading = true;
  bool _busy = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gifts = context.read<GiftService>();
    final K = widget.kind;
    try {
      final owner = widget.owner ?? await gifts.ownerOf(K, widget.number);
      GiftItem? g;
      if (owner != null) g = await gifts.loadGift(K, widget.number, owner);
      final listing = await gifts.listingOf(K, widget.number);
      Json? ou;
      if (owner != null) ou = await context.read<ChatService>().getUser(owner);
      final iss = await gifts.issued(K);
      if (!mounted) return;
      setState(() {
        _owner = owner;
        _g = g;
        _listing = listing;
        _ownerUser = ou;
        _issued = iss;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _mine => _owner != null && _owner == context.read<AuthService>().uid;

  Future<void> _upgrade() async {
    final auth = context.read<AuthService>();
    final gifts = context.read<GiftService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ترقية الهدية'),
        content: const Text('تتحول لنسخة فريدة بنموذج ورمز وخلفية عشوائية، ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ترقية')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await gifts.upgrade(widget.kind, widget.number, auth.user!);
      _reveal = true;
      await _load();
      if (mounted) toast(context, '✨ تمت الترقية');
    } on GiftError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sell({bool update = false}) async {
    final gifts = context.read<GiftService>();
    final me = context.read<AuthService>().uid;
    final g = _g!;
    final c = TextEditingController(text: update ? '${(_listing?['price'] as num?)?.toInt() ?? ''}' : '');
    final fl = await gifts.floorFor(widget.kind);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(update ? 'تعديل السعر' : 'بيع الهدية'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'السعر بالنجوم')),
          const SizedBox(height: 8),
          Text('عمولة السوق $giftFeePct% · تستلم ${100 - giftFeePct}% من السعر${fl != null ? '\nأرخص عرض حالياً: ${fmtN(fl)} ⭐' : ''}', style: const TextStyle(fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    final price = int.tryParse(c.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (price == null || price < 1 || price > 1000000) return toast(context, 'اكتب سعراً بين 1 و 1,000,000');
    try {
      await gifts.sell(widget.kind, g, price, me, update: update);
      if (mounted) toast(context, '🏷️ ${update ? 'تم تحديث السعر' : 'انعرضت للبيع بـ ${fmtN(price)} ⭐ · تستلم ${fmtN(netOf(price))}'}');
      await _load();
    } catch (_) {
      if (mounted) toast(context, 'تعذر العرض للبيع');
    }
  }

  Future<void> _unlist() async {
    await context.read<GiftService>().unlist(widget.kind, widget.number);
    if (mounted) toast(context, 'تم إلغاء العرض');
    await _load();
  }

  Future<void> _buyListing() async {
    final auth = context.read<AuthService>();
    final gifts = context.read<GiftService>();
    final price = (_listing?['price'] as num?)?.toInt() ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('شراء ${widget.kind.name} #${widget.number}'),
        content: Text('سعرها ${fmtN(price)} ⭐'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('شراء')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await gifts.buyListing(widget.kind, widget.number, auth.user!);
      if (mounted) toast(context, '🎁 صارت ملكك');
      await _load();
    } on GiftError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final K = widget.kind;
    final gifts = context.watch<GiftService>();
    final g = _g;
    final mine = _mine;
    final listed = _listing != null;
    final price = (_listing?['price'] as num?)?.toInt();
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: Text('${K.name} #${widget.number}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? const Center(child: Text('الهدية غير موجودة'))
              : ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        scale: _reveal ? 1 : 1,
                        child: GiftArt(kind: K, gift: g, size: MediaQuery.of(context).size.width - 90, animate: true, ribbon: true),
                      ),
                    ),
                  ),
                  Center(child: Text('${K.name} #${g.number}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  if (listed && price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(child: _starText(p, price, size: 17)),
                    ),
                  const SizedBox(height: 14),
                  InfoCard(children: [
                    GestureDetector(
                      onTap: _owner == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(uid: _owner!))),
                      child: ListTile(
                        leading: Avatar(url: avatarOf(_ownerUser), name: (_ownerUser?['displayName'] as String?) ?? '?', size: 44, seed: _owner),
                        title: Text(mine ? 'أنت' : ((_ownerUser?['displayName'] as String?) ?? '...'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('المالك', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ),
                    ),
                    if (g.upgraded) ...[
                      PfRow(icon: Icons.category_outlined, value: '${K.models[g.model.clamp(0, K.models.length - 1)].n}  ·  ${K.rarePct(g.model)}%', label: 'النموذج'),
                      PfRow(icon: Icons.emoji_symbols, value: '${giftSyms[g.sym.clamp(0, giftSyms.length - 1)].n}  ·  ${(giftSyms[g.sym.clamp(0, giftSyms.length - 1)].p / giftSyms.fold<int>(0, (a, x) => a + x.p) * 100).toStringAsFixed(1)}%', label: 'الرمز'),
                      PfRow(icon: Icons.gradient, value: '${giftBgs[g.bg.clamp(0, giftBgs.length - 1)].n}  ·  ${(giftBgs[g.bg.clamp(0, giftBgs.length - 1)].p / giftBgs.fold<int>(0, (a, x) => a + x.p) * 100).toStringAsFixed(1)}%', label: 'الخلفية'),
                    ],
                    PfRow(icon: Icons.tag, value: '$_issued من ${K.max}', label: 'الكمية المصدرة', last: true),
                  ]),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(children: [
                      if (mine && !g.upgraded)
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _upgrade,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('ترقية'),
                        ),
                      if (mine && g.upgraded && !listed)
                        ElevatedButton.icon(onPressed: _sell, icon: const Icon(Icons.sell_outlined), label: const Text('بيع')),
                      if (mine && listed) ...[
                        ElevatedButton(onPressed: () => _sell(update: true), child: const Text('تعديل السعر')),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _unlist, child: const Text('إلغاء العرض')),
                      ],
                      if (mine && !listed) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await gifts.loadPrefs(context.read<AuthService>().uid);
                                await gifts.togglePin(g);
                                if (mounted) toast(context, gifts.isPinned(g) ? 'تم التثبيت بالملف' : 'تم إلغاء التثبيت');
                              },
                              icon: const Icon(Icons.push_pin_outlined),
                              label: const Text('تثبيت'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SendGiftScreen(pick: g))),
                              icon: const Icon(Icons.card_giftcard),
                              label: const Text('إهداء'),
                            ),
                          ),
                        ]),
                      ],
                      if (!mine && listed && price != null)
                        ElevatedButton(
                          onPressed: _busy ? null : _buyListing,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('شراء بـ ${fmtN(price)}'),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 18),
                          ]),
                        ),
                    ]),
                  ),
                ]),
    );
  }
}

// ===================== إهداء =====================
/// إذا مُرّرت pick: تختار المستلم. وإلا: (من المحادثة) تختار هدية من هداياك للمستلم otherId
class SendGiftScreen extends StatefulWidget {
  final String? otherId;
  final GiftItem? pick;
  const SendGiftScreen({super.key, this.otherId, this.pick});
  @override
  State<SendGiftScreen> createState() => _SendGiftScreenState();
}

class _SendGiftScreenState extends State<SendGiftScreen> {
  List<GiftItem>? _mine;
  final _u = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.pick == null) {
      final me = context.read<AuthService>().uid;
      context.read<GiftService>().myGifts(me).then((l) async {
        final lst = await context.read<GiftService>().listings();
        final listed = lst.map((x) => '${x['k']}_${x['number']}').toSet();
        if (mounted) setState(() => _mine = l.where((g) => !listed.contains(g.id)).toList());
      }).catchError((_) {
        if (mounted) setState(() => _mine = []);
      });
    }
  }

  Future<void> _send(GiftItem g, String to) async {
    final gifts = context.read<GiftService>();
    final me = context.read<AuthService>().uid;
    final K = gifts.kindOf(g.k);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إهداء الهدية'),
        content: Text('إرسال ${K.name} #${g.number}؟ تنتقل ملكيتها للمستلم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await gifts.transfer(K, g, to, me);
      if (mounted) {
        toast(context, '🎁 انرسلت الهدية');
        Navigator.pop(context);
        if (widget.pick != null) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'تعذر الإرسال');
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickUser() async {
    final user = await context.read<ChatService>().findByUsername(_u.text);
    if (!mounted) return;
    if (user == null) return toast(context, 'ما لكيت المستخدم');
    final id = user['id'] as String;
    if (id == context.read<AuthService>().uid) return toast(context, 'ما تكدر تهدي نفسك');
    await _send(widget.pick!, id);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final gifts = context.read<GiftService>();
    if (widget.pick != null) {
      return Scaffold(
        backgroundColor: p.chatListBg,
        appBar: AppBar(title: const Text('إهداء إلى')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _u, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'يوزر المستلم', prefixText: '@')),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _busy ? null : _pickUser, child: const Text('إرسال')),
        ]),
      );
    }
    final list = _mine;
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('اختر هدية للإرسال')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('ما عندك هدايا للإهداء. اشترِ من المتجر أول.', textAlign: TextAlign.center, style: TextStyle(color: p.muted))))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final g = list[i];
                    return GestureDetector(
                      onTap: _busy || widget.otherId == null ? null : () => _send(g, widget.otherId!),
                      child: GiftArt(kind: gifts.kindOf(g.k), gift: g, ribbon: true, size: 110),
                    );
                  },
                ),
    );
  }
}

// ===================== شبكة الهدايا بالملف الشخصي =====================
class GiftsGrid extends StatefulWidget {
  final String uid;
  final bool mine;
  const GiftsGrid({super.key, required this.uid, required this.mine});
  @override
  State<GiftsGrid> createState() => _GiftsGridState();
}

class _GiftsGridState extends State<GiftsGrid> {
  List<GiftItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gifts = context.read<GiftService>();
    await gifts.loadPrefs(widget.uid);
    try {
      final l = await gifts.myGifts(widget.uid);
      if (mounted) setState(() => _items = l);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final gifts = context.watch<GiftService>();
    var items = List<GiftItem>.of(_items ?? []);
    if (!widget.mine) items = items.where((g) => !gifts.isHidden(g)).toList();
    items.sort((a, b) {
      final pa = gifts.isPinned(a) ? 1 : 0, pb = gifts.isPinned(b) ? 1 : 0;
      return pa != pb ? pb - pa : b.at.compareTo(a.at);
    });
    if (_items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Text('الهدايا (${items.length})', style: TextStyle(color: p.gold, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final g = items[i];
          final k = gifts.kindOf(g.k);
          return GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => GiftPageScreen(kind: k, number: g.number, owner: widget.uid)));
              if (mounted) _load();
            },
            onLongPress: !widget.mine
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (c) => SafeArea(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          ListTile(
                            leading: const Icon(Icons.push_pin_outlined),
                            title: Text(gifts.isPinned(g) ? 'إلغاء التثبيت' : 'تثبيت بالملف'),
                            onTap: () {
                              Navigator.pop(c);
                              gifts.togglePin(g);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.visibility_off_outlined),
                            title: Text(gifts.isHidden(g) ? 'إظهار للجميع' : 'إخفاء من الملف'),
                            onTap: () {
                              Navigator.pop(c);
                              gifts.toggleHidden(g);
                            },
                          ),
                        ]),
                      ),
                    ),
            child: Stack(children: [
              Positioned.fill(child: LayoutBuilder(builder: (_, c) => GiftArt(kind: k, gift: g, ribbon: true, size: c.maxWidth))),
              if (gifts.isPinned(g))
                const Positioned(bottom: 4, left: 4, child: Icon(Icons.push_pin, size: 16, color: Colors.white)),
              if (widget.mine && gifts.isHidden(g))
                const Positioned(bottom: 4, right: 4, child: Icon(Icons.visibility_off, size: 16, color: Colors.white70)),
            ]),
          );
        },
      ),
    ]);
  }
}
