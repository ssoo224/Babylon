import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../screens/sticker_screens.dart';
import '../services/auth_service.dart';
import '../services/sticker_service.dart';
import 'sticker_view.dart';

/// لوحة الملصقات: المفضلة، الأخيرة، حزمك المثبتة، بحث
class StickerPanel extends StatefulWidget {
  final void Function(Sticker st) onSend;
  final double height;
  const StickerPanel({super.key, required this.onSend, this.height = 300});
  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  List<StickerSet> _sets = [];
  bool _loading = true;
  String _tab = 'rec'; // fav | rec | اسم حزمة
  bool _search = false;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = context.read<StickerService>();
    await svc.ensure(context.read<AuthService>().uid);
    final sets = await svc.loadInstalled();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
      if (svc.recent.isEmpty && svc.faves.isEmpty && sets.isNotEmpty) _tab = sets.first.name;
    });
  }

  List<Sticker> _items(StickerService svc) {
    final q = _q.text.trim().replaceAll('\uFE0F', '').toLowerCase();
    if (_search && q.isNotEmpty) {
      final out = <Sticker>[];
      for (final s in _sets) {
        for (final st in s.stickers) {
          if (st.e.replaceAll('\uFE0F', '').contains(q) || s.title.toLowerCase().contains(q)) out.add(st);
        }
      }
      return out.take(120).toList();
    }
    if (_tab == 'fav') return svc.faves;
    if (_tab == 'rec') return svc.recent;
    return _sets.where((s) => s.name == _tab).expand((s) => s.stickers).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final svc = context.watch<StickerService>();
    final items = _items(svc);
    return Container(
      height: widget.height,
      color: p.surface,
      child: Column(children: [
        SizedBox(
          height: 46,
          child: Row(children: [
            IconButton(
              icon: Icon(_search ? Icons.close : Icons.search, size: 22),
              onPressed: () => setState(() {
                _search = !_search;
                _q.clear();
              }),
            ),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _tabBtn(p, 'fav', child: Icon(Icons.star_rounded, size: 22, color: p.gold)),
                  _tabBtn(p, 'rec', child: Icon(Icons.access_time_rounded, size: 22, color: p.gold)),
                  for (final s in _sets)
                    _tabBtn(
                      p,
                      s.name,
                      child: s.stickers.isEmpty
                          ? const SizedBox(width: 26, height: 26)
                          : StickerView(st: s.stickers.first, size: 28, play: false),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              tooltip: 'إدارة الملصقات',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const StickerManagerScreen()));
                if (mounted) _load();
              },
            ),
          ]),
        ),
        if (_search)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  hintText: 'ابحث بإيموجي أو اسم حزمة', isDense: true, contentPadding: EdgeInsets.all(10)),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            _sets.isEmpty ? 'ما عندك ملصقات بعد' : (_search ? 'لا توجد نتائج' : 'ما اكو ملصقات هنا بعد'),
                            style: TextStyle(color: p.muted),
                          ),
                          if (_sets.isEmpty)
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const StickerManagerScreen()));
                                if (mounted) _load();
                              },
                              child: const Text('استكشاف الملصقات'),
                            ),
                        ]),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 84),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final st = items[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onSend(st),
                          onLongPress: () => showStickerPreview(context, st, onSend: widget.onSend),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: StickerView(st: st, size: 72, play: false),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _tabBtn(BP p, String key, {required Widget child}) {
    final sel = _tab == key && !_search;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = key;
        _search = false;
      }),
      child: Container(
        width: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: sel ? p.gold : Colors.transparent, width: 2.5)),
        ),
        child: child,
      ),
    );
  }
}
