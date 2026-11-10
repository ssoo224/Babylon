import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';

enum UpStatus { idle, downloading, installing, needPermission, error }

/// بوابة التحديث (نفس منطق update-gate.js الأصلي):
/// version.json => minVersion (إجباري) / latest (اختياري) + تنزيل وتثبيت داخل التطبيق
class UpdateController extends ChangeNotifier with WidgetsBindingObserver {
  int cur = 0, min = 0, latest = 0;
  String curName = '', notes = '', urlPath = '/api/apk';
  bool dismissed = false;
  bool promptShown = false;

  UpStatus status = UpStatus.idle;
  double progress = 0;
  int gotBytes = 0, totalBytes = 0;
  String message = '';

  String? _apkPath;
  DateTime? _lastCheck;

  UpdateController() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  /// رقم النسخة مجهول (0): لا نحظر أحداً
  bool get forced => cur > 0 && cur < min;
  bool get optional => cur > 0 && cur < latest && !forced && !dismissed;
  int get target => latest > min ? latest : min;

  String get apkUrl {
    final u = urlPath.trim();
    if (u.startsWith('/')) return '${BabylonApi.base}$u';
    if (u.startsWith(BabylonApi.base)) return u;
    return '${BabylonApi.base}/api/apk'; // رابط خارجي غير مسموح
  }

  Future<void> _init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      cur = int.tryParse(info.buildNumber) ?? 0;
      curName = info.version;
    } catch (_) {}
    // من آخر قيمة محفوظة فوراً (حتى بدون إنترنت)
    try {
      final p = await SharedPreferences.getInstance();
      min = p.getInt('upd_min') ?? 0;
      latest = p.getInt('upd_latest') ?? 0;
      notes = p.getString('upd_notes') ?? '';
      urlPath = p.getString('upd_url') ?? '/api/apk';
    } catch (_) {}
    notifyListeners();
    check();
  }

  Future<void> check() async {
    _lastCheck = DateTime.now();
    try {
      final r = await http
          .get(Uri.parse('${BabylonApi.base}/version.json?t=${DateTime.now().millisecondsSinceEpoch}'),
              headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      min = (j['minVersion'] as num?)?.toInt() ?? 0;
      latest = (j['latest'] as num?)?.toInt() ?? 0;
      notes = (j['notes'] as String?) ?? '';
      urlPath = (j['url'] as String?) ?? '/api/apk';
      final p = await SharedPreferences.getInstance();
      await p.setInt('upd_min', min);
      await p.setInt('upd_latest', latest);
      await p.setString('upd_notes', notes);
      await p.setString('upd_url', urlPath);
      notifyListeners();
    } catch (_) {}
  }

  void later() {
    dismissed = true;
    notifyListeners();
  }

  void _fail(String msg) {
    status = UpStatus.error;
    message = msg;
    notifyListeners();
  }

  Future<bool> _looksLikeApk(File f) async {
    try {
      final raf = await f.open();
      final head = await raf.read(4);
      await raf.close();
      return head.length == 4 && head[0] == 0x50 && head[1] == 0x4B; // 'PK' (zip/apk)
    } catch (_) {
      return false;
    }
  }

  /// تنزيل الملف من موقعنا (/api/apk) مع حلقة تقدم، ثم فتح شاشة التثبيت
  Future<void> startUpdate() async {
    if (status == UpStatus.downloading) return;
    status = UpStatus.downloading;
    progress = 0;
    gotBytes = 0;
    totalBytes = 0;
    message = '';
    notifyListeners();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(apkUrl))
        ..headers['Accept'] = 'application/octet-stream';
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode == 502 || res.statusCode == 503) {
        return _fail('السيرفر ما قدر يجيب الملف حالياً (جرّب بعد دقيقة).');
      }
      if (res.statusCode != 200) return _fail('رابط التنزيل غير متاح.');

      totalBytes = res.contentLength ?? int.tryParse(res.headers['x-apk-size'] ?? '') ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/babylon-chat.apk');
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();
      var lastPct = -1;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 40))) {
        sink.add(chunk);
        gotBytes += chunk.length;
        progress = totalBytes > 0 ? (gotBytes / totalBytes).clamp(0.0, 1.0) : 0;
        final pct = (progress * 100).floor();
        if (pct != lastPct) {
          lastPct = pct;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();

      if (totalBytes > 0 && gotBytes < totalBytes) {
        return _fail('انقطع التنزيل قبل ما يكتمل، جرّب مرة ثانية.');
      }
      if (gotBytes < 1024 * 1024 || !await _looksLikeApk(file)) {
        return _fail('الملف اللي نزل مو سليم.');
      }
      _apkPath = file.path;
      await _install();
    } on SocketException {
      _fail('مشكلة بالاتصال بالإنترنت أثناء التنزيل.');
    } on TimeoutException {
      _fail('انقطع التنزيل قبل ما يكتمل، جرّب مرة ثانية.');
    } on HttpException {
      _fail('مشكلة بالاتصال بالإنترنت أثناء التنزيل.');
    } catch (_) {
      _fail('تعذر التنزيل داخل التطبيق. انسخ الرابط وافتحه بكروم.');
    } finally {
      client.close();
    }
  }

  Future<void> install() async {
    if (_apkPath == null || !File(_apkPath!).existsSync()) return startUpdate();
    await _install();
  }

  Future<void> _install() async {
    final path = _apkPath;
    if (path == null) return;
    status = UpStatus.installing;
    message = 'اكتمل التنزيل. اضغط تثبيت بالنافذة اللي طلعت، وبعدها افتح التطبيق.';
    notifyListeners();
    try {
      final r = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (r.type == ResultType.permissionDenied) {
        status = UpStatus.needPermission;
        message =
            'فعّل خيار (السماح بالتثبيت من هذا المصدر) لبابل ثم ارجع للتطبيق، وسيبدأ التثبيت تلقائياً.';
        notifyListeners();
      } else if (r.type != ResultType.done) {
        _fail('ما قدر يفتح شاشة التثبيت.');
      }
    } catch (_) {
      _fail('ما قدر يفتح شاشة التثبيت.');
    }
  }

  Future<void> copyLink() => Clipboard.setData(ClipboardData(text: apkUrl));

  Future<void> openInBrowser() async {
    try {
      await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    // رجع من إعدادات السماح بالتثبيت => كمّل التثبيت تلقائياً
    if (status == UpStatus.needPermission && _apkPath != null) {
      _install();
      return;
    }
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last).inSeconds > 60) check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
