import 'package:flutter/material.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import 'avatar.dart';
import 'bicon.dart';
import 'pattern_layer.dart';

/// رأس الملف الشخصي الأصلي: غلاف (تدرج ثيم + شبكة نقوش) يتلاشى، أفاتار كبير بحلقة، اسم، حالة
class ProfileHeader extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String username;
  final String status;
  final bool online;
  final bool verified;
  final VoidCallback? onAvatarTap;
  final String coverKey;
  final String? seed;
  final bool hasStory;
  const ProfileHeader({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.username,
    required this.status,
    this.online = false,
    this.verified = false,
    this.onAvatarTap,
    this.coverKey = 'babylon',
    this.seed,
    this.hasStory = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final top = MediaQuery.of(context).padding.top;
    final coverH = 150 + top;
    final theme = chatThemeBase(coverKey);
    return SizedBox(
      height: coverH + 170,
      child: Stack(clipBehavior: Clip.none, children: [
        // الغلاف
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coverH,
          child: Stack(fit: StackFit.expand, children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.cover),
              ),
            ),
            Padding(padding: EdgeInsets.only(top: top * .6), child: CoverPattern(theme: theme)),
            // تلاشي سفلي 70%
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: coverH * .7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [p.chatListBg.withOpacity(0), p.chatListBg]),
                ),
              ),
            ),
          ]),
        ),
        // الأفاتار + الاسم + الحالة
        Positioned(
          top: coverH - 58,
          left: 0,
          right: 0,
          child: Column(children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.chatListBg,
                  border: Border.all(
                      color: hasStory ? p.gold : (p.dark ? const Color(0xFF2F3E50) : const Color(0xFFD5DCE6)),
                      width: 2.5),
                  boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 26, offset: Offset(0, 10))],
                ),
                child: Avatar(url: avatarUrl, name: name, size: 106, seed: seed),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.dark ? Colors.white : p.text)),
                ),
                if (verified)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: Icon(Icons.verified, color: p.gold, size: 22),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? const Color(0xFF4ADE80) : const Color(0xFF5B6B7E),
                  boxShadow: online ? const [BoxShadow(color: Color(0x2E4ADE80), spreadRadius: 3)] : null,
                ),
              ),
              const SizedBox(width: 7),
              Text(status,
                  style: TextStyle(fontSize: 13, color: online ? const Color(0xFF4ADE80) : p.muted)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// زر سريع مربع (أيقونة فوق النص) — .pf-q
class QuickAction extends StatelessWidget {
  final IconData? icon;
  final String? biconName;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const QuickAction({super.key, this.icon, this.biconName, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final c = color ?? p.gold;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.dark ? const Color(0xFF2A394A) : p.border),
          ),
          child: Column(children: [
            biconName != null ? BIcon(biconName!, size: 22, color: c) : Icon(icon, color: c, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

/// زر أساسي/محيطي (pf-actions) للملف الآخر
class PfButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  const PfButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final fg = primary ? const Color(0xFF17212B) : (danger ? p.error : p.text);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 46,
          decoration: BoxDecoration(
            color: primary ? p.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: primary ? p.gold : (danger ? p.error : p.border)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.dark ? const Color(0x12FFFFFF) : p.border),
      ),
      child: Column(children: children),
    );
  }
}

/// صف معلومات الملف (pf-row): أيقونة ذهبية في مربع، القيمة فوق والعنوان تحتها
class PfRow extends StatelessWidget {
  final IconData? icon;
  final String? biconName;
  final String value;
  final String label;
  final bool ltr;
  final bool muted;
  final bool last;
  final VoidCallback? onTap;
  const PfRow({
    super.key,
    this.icon,
    this.biconName,
    required this.value,
    required this.label,
    this.ltr = false,
    this.muted = false,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: p.dark ? const Color(0x0DFFFFFF) : p.border)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.gold.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
            child: Center(
              child: biconName != null ? BIcon(biconName!, size: 21, color: p.gold) : Icon(icon, size: 21, color: p.gold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Directionality(
                textDirection: ltr ? TextDirection.ltr : Directionality.of(context),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                          color: muted ? p.muted : (p.dark ? Colors.white : p.text))),
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12.5, color: p.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
