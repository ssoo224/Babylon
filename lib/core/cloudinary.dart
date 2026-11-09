import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// رفع الوسائط على Cloudinary بنفس إعدادات الأصل (unsigned preset)
class Cloudinary {
  static const cloud = 'xuljmnmh';
  static const preset = 'stories_unsigned';

  static Future<String?> upload(File file, {required bool video, String folder = 'chat'}) async {
    final kind = video ? 'video' : 'image';
    final req = http.MultipartRequest(
        'POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloud/$kind/upload'))
      ..fields['upload_preset'] = preset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final res = await req.send().timeout(const Duration(minutes: 3));
    final body = await res.stream.bytesToString();
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['secure_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// صورة مصغّرة لأول إطار من الفيديو (نفس أسلوب Cloudinary)
  static String posterOf(String videoUrl) => videoUrl
      .replaceFirst('/video/upload/', '/video/upload/so_0,w_480,c_limit,q_auto/')
      .replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '.jpg');
}
