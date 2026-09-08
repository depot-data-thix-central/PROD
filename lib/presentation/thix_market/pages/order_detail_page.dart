// lib/presentation/thix_market/pages/order_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
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

  String _statusLabel(String s, AppLocalizations l10n) {
    switch (s) {
      case 'pending': return l10n.t('order_detail_status_pending');
      case 'confirmed': return l10n.t('order_detail_status_confirmed');
      case 'processing': return l10n.t('order_detail_status_processing');
      case 'shipped': return l10n.t('order_detail_status_shipped');
      case 'delivered': return l10n.t('order_detail_status_delivered');
      case 'cancelled': return l10n.t('order_detail_status_cancelled');
      case 'refund_requested': return l10n.t('order_detail_status_refunded');
      default: return s;
    }
  }

  int _stepIndex(String status) {
    if (status == 'cancelled' || status == 'refund_requested') return -1;
    final i = _steps.indexOf(status);
    return i < 0 ? 0 : i;
  }

  // ─── CONFIRMER RÉCEPTION (code du livreur) ───
  Future<void> _confirmReception(Map<String, dynamic> order, AppLocalizations l10n) async {
    final codeCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.success, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.t('order_detail_confirm_reception'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('order_detail_confirm_desc'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: l10n.t('order_detail_code_hint'),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                counterText: '',
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('common_cancel'), style: const TextStyle(color: ThixPolicy.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.success, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(l10n.t('common_confirm')),
          ),
        ],
      ),
    );

    if (ok != true || codeCtrl.text.trim().isEmpty) return;
    codeCtrl.dispose();
    await _runAction('confirm_reception', order, extra: codeCtrl.text.trim().toUpperCase(), l10n: l10n);
  }

  // ─── RÉCLAMER REMBOURSEMENT ───
  Future<void> _requestRefund(Map<String, dynamic> order, AppLocalizations l10n) async {
    String? reason;
    final detailsCtrl = TextEditingController();
    final reasons = [
      l10n.t('order_detail_refund_r1'),
      l10n.t('order_detail_refund_r2'),
      l10n.t('order_detail_refund_r3'),
      l10n.t('order_detail_refund_r4'),
      l10n.t('order_detail_refund_r5'),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.money_off_csred_rounded, color: ThixPolicy.danger, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.t('order_detail_request_refund'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: reason,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary),
                    hint: Text(l10n.t('order_detail_refund_reason'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
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
                  hintText: l10n.t('order_detail_refund_details'),
                  hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                  counterText: '',
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('common_cancel'), style: const TextStyle(color: ThixPolicy.textMuted))),
            ElevatedButton(
              onPressed: reason == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('common_send')),
            ),
          ],
        ),
      ),
    );

    if (ok != true || reason == null) return;
    await _runAction('request_refund', order, extra: reason, details: detailsCtrl.text.trim(), l10n: l10n);
    detailsCtrl.dispose();
  }

  // ─── ACTION CENTRALISÉE (RPC + fallback) ───
  Future<void> _runAction(String action, Map<String, dynamic> order, {String? extra, String? details, required AppLocalizations l10n}) async {
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
        _snack(l10n.t('order_detail_success_reception'), ThixPolicy.success);
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
        _snack(l10n.t('order_detail_success_refund'), ThixPolicy.success);
      }

      ref.invalidate(orderDetailProvider(widget.orderId));
      debugPrint('[OrderDetail] ✓ $action done for $id');
    } catch (e) {
      debugPrint('[OrderDetail] ❌ $action error: $e');
      _snack('${l10n.t('common_error')} : $e', ThixPolicy.danger);
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

  // Un conteneur épuré réutilisable
  Widget _sleekSection({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          onPressed: () { HapticFeedback.selectionClick(); context.pop(); },
        ),
        title: Text(l10n.t('order_detail_title'), style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: ThixPolicy.textMain)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textSecondary),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(orderDetailProvider(widget.orderId));
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('${l10n.t('common_error')} : $e', style: ThixPolicy.bodySmallStyle)),
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 56, color: ThixPolicy.textDisabled),
                  const SizedBox(height: 12),
                  Text(l10n.t('order_detail_not_found'), style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }
          return _content(order, l10n);
        },
      ),
    );
  }

  Widget _content(Map<String, dynamic> order, AppLocalizations l10n) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // ─── TIMELINE STATUT ───
        _sleekSection(child: _timeline(step, status, l10n)),

        // ─── BOUTIQUE ───
        _sleekSection(child: _shopCard(shop, l10n)),

        // ─── ARTICLES ───
        _sleekSection(child: _itemsCard(items, subtotal, deliveryFee, total, cur, l10n)),

        // ─── ADRESSE ───
        _sleekSection(child: _addressCard(order, l10n)),

        // ─── ACTIONS ───
        if (canConfirm) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _confirmReception(order, l10n),
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(l10n.t('order_detail_confirm_reception_btn'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // Pill shape
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              l10n.t('order_detail_confirm_desc'),
              textAlign: TextAlign.center,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
            ),
          ),
        ],
        if (canRefund) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _requestRefund(order, l10n),
            icon: const Icon(Icons.money_off_csred_rounded, size: 18),
            label: Text(l10n.t('order_detail_request_refund'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.danger,
              side: BorderSide(color: ThixPolicy.danger.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        OutlinedButton.icon(
          onPressed: () { HapticFeedback.selectionClick(); context.pop(); },
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: Text(l10n.t('order_detail_back_btn'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          style: OutlinedButton.styleFrom(
            foregroundColor: ThixPolicy.textMain,
            side: BorderSide(color: ThixPolicy.border.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ],
    );
  }

  Widget _timeline(int step, String status, AppLocalizations l10n) {
    final cancelled = step == -1;
    if (cancelled) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(status == 'cancelled' ? Icons.cancel_rounded : Icons.money_off_csred_rounded, color: ThixPolicy.danger, size: 24),
          const SizedBox(width: 10),
          Text(_statusLabel(status, l10n), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.danger)),
        ],
      );
    }

    return Row(
      children: List.generate(_steps.length, (i) {
        final done = i <= step;
        final isLast = i == _steps.length - 1;
        final color = done ? ThixPolicy.success : ThixPolicy.border;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: done ? ThixPolicy.success.withValues(alpha: 0.1) : ThixPolicy.surfaceSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: done ? const Icon(Icons.check_rounded, size: 14, color: ThixPolicy.success) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusLabel(_steps[i], l10n),
                      style: ThixPolicy.microStyle.copyWith(
                        fontSize: 9,
                        fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                        color: done ? ThixPolicy.textMain : ThixPolicy.textMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 16, height: 2,
                  margin: const EdgeInsets.only(bottom: 20), // Alignement optique
                  color: i < step ? ThixPolicy.success : ThixPolicy.surfaceSoft,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _shopCard(Map? shop, AppLocalizations l10n) {
    final name = _Validators.sanitize(shop?['name']?.toString() ?? l10n.t('order_detail_shop_fallback'), maxLength: 60);
    final logo = _Validators.sanitizeUrl(shop?['logo_url']?.toString());
    
    return Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.4)),
            image: logo != null ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover) : null
          ),
          child: logo == null ? const Icon(Icons.storefront_rounded, size: 24, color: ThixPolicy.textMuted) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: [
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16))),
              if (shop?['is_verified'] == true) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 16, color: ThixPolicy.primary),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemsCard(List<Map<String, dynamic>> items, num subtotal, num fee, num total, String cur, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('order_detail_items_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 16),
        ...items.map((it) {
          final img = _Validators.sanitizeUrl((it['product_image'] ?? it['product']?['image_url'] ?? '').toString());
          final name = _Validators.sanitize((it['product_name'] ?? it['title_snapshot'] ?? it['product']?['title'] ?? l10n.t('order_detail_product_fallback')).toString(), maxLength: 80);
          final qty = it['quantity'] ?? 1;
          final price = (it['price'] as num?) ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img == null
                      ? Container(width: 64, height: 64, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted))
                      : CachedNetworkImage(imageUrl: img, width: 64, height: 64, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 64, height: 64, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                      const SizedBox(height: 4),
                      Text('${l10n.t('order_detail_qty')}: $qty  •  ${_Validators.money(price, cur)}/u', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(_Validators.money(price * (qty as num), cur), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
          );
        }),
        Divider(color: ThixPolicy.border.withValues(alpha: 0.3), height: 32),
        _totalRow(l10n.t('order_detail_subtotal'), _Validators.money(subtotal, cur), false),
        const SizedBox(height: 8),
        _totalRow(l10n.t('order_detail_delivery'), _Validators.money(fee, cur), false),
        const SizedBox(height: 16),
        _totalRow(l10n.t('order_detail_total'), _Validators.money(total, cur), true),
      ],
    );
  }

  Widget _totalRow(String label, String value, bool highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: ThixPolicy.labelStyle.copyWith(fontWeight: highlight ? FontWeight.w800 : FontWeight.w600, color: highlight ? ThixPolicy.textMain : ThixPolicy.textSecondary, fontSize: highlight ? 15 : 13)),
        Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w900, color: highlight ? ThixPolicy.primaryDeep : ThixPolicy.textMain, fontSize: highlight ? 18 : 14)),
      ],
    );
  }

  Widget _addressCard(Map<String, dynamic> order, AppLocalizations l10n) {
    final name = _Validators.sanitize(order['customer_name']?.toString() ?? order['recipient_name']?.toString() ?? '', maxLength: 60);
    final addr = _Validators.sanitize(order['address']?.toString() ?? order['delivery_address']?.toString() ?? '', maxLength: 150);
    final phone = _Validators.sanitize(order['phone']?.toString() ?? order['customer_phone']?.toString() ?? '', maxLength: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ThixPolicy.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, color: ThixPolicy.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Text(l10n.t('order_detail_address_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        if (name.isNotEmpty) Text(name, style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w800)),
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(addr, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_rounded, size: 16, color: ThixPolicy.textMuted),
              const SizedBox(width: 8),
              Text(phone, style: ThixPolicy.bodySmallStyle.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    );
  }
}
