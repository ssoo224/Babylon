import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';

const _errs = {
  'forbidden': 'هذا الخيار للمطوّر فقط',
  'rate': 'انتظر قليلاً قبل المحاولة مرة ثانية',
  'empty': 'اكتب العنوان والنص',
  'auth': 'سجّل دخول من جديد',
  'unverified': 'البريد غير مؤكد',
  'origin': 'طلب مرفوض',
  'server': 'خطأ بالسيرفر، حاول بعد شوي',
};

/// لوحة المطوّر (dev-panel.js): إحصائيات + إذاعة إشعار لكل المستخدمين (بتأكيد مرتين)
class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});
  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _armed = false;
  bool _sending = false;
  Timer? _armT;
  String? _msg;
  bool _msgOk = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _armT?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _api(String op, [Map<String, dynamic>? data]) async {
    final u = context.read<AuthService>().user;
    if (u == null) throw 'auth';
    final r = await BabylonApi.post('/api/broadcast', {'op': op, ...?data}, user: u);
    if (r.status < 200 || r.status >= 300) throw (r.data['error'] as String?) ?? 'server';
    return r.data;
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final r = await _api('stats');
      if (mounted) setState(() => _stats = r);
    } catch (e) {
      if (mounted) _show(false, _errs[e] ?? _errs['server']!);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _show(bool ok, String t) => setState(() {
        _msg = t;
        _msgOk = ok;
      });

  void _disarm() {
    _armT?.cancel();
    if (mounted) setState(() => _armed = false);
  }

  Future<void> _send() async {
    final t = _title.text.trim(), b = _body.text.trim();
    if (t.isEmpty || b.isEmpty) return _show(false, _errs['empty']!);
    if (!_armed) {
      setState(() => _armed = true);
      _armT = Timer(const Duration(seconds: 5), _disarm);
      return;
    }
    _disarm();
    setState(() => _sending = true);
    try {
      final r = await _api('send', {'title': t, 'body': b});
      final nf = NumberFormat('#,###');
      _show(
          true,
          'تم الإرسال · وصل لـ ${nf.format(r['sent'] ?? 0)} جهاز من ${nf.format(r['devices'] ?? 0)}'
          '${(r['failed'] ?? 0) > 0 ? ' (فشل ${nf.format(r['failed'])})' : ''}'
          '${(r['cleaned'] ?? 0) > 0 ? ' · تنظيف ${nf.format(r['cleaned'])} توكن ميت' : ''}');
      _title.clear();
      _body.clear();
      _loadStats();
    } catch (e) {
      _show(false, _errs[e] ?? _errs['server']!);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = BP.of(context);
    final nf = NumberFormat('#,###');
    final s = _stats ?? {};
    final last = ((s['last'] as List?) ?? []).whereType<Map>().toList();

    Widget statCard(String n, String label) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.dark ? const Color(0x17FFFFFF) : p.border),
            ),
            child: Column(children: [
              Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.gold)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.muted)),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: Text('لوحة المطوّر', style: TextStyle(color: p.gold, fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.dark ? const Color(0x17FFFFFF) : p.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Row(children: [
                Icon(Icons.insights, size: 18, color: p.gold),
                const SizedBox(width: 8),
                Text('إحصائيات المستخدمين',
                    style: TextStyle(color: p.gold, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(
                    visualDensity: VisualDensity.compact, icon: const Icon(Icons.refresh, size: 20), onPressed: _loadStats),
              ]),
            ),
            Row(children: [
              statCard(nf.format(s['total'] ?? 0), 'المستخدمين الكليين'),
              statCard(nf.format(s['day'] ?? 0), 'النشطين آخر 24 ساعة'),
              statCard(nf.format(s['online'] ?? 0), 'النشطين الآن'),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
          child: Text('إشعار للهاتف لكل المستخدمين',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.muted)),
        ),
        TextField(controller: _title, maxLength: 60, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'العنوان', counterText: '')),
        const SizedBox(height: 10),
        TextField(
            controller: _body,
            maxLength: 300,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'نص الإشعار', counterText: '')),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text('${_title.text.length}/60  ·  ${_body.text.length}/300',
              style: TextStyle(fontSize: 11, color: p.muted)),
        ),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: _armed ? const Color(0xFFEF4444) : p.gold,
              foregroundColor: Colors.white,
            ),
            child: Text(_sending
                ? 'جاري الإرسال...'
                : (_armed ? 'اضغط مرة ثانية لتأكيد الإرسال لكل المستخدمين' : 'إرسال للكل')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
              'يوصل لكل الأجهزة المسجلة للإشعارات. من فتح التطبيق وقت الإرسال ممكن ما يطلعله إشعار بالشريط.',
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.6)),
        ),
        if (_msg != null)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: (_msgOk ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_msg!, style: TextStyle(color: _msgOk ? const Color(0xFF4ADE80) : const Color(0xFFF87171), fontSize: 13.5)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text('إحصائيات الإرسال', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.muted)),
        ),
        if (last.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(_loading ? 'جاري التحميل...' : 'ما اكو إرسال سابق.', style: TextStyle(fontSize: 12.5, color: p.muted))),
          )
        else
          for (final r in last)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.dark ? const Color(0x17FFFFFF) : p.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('d/M/yyyy h:mm a', 'ar').format(DateTime.fromMillisecondsSinceEpoch(((r['at'] ?? 0) as num).toInt())),
                      style: TextStyle(fontSize: 11, color: p.muted),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: ((r['devices'] ?? 0) as num) == 0 ? 0 : (((r['sent'] ?? 0) as num) / ((r['devices'] ?? 1) as num)).clamp(0.0, 1.0).toDouble(),
                        color: p.gold,
                        backgroundColor: p.dark ? const Color(0x0FFFFFFF) : const Color(0x0D16202B),
                      ),
                    ),
                  ]),
                ),
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 12),
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: p.border))),
                  child: Column(children: [
                    Text(nf.format(r['sent'] ?? 0), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.gold)),
                    Text('من ${nf.format(r['devices'] ?? 0)}', style: TextStyle(fontSize: 11, color: p.muted)),
                    if (((r['failed'] ?? 0) as num) > 0)
                      Text('فشل ${nf.format(r['failed'])}', style: const TextStyle(fontSize: 11, color: Color(0xFFF87171))),
                  ]),
                ),
              ]),
            ),
      ]),
    );
  }
}
