// lib/presentation/thix_market/pages/order_history_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kTimeout = Duration(seconds: 15);
const int _kOrderLimit = 50;

class _OrderValidators {
  _OrderValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String money(num amount, String cur) {
    if (cur == '\$') return '\$${amount.toStringAsFixed(2)}';
    return '${amount.toInt()} $cur';
  }

  static String currency(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase().trim();
    if (v == 'XOF' || v == 'CDF' || v == 'FCFA' || v == 'FC') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }
}

// ============================================================================
// PROVIDER — BATCH QUERIES (3 requêtes au lieu de 100+)
// ============================================================================
final orderHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  debugPrint('[Orders] 📦 Loading orders (filter=$filter)');

  var query = db.from('orders').select('*').eq('user_id', uid);
  if (filter != 'all') query = query.eq('status', filter);

  final res = await query
      .order('created_at', ascending: false)
      .limit(_kOrderLimit)
      .timeout(_kTimeout);

  final list = List<Map<String, dynamic>>.from(res);
  if (list.isEmpty) return [];

  final orderIds = list.map((o) => o['id'].toString()).toList();
  final shopIds = list
      .map((o) => o['shop_id']?.toString())
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  // ✅ BATCH : items + shops en parallèle (2 requêtes au lieu de 2×N)
  final itemsFuture = db
      .from('order_items')
      .select('*, product:products(title, image_url, currency)')
      .inFilter('order_id', orderIds)
      .timeout(_kTimeout)
      .then((r) => List<Map<String, dynamic>>.from(r))
      .catchError((_) => <Map<String, dynamic>>[]);

  final shopsFuture = shopIds.isEmpty
      ? Future.value(<Map<String, dynamic>>[])
      : db
          .from('shops')
          .select('id, name, logo_url, city, is_verified')
          .inFilter('id', shopIds)
          .timeout(_kTimeout)
          .then((r) => List<Map<String, dynamic>>.from(r))
          .catchError((_) => <Map<String, dynamic>>[]);

  final results = await Future.wait([itemsFuture, shopsFuture]);

  final itemsByOrder = <String, List<Map<String, dynamic>>>{};
  for (final it in results[0]) {
    final oid = it['order_id']?.toString() ?? '';
    itemsByOrder.putIfAbsent(oid, () => []).add(it);
  }
  final shopById = <String, Map<String, dynamic>>{
    for (final s in results[1]) s['id'].toString(): s,
  };

  debugPrint('[Orders] ✓ Loaded ${list.length} orders (2 batch queries)');

  return list
      .map((o) => {
            ...o,
            'items': itemsByOrder[o['id'].toString()] ?? [],
            'shop': shopById[o['shop_id']?.toString() ?? ''],
          })
      .toList();
});

// ============================================================================
// PAGE
// ============================================================================
class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});
  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  String _filter = 'all';

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return ThixPolicy.success;
      case 'cancelled': return ThixPolicy.danger;
      case 'shipped': return ThixPolicy.primary;
      case 'confirmed':
      case 'processing': return ThixPolicy.domainMedia;
      default: return ThixPolicy.gold;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'processing': return 'Préparation';
      case 'shipped': return 'Expédiée';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      case 'refund_requested': return 'Remboursement';
      default: return s;
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 32),
              ),
              const SizedBox(height: 14),
              Text('Annuler la commande ?', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Le stock sera rendu à la boutique.', textAlign: TextAlign.center, style: ThixPolicy.bodySmallStyle),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Garder'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Oui, annuler', style: TextStyle(fontWeight: FontWeight.w800)),
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
    HapticFeedback.mediumImpact();

    try {
      final db = ref.read(supabaseClientProvider);
      try {
        await db.rpc('cancel_order', params: {
          'p_order_id': id,
          'p_reason_code': 'client_request',
          'p_reason': 'Client depuis historique',
        }).timeout(_kTimeout);
      } catch (_) {
        await db.from('orders').update({
          'status': 'cancelled',
          'payout_status': 'refunded',
        }).eq('id', id).timeout(_kTimeout);
      }
      ref.invalidate(orderHistoryProvider(_filter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande annulée'), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating),
        );
      }
      debugPrint('[Orders] ✓ Cancelled $id');
    } catch (e) {
      debugPrint('[Orders] ❌ Cancel error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderHistoryProvider(_filter));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ThixPolicy.textMain),
          onPressed: () { HapticFeedback.selectionClick(); context.pop(); },
        ),
        title: Text('Mes commandes', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w900, color: ThixPolicy.textMain, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () { HapticFeedback.selectionClick(); ref.invalidate(orderHistoryProvider(_filter)); },
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: async.when(
              loading: () => _skeleton(),
              error: (e, _) => _errorState(e),
              data: (orders) {
                if (orders.isEmpty) return _empty();
                return RefreshIndicator(
                  color: ThixPolicy.primary,
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
      color: ThixPolicy.card,
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: tabs.map((t) {
            final sel = _filter == t['k'];
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _filter = t['k']!); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? ThixPolicy.inkDeep : ThixPolicy.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: sel ? null : Border.all(color: ThixPolicy.border),
                ),
                child: Text(
                  t['l']!,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : ThixPolicy.textSecondary),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Row(children: [
              Container(width: 36, height: 36, color: Colors.grey.shade200),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Container(width: 48, height: 48, color: Colors.grey.shade200),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
            ]),
            const SizedBox(height: 12),
            Container(height: 50, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _errorState(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Vérifiez votre connexion puis réessayez.', style: ThixPolicy.bodySmallStyle),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(orderHistoryProvider(_filter)),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull))),
            ),
          ],
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
            decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, boxShadow: ThixPolicy.shadowSoft()),
            child: const Icon(Icons.receipt_long_rounded, size: 56, color: ThixPolicy.textDisabled),
          ),
          const SizedBox(height: 14),
          Text('Aucune commande', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
          const SizedBox(height: 6),
          Text('Vos commandes apparaîtront ici', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/market'),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull))),
            child: const Text('Découvrir la boutique'),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'pending').toString();
    final total = ((o['total'] ?? o['total_amount'] ?? 0) as num);
    final cur = _OrderValidators.currency(o['currency']);
    final items = List<Map<String, dynamic>>.from(o['items'] ?? []);
    final shop = o['shop'] as Map?;
    final shopName = _OrderValidators.sanitize(shop?['name']?.toString() ?? 'Boutique', maxLength: 60);
    final city = _OrderValidators.sanitize(shop?['city']?.toString(), maxLength: 40);
    final logoUrl = _OrderValidators.sanitizeUrl(shop?['logo_url']?.toString());
    final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
    final color = _statusColor(status);
    final id = o['id']?.toString() ?? '';
    final short = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    final canCancel = status == 'pending' || status == 'confirmed';

    return Semantics(
      label: 'Commande $short, ${_statusLabel(status)}, total ${_OrderValidators.money(total, cur)}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
        ),
        child: Column(
          children: [
            // Header boutique + statut
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(10),
                      image: logoUrl != null ? DecorationImage(image: CachedNetworkImageProvider(logoUrl), fit: BoxFit.cover) : null,
                    ),
                    child: logoUrl == null ? const Icon(Icons.storefront_rounded, size: 18, color: ThixPolicy.textMuted) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 12.5, color: ThixPolicy.textMain))),
                            if (shop?['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 12, color: ThixPolicy.primary),
                            ],
                          ],
                        ),
                        if (city.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 11, color: ThixPolicy.textMuted),
                              const SizedBox(width: 2),
                              Text(city, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Divider(height: 22, color: ThixPolicy.surface)),

            // Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: items.take(2).map((it) {
                  final img = _OrderValidators.sanitizeUrl(
                    (it['product_image'] ?? it['product']?['image_url'] ?? '').toString(),
                  );
                  final name = _OrderValidators.sanitize(
                    (it['product_name'] ?? it['title_snapshot'] ?? it['product']?['title'] ?? 'Produit').toString(),
                    maxLength: 80,
                  );
                  final qty = it['quantity'] ?? 1;
                  final itemPrice = (it['price'] as num?) ?? 0;
                  final itemCur = _OrderValidators.currency(it['product']?['currency'] ?? o['currency']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: img == null
                              ? Container(width: 48, height: 48, color: ThixPolicy.surface, child: const Icon(Icons.image_outlined, size: 18, color: ThixPolicy.textMuted))
                              : CachedNetworkImage(imageUrl: img, width: 48, height: 48, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: ThixPolicy.surface, child: const Icon(Icons.image_outlined, size: 18, color: ThixPolicy.textMuted))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMain)),
                              const SizedBox(height: 2),
                              Text('$qty x ${_OrderValidators.money(itemPrice, itemCur)}', style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, color: ThixPolicy.textSecondary)),
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
                  child: Text('+ ${items.length - 2} article(s)', style: ThixPolicy.captionStyle.copyWith(fontStyle: FontStyle.italic, color: ThixPolicy.textMuted)),
                ),
              ),

            // Footer
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted)),
                      const SizedBox(height: 2),
                      Text('#$short', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted)),
                      Text(_OrderValidators.money(total, cur), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // ✅ BOUTONS : Annuler (si possible) + Détails (toujours)
                  if (canCancel)
                    InkWell(
                      onTap: () => _cancel(id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThixPolicy.danger.withOpacity(0.3))),
                        child: Text('Annuler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.danger)),
                      ),
                    ),
                  if (canCancel) const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/market/orders/$id');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(10)),
                      child: Text('Détails', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
}
