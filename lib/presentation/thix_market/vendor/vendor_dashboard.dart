// lib/presentation/thix_market/vendor/vendor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../providers/shop_provider.dart';
import '../providers/market_providers.dart';

// ============================================================
// PROVIDERS (réels via shop_id)
// ============================================================
final vendorOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  final shopsRes = await db.from('shops').select('id').eq('owner_id', uid);
  final shops = List<Map<String, dynamic>>.from(shopsRes);
  if (shops.isEmpty) return [];

  final shopIds = shops.map((s) => s['id']).toList();

  final res = await db
      .from('orders')
      .select(
        'id, total, status, payment_status, payout_status, payment_method, '
        'currency, created_at, user_id, receipt_code, refund_requested, '
        'refund_reason, received_at, shipping_method, shipping_address, '
        'customer_name, customer_phone, customer_email',
      )
      .inFilter('shop_id', shopIds)
      .order('created_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(res);
});

final vendorProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  final shopsRes = await db.from('shops').select('id').eq('owner_id', uid);
  final shops = List<Map<String, dynamic>>.from(shopsRes);
  if (shops.isEmpty) return [];

  final shopIds = shops.map((s) => s['id']).toList();

  final res = await db
      .from('products')
      .select('id, title, price, status, stock')
      .inFilter('shop_id', shopIds)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(res);
});

// ============================================================
// PAGE
// ============================================================
class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  static const primary = Color(0xFF1A73E8);
  static const bg = Color(0xFFF6F7FB);
  static const dark = Color(0xFF10192E);
  static const muted = Color(0xFF7386A8);
  static const red = Color(0xFFD81E2C);
  static const green = Color(0xFF00B074);
  static const gold = Color(0xFFF0A93B);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(myShopsProvider);
      ref.invalidate(vendorOrdersProvider);
      ref.invalidate(vendorProductsProvider);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(myShopsProvider);
    ref.invalidate(vendorOrdersProvider);
    ref.invalidate(vendorProductsProvider);
    await Future.wait([
      ref.read(myShopsProvider.future),
      ref.read(vendorOrdersProvider.future),
      ref.read(vendorProductsProvider.future),
    ]);
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'processing':
        return 'En cours';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return gold;
      case 'processing':
        return primary;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return green;
      case 'cancelled':
        return red;
      default:
        return Colors.grey;
    }
  }

  String _cur(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase();
    if (v == 'XOF' || v == 'FCFA' || v == 'FC' || v == 'CDF') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }

  // --- Gestion du changement de statut depuis le dashboard ---
  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final db = ref.read(supabaseClientProvider);
      final payload = <String, dynamic>{
        'status': newStatus,
      };

      if (newStatus == 'shipped') {
        payload['receipt_code'] = orderId;
        payload['payout_status'] = 'held';
      }

      if (newStatus == 'delivered') {
        payload['received_at'] = DateTime.now().toIso8601String();
        payload['payout_status'] = 'released';
        payload['payment_status'] = 'paid';
      }

      if (newStatus == 'cancelled') {
        payload['payout_status'] = 'refunded';
      }

      await db.from('orders').update(payload).eq('id', orderId);

      ref.invalidate(vendorOrdersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut → ${_statusLabel(newStatus)}'),
            backgroundColor: green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: red,
          ),
        );
      }
    }
  }

  // --- Affichage QR Code de livraison ---
  void _showQrSheet(Map<String, dynamic> order) {
    final orderId = order['id'].toString();
    final code = (order['receipt_code'] ?? orderId).toString();
    final short = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Code de livraison',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Commande #$short',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Présentez ce QR au client pour confirmer la réception.\nL\'argent ne sera versé qu\'après le scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: code,
                  width: 200,
                  height: 200,
                  drawText: false,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: dark,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copié'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copier'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Confirmation d'annulation ---
  Future<void> _confirmCancel(String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cette commande ?'),
        content: const Text(
          'Le client sera notifié et le paiement ne sera pas versé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await _updateStatus(orderId, 'cancelled');
  }

  // --- Ouverture des détails de commande complets ---
  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _DashboardOrderDetailsSheet(
          order: order,
          scrollController: scrollController,
          onUpdateStatus: _updateStatus,
          onShowQr: _showQrSheet,
          onCancel: _confirmCancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(myShopsProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final productsAsync = ref.watch(vendorProductsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Espace vendeur',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primary)),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (shops) {
          final hasShop = shops.isNotEmpty;
          final shop = hasShop ? shops.first : null;

          return ordersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: primary)),
            error: (e, _) => Center(child: Text('Erreur commandes : $e')),
            data: (orders) {
              final products = productsAsync.valueOrNull ?? [];
              final pending =
                  orders.where((o) => o['status'] == 'pending').length;
              final processing =
                  orders.where((o) => o['status'] == 'processing').length;
              final rating = (shop?['rating'] as num?)?.toDouble() ?? 0.0;

              return RefreshIndicator(
                color: primary,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      hasShop
                          ? _shopHeader(shop!, context)
                          : _noShopHeader(context),
                      const SizedBox(height: 20),
                      if (hasShop) ...[
                        _kpiGrid(
                          ordersCount: orders.length,
                          pending: pending,
                          processing: processing,
                          productsCount: products.length,
                          rating: rating,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _actionGrid(context, hasShop, shop),
                      const SizedBox(height: 24),
                      if (hasShop) _recentOrders(orders, context),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // HEADER SANS BOUTIQUE
  // ----------------------------------------------------------
  Widget _noShopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, size: 40, color: primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Créez votre boutique',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pour vendre sur THIX Market, créez d\'abord votre boutique.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.pushNamed('marketCreateShop'),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text(
                'Créer une boutique',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // HEADER BOUTIQUE
  // ----------------------------------------------------------
  Widget _shopHeader(Map<String, dynamic> shop, BuildContext context) {
    final logo = shop['logo_url']?.toString() ?? '';
    final name = shop['name']?.toString() ?? 'Ma boutique';
    final city = shop['city']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage:
                logo.isNotEmpty ? NetworkImage(logo) : null,
            child: logo.isEmpty
                ? const Icon(Icons.store, color: primary, size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (city.isNotEmpty)
                  Text(
                    city,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () => context.pushNamed(
              'marketManageShop',
              pathParameters: {'shopId': shop['id'].toString()},
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // KPI (données réelles uniquement)
  // ----------------------------------------------------------
  Widget _kpiGrid({
    required int ordersCount,
    required int pending,
    required int processing,
    required int productsCount,
    required double rating,
  }) {
    final kpis = [
      {
        'label': 'Commandes',
        'value': '$ordersCount',
        'icon': Icons.shopping_bag_outlined,
        'color': primary,
      },
      {
        'label': 'En attente',
        'value': '$pending',
        'icon': Icons.pending_actions_rounded,
        'color': Colors.orange,
      },
      {
        'label': 'Produits',
        'value': '$productsCount',
        'icon': Icons.inventory_2_outlined,
        'color': Colors.teal,
      },
      {
        'label': 'Note',
        'value': rating > 0 ? rating.toStringAsFixed(1) : '-',
        'icon': Icons.star_rounded,
        'color': Colors.amber.shade700,
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: kpis.map((kpi) {
        final color = kpi['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(kpi['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      kpi['value'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      kpi['label'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------
  // ACTIONS RAPIDES
  // ----------------------------------------------------------
  Widget _actionGrid(
    BuildContext context,
    bool hasShop,
    Map<String, dynamic>? shop,
  ) {
    final shopId = shop?['id']?.toString();

    final actions = <Map<String, dynamic>>[
      {
        'icon': Icons.inventory_2_outlined,
        'label': 'Produits',
        'onTap': () => context.pushNamed('marketSell'),
        'needShop': true,
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'label': 'Commandes',
        'onTap': () {
          try {
            context.push('/market/vendor/orders');
          } catch (_) {
            context.pushNamed('marketSell', queryParameters: {'tab': 'orders'});
          }
        },
        'needShop': true,
      },
      {
        'icon': Icons.add_box_outlined,
        'label': 'Annonce',
        'onTap': () => context.pushNamed('marketPublishAnnouncement'),
        'needShop': true,
      },
      {
        'icon': Icons.live_tv_outlined,
        'label': 'Live',
        'onTap': () => context.pushNamed('marketCreateLive'),
        'needShop': true,
      },
      {
        'icon': Icons.bar_chart_rounded,
        'label': 'Stats',
        'onTap': () {
          if (shopId != null) {
            // Route corrigée et fonctionnelle pour les statistiques
            context.push('/market/shop/$shopId/stats');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Créez d\'abord une boutique')),
            );
          }
        },
        'needShop': true,
      },
      {
        'icon': Icons.local_shipping_outlined,
        'label': 'Livraisons',
        'onTap': () => context.pushNamed('deliveryManagement'),
        'needShop': true,
      },
      {
        'icon': Icons.storefront_outlined,
        'label': 'Boutique',
        'onTap': () {
          if (shopId != null) {
            context.pushNamed(
              'marketManageShop',
              pathParameters: {'shopId': shopId},
            );
          } else {
            context.pushNamed('marketCreateShop');
          }
        },
        'needShop': false,
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Réglages',
        'onTap': () {
          if (shopId != null) {
            context.pushNamed(
              'marketManageShop',
              pathParameters: {'shopId': shopId},
            );
          }
        },
        'needShop': true,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: actions.map((a) {
            return InkWell(
              onTap: () {
                final needShop = a['needShop'] == true;
                if (needShop && !hasShop) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Créez d\'abord une boutique'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                (a['onTap'] as VoidCallback)();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      a['icon'] as IconData,
                      size: 26,
                      color: primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // DERNIÈRES COMMANDES (réelles avec fiche détaillée)
  // ----------------------------------------------------------
  Widget _recentOrders(
    List<Map<String, dynamic>> orders,
    BuildContext context,
  ) {
    final recent = orders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dernières commandes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(
              onPressed: () {
                try {
                  context.push('/market/vendor/orders');
                } catch (_) {
                  context.pushNamed(
                    'marketSell',
                    queryParameters: {'tab': 'orders'},
                  );
                }
              },
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'Aucune commande pour le moment',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (c, i) {
                final o = recent[i];
                final id = o['id']?.toString() ?? '';
                final shortId =
                    id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
                final total = (o['total'] as num?)?.toInt() ?? 0;
                final currency = _cur(o['currency']);
                final status = o['status']?.toString() ?? '';
                final color = _statusColor(status);

                return ListTile(
                  onTap: () {
                    // Ouvre les détails complets de la commande au clic
                    _showOrderDetails(o);
                  },
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    radius: 18,
                    child: Icon(
                      status == 'pending'
                          ? Icons.hourglass_top_rounded
                          : Icons.receipt_long_rounded,
                      color: color,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Commande #$shortId',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '$total $currency',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ============================================================
// WIDGET DÉTAILS DE COMMANDE (Feuille de bas de page interactive)
// ============================================================
class _DashboardOrderDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final ScrollController scrollController;
  final Future<void> Function(String, String) onUpdateStatus;
  final void Function(Map<String, dynamic>) onShowQr;
  final Future<void> Function(String) onCancel;

  const _DashboardOrderDetailsSheet({
    required this.order,
    required this.scrollController,
    required this.onUpdateStatus,
    required this.onShowQr,
    required this.onCancel,
  });

  @override
  ConsumerState<_DashboardOrderDetailsSheet> createState() =>
      _DashboardOrderDetailsSheetState();
}

class _DashboardOrderDetailsSheetState
    extends ConsumerState<_DashboardOrderDetailsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _profile;

  static const primary = Color(0xFF1A73E8);
  static const dark = Color(0xFF10192E);
  static const muted = Color(0xFF7386A8);
  static const red = Color(0xFFD81E2C);
  static const green = Color(0xFF00B074);

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    try {
      final db = ref.read(supabaseClientProvider);
      final orderId = widget.order['id'];
      final userId = widget.order['user_id'];

      // Charger les items de la commande avec le prix exact enregistré
      final itemsRes = await db
          .from('order_items')
          .select('*, product:products(title, image_url, currency)')
          .eq('order_id', orderId);
      _items = List<Map<String, dynamic>>.from(itemsRes);

      // Charger le profil client
      if (userId != null) {
        final profileRes = await db
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (profileRes != null) {
          _profile = profileRes;
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement détails: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cur(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase();
    if (v == 'XOF' || v == 'FCFA' || v == 'FC' || v == 'CDF') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final orderId = o['id'].toString();
    final short = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final status = (o['status'] ?? 'pending').toString();
    final total = (o['total'] as num?) ?? 0;
    final cur = _cur(o['currency']);
    final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
    final shippingMethod = o['shipping_method']?.toString() ?? 'Standard';
    final shippingAddress = o['shipping_address']?.toString() ?? 'Non spécifiée';

    final clientName = _profile?['full_name'] ?? o['customer_name'] ?? _profile?['name'] ?? 'Client';
    final clientPhone = _profile?['phone'] ?? o['customer_phone'] ?? _profile?['phone_number'] ?? 'Non renseigné';
    final clientEmail = _profile?['email'] ?? o['customer_email'] ?? 'Non renseigné';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Détails Commande #$short',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: dark,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (date != null)
            Text(
              'Commandé le ${DateFormat('dd/MM/yyyy à HH:mm').format(date)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          const SizedBox(height: 20),

          // 1. CLIENT & LIVRAISON
          _sectionTitle('Client & Livraison'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_outline, 'Client', clientName),
                const SizedBox(height: 6),
                _infoRow(Icons.phone_outlined, 'Téléphone', clientPhone),
                const SizedBox(height: 6),
                _infoRow(Icons.email_outlined, 'Email', clientEmail),
                const Divider(height: 16),
                _infoRow(Icons.local_shipping_outlined, 'Mode', shippingMethod),
                const SizedBox(height: 6),
                _infoRow(Icons.location_on_outlined, 'Adresse', shippingAddress),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. ARTICLES DE LA COMMANDE
          _sectionTitle('Articles commandés'),
          const SizedBox(height: 8),
          _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: primary),
                  ),
                )
              : _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Aucun article trouvé pour cette commande.',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: _items.map((item) {
                        final product = item['product'] as Map? ?? {};
                        final title = product['title'] ?? item['title'] ?? 'Produit';
                        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                        final price = (item['price'] as num?) ?? 0;
                        final variant = item['variant']?.toString();
                        final color = item['color']?.toString();
                        final imageUrl = product['image_url']?.toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderImg(),
                                      )
                                    : _placeholderImg(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: dark,
                                      ),
                                    ),
                                    if (variant != null || color != null)
                                      Text(
                                        [if (variant != null) 'Var: $variant', if (color != null) 'Couleur: $color']
                                            .join(' | '),
                                        style: const TextStyle(fontSize: 11, color: muted),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qté : $qty x ${price.toInt()} $cur',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
          const SizedBox(height: 20),

          // 3. FACTURATION
          _sectionTitle('Facturation'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Méthode de paiement', style: TextStyle(color: muted, fontSize: 13)),
                    Text(o['payment_method']?.toString().toUpperCase() ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: dark)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Statut paiement', style: TextStyle(color: muted, fontSize: 13)),
                    Text(o['payment_status']?.toString() ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: green)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: dark)),
                    Text('${total.toInt()} $cur',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. ACTIONS
          _sectionTitle('Actions'),
          const SizedBox(height: 10),
          if (status == 'pending')
            _actionButton(
              icon: Icons.inventory_2_outlined,
              label: 'Passer en préparation',
              color: const Color(0xFF8B5CF6),
              onTap: () async {
                Navigator.pop(context);
                await widget.onUpdateStatus(orderId, 'processing');
              },
            ),
          if (status == 'pending' || status == 'processing' || status == 'confirmed')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _actionButton(
                icon: Icons.local_shipping_outlined,
                label: 'Marquer comme expédiée',
                color: primary,
                onTap: () async {
                  Navigator.pop(context);
                  await widget.onUpdateStatus(orderId, 'shipped');
                  final refreshed = {...o, 'status': 'shipped', 'receipt_code': orderId};
                  widget.onShowQr(refreshed);
                },
              ),
            ),
          if (status == 'shipped')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _actionButton(
                icon: Icons.qr_code_2_rounded,
                label: 'Afficher le QR de livraison',
                color: primary,
                onTap: () {
                  Navigator.pop(context);
                  widget.onShowQr(o);
                },
              ),
            ),
          if (status != 'delivered' && status != 'cancelled')
            _actionButton(
              icon: Icons.cancel_outlined,
              label: 'Annuler la commande',
              color: red,
              onTap: () {
                Navigator.pop(context);
                widget.onCancel(orderId);
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        color: dark,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Text('$label : ', style: const TextStyle(fontSize: 13, color: muted)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _placeholderImg() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined, color: muted, size: 20),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
