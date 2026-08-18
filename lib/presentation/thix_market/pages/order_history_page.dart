// lib/presentation/thix_market/pages/order_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/market_providers.dart';

// ============================================================
// COULEURS
// ============================================================
class _C {
  static const navy = Color(0xFF0A1931);
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const blue = Color(0xFF2D6CDF);
  static const bg = Color(0xFFF7F8FC);
  static const green = Color(0xFF00B074);
  static const muted = Color(0xFF6B7280);
}

// ============================================================
// PROVIDER
// ============================================================
final orderHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  var query = db.from('orders').select('*').eq('user_id', uid);

  if (filter != 'all') {
    query = query.eq('status', filter);
  }

  final res = await query.order('created_at', ascending: false).limit(50);
  final list = List<Map<String, dynamic>>.from(res);
  final full = <Map<String, dynamic>>[];

  for (final o in list) {
    List<dynamic> items = [];
    try {
      items = await db
          .from('order_items')
          .select('*, product:products(title, image_url, currency)')
          .eq('order_id', o['id'])
          .limit(5);
    } catch (_) {
      try {
        items = await db
            .from('order_items')
            .select('*')
            .eq('order_id', o['id'])
            .limit(5);
      } catch (_) {}
    }

    Map<String, dynamic>? shop;
    if (o['shop_id'] != null) {
      try {
        shop = await db
            .from('shops')
            .select('id, name, logo_url, city, is_verified')
            .eq('id', o['shop_id'])
            .maybeSingle();
      } catch (_) {
        try {
          shop = await db
              .from('shops')
              .select('id, name, logo_url, city')
              .eq('id', o['shop_id'])
              .maybeSingle();
        } catch (_) {}
      }
    }

    full.add({
      ...o,
      'items': items,
      'shop': shop,
    });
  }

  return full;
});

// ============================================================
// PAGE
// ============================================================
class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  String _filter = 'all';

  String _cur(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase().trim();
    if (v == 'XOF' || v == 'CDF' || v == 'FCFA' || v == 'FC') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }

  String _money(num amount, String cur) {
    if (cur == '\\( ') return ' \){amount.toStringAsFixed(2)} $cur';
    return '${amount.toInt()} $cur';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered':
        return _C.green;
      case 'cancelled':
        return _C.red;
      case 'shipped':
        return _C.blue;
      case 'confirmed':
      case 'processing':
        return const Color(0xFF8B5CF6);
      default:
        return _C.gold; // pending
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'processing':
        return 'Préparation';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return s;
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _C.red, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Annuler la commande ?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Le stock sera rendu à la boutique.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Garder'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Oui, annuler',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    try {
      final db = ref.read(supabaseClientProvider);
      try {
        await db.rpc('cancel_order', params: {
          'p_order_id': id,
          'p_reason_code': 'client_request',
          'p_reason': 'Client depuis historique',
        });
      } catch (_) {
        await db.from('orders').update({
          'status': 'cancelled',
          'payout_status': 'refunded',
        }).eq('id', id);
      }
      ref.invalidate(orderHistoryProvider(_filter));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderHistoryProvider(_filter));

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _C.navy),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mes commandes',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _C.navy,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(orderHistoryProvider(_filter)),
            icon: const Icon(Icons.refresh_rounded, color: _C.navy),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _C.navy),
              ),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (orders) {
                if (orders.isEmpty) return _empty();
                return RefreshIndicator(
                  color: _C.navy,
                  onRefresh: () async {
                    ref.invalidate(orderHistoryProvider(_filter));
                    await ref.read(orderHistoryProvider(_filter).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _orderCard(orders[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final tabs = [
      {'k': 'all', 'l': 'Tous'},
      {'k': 'pending', 'l': 'En attente'},
      {'k': 'processing', 'l': 'Préparation'},
      {'k': 'shipped', 'l': 'Expédiée'},
      {'k': 'delivered', 'l': 'Livrée'},
      {'k': 'cancelled', 'l': 'Annulée'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: tabs.map((t) {
            final sel = _filter == t['k'];
            return GestureDetector(
              onTap: () => setState(() => _filter = t['k']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _C.navy : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                  border: sel
                      ? null
                      : Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  t['l']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : _C.muted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 56, color: Color(0xFFD1D5DB)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucune commande',
            style: TextStyle(fontWeight: FontWeight.w800, color: _C.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos commandes apparaîtront ici',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'pending').toString();
    final total = ((o['total'] ?? o['total_amount'] ?? 0) as num);
    final cur = _cur(o['currency']);
    final items = List<Map<String, dynamic>>.from(o['items'] ?? []);
    final shop = o['shop'] as Map?;
    final shopName = shop?['name']?.toString() ?? 'Boutique';
    final city = shop?['city']?.toString() ?? '';
    final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
    final color = _statusColor(status);
    final id = o['id']?.toString() ?? '';
    final short =
        id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header boutique + statut
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    image: shop?['logo_url'] != null &&
                            shop!['logo_url'].toString().isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(shop['logo_url'].toString()),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: shop?['logo_url'] == null ||
                          (shop?['logo_url']?.toString().isEmpty ?? true)
                      ? const Icon(Icons.storefront_rounded,
                          size: 18, color: Color(0xFF9CA3AF))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: _C.navy,
                              ),
                            ),
                          ),
                          if (shop?['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 12, color: _C.blue),
                          ],
                        ],
                      ),
                      if (city.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 11, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 2),
                            Text(
                              city,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 22, color: Color(0xFFF3F4F6)),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: items.take(2).map((it) {
                final img = it['product_image'] ??
                    it['product']?['image_url'] ??
                    '';
                final name = it['product_name'] ??
                    it['title_snapshot'] ??
                    it['product']?['title'] ??
                    'Produit';
                final qty = it['quantity'] ?? 1;
                final itemPrice = (it['price'] as num?) ?? 0;
                final itemCur = _cur(
                  it['product']?['currency'] ?? o['currency'],
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: img.toString().isEmpty
                            ? Container(
                                width: 48,
                                height: 48,
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.image_outlined,
                                    size: 18),
                              )
                            : Image.network(
                                img.toString(),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Icon(Icons.image_outlined,
                                      size: 18),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _C.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$qty x ${_money(itemPrice, itemCur)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _C.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          if (items.length > 2)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+ ${items.length - 2} article(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Footer
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null
                          ? DateFormat('dd/MM/yyyy').format(date)
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$short',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.navy,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                    Text(
                      _money(total, cur),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _C.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (status == 'pending' || status == 'confirmed')
                  InkWell(
                    onTap: () => _cancel(id),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD0D0)),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _C.red,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => context.pushNamed(
                      'marketOrderDetail',
                      pathParameters: {'orderId': id},
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Détails',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
