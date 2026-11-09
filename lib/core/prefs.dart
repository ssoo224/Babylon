import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ثيمات المحادثة الأصلية (THEMES في تطبيق الويب) بكل أوضاعها (داكن/فاتح) ونقوش الخلفية
class ChatTheme {
  final String key, name;
  final Color chatBg, other, textMine, textOther, accent, tick, metaOther, pattern;
  final double patternOp;
  final List<Color> mine; // لونان = تدرج
  final List<String> symbols; // رموز بابلية للنقش
  final List<Color> cover; // تدرج الغلاف (mine الأساسي)
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
    required this.pattern,
    required this.patternOp,
    required this.symbols,
    required this.cover,
  });
}

const _babylonBase = ChatTheme(key: 'babylon', name: 'بابل',
    chatBg: Color(0xFF0D1626), mine: [Color(0xFFE8C85D), Color(0xFFCBA843)], other: Color(0xFF263345), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFF3F4F6),
    accent: Color(0xFFC29D30), tick: Color(0xFFFFE08A), metaOther: Color(0xFF94A3B8), pattern: Color(0xFFC29D30), patternOp: 0.11,
    symbols: ['gate', 'star8', 'bull', 'tablet', 'crescent', 'jar'], cover: [Color(0xFFE8C85D), Color(0xFFCBA843)]);
const _ashurBase = ChatTheme(key: 'ashur', name: 'آشور',
    chatBg: Color(0xFF1F1710), mine: [Color(0xFF8A5A2B), Color(0xFFC48B47)], other: Color(0xFF3A2C1D), textMine: Color(0xFFFFF8EC), textOther: Color(0xFFF1E4CC),
    accent: Color(0xFFE0B36A), tick: Color(0xFFFFE6B0), metaOther: Color(0xFFB89F7A), pattern: Color(0xFFC9A064), patternOp: 0.11,
    symbols: ['bull', 'arch', 'sun', 'gate', 'star8', 'tablet'], cover: [Color(0xFF8A5A2B), Color(0xFFC48B47)]);
const _ashurDark = ChatTheme(key: 'ashur', name: 'آشور',
    chatBg: Color(0xFF241D33), mine: [Color(0xFF6B5A9E)], other: Color(0xFF352C4A), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFECE7F6),
    accent: Color(0xFFB7A6E0), tick: Color(0xFFD9CFF2), metaOther: Color(0xFFA89CC4), pattern: Color(0xFFB7A6E0), patternOp: 0.09,
    symbols: ['bull', 'arch', 'sun', 'gate', 'star8', 'tablet'], cover: [Color(0xFF8A5A2B), Color(0xFFC48B47)]);
const _ashurLight = ChatTheme(key: 'ashur', name: 'آشور',
    chatBg: Color(0xFFEBE6F3), mine: [Color(0xFF6B5A9E)], other: Color(0xFFFAF8FD), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF2D2542),
    accent: Color(0xFF6B5A9E), tick: Color(0xFFE3DBF5), metaOther: Color(0xFF74688F), pattern: Color(0xFF6B5A9E), patternOp: 0.1,
    symbols: ['bull', 'arch', 'sun', 'gate', 'star8', 'tablet'], cover: [Color(0xFF8A5A2B), Color(0xFFC48B47)]);
const _sumerBase = ChatTheme(key: 'sumer', name: 'سومر',
    chatBg: Color(0xFFECD9B8), mine: [Color(0xFFA8552D), Color(0xFFCC7B49)], other: Color(0xFFFBF1DE), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF3B2412),
    accent: Color(0xFF8A4524), tick: Color(0xFFFFF3C4), metaOther: Color(0xFF7A5C3A), pattern: Color(0xFF7A4A24), patternOp: 0.16,
    symbols: ['ziggurat', 'tablet', 'lyre', 'jar', 'reeds', 'sun'], cover: [Color(0xFFA8552D), Color(0xFFCC7B49)]);
const _sumerDark = ChatTheme(key: 'sumer', name: 'سومر',
    chatBg: Color(0xFF2E211B), mine: [Color(0xFFA1573A)], other: Color(0xFF43322A), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFF3E7DE),
    accent: Color(0xFFD9A07F), tick: Color(0xFFF6DFCF), metaOther: Color(0xFFB9A091), pattern: Color(0xFFD9A07F), patternOp: 0.09,
    symbols: ['ziggurat', 'tablet', 'lyre', 'jar', 'reeds', 'sun'], cover: [Color(0xFFA8552D), Color(0xFFCC7B49)]);
const _sumerLight = ChatTheme(key: 'sumer', name: 'سومر',
    chatBg: Color(0xFFF1E4D9), mine: [Color(0xFFA1573A)], other: Color(0xFFFCF8F4), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF3B2519),
    accent: Color(0xFFA1573A), tick: Color(0xFFF6DFCF), metaOther: Color(0xFF7F6455), pattern: Color(0xFFA1573A), patternOp: 0.1,
    symbols: ['ziggurat', 'tablet', 'lyre', 'jar', 'reeds', 'sun'], cover: [Color(0xFFA8552D), Color(0xFFCC7B49)]);
const _samarraBase = ChatTheme(key: 'samarra', name: 'سامراء',
    chatBg: Color(0xFFDCC690), mine: [Color(0xFF5F4A1C), Color(0xFF8C6D2F)], other: Color(0xFFF6EACB), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF3A2C10),
    accent: Color(0xFF5A4318), tick: Color(0xFFFFFFFF), metaOther: Color(0xFF7B6537), pattern: Color(0xFF5F4A1C), patternOp: 0.15,
    symbols: ['minaret', 'palm', 'arch', 'sun', 'wave', 'jar'], cover: [Color(0xFF5F4A1C), Color(0xFF8C6D2F)]);
const _samarraDark = ChatTheme(key: 'samarra', name: 'سامراء',
    chatBg: Color(0xFF2A261A), mine: [Color(0xFF7F6D2D)], other: Color(0xFF3C3624), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFF1EAD3),
    accent: Color(0xFFCDB866), tick: Color(0xFFEFE3B0), metaOther: Color(0xFFB2A778), pattern: Color(0xFFCDB866), patternOp: 0.09,
    symbols: ['minaret', 'palm', 'arch', 'sun', 'wave', 'jar'], cover: [Color(0xFF5F4A1C), Color(0xFF8C6D2F)]);
const _samarraLight = ChatTheme(key: 'samarra', name: 'سامراء',
    chatBg: Color(0xFFEFE9D3), mine: [Color(0xFF7F6D2D)], other: Color(0xFFFBF9EE), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF37301A),
    accent: Color(0xFF7F6D2D), tick: Color(0xFFEFE3B0), metaOther: Color(0xFF756C47), pattern: Color(0xFF7F6D2D), patternOp: 0.1,
    symbols: ['minaret', 'palm', 'arch', 'sun', 'wave', 'jar'], cover: [Color(0xFF5F4A1C), Color(0xFF8C6D2F)]);
const _baghdadBase = ChatTheme(key: 'baghdad', name: 'بغداد العباسية',
    chatBg: Color(0xFF0B2B2C), mine: [Color(0xFF13787A), Color(0xFF25AAA3)], other: Color(0xFF17484A), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFEEF6F2),
    accent: Color(0xFFF3EAD3), tick: Color(0xFFC4F5F0), metaOther: Color(0xFF8FB8B4), pattern: Color(0xFFF3EAD3), patternOp: 0.1,
    symbols: ['arch', 'crescent', 'star8', 'minaret', 'palm', 'sun'], cover: [Color(0xFF13787A), Color(0xFF25AAA3)]);
const _baghdadDark = ChatTheme(key: 'baghdad', name: 'بغداد العباسية',
    chatBg: Color(0xFF1B2A3D), mine: [Color(0xFF3F6FA3)], other: Color(0xFF2A3D56), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFE6EEF8),
    accent: Color(0xFF9CC0E6), tick: Color(0xFFD3E4F7), metaOther: Color(0xFF9FB3CB), pattern: Color(0xFF9CC0E6), patternOp: 0.09,
    symbols: ['arch', 'crescent', 'star8', 'minaret', 'palm', 'sun'], cover: [Color(0xFF13787A), Color(0xFF25AAA3)]);
const _baghdadLight = ChatTheme(key: 'baghdad', name: 'بغداد العباسية',
    chatBg: Color(0xFFE1EAF4), mine: [Color(0xFF3F6FA3)], other: Color(0xFFF8FBFE), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF1F2F44),
    accent: Color(0xFF3F6FA3), tick: Color(0xFFD3E4F7), metaOther: Color(0xFF5F7490), pattern: Color(0xFF3F6FA3), patternOp: 0.1,
    symbols: ['arch', 'crescent', 'star8', 'minaret', 'palm', 'sun'], cover: [Color(0xFF13787A), Color(0xFF25AAA3)]);
const _ahwarBase = ChatTheme(key: 'ahwar', name: 'الأهوار',
    chatBg: Color(0xFFCFE3D4), mine: [Color(0xFF2B7A8C), Color(0xFF3F9A7A)], other: Color(0xFFF2F8EF), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF1F3A2A),
    accent: Color(0xFF2B6A4A), tick: Color(0xFFD9F5C8), metaOther: Color(0xFF5F7F6A), pattern: Color(0xFF3F6B3A), patternOp: 0.16,
    symbols: ['reeds', 'boat', 'fish', 'wave', 'palm', 'sun'], cover: [Color(0xFF2B7A8C), Color(0xFF3F9A7A)]);
const _ahwarDark = ChatTheme(key: 'ahwar', name: 'الأهوار',
    chatBg: Color(0xFF1D2E26), mine: [Color(0xFF3F8060)], other: Color(0xFF2C4339), textMine: Color(0xFFFFFFFF), textOther: Color(0xFFE5F1EA),
    accent: Color(0xFF9BD0B3), tick: Color(0xFFD2ECDD), metaOther: Color(0xFF9FBCAE), pattern: Color(0xFF9BD0B3), patternOp: 0.09,
    symbols: ['reeds', 'boat', 'fish', 'wave', 'palm', 'sun'], cover: [Color(0xFF2B7A8C), Color(0xFF3F9A7A)]);
const _ahwarLight = ChatTheme(key: 'ahwar', name: 'الأهوار',
    chatBg: Color(0xFFE1EDE5), mine: [Color(0xFF3F8060)], other: Color(0xFFF8FCF9), textMine: Color(0xFFFFFFFF), textOther: Color(0xFF1F3328),
    accent: Color(0xFF3F8060), tick: Color(0xFFD2ECDD), metaOther: Color(0xFF5D7A6A), pattern: Color(0xFF3F8060), patternOp: 0.1,
    symbols: ['reeds', 'boat', 'fish', 'wave', 'palm', 'sun'], cover: [Color(0xFF2B7A8C), Color(0xFF3F9A7A)]);

const chatThemeKeys = ['babylon', 'ashur', 'sumer', 'samarra', 'baghdad', 'ahwar'];

ChatTheme chatThemeFor(String key, bool dark) {
  switch (key) {
    case 'ashur':
      return dark ? _ashurDark : _ashurLight;
    case 'sumer':
      return dark ? _sumerDark : _sumerLight;
    case 'samarra':
      return dark ? _samarraDark : _samarraLight;
    case 'baghdad':
      return dark ? _baghdadDark : _baghdadLight;
    case 'ahwar':
      return dark ? _ahwarDark : _ahwarLight;
    default:
      return _babylonBase;
  }
}

/// الثيم الأساسي (للغلاف والمعاينات)
ChatTheme chatThemeBase(String key) {
  switch (key) {
    case 'ashur':
      return _ashurBase;
    case 'sumer':
      return _sumerBase;
    case 'samarra':
      return _samarraBase;
    case 'baghdad':
      return _baghdadBase;
    case 'ahwar':
      return _ahwarBase;
    default:
      return _babylonBase;
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
  Map<String, int> cleared = {}; // مسح المحادثة محلياً (chatClearedAt)
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
    try {
      final c = jsonDecode(_p.getString('babylon_cleared') ?? '{}') as Map<String, dynamic>;
      cleared = c.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {}
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

  void clearChat(String id) {
    cleared[id] = DateTime.now().millisecondsSinceEpoch;
    _p.setString('babylon_cleared', jsonEncode(cleared));
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
    cleared = {};
    notifyListeners();
  }
}
