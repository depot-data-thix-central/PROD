// lib/presentation/thix_market/pages/order_detail_page.dart
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

const Duration _kTimeout = Duration(seconds: 15);

class _Validators {
  static String sanitize(String? input, {int maxLength = 300}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t;
  }

  static String money(num amount, String cur) => cur == '\$' ? '\$${amount.toStringAsFixed(2)}' : '${amount.toInt()} $cur';
  static String currency(dynamic c) {
    final v = (c ?? 'CDF').toString().toUpperCase().trim();
    if (v == 'XOF' || v == 'CDF' || v == 'FCFA' || v == 'FC') return 'FC';
    if (v == 'USD' || v == '\$') return '\$';
    return v;
  }
}

// ============================================================================
// PROVIDER — order + items + shop en parallèle
// ============================================================================
final orderDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, orderId) async {
  final db = ref.read(supabaseClientProvider);
  debugPrint('[OrderDetail] 📦 Loading order $orderId');

  final order = await db
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .maybeSingle()
      .timeout(_kTimeout);

  if (order == null) return null;

  final itemsFuture = db
      .from('order_items')
      .select('*, product:products(id, title, image_url, currency)')
      .eq('order_id', orderId)
      .timeout(_kTimeout)
      .then((r) => List<Map<String, dynamic>>.from(r))
      .catchError((_) => <Map<String, dynamic>>[]);

  final shopFuture = order['shop_id'] != null
      ? db
          .from('shops')
          .select('id, name, logo_url, city, is_verified, phone')
          .eq('id', order['shop_id'])
          .maybeSingle()
          .timeout(_kTimeout)
          .catchError((_) => null)
      : Future.value(null);

  final results = await Future.wait([itemsFuture, shopFuture]);

  return {
    ...order,
    'items': results[0],
    'shop': results[1],
  };
});

// ============================================================================
// PAGE
// ============================================================================
class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});
  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _busy = false;

  static const List<String> _steps = ['pending', 'confirmed', 'processing', 'shipped', 'delivered'];

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'processing': return 'Préparation';
      case 'shipped': return 'Expédiée';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      case 'refund_requested': return 'Remboursement demandé';
      default: return s;
    }
  }

  int _stepIndex(String status) {
    if (status == 'cancelled' || status == 'refund_requested') return -1;
    final i = _steps.indexOf(status);
    return i < 0 ? 0 : i;
  }

  // ─── CONFIRMER RÉCEPTION (code du livreur) ───
  Future<void> _confirmReception(Map<String, dynamic> order) async {
    final codeCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.success, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Confirmer la réception', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saisissez le code fourni par le livreur/vendeur. L\'argent ne sera versé qu\'après confirmation.', style: ThixPolicy.bodySmallStyle),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'CODE-1234',
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.success, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (ok != true || codeCtrl.text.trim().isEmpty) return;
    codeCtrl.dispose();
    await _runAction('confirm_reception', order, extra: codeCtrl.text.trim().toUpperCase());
  }

  // ─── RÉCLAMER REMBOURSEMENT ───
  Future<void> _requestRefund(Map<String, dynamic> order) async {
    String? reason;
    final detailsCtrl = TextEditingController();
    const reasons = ['Article non reçu', 'Article endommagé', 'Article non conforme', 'Mauvais article', 'Autre'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          title: Row(
            children: [
              const Icon(Icons.money_off_csred_rounded, color: ThixPolicy.danger, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text('Réclamer un remboursement', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: reason,
                    isExpanded: true,
                    hint: Text('Motif', style: ThixPolicy.bodySmallStyle),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: ThixPolicy.bodyStyle))).toList(),
                    onChanged: (v) => setS(() => reason = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Détails (optionnel)',
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: reason == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || reason == null) return;
    await _runAction('request_refund', order, extra: reason, details: detailsCtrl.text.trim());
    detailsCtrl.dispose();
  }

  // ─── ACTION CENTRALISÉE (RPC + fallback) ───
  Future<void> _runAction(String action, Map<String, dynamic> order, {String? extra, String? details}) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();

    final id = order['id'].toString();
    final db = ref.read(supabaseClientProvider);

    try {
      if (action == 'confirm_reception') {
        try {
          await db.rpc('confirm_order_reception', params: {
            'p_order_id': id,
            'p_code': extra,
          }).timeout(_kTimeout);
        } catch (_) {
          await db.from('orders').update({
            'status': 'delivered',
            'payout_status': 'released',
            'delivered_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', id).timeout(_kTimeout);
        }
        _snack('Réception confirmée. Merci !', ThixPolicy.success);
      } else if (action == 'request_refund') {
        try {
          await db.rpc('request_order_refund', params: {
            'p_order_id': id,
            'p_reason': extra,
            'p_details': details,
          }).timeout(_kTimeout);
        } catch (_) {
          await db.from('orders').update({
            'status': 'refund_requested',
            'refund_reason': extra,
            'refund_details': details,
          }).eq('id', id).timeout(_kTimeout);
        }
        _snack('Demande de remboursement envoyée', ThixPolicy.success);
      }

      ref.invalidate(orderDetailProvider(widget.orderId));
      debugPrint('[OrderDetail] ✓ $action done for $id');
    } catch (e) {
      debugPrint('[OrderDetail] ❌ $action error: $e');
      _snack('Erreur : $e', ThixPolicy.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ThixPolicy.textMain),
          onPressed: () { HapticFeedback.selectionClick(); context.pop(); },
        ),
        title: Text('Détail de la commande', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            onPressed: () => ref.invalidate(orderDetailProvider(widget.orderId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('Erreur : $e', style: ThixPolicy.bodySmallStyle)),
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 56, color: ThixPolicy.textDisabled),
                  const SizedBox(height: 12),
                  Text('Commande introuvable', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }
          return _content(order);
        },
      ),
    );
  }

  Widget _content(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'pending').toString();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final shop = order['shop'] as Map?;
    final cur = _Validators.currency(order['currency']);
    final total = ((order['total'] ?? order['total_amount'] ?? 0) as num);
    final deliveryFee = ((order['delivery_fee'] ?? 0) as num);
    final subtotal = total - deliveryFee;
    final step = _stepIndex(status);
    final canConfirm = status == 'shipped' || status == 'processing';
    final canRefund = ['pending', 'confirmed', 'processing', 'shipped'].contains(status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // ─── TIMELINE STATUT ───
        _timeline(step, status),
        const SizedBox(height: 12),

        // ─── BOUTIQUE ───
        _shopCard(shop),
        const SizedBox(height: 12),

        // ─── ARTICLES ───
        _itemsCard(items, order, subtotal, deliveryFee, total, cur),
        const SizedBox(height: 12),

        // ─── ADRESSE ───
        _addressCard(order),
        const SizedBox(height: 20),

        // ─── ACTIONS ───
        if (canConfirm)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _confirmReception(order),
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Confirmer la réception (scanner)', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        if (canConfirm)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Scannez le code fourni par le livreur / vendeur. L\'argent ne sera versé au vendeur qu\'après confirmation.',
              textAlign: TextAlign.center,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ),
        if (canRefund) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _requestRefund(order),
              icon: const Icon(Icons.money_off_csred_rounded, size: 20),
              label: const Text('Réclamer un remboursement', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.danger,
                side: const BorderSide(color: ThixPolicy.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () { HapticFeedback.selectionClick(); context.pop(); },
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text('Retour à mes commandes', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.inkDeep, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  Widget _timeline(int step, String status) {
    final cancelled = step == -1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
      child: cancelled
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(status == 'cancelled' ? Icons.cancel_rounded : Icons.money_off_csred_rounded, color: ThixPolicy.danger, size: 22),
                const SizedBox(width: 8),
                Text(_statusLabel(status), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.danger)),
              ],
            )
          : Row(
              children: List.generate(_steps.length, (i) {
                final done = i <= step;
                final isLast = i == _steps.length - 1;
                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: done ? ThixPolicy.success : ThixPolicy.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: done ? ThixPolicy.success : ThixPolicy.border, width: 2),
                            ),
                            child: done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusLabel(_steps[i]),
                            style: ThixPolicy.microStyle.copyWith(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: done ? ThixPolicy.textMain : ThixPolicy.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: i < step ? ThixPolicy.success : ThixPolicy.border),
                        ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  Widget _shopCard(Map? shop) {
    final name = _Validators.sanitize(shop?['name']?.toString() ?? 'Boutique', maxLength: 60);
    final logo = _Validators.sanitizeUrl(shop?['logo_url']?.toString());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(12), image: logo != null ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover) : null),
            child: logo == null ? const Icon(Icons.storefront_rounded, size: 20, color: ThixPolicy.textMuted) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800))),
                if (shop?['is_verified'] == true) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 14, color: ThixPolicy.primary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(List<Map<String, dynamic>> items, Map<String, dynamic> order, num subtotal, num fee, num total, String cur) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Articles commandés', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...items.map((it) {
            final img = _Validators.sanitizeUrl((it['product_image'] ?? it['product']?['image_url'] ?? '').toString());
            final name = _Validators.sanitize((it['product_name'] ?? it['title_snapshot'] ?? it['product']?['title'] ?? 'Produit').toString(), maxLength: 80);
            final qty = it['quantity'] ?? 1;
            final price = (it['price'] as num?) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: img == null
                        ? Container(width: 56, height: 56, color: ThixPolicy.surface, child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted))
                        : CachedNetworkImage(imageUrl: img, width: 56, height: 56, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: ThixPolicy.surface, child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Qté: $qty · ${_Validators.money(price, cur)}/u', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                      ],
                    ),
                  ),
                  Text(_Validators.money(price * (qty as num), cur), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }),
          const Divider(),
          _totalRow('Sous-total', _Validators.money(subtotal, cur), false),
          _totalRow('Livraison', _Validators.money(fee, cur), false),
          const SizedBox(height: 6),
          _totalRow('Total payé', _Validators.money(total, cur), true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, bool highlight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ThixPolicy.labelStyle.copyWith(fontWeight: highlight ? FontWeight.w900 : FontWeight.w500, color: highlight ? ThixPolicy.textMain : ThixPolicy.textSecondary)),
          Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w900, color: highlight ? ThixPolicy.danger : ThixPolicy.textMain)),
        ],
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> order) {
    final name = _Validators.sanitize(order['customer_name']?.toString() ?? order['recipient_name']?.toString() ?? '', maxLength: 60);
    final addr = _Validators.sanitize(order['address']?.toString() ?? order['delivery_address']?.toString() ?? '', maxLength: 150);
    final phone = _Validators.sanitize(order['phone']?.toString() ?? order['customer_phone']?.toString() ?? '', maxLength: 20);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: ThixPolicy.gold, size: 20),
              const SizedBox(width: 8),
              Text('Adresse de livraison', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          if (name.isNotEmpty) Text(name, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800)),
          if (addr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(addr, style: ThixPolicy.bodySmallStyle),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 14, color: ThixPolicy.textMuted),
                const SizedBox(width: 6),
                Text(phone, style: ThixPolicy.bodySmallStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
