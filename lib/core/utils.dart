import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

/// نفس صيغة الويب: [uid1, uid2].sort().join('__')
String pairChatId(String a, String b) => ([a, b]..sort()).join('__');

final Map<String, Uint8List> _dataCache = {};

/// الصور في بابيلون تُخزَّن إما رابط https أو data:image/...;base64
ImageProvider? imageFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final bytes = _dataCache.putIfAbsent(url, () {
      if (_dataCache.length > 80) _dataCache.remove(_dataCache.keys.first);
      return base64Decode(url.substring(url.indexOf(',') + 1));
    });
    return MemoryImage(bytes);
  }
  return NetworkImage(url);
}

Uint8List? bytesFromDataUrl(String url) {
  if (!url.startsWith('data:')) return null;
  return base64Decode(url.substring(url.indexOf(',') + 1));
}

String toDataUrl(Uint8List bytes, {String mime = 'image/jpeg'}) =>
    'data:$mime;base64,${base64Encode(bytes)}';

String formatTime(int ms) =>
    DateFormat('h:mm a', 'ar').format(DateTime.fromMillisecondsSinceEpoch(ms));

String formatChatTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return formatTime(ms);
  }
  if (now.difference(d).inDays < 7) return DateFormat('EEEE', 'ar').format(d);
  return DateFormat('d/M/yyyy').format(d);
}

String formatLastSeen(Map<String, dynamic> u) {
  final ls = (u['lastSeen'] as num?)?.toInt();
  if (u['online'] == true &&
      ls != null &&
      DateTime.now().millisecondsSinceEpoch - ls < 60000) {
    return 'متصل الآن';
  }
  if (ls == null) return 'غير متصل';
  return 'آخر ظهور ${formatChatTime(ls)}';
}

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

bool isValidUsername(String u) => RegExp(r'^[a-z][a-z0-9_.]{4,}$').hasMatch(u);

/// خصوصية الأصل: hideAvatar / hideLastSeen على مستند المستخدم
String? avatarOf(Map<String, dynamic>? u) =>
    (u == null || u['hideAvatar'] == true) ? null : u['avatarUrl'] as String?;

bool isOnline(Map<String, dynamic> u) {
  if (u['hideLastSeen'] == true) return false;
  final ls = (u['lastSeen'] as num?)?.toInt();
  return u['online'] == true &&
      ls != null &&
      DateTime.now().millisecondsSinceEpoch - ls < 60000;
}

String statusOf(Map<String, dynamic> u) {
  if (u['hideLastSeen'] == true) return 'آخر ظهور منذ فترة';
  return formatLastSeen(u);
}
