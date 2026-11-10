import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'bicon.dart';

/// الشريط السفلي الأصلي: خط ذهبي علوي متدرج + كبسولة ذهبية خلف الأيقونة النشطة
class BBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const BBottomNav({super.key, required this.index, required this.onTap});

  static const _items = [
    ['chat', 'المحادثات'],
    ['sliders', 'الإعدادات'],
    ['user', 'الملف الشخصي'],
  ];

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final gold = p.dark ? const Color(0xFFE4C45B) : const Color(0xFFB8861B);
    return Container(
      decoration: BoxDecoration(color: p.surface),
      child: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Color(0x99D4AF37),
                Color(0xD9F6DF86),
                Color(0x99D4AF37),
                Colors.transparent,
              ], stops: [0, .25, .5, .75, 1]),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: SizedBox(
              height: 56,
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Opacity(
                        opacity: i == index ? 1 : .78,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 54,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: i == index ? const Color(0x2BD4AF37) : Colors.transparent,
                            ),
                            child: Center(child: BIcon(_items[i][0], size: 22, color: gold)),
                          ),
                          const SizedBox(height: 4),
                          Text(_items[i][1],
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: gold)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
