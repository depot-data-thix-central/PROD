// lib/presentation/thix_market/vendor/vendor_orders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../providers/market_providers.dart';

// ============================================================
// PROVIDER (Utilise la table 'orders')
// ============================================================
final vendorAllOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  final shopsRes = await db.from('shops').select('id').eq('owner_id', uid);
  final shops = List<Map<String, dynamic>>.from(shopsRes);
  if (shops.isEmpty) return [];

  final shopIds = shops.map((s) => s['id']).toList();

  if (statusFilter != null &&
      statusFilter.isNotEmpty &&
      statusFilter != 'all') {
    final res = await db
        .from('orders')
        .select(
          'id, total, status, payment_status, payout_status, payment_method, '
          'currency, created_at, user_id, receipt_code, refund_requested, '
          'refund_reason, received_at, shipping_method, shipping_address, '
          'customer_name, customer_phone, customer_email',
        )
        .inFilter('shop_id', shopIds)
        .eq('status', statusFilter)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res);
  }

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
      .limit(100);

  return List<Map<String, dynamic>>.from(res);
});

// ============================================================
// PAGE
// ============================================================
class VendorOrdersPage extends ConsumerStatefulWidget {
  const VendorOrdersPage({super.key});

  @override
  ConsumerState<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends ConsumerState<VendorOrdersPage> {
  String _filter = 'all';
  bool _busy = false;

  static const primary = Color(0xFF1A73E8);
  static const bg = Color(0xFFF6F7FB);
  static const dark = Color(0xFF10192E);
  static const muted = Color(0xFF7386A8);
  static const red = Color(0xFFD81E2C);
  static const green = Color(0xFF00B074);
  static const gold = Color(0xFFF0A93B);

  final _statusTabs = const [
    {'key': 'all', 'label': 'Toutes'},
    {'key': 'pending', 'label': 'En attente'},
    {'key': 'processing', 'label': 'Préparation'},
    {'key': 'shipped', 'label': 'Expédiées'},
    {'key': 'delivered', 'label': 'Livrées'},
    {'key': 'cancelled', 'label': 'Annulées'},
  ];

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return gold;
      case 'processing':
      case 'confirmed':
        return const Color(0xFF8B5CF6);
      case 'shipped':
        return primary;
      case 'delivered':
        return green;
      case 'cancelled':
        return red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
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
        return status;
    }
  }

  String _cur(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase();
    if (v == 'XOF' || v == 'FCFA' || v == 'FC' || v == 'CDF') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }

  String _money(num amount, String cur) {
    return '${amount.toInt()} $cur';
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _busy = true);
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

      ref.invalidate(vendorAllOrdersProvider(_filter));
      ref.invalidate(vendorAllOrdersProvider(null));

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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
        builder: (_, scrollController) => _OrderDetailsSheet(
          order: order,
          scrollController: scrollController,
          onUpdateStatus: _updateStatus,
          onShowQr: _showQrSheet,
          onCancel: _confirmCancel,
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorAllOrdersProvider(_filter));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Commandes vendeur',
          style: TextStyle(
            color: dark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: dark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(vendorAllOrdersProvider(_filter));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _statusTabs.map((t) {
                  final sel = _filter == t['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _filter = t['key']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? primary : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : muted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: primary),
              ),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune commande',
                      style: TextStyle(color: muted),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: primary,
                  onRefresh: () async {
                    ref.invalidate(vendorAllOrdersProvider(_filter));
                    await ref.read(vendorAllOrdersProvider(_filter).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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

  Widget _orderCard(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final short = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final status = (o['status'] ?? 'pending').toString();
    final color = _statusColor(status);
    final total = (o['total'] as num?) ?? 0;
    final cur = _cur(o['currency']);
    final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
    final payout = (o['payout_status'] ?? 'held').toString();
    final refund = o['refund_requested'] == true;
    final paymentStatus = (o['payment_status'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetails(o),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: refund ? gold.withOpacity(0.5) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande #$short',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: dark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _money(total, cur),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: dark,
                    ),
                  ),
                  const Spacer(),
                  if (date != null)
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(date),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _badge(
                    payout == 'released'
                        ? 'Payé vendeur'
                        : payout == 'refunded'
                            ? 'Remboursé'
                            : 'Fonds bloqués',
                    payout == 'released'
                        ? green
                        : payout == 'refunded'
                            ? red
                            : gold,
                  ),
                  if (paymentStatus.isNotEmpty)
                    _badge(
                      paymentStatus == 'paid'
                          ? 'Client payé'
                          : paymentStatus == 'pending_delivery'
                              ? 'Cash livraison'
                              : paymentStatus,
                      paymentStatus == 'paid' ? green : muted,
                    ),
                  if (refund)
                    _badge('Réclamation', red),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Appuyer pour voir les détails',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const Spacer(),
                  Text(
                    'Détails ›',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// ORDER DETAILS SHEET (Interroge la table 'order_items')
// ============================================================
class _OrderDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final ScrollController scrollController;
  final Future<void> Function(String, String) onUpdateStatus;
  final void Function(Map<String, dynamic>) onShowQr;
  final Future<void> Function(String) onCancel;

  const _OrderDetailsSheet({
    required this.order,
    required this.scrollController,
    required this.onUpdateStatus,
    required this.onShowQr,
    required this.onCancel,
  });

  @override
  ConsumerState<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends ConsumerState<_OrderDetailsSheet> {
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

      // Interroge 'order_items'
      final itemsRes = await db
          .from('order_items')
          .select('*, product:products(title, image_url, currency)')
          .eq('order_id', orderId);
      _items = List<Map<String, dynamic>>.from(itemsRes);

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
    final shippingAddress = o['shipping_address']?.toString() ?? o['address']?.toString() ?? 'Non spécifiée';

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
