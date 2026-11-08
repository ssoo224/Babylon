import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BabylonColors {
  static const goldDark = Color(0xFFE4C45B);
  static const goldLight = Color(0xFF9B7410);
  static const bgDark = Color(0xFF090D16);
  static const surfaceDark = Color(0xFF111827);
  static const bgLight = Color(0xFFEDF2F8);
  static const surfaceLight = Color(0xFFFFFFFF);
}

class ThemeController extends ChangeNotifier {
  static const _key = 'babylon_chat_app_theme';
  ThemeMode mode = ThemeMode.dark;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    mode = v == 'light' ? ThemeMode.light : ThemeMode.dark;
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
  final dark = b == Brightness.dark;
  final gold = dark ? BabylonColors.goldDark : BabylonColors.goldLight;
  final bg = dark ? BabylonColors.bgDark : BabylonColors.bgLight;
  final surface = dark ? BabylonColors.surfaceDark : BabylonColors.surfaceLight;
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: b,
      primary: gold,
      surface: surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: dark ? Colors.white : Colors.black87,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: dark ? Colors.black : Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
