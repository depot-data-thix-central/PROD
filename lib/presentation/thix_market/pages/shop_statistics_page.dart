import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/market_providers.dart';

const navyDeep = Color(0xFF0A1F44);
const gold = Color(0xFFE3B23C);
const bg = Color(0xFFF6F7FB);
const white = Colors.white;
const hair = Color(0xFFE7EAF3);
const muted = Color(0xFF8A8FA3);

final shopStatsProvider = FutureProvider.family<Map<String,dynamic>, String>((ref, shopId) async {
  final db = ref.read(supabaseClientProvider);
  final prod = await db.from('products').select('id').eq('shop_id', shopId);
  final followers = await db.from('shop_followers').select('id').eq('shop_id', shopId).count();
  final orders = await db.from('order_items').select('id').eq('shop_id', shopId).count().catchError((e)=> const CountResult(0));
  return {'products': (prod as List).length, 'followers': followers.count, 'orders': orders.count};
});

class ShopStatisticsPage extends ConsumerWidget {
  final String shopId;
  const ShopStatisticsPage({super.key, required this.shopId});
  @override Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(shopStatsProvider(shopId));
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Statistiques', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: navyDeep, foregroundColor: Colors.white, centerTitle: true),
      body: async.when(
        loading: ()=> const Center(child: CircularProgressIndicator(color: gold)),
        error: (e,_ )=> Center(child: Text('Erreur $e')),
        data: (s)=> GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _card('Produits', '${s['products']}', Icons.inventory_2_rounded),
            _card('Abonnés', '${s['followers']}', Icons.favorite_rounded),
            _card('Commandes', '${s['orders']}', Icons.receipt_long_rounded),
            _card('Note', '4.8 ★', Icons.star_rounded),
          ],
        ),
      ),
    );
  }
  Widget _card(String label, String value, IconData icon){
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(16), border: Border.all(color: hair)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: navyDeep)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      ]),
    );
  }
}

class CountResult { final int count; const CountResult(this.count); }
