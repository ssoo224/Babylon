import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ثيمات المحادثة الأصلية (THEMES في تطبيق الويب)
class ChatTheme {
  final String key, name;
  final Color chatBg, other, textMine, textOther, accent, tick, metaOther;
  final List<Color> mine; // لونان = تدرج
  const ChatTheme({
    required this.key,
    required this.name,
    required this.chatBg,
    required this.mine,
    required this.other,
    required this.textMine,
    required this.textOther,
    required this.accent,
    required this.tick,
    required this.metaOther,
  });
}

const _babylon = ChatTheme(
  key: 'babylon', name: 'بابل',
  chatBg: Color(0xFF0D1626),
  mine: [Color(0xFFE8C85D), Color(0xFFCBA843)],
  other: Color(0xFF263345),
  textMine: Colors.white, textOther: Color(0xFFF3F4F6),
  accent: Color(0xFFC29D30), tick: Color(0xFFFFE08A), metaOther: Color(0xFF94A3B8),
);

const _ashurDark = ChatTheme(
  key: 'ashur', name: 'آشور',
  chatBg: Color(0xFF241D33), mine: [Color(0xFF6B5A9E)], other: Color(0xFF352C4A),
  textMine: Colors.white, textOther: Color(0xFFECE7F6),
  accent: Color(0xFFB7A6E0), tick: Color(0xFFD9CFF2), metaOther: Color(0xFFA89CC4),
);
const _ashurLight = ChatTheme(
  key: 'ashur', name: 'آشور',
  chatBg: Color(0xFFEBE6F3), mine: [Color(0xFF6B5A9E)], other: Color(0xFFFAF8FD),
  textMine: Colors.white, textOther: Color(0xFF2D2542),
  accent: Color(0xFF6B5A9E), tick: Color(0xFFE3DBF5), metaOther: Color(0xFF74688F),
);
const _sumerDark = ChatTheme(
  key: 'sumer', name: 'سومر',
  chatBg: Color(0xFF2E211B), mine: [Color(0xFFA1573A)], other: Color(0xFF43322A),
  textMine: Colors.white, textOther: Color(0xFFF3E7DE),
  accent: Color(0xFFD9A07F), tick: Color(0xFFF6DFCF), metaOther: Color(0xFFB9A091),
);
const _sumerLight = ChatTheme(
  key: 'sumer', name: 'سومر',
  chatBg: Color(0xFFF1E4D9), mine: [Color(0xFFA1573A)], other: Color(0xFFFCF8F4),
  textMine: Colors.white, textOther: Color(0xFF3B2519),
  accent: Color(0xFFA1573A), tick: Color(0xFFF6DFCF), metaOther: Color(0xFF7F6455),
);
const _samarra = ChatTheme(
  key: 'samarra', name: 'سامراء',
  chatBg: Color(0xFFDCC690),
  mine: [Color(0xFF5F4A1C), Color(0xFF8C6D2F)],
  other: Color(0xFFF6EACB),
  textMine: Colors.white, textOther: Color(0xFF3A2C10),
  accent: Color(0xFF5A4318), tick: Color(0xFFFFE9A8), metaOther: Color(0xFF7A6330),
);
const _baghdad = ChatTheme(
  key: 'baghdad', name: 'بغداد العباسية',
  chatBg: Color(0xFF0B2B2C),
  mine: [Color(0xFF13787A), Color(0xFF25AAA3)],
  other: Color(0xFF17484A),
  textMine: Colors.white, textOther: Color(0xFFEEF6F2),
  accent: Color(0xFFF3EAD3), tick: Color(0xFFBFF3EE), metaOther: Color(0xFF8DB8B4),
);
const _ahwar = ChatTheme(
  key: 'ahwar', name: 'الأهوار',
  chatBg: Color(0xFFCFE3D4),
  mine: [Color(0xFF2B7A8C), Color(0xFF3F9A7A)],
  other: Color(0xFFF2F8EF),
  textMine: Colors.white, textOther: Color(0xFF1F3A2A),
  accent: Color(0xFF2B6A4A), tick: Color(0xFFD6F5E6), metaOther: Color(0xFF58806A),
);

const chatThemeKeys = ['babylon', 'ashur', 'sumer', 'samarra', 'baghdad', 'ahwar'];

ChatTheme chatThemeFor(String key, bool dark) {
  switch (key) {
    case 'ashur':
      return dark ? _ashurDark : _ashurLight;
    case 'sumer':
      return dark ? _sumerDark : _sumerLight;
    case 'samarra':
      return _samarra;
    case 'baghdad':
      return _baghdad;
    case 'ahwar':
      return _ahwar;
    default:
      return _babylon;
  }
}

/// تفضيلات محلية: ثيم المحادثة، حجم الخط، زوايا الفقاعة، الإشعارات، التثبيت، الكتم
class AppPrefs extends ChangeNotifier {
  String chatTheme = 'babylon';
  int font = 15;
  int radius = 12;
  bool msgNotif = true;
  bool sound = true;
  Set<String> pinned = {};
  Set<String> muted = {};
  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('babylon_chat_prefs');
    if (raw != null) {
      try {
        applyMap(jsonDecode(raw) as Map<String, dynamic>, save: false);
      } catch (_) {}
    }
    msgNotif = _p.getBool('babylon_msg_notif') ?? true;
    sound = _p.getBool('babylon_sound') ?? true;
    pinned = (_p.getStringList('babylon_pins') ?? []).toSet();
    muted = (_p.getStringList('babylon_muted') ?? []).toSet();
    notifyListeners();
  }

  Map<String, dynamic> toMap() =>
      {'theme': chatTheme, 'font': font, 'radius': radius};

  /// يطبّق chatPrefs القادمة من users/{uid}.chatPrefs (مزامنة مع نسخة الويب)
  void applyMap(Map<String, dynamic> c, {bool save = true}) {
    final t = c['theme'];
    if (t is String && chatThemeKeys.contains(t)) chatTheme = t;
    final f = c['font'];
    if (f is num && f >= 12 && f <= 22) font = f.toInt();
    final r = c['radius'];
    if (r is num && r >= 0 && r <= 20) radius = r.toInt();
    if (save) _save();
    notifyListeners();
  }

  void _save() => _p.setString('babylon_chat_prefs', jsonEncode(toMap()));

  void set({String? theme, int? fontSize, int? corner}) {
    if (theme != null) chatTheme = theme;
    if (fontSize != null) font = fontSize;
    if (corner != null) radius = corner;
    _save();
    notifyListeners();
  }

  void setNotif({bool? messages, bool? snd}) {
    if (messages != null) {
      msgNotif = messages;
      _p.setBool('babylon_msg_notif', messages);
    }
    if (snd != null) {
      sound = snd;
      _p.setBool('babylon_sound', snd);
    }
    notifyListeners();
  }

  bool isPinned(String id) => pinned.contains(id);
  bool isMuted(String id) => muted.contains(id);

  void togglePin(String id) {
    pinned.contains(id) ? pinned.remove(id) : pinned.add(id);
    _p.setStringList('babylon_pins', pinned.toList());
    notifyListeners();
  }

  void toggleMute(String id) {
    muted.contains(id) ? muted.remove(id) : muted.add(id);
    _p.setStringList('babylon_muted', muted.toList());
    notifyListeners();
  }

  Future<void> wipe() async {
    await _p.clear();
    chatTheme = 'babylon';
    font = 15;
    radius = 12;
    msgNotif = true;
    sound = true;
    pinned = {};
    muted = {};
    notifyListeners();
  }
}
