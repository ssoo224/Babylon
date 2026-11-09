import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';

/// معرض صور الملف الشخصي: سحب بين الصور، اعتماد، حذف
class AvatarGallery extends StatefulWidget {
  final List<String> images; // الحالية أولاً ثم السابقة
  final bool mine;
  const AvatarGallery({super.key, required this.images, this.mine = false});
  @override
  State<AvatarGallery> createState() => _AvatarGalleryState();
}

class _AvatarGalleryState extends State<AvatarGallery> {
  final _pc = PageController();
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final imgs = widget.images;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1} / ${imgs.length}'),
        actions: [
          if (widget.mine && _i > 0)
            TextButton(
              onPressed: () async {
                final cur = (auth.me?['avatarUrl'] as String?) ?? '';
                final picked = imgs[_i];
                final h = ((auth.me?['avatarHistory'] as List?) ?? []).cast<String>().where((e) => e != picked).toList();
                if (cur.isNotEmpty) h.insert(0, cur);
                await auth.updateProfile({'avatarUrl': picked, 'avatarHistory': h.take(5).toList()});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('اعتماد الصورة', style: TextStyle(color: Colors.white)),
            ),
          if (widget.mine && _i > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final picked = imgs[_i];
                final h = ((auth.me?['avatarHistory'] as List?) ?? []).cast<String>().where((e) => e != picked).toList();
                await auth.updateProfile({'avatarHistory': h});
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: imgs.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, k) => InteractiveViewer(
          child: Center(child: Image(image: imageFromUrl(imgs[k])!)),
        ),
      ),
    );
  }
}
