import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ألوان مأخوذة حرفياً من CSS تطبيق الويب الأصلي (data-app-theme)
class BP {
  final Color bg, surface, card, hover, border, gold, text, muted, error;
  final Color bubbleMine, bubbleOther, bubbleMineText, bubbleOtherText;
  final Color chatListBg, navActive, authFrom, authTo;
  final bool dark;
  const BP({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.card,
    required this.hover,
    required this.border,
    required this.gold,
    required this.text,
    required this.muted,
    required this.error,
    required this.bubbleMine,
    required this.bubbleOther,
    required this.bubbleMineText,
    required this.bubbleOtherText,
    required this.chatListBg,
    required this.navActive,
    required this.authFrom,
    required this.authTo,
  });

  static const darkP = BP(
    dark: true,
    bg: Color(0xFF0F172A),
    surface: Color(0xFF17212B),
    card: Color(0xFF1E293B),
    hover: Color(0xFF263548),
    border: Color(0xFF344256),
    gold: Color(0xFFE4C45B),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFFA5B2C2),
    error: Color(0xFFFB7185),
    bubbleMine: Color(0xFF2B5278),
    bubbleOther: Color(0xFF182533),
    bubbleMineText: Colors.white,
    bubbleOtherText: Colors.white,
    chatListBg: Color(0xFF0E1621),
    navActive: Color(0xFF64B5F6),
    authFrom: Color(0xFF1E293B),
    authTo: Color(0xFF090D16),
  );

  static const lightP = BP(
    dark: false,
    bg: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    hover: Color(0xFFEAF0F7),
    border: Color(0xFFDCE4EE),
    gold: Color(0xFF9B7410),
    text: Color(0xFF17212B),
    muted: Color(0xFF68798D),
    error: Color(0xFFC0392B),
    bubbleMine: Color(0xFFD8F7D2),
    bubbleOther: Color(0xFFFFFFFF),
    bubbleMineText: Color(0xFF17212B),
    bubbleOtherText: Color(0xFF17212B),
    chatListBg: Color(0xFFEEF1F6),
    navActive: Color(0xFF1E6FD9),
    authFrom: Color(0xFFFFFFFF),
    authTo: Color(0xFFEDF2F8),
  );

  static BP of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkP : lightP;
}

class ThemeController extends ChangeNotifier {
  static const _key = 'babylon_chat_app_theme';
  ThemeMode mode = ThemeMode.dark;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = p.getString(_key) == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, m == ThemeMode.light ? 'light' : 'dark');
  }
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? BP.darkP : BP.lightP;
  OutlineInputBorder ob([Color? c]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c ?? p.border),
      );
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.surface,
    dividerColor: p.border,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.gold,
      brightness: b,
      primary: p.gold,
      surface: p.surface,
      error: p.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: p.text, letterSpacing: .3),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      height: 60,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 11,
          color: s.contains(WidgetState.selected) ? p.navActive : p.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          size: 22, color: s.contains(WidgetState.selected) ? p.navActive : p.muted)),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.dark ? const Color(0x0AFFFFFF) : p.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: ob(),
      enabledBorder: ob(),
      focusedBorder: ob(p.gold),
      hintStyle: TextStyle(color: p.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.dark ? p.bg : Colors.white,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.muted,
      ),
    ),
    textTheme: Typography.material2021().white.apply(
          bodyColor: p.text,
          displayColor: p.text,
        ),
  );
}
