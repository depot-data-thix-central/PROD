// lib/presentation/thix_market/pages/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/market_providers.dart';

// ============================================================
// COULEURS
// ============================================================
class _C {
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const bg = Color(0xFFF7F7FA);
  static const white = Color(0xFFFFFFFF);
  static const dark = Color(0xFF1A1A1A);
  static const muted = Color(0xFF8A8A8F);
  static const border = Color(0xFFF0F0F0);
  static const green = Color(0xFF00B074);
  static const blue = Color(0xFF2D6CDF);
}

// ============================================================
// PROVIDER
// ============================================================
final orderDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, orderId) async {
  final db = ref.read(supabaseClientProvider);

  final orderRes =
      await db.from('orders').select().eq('id', orderId).single();
  final order = Map<String, dynamic>.from(orderRes);

  // Items + snapshot produit
  try {
    final items = await db
        .from('order_items')
        .select('*, product:products(title, image_url, currency)')
        .eq('order_id', orderId);
    order['items'] = List<Map<String, dynamic>>.from(items);
  } catch (_) {
    try {
      final items =
          await db.from('order_items').select().eq('order_id', orderId);
      order['items'] = List<Map<String, dynamic>>.from(items);
    } catch (_) {
      order['items'] = <Map<String, dynamic>>[];
    }
  }

  // Adresse
  if (order['address_id'] != null) {
    try {
      order['address'] = await db
          .from('addresses')
          .select()
          .eq('id', order['address_id'])
          .maybeSingle();
    } catch (_) {}
  }

  // Boutique (toujours)
  if (order['shop_id'] != null) {
    try {
      order['shop'] = await db
          .from('shops')
          .select('id, name, logo_url, city, phone, is_verified')
          .eq('id', order['shop_id'])
          .maybeSingle();
    } catch (_) {
      try {
        order['shop'] = await db
            .from('shops')
            .select('id, name, logo_url, city')
            .eq('id', order['shop_id'])
            .maybeSingle();
      } catch (_) {}
    }
  }

  return order;
});

// ============================================================
// PAGE
// ============================================================
class OrderDetailPage extends ConsumerWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  String _cur(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase().trim();
    if (v == 'XOF' || v == 'FCFA' || v == 'FC' || v == 'CDF') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'processing':
        return 'En préparation';
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

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered':
        return _C.green;
      case 'cancelled':
        return _C.red;
      case 'shipped':
        return _C.blue;
      case 'processing':
      case 'confirmed':
        return const Color(0xFF8B5CF6);
      default:
        return _C.gold;
    }
  }

  String _formatDate(String? s) {
    if (s == null) return '—';
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  String _money(num amount, String cur) {
    if (cur == '\\( ') return ' \){amount.toStringAsFixed(2)} $cur';
    return '${amount.toInt()} $cur';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Détail de la commande',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: _C.dark,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _C.red)),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (order) => _Body(
          order: order,
          orderId: orderId,
          curFn: _cur,
          statusLabel: _statusLabel,
          statusColor: _statusColor,
          formatDate: _formatDate,
          money: _money,
          onRefresh: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
      ),
    );
  }
}

// ============================================================
// BODY
// ============================================================
class _Body extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;
  final String Function(dynamic) curFn;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final String Function(String?) formatDate;
  final String Function(num, String) money;
  final VoidCallback onRefresh;

  const _Body({
    required this.order,
    required this.orderId,
    required this.curFn,
    required this.statusLabel,
    required this.statusColor,
    required this.formatDate,
    required this.money,
    required this.onRefresh,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Map<String, dynamic> get o => widget.order;
  String get status => (o['status'] ?? 'pending').toString();
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get canConfirmReceipt =>
      !isDelivered &&
      !isCancelled &&
      (status == 'shipped' || status == 'processing' || status == 'pending' || status == 'confirmed');
  bool get canClaimRefund =>
      !isDelivered &&
      !isCancelled &&
      (o['refund_requested'] != true);

  String get currency {
    // 1. Devise commande
    if (o['currency'] != null && o['currency'].toString().isNotEmpty) {
      return widget.curFn(o['currency']);
    }
    // 2. Devise premier item / produit
    final items = List<Map<String, dynamic>>.from(o['items'] ?? []);
    if (items.isNotEmpty) {
      final p = items.first['product'];
      if (p is Map && p['currency'] != null) {
        return widget.curFn(p['currency']);
      }
      if (items.first['currency'] != null) {
        return widget.curFn(items.first['currency']);
      }
    }
    return 'FC';
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ReceiptScanPage()),
    );
    if (code == null || code.isEmpty) return;
    await _confirmReceipt(code);
  }

  Future<void> _confirmReceipt(String scannedCode) async {
    setState(() => _busy = true);
    try {
      final db = ref.read(supabaseClientProvider);
      final expected = (o['receipt_code'] ?? o['id']).toString();

      // Accepte le code QR généré OU l'id commande
      final ok = scannedCode.trim() == expected ||
          scannedCode.trim() == o['id'].toString() ||
          scannedCode.contains(o['id'].toString());

      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code invalide pour cette commande'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await db.from('orders').update({
        'status': 'delivered',
        'received_at': DateTime.now().toIso8601String(),
        'payout_status': 'released', // argent libéré au vendeur
        'payment_status': 'paid',
      }).eq('id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réception confirmée. Merci !'),
            backgroundColor: _C.green,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimRefund() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Réclamer un remboursement',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Si vous n\'avez pas reçu la commande, expliquez le problème. Le paiement restera bloqué.',
              style: TextStyle(fontSize: 13, color: _C.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: Colis non livré après 7 jours',
                filled: true,
                fillColor: _C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _C.red),
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(supabaseClientProvider);
      await db.from('orders').update({
        'refund_requested': true,
        'refund_reason': reason,
        'payout_status': 'held',
      }).eq('id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réclamation envoyée. Support notifié.'),
            backgroundColor: _C.gold,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Le stock sera rendu à la boutique.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _C.red),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(supabaseClientProvider);
      try {
        await db.rpc('cancel_order', params: {
          'p_order_id': widget.orderId,
          'p_reason_code': 'client_request',
          'p_reason': 'Client depuis détail commande',
        });
      } catch (_) {
        await db.from('orders').update({
          'status': 'cancelled',
          'payout_status': 'refunded',
        }).eq('id', widget.orderId);
      }
      widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(o['items'] ?? []);
    final shop = o['shop'] as Map?;
    final address = o['address'] as Map?;
    final total = (o['total'] as num?) ?? 0;
    final cur = currency;
    final color = widget.statusColor(status);
    final shortId = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8)
        : widget.orderId;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header commande
            _card(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande #${shortId.toLowerCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _C.dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 13, color: _C.muted),
                            const SizedBox(width: 4),
                            Text(
                              widget.formatDate(o['created_at']?.toString()),
                              style: const TextStyle(fontSize: 12, color: _C.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.statusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Boutique
            _card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _C.bg,
                    backgroundImage: shop?['logo_url'] != null &&
                            shop!['logo_url'].toString().isNotEmpty
                        ? NetworkImage(shop['logo_url'].toString())
                        : null,
                    child: shop?['logo_url'] == null ||
                            (shop?['logo_url']?.toString().isEmpty ?? true)
                        ? const Icon(Icons.storefront_rounded, color: _C.muted)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shop?['name']?.toString() ?? 'Boutique',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (shop?['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded,
                                  size: 14, color: _C.blue),
                            ],
                          ],
                        ),
                        if (shop?['city'] != null)
                          Text(
                            shop!['city'].toString(),
                            style:
                                const TextStyle(fontSize: 12, color: _C.muted),
                          ),
                        if (shop?['phone'] != null)
                          Text(
                            shop!['phone'].toString(),
                            style:
                                const TextStyle(fontSize: 12, color: _C.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Articles
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Articles commandés',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((it) {
                    final name = it['product_name'] ??
                        it['title_snapshot'] ??
                        it['product']?['title'] ??
                        'Produit';
                    final img = it['product_image'] ??
                        it['product']?['image_url'] ??
                        '';
                    final qty = it['quantity'] ?? 1;
                    final price = (it['price'] as num?) ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: img.toString().isEmpty
                                ? Container(
                                    width: 52,
                                    height: 52,
                                    color: _C.bg,
                                    child: const Icon(Icons.image_outlined),
                                  )
                                : Image.network(
                                    img.toString(),
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 52,
                                      height: 52,
                                      color: _C.bg,
                                      child: const Icon(Icons.image_outlined),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Qté: $qty · ${widget.money(price, cur)}/u',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _C.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            widget.money(price * (qty as num), cur),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total payé',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.money(total, cur),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _C.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Adresse
            if (address != null)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: _C.gold, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Adresse de livraison',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      address['full_name']?.toString() ??
                          address['name']?.toString() ??
                          '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        address['street'] ?? address['address_line1'],
                        address['city'],
                        address['postal_code'],
                      ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                      style: const TextStyle(color: _C.muted, fontSize: 13),
                    ),
                    if (address['phone'] != null)
                      Text(
                        '☎ ${address['phone']}',
                        style: const TextStyle(color: _C.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // === ACCUSÉ DE RÉCEPTION ===
            if (canConfirmReceipt) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _openScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(
                    'Confirmer la réception (scanner)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scannez le code fourni par le livreur / vendeur. L\'argent ne sera versé au vendeur qu\'après confirmation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _C.muted, height: 1.3),
              ),
              const SizedBox(height: 12),
            ],

            if (isDelivered)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: _C.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Réception confirmée. Paiement libéré au vendeur.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (o['refund_requested'] == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Réclamation en cours de traitement.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Remboursement
            if (canClaimRefund)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _claimRefund,
                  icon: const Icon(Icons.money_off_csred_rounded, size: 18),
                  label: const Text('Réclamer un remboursement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.red,
                    side: const BorderSide(color: _C.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

            // Annuler
            if (status == 'pending' || status == 'confirmed') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _cancelOrder,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler la commande'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.red,
                    side: const BorderSide(color: _C.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Retour à mes commandes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }
}

// ============================================================
// SCANNER QR
// ============================================================
class _ReceiptScanPage extends StatefulWidget {
  const _ReceiptScanPage();

  @override
  State<_ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<_ReceiptScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scanner le code de livraison'),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Alignez le QR code du livreur / vendeur dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
