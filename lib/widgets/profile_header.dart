import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import 'avatar.dart';

/// تصميم Profile v2: غلاف من الصورة مموّه + أفاتار متداخل + اسم + حالة
class ProfileHeader extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String username;
  final String status;
  final bool online;
  final bool verified;
  final VoidCallback? onAvatarTap;
  const ProfileHeader({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.username,
    required this.status,
    this.online = false,
    this.verified = false,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final img = imageFromUrl(avatarUrl);
    return Column(children: [
      SizedBox(
        height: 176,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          if (img != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image(image: img, fit: BoxFit.cover),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC29D30), Color(0xFF6B4F10)]),
              ),
            ),
          Container(color: Colors.black.withOpacity(.25)),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 96,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, p.chatListBg]),
              ),
            ),
          ),
        ]),
      ),
      Transform.translate(
        offset: const Offset(0, -62),
        child: Column(children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.chatListBg,
                boxShadow: const [
                  BoxShadow(color: Color(0x47000000), blurRadius: 26, offset: Offset(0, 10))
                ],
              ),
              child: Avatar(url: avatarUrl, name: name, size: 104),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w800, color: p.text, letterSpacing: -.2)),
            ),
            if (verified)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Icon(Icons.verified, color: p.gold, size: 22),
              ),
          ]),
          const SizedBox(height: 4),
          if (username.isNotEmpty)
            Text('@$username', textDirection: TextDirection.ltr, style: TextStyle(color: p.muted)),
          const SizedBox(height: 4),
          Text(status,
              style: TextStyle(
                  fontSize: 13, color: online ? const Color(0xFF4ADE80) : p.muted)),
        ]),
      ),
    ]);
  }
}

/// زر سريع مربع (مثل .pf-q)
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final c = color ?? p.gold;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.dark ? const Color(0x12FFFFFF) : p.border),
          ),
          child: Column(children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final List<Widget> children;
  const InfoCard({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.dark ? const Color(0x12FFFFFF) : p.border),
      ),
      child: Column(children: children),
    );
  }
}
