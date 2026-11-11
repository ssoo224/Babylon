import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import '../core/cloudinary.dart';
import '../services/sticker_service.dart';

final Map<String, Uint8List> _tgsCache = {};
final List<String> _tgsOrder = [];

/// TGS = Lottie JSON مضغوط gzip (مثل lotJson في الأصل)
Future<Uint8List> _loadTgs(String url) async {
  final hit = _tgsCache[url];
  if (hit != null) return hit;
  final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) throw Exception('tgs');
  final json = Uint8List.fromList(GZipCodec().decode(r.bodyBytes));
  _tgsCache[url] = json;
  _tgsOrder.add(url);
  if (_tgsOrder.length > 40) _tgsCache.remove(_tgsOrder.removeAt(0));
  return json;
}

/// يعرض ملصق: ثابت / متحرك (TGS) / فيديو (WEBM)
class StickerView extends StatelessWidget {
  final Sticker st;
  final double size;
  final bool play; // false = إطار ثابت (للشبكات)
  const StickerView({super.key, required this.st, this.size = 120, this.play = true});

  Widget _fallback() => SizedBox(
        width: size,
        height: size,
        child: Center(child: Text(st.e, style: TextStyle(fontSize: size * .5))),
      );

  @override
  Widget build(BuildContext context) {
    switch (st.k) {
      case 'animated':
        return SizedBox(
          width: size,
          height: size,
          child: FutureBuilder<Uint8List>(
            future: _loadTgs(st.u),
            builder: (_, s) {
              if (s.hasError) return _fallback();
              if (!s.hasData) return Center(child: Text(st.e, style: TextStyle(fontSize: size * .4)));
              return Lottie.memory(
                s.data!,
                width: size,
                height: size,
                repeat: play,
                animate: play,
                errorBuilder: (_, __, ___) => _fallback(),
              );
            },
          ),
        );
      case 'video':
        return play
            ? _VideoSticker(url: st.u, size: size, fallback: _fallback())
            : Image.network(Cloudinary.posterOf(st.u),
                width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback());
      default:
        return Image.network(
          st.u,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(),
        );
    }
  }
}

class _VideoSticker extends StatefulWidget {
  final String url;
  final double size;
  final Widget fallback;
  const _VideoSticker({required this.url, required this.size, required this.fallback});
  @override
  State<_VideoSticker> createState() => _VideoStickerState();
}

class _VideoStickerState extends State<_VideoSticker> {
  VideoPlayerController? _c;
  bool _ok = false;
  bool _bad = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      setState(() => _ok = true);
    }).catchError((_) {
      if (mounted) setState(() => _bad = true);
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bad) return widget.fallback;
    if (!_ok) return SizedBox(width: widget.size, height: widget.size);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _c!.value.size.width,
          height: _c!.value.size.height,
          child: VideoPlayer(_c!),
        ),
      ),
    );
  }
}
