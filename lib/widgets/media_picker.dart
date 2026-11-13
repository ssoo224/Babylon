import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/theme.dart';

/// منتقي صور/فيديو داخل التطبيق مثل تليجرام: شبكة من معرض الجهاز + تبديل الألبوم + كاميرا + تحديد متعدد
Future<List<XFile>?> showMediaPicker(
  BuildContext context, {
  bool allowVideo = false,
  bool videoOnly = false,
  int max = 1,
  int maxVideoSeconds = 0,
}) {
  return showModalBottomSheet<List<XFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MediaSheet(
        allowVideo: allowVideo || videoOnly, videoOnly: videoOnly, max: max, maxVideoSeconds: maxVideoSeconds),
  );
}

class _MediaSheet extends StatefulWidget {
  final bool allowVideo, videoOnly;
  final int max, maxVideoSeconds;
  const _MediaSheet(
      {required this.allowVideo, required this.videoOnly, required this.max, required this.maxVideoSeconds});
  @override
  State<_MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends State<_MediaSheet> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  final List<AssetEntity> _items = [];
  final List<AssetEntity> _picked = [];
  bool _denied = false;
  bool _loading = true;
  bool _more = true;
  int _page = 0;
  bool _busy = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final type = widget.videoOnly ? RequestType.video : (widget.allowVideo ? RequestType.common : RequestType.image);
    final list = await PhotoManager.getAssetPathList(type: type, onlyAll: false);
    if (!mounted) return;
    setState(() {
      _albums = list;
      _album = list.isNotEmpty ? list.first : null;
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    final a = _album;
    if (a == null || _busy) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _busy = true;
    if (reset) {
      _items.clear();
      _page = 0;
      _more = true;
    }
    final batch = await a.getAssetListPaged(page: _page, size: 80);
    _items.addAll(batch);
    _page++;
    if (batch.length < 80) _more = false;
    _busy = false;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _finish(List<AssetEntity> assets) async {
    final out = <XFile>[];
    for (final a in assets) {
      final f = await a.file;
      if (f != null) out.add(XFile(f.path));
    }
    if (mounted) Navigator.pop(context, out);
  }

  Future<void> _camera() async {
    final p = ImagePicker();
    XFile? x;
    if (widget.videoOnly) {
      x = await p.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: widget.maxVideoSeconds > 0 ? widget.maxVideoSeconds : 120));
    } else {
      x = await p.pickImage(source: ImageSource.camera, imageQuality: 90);
    }
    if (x != null && mounted) Navigator.pop(context, [x]);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final h = MediaQuery.of(context).size.height;
    return DraggableScrollableSheet(
      initialChildSize: .68,
      minChildSize: .4,
      maxChildSize: .95,
      expand: false,
      builder: (context, sc) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3))),
          SizedBox(
            height: 52,
            child: Row(children: [
              const SizedBox(width: 6),
              PopupMenuButton<AssetPathEntity>(
                onSelected: (a) {
                  setState(() {
                    _album = a;
                    _loading = true;
                  });
                  _loadMore(reset: true);
                },
                itemBuilder: (_) => [for (final a in _albums) PopupMenuItem(value: a, child: Text(a.name == 'Recent' ? 'الأحدث' : a.name))],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_album == null ? 'المعرض' : (_album!.name == 'Recent' ? 'الأحدث' : _album!.name),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const Icon(Icons.keyboard_arrow_down),
                  ]),
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: _camera),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: _denied
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('اسمح لبابيلون بالوصول للصور حتى تظهر هنا', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
                          onPressed: PhotoManager.openSetting,
                          child: const Text('فتح الإعدادات'),
                        ),
                        TextButton(onPressed: _camera, child: const Text('استخدم الكاميرا')),
                      ]),
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400 && _more) _loadMore();
                          return false;
                        },
                        child: GridView.builder(
                          controller: sc,
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final a = _items[i];
                            final idx = _picked.indexOf(a);
                            final isVideo = a.type == AssetType.video;
                            final tooLong =
                                isVideo && widget.maxVideoSeconds > 0 && a.videoDuration.inSeconds > widget.maxVideoSeconds;
                            return GestureDetector(
                              onTap: tooLong
                                  ? null
                                  : () {
                                      if (widget.max == 1) {
                                        _finish([a]);
                                      } else {
                                        setState(() {
                                          idx >= 0
                                              ? _picked.remove(a)
                                              : (_picked.length < widget.max ? _picked.add(a) : null);
                                        });
                                      }
                                    },
                              child: Stack(fit: StackFit.expand, children: [
                                _Thumb(asset: a),
                                if (tooLong) Container(color: Colors.black54),
                                if (isVideo)
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.videocam, size: 12, color: Colors.white),
                                        const SizedBox(width: 3),
                                        Text(_dur(a.videoDuration), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                      ]),
                                    ),
                                  ),
                                if (widget.max > 1)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: idx >= 0 ? p.gold : Colors.black26,
                                        border: Border.all(color: Colors.white, width: 1.8),
                                      ),
                                      child: idx >= 0
                                          ? Text('${idx + 1}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.dark ? p.bg : Colors.white))
                                          : null,
                                    ),
                                  ),
                              ]),
                            );
                          },
                        ),
                      ),
          ),
          if (_picked.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () => _finish(List.of(_picked)),
                  child: Text('إرسال (${_picked.length})'),
                ),
              ),
            ),
          SizedBox(height: h > 0 ? 0 : 0),
        ]),
      ),
    );
  }

  String _dur(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _Thumb extends StatefulWidget {
  final AssetEntity asset;
  const _Thumb({required this.asset});
  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  Uint8List? _data;
  @override
  void initState() {
    super.initState();
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(260, 260)).then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return d == null ? Container(color: const Color(0x14808080)) : Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
