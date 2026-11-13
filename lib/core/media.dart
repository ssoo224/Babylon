import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../widgets/media_picker.dart';

/// صورة واحدة من منتقي بابيلون الداخلي (مثل تليجرام)
Future<XFile?> pickImageInApp(BuildContext context) async {
  final r = await showMediaPicker(context, allowVideo: false, max: 1);
  return (r == null || r.isEmpty) ? null : r.first;
}

/// فيديو واحد (بحد أقصى مدة بالثواني)
Future<XFile?> pickVideoInApp(BuildContext context, {int maxSeconds = 0}) async {
  final r = await showMediaPicker(context, videoOnly: true, max: 1, maxVideoSeconds: maxSeconds);
  return (r == null || r.isEmpty) ? null : r.first;
}

/// تصغير وضغط الصورة قبل تخزينها كنص base64 (حد Firestore 1MB)
Future<Uint8List> compressImage(XFile x, int maxSide, int quality) async {
  final bytes = await x.readAsBytes();
  try {
    final im = img.decodeImage(bytes);
    if (im == null) return bytes;
    final big = im.width > im.height ? im.width : im.height;
    final r = big > maxSide
        ? img.copyResize(im,
            width: im.width >= im.height ? maxSide : null,
            height: im.height > im.width ? maxSide : null,
            interpolation: img.Interpolation.average)
        : im;
    return Uint8List.fromList(img.encodeJpg(r, quality: quality));
  } catch (_) {
    return bytes;
  }
}
