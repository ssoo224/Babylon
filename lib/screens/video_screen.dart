import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends StatefulWidget {
  final String url;
  const VideoScreen({super.key, required this.url});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
        _c.play();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: !_ready
            ? const CircularProgressIndicator()
            : GestureDetector(
                onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
                child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
              ),
      ),
    );
  }
}
