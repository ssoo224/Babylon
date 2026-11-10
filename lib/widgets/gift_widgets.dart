import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart' show Json;
import '../services/gift_service.dart';
import 'tgs_gift.dart'; // 🌟 استدعاء ويدجت الأنميشن

class GiftGrid extends StatelessWidget {
  final String uid;
  final String kind; // pepe, cat, gift
  const GiftGrid({super.key, required this.uid, required this.kind});

  // دالة مساعدة لتوليد رابط الأنميشن من سيرفرات تليجرام
  String _getTgsUrl(String kind, Map<String, dynamic>? gift) {
    String folder = 'Plush Pepe';
    if (kind == 'cat') folder = 'Scared Cat';
    if (kind == 'gift') return ''; // نتركه فارغاً للهدايا الأخرى

    // إذا كانت الهدية مرقاة ولها موديل، نجيب اسم الموديل، وإلا نجيب original
    // ملاحظة: هنا نحتاج جدول ربط أسماء الموديلات، حالياً نستخدم original كبداية
    final isUpgraded = gift?['upgraded'] == true;
    
    // رابط افتراضي (سيتم تطويره لاحقاً ليجلب الموديل الحقيقي)
    return 'https://cdn.changes.tg/gifts/models/${Uri.encodeComponent(folder)}/original.tgs';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<GiftService>();
    final p = BP.of(context);

    return StreamBuilder<List<Json>>(
      stream: svc.getUserGiftsStream(uid, kind),
      builder: (context, snap) {
        final gifts = snap.data ?? [];
        if (gifts.isEmpty) return const SizedBox.shrink();

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: gifts.length,
          itemBuilder: (context, i) {
            final g = gifts[i];
            final number = g['number'] as int? ?? 1;
            final pinned = g['pinned'] == true;
            final url = _getTgsUrl(kind, g);

            return GestureDetector(
              onTap: () => showGiftDetails(context, g, kind),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Stack(
                  children: [
                    Center(
                      // 🌟 عرض الأنميشن الحقيقي
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: url.isNotEmpty 
                          ? TgsGift(url: url, size: 60)
                          : Icon(Icons.card_giftcard, size: 40, color: p.gold),
                      ),
                    ),
                    // رقم الهدية
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Text(
                        '#$number', 
                        style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                    ),
                    // علامة التثبيت
                    if (pinned)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Icon(Icons.push_pin, size: 14, color: p.gold),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =================== شاشة تفاصيل الهدية (Bottom Sheet) ===================
void showGiftDetails(BuildContext context, Json gift, String kind) {
  final p = BP.of(context);
  final svc = context.read<GiftService>();
  final auth = context.read<AuthService>();
  
  // توليد الرابط للشاشة الكبيرة
  String folder = 'Plush Pepe';
  if (kind == 'cat') folder = 'Scared Cat';
  final url = 'https://cdn.changes.tg/gifts/models/${Uri.encodeComponent(folder)}/original.tgs';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // شريط السحب
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
          ),
          
          // الأنميشن الكبير
          Expanded(
            flex: 4,
            child: Center(
              child: TgsGift(url: url, size: 180), // حجم كبير
            ),
          ),
          
          // التفاصيل والأزرار
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  'الهدية #${gift['number']}', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                Text(
                  'النموذج: ${gift['model'] ?? 'الأصلي (غير مرقى)'}', 
                  style: TextStyle(fontSize: 16, color: p.muted)
                ),
                
                const SizedBox(height: 24),
                
                // الأزرار
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // زر الترقية (يظهر فقط إذا لم تكن مرقاة)
                      if (gift['upgraded'] != true)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                Navigator.pop(context);
                                toast(context, 'جاري الترقية...');
                                final res = await svc.upgradeGift(kind, gift['number']);
                                toast(context, 'تمت الترقية إلى النموذج ${res['model']}');
                              } catch (e) {
                                toast(context, 'تعذرت الترقية');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.gold, 
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('ترقية', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (gift['upgraded'] != true) const SizedBox(width: 12),
                      
                      // زر التثبيت
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pinned = gift['pinned'] == true;
                            await svc.togglePinGift(auth.uid, kind, gift['id'], !pinned);
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.dark ? Colors.white12 : Colors.black12, 
                            foregroundColor: p.text,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: Icon(gift['pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined),
                          label: Text(
                            gift['pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت', 
                            style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
