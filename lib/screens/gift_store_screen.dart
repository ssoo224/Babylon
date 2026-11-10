import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../widgets/tgs_gift.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/gift_service.dart';

class GiftStoreScreen extends StatefulWidget {
  const GiftStoreScreen({super.key});

  @override
  State<GiftStoreScreen> createState() => _GiftStoreScreenState();
}

class _GiftStoreScreenState extends State<GiftStoreScreen> {
  final _giftSvc = GiftService();
  bool _loading = true;
  List<Map<String, dynamic>> _catalog = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final items = await _giftSvc.getCatalog();
      if (mounted) setState(() { _catalog = items; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); toast(context, 'تعذر تحميل المتجر'); }
    }
  }

  Future<void> _buy(String kind, int price) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('شراء هدية'),
        content: Text('هل تريد شراء هذه الهدية بـ $price نجمة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('شراء')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (mounted) toast(context, 'جاري الشراء...');
      final number = await _giftSvc.buyGift(kind);
      if (mounted) toast(context, 'مبروك! حصلت على الهدية رقم #$number');
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final p = BP.of(context);

    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(
        title: const Text('متجر الهدايا'),
        actions: [
          StreamBuilder<int>(
            stream: _giftSvc.getWallet(auth.uid),
            builder: (context, snap) {
              final stars = snap.data ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Icon(Icons.star, color: p.gold, size: 20),
                  const SizedBox(width: 4),
                  Text('$stars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: p.gold)),
                ]),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _catalog.isEmpty
              ? const Center(child: Text('لا توجد هدايا متاحة حالياً'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _catalog.length,
                  itemBuilder: (context, index) {
                    final item = _catalog[index];
                    final kind = item['id'];
                    final name = item['name'] ?? 'هدية';
                    final price = (item['price'] as num?)?.toInt() ?? 0;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: p.gold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.card_giftcard, size: 40, color: p.gold),
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: p.gold, size: 16),
                              const SizedBox(width: 4),
                              Text('$price', style: TextStyle(color: p.muted, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _buy(kind, price),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('شراء'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
