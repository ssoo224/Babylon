import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class TgsGift extends StatefulWidget {
  final String url;
  final double size;
  const TgsGift({super.key, required this.url, this.size = 100});

  @override
  State<TgsGift> createState() => _TgsGiftState();
}

class _TgsGiftState extends State<TgsGift> {
  String? _jsonData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTgs();
  }

  Future<void> _loadTgs() async {
    try {
      // 1. تحميل الملف من CDN
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode == 200) {
        // 2. فك ضغط GZIP (لأن ملفات TGS مضغوطة)
        final decompressed = gzip.decode(res.bodyBytes);
        // 3. تحويله لنص JSON
        final jsonStr = utf8.decode(decompressed);
        
        if (mounted) {
          setState(() {
            _jsonData = jsonStr;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading TGS: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    
    // إذا فشل التحميل نعرض أيقونة هدية كاحتياط
    if (_jsonData == null) {
      return Icon(Icons.card_giftcard, size: widget.size * 0.5, color: Colors.grey);
    }

    // تشغيل الأنميشن من الذاكرة
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.memory(
        utf8.encode(_jsonData!),
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}
