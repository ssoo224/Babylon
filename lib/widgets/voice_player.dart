import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../core/utils.dart';

class VoicePlayer extends StatefulWidget {
  final String url;
  final int seconds;
  const VoicePlayer({super.key, required this.url, required this.seconds});
  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _p = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _dur = Duration(seconds: widget.seconds);
    _p.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _p.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _p.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _dur = d);
    });
    _p.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = Duration.zero);
    });
  }

  Future<void> _toggle() async {
    if (_playing) return _p.pause();
    final bytes = bytesFromDataUrl(widget.url);
    if (_pos > Duration.zero) return _p.resume();
    await _p.play(bytes != null ? BytesSource(bytes) : UrlSource(widget.url));
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final v = _dur.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 36),
        ),
        Expanded(child: LinearProgressIndicator(value: v)),
        const SizedBox(width: 8),
        Text(_fmt(_playing || _pos > Duration.zero ? _pos : _dur),
            style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
