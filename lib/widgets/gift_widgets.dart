import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/utils.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/gift_service.dart';


typedef Json = Map<String, dynamic>;

class GiftGrid extends StatelessWidget {
  final String uid;
  final String kind; // pepe, cat, gift
  const GiftGrid({super.key, required this.uid, required this.kind});

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
                      // 🌟 هنا نضع الأنميشن الحقيقي Lottie
                      // كمثال، سنستخدم أيقونة مؤقتة
                      child: Icon(Icons.card_giftcard, size: 40, color: p.gold),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Text('#$number', style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          // الأنميشن
          Expanded(
            flex: 3,
            child: Center(
              // 🌟 هنا يوضع الأنميشن
              child: Icon(Icons.card_giftcard, size: 120, color: p.gold),
            ),
          ),
          // التفاصيل
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text('الهدية #${gift['number']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('النموذج: ${gift['model'] ?? 'غير مرقى'}', style: TextStyle(fontSize: 16, color: p.muted)),
                const SizedBox(height: 20),
                // الأزرار
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // كود الترقية
                            try {
                              Navigator.pop(context);
                              toast(context, 'جاري الترقية...');
                              final res = await context.read<GiftService>().upgradeGift(kind, gift['number']);
                              toast(context, 'تمت الترقية إلى النموذج ${res['model']}');
                            } catch (e) {
                              toast(context, 'تعذرت الترقية');
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: p.gold, foregroundColor: Colors.black),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('ترقية'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final auth = context.read<AuthService>();
                            final pinned = gift['pinned'] == true;
                            await context.read<GiftService>().togglePinGift(auth.uid, kind, gift['id'], !pinned);
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.dark ? Colors.white12 : Colors.black12, 
                            foregroundColor: p.text
                          ),
                          icon: const Icon(Icons.push_pin),
                          label: Text(gift['pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
