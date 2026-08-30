// lib/presentation/thix_market/vendor/vendor_orders_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxOrderIdDisplay = 8;
const int _kMaxNameLength = 60;
const int _kMaxTitleLength = 80;

// ============================================================================
// PROVIDER
// ============================================================================
final vendorAllOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (!_VoValidators.isValidId(uid)) return [];

  try {
    final shopsRes = await _voRetry(
      () => db.from('shops').select('id').eq('owner_id', uid!),
      label: 'fetchVendorShops',
    );
    final shopIds = (shopsRes as List)
        .map((s) => (s as Map)['id']?.toString())
        .whereType<String>()
        .where(_VoValidators.isValidId)
        .toList();

    if (shopIds.isEmpty) return [];

    // 1. On prépare la requête de base AVEC le filtre inFilter
    var query = db
        .from('orders')
        .select(
          'id, total, status, payment_status, payout_status, payment_method, '
          'currency, created_at, user_id, receipt_code, refund_requested, '
          'refund_reason, received_at, shipping_method, shipping_address, '
          'customer_name, customer_phone, customer_email',
        )
        .inFilter('shop_id', shopIds);

    // 2. On ajoute le filtre eq() AVANT de faire le tri
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    // 3. On ajoute l'ordre et la limite, et on exécute la requête
    final res = await _voRetry(
      () => query.order('created_at', ascending: false).limit(100),
      label: 'fetchVendorOrders[${statusFilter ?? 'all'}]',
    );

    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('[VendorOrders] ❌ Provider error: $e');
    return [];
  }
});


// ============================================================================
// VALIDATEURS
// ============================================================================
class _VoValidators {
  _VoValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
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

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String shortId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= _kMaxOrderIdDisplay) return id.toUpperCase();
    return id.substring(0, _kMaxOrderIdDisplay).toUpperCase();
  }

  static String normalizeCurrency(String? raw) {
    if (raw == null) return 'FC';
    final c = raw.toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$') return 'USD';
    if (c == 'XOF' || c == 'FCFA' || c == 'FC' || c == 'CDF' || c == 'XAF') return 'FC';
    if (c == 'EUR' || c == '€') return 'EUR';
    return c.isEmpty ? 'FC' : c;
  }

  static String currencySymbol(String currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      default: return 'FC';
    }
  }

  static String formatAmount(double amount, String locale, {bool isUSD = false}) {
    try {
      if (isUSD) {
        return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2).format(amount);
      }
      return NumberFormat.decimalPattern(locale).format(amount.toInt());
    } catch (_) {
      return isUSD ? amount.toStringAsFixed(2) : amount.toInt().toString();
    }
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _VoL10n on BuildContext {
  String voT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _voRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[VendorOrders] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[VendorOrders] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[VendorOrders] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// STATUS CONFIGURATION
// ============================================================================
class _OrderStatus {
  final String key;
  final String labelFr;
  final String labelEn;
  final IconData icon;
  final Color color;

  const _OrderStatus({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
    required this.color,
  });

  String label(BuildContext context) => context.voT(labelFr, labelEn);
}

const List<_OrderStatus> _kOrderStatuses = [
  _OrderStatus(key: 'pending', labelFr: 'En attente', labelEn: 'Pending', icon: Icons.hourglass_top_rounded, color: ThixPolicy.gold),
  _OrderStatus(key: 'confirmed', labelFr: 'Confirmée', labelEn: 'Confirmed', icon: Icons.check_circle_outline_rounded, color: ThixPolicy.primary),
  _OrderStatus(key: 'processing', labelFr: 'En préparation', labelEn: 'Processing', icon: Icons.kitchen_rounded, color: ThixPolicy.primary),
  _OrderStatus(key: 'shipped', labelFr: 'Expédiée', labelEn: 'Shipped', icon: Icons.local_shipping_rounded, color: ThixPolicy.primary),
  _OrderStatus(key: 'delivered', labelFr: 'Livrée', labelEn: 'Delivered', icon: Icons.check_circle_rounded, color: ThixPolicy.success),
  _OrderStatus(key: 'cancelled', labelFr: 'Annulée', labelEn: 'Cancelled', icon: Icons.cancel_rounded, color: ThixPolicy.danger),
];

_OrderStatus _getOrderStatus(String key) {
  return _kOrderStatuses.firstWhere(
    (s) => s.key == key.toLowerCase(),
    orElse: () => const _OrderStatus(key: 'unknown', labelFr: 'Inconnu', labelEn: 'Unknown', icon: Icons.help_outline_rounded, color: ThixPolicy.textMuted),
  );
}

// ============================================================================
// STATUS TABS CONFIGURATION
// ============================================================================
class _StatusTab {
  final String key;
  final String labelFr;
  final String labelEn;

  const _StatusTab({required this.key, required this.labelFr, required this.labelEn});

  String label(BuildContext context) => context.voT(labelFr, labelEn);
}

const List<_StatusTab> _kStatusTabs = [
  _StatusTab(key: 'all', labelFr: 'Toutes', labelEn: 'All'),
  _StatusTab(key: 'pending', labelFr: 'En attente', labelEn: 'Pending'),
  _StatusTab(key: 'processing', labelFr: 'Préparation', labelEn: 'Processing'),
  _StatusTab(key: 'shipped', labelFr: 'Expédiées', labelEn: 'Shipped'),
  _StatusTab(key: 'delivered', labelFr: 'Livrées', labelEn: 'Delivered'),
  _StatusTab(key: 'cancelled', labelFr: 'Annulées', labelEn: 'Cancelled'),
];

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class VendorOrdersPage extends ConsumerStatefulWidget {
  const VendorOrdersPage({super.key});

  @override
  ConsumerState<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends ConsumerState<VendorOrdersPage> {
  String _filter = 'all';
  final Set<String> _updatingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    debugPrint('[VendorOrders] 📦 Page opened');
  }

  @override
  void dispose() {
    debugPrint('[VendorOrders] 👋 Page disposed');
    super.dispose();
  }

  // ============================================================
  // REFRESH
  // ============================================================
  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    debugPrint('[VendorOrders] 🔄 Refresh triggered (filter=$_filter)');
    ref.invalidate(vendorAllOrdersProvider(_filter));
    await ref.read(vendorAllOrdersProvider(_filter).future);
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================
  Future<void> _updateStatus(String orderId, String newStatus) async {
    if (!_VoValidators.isValidId(orderId)) {
      _showError(context.voT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    if (_updatingOrders.contains(orderId)) {
      debugPrint('[VendorOrders] ⚠️ Update already in progress for ${_VoValidators.shortId(orderId)}');
      return;
    }

    setState(() => _updatingOrders.add(orderId));
    HapticFeedback.mediumImpact();
    debugPrint('[VendorOrders] 🔄 Update ${_VoValidators.shortId(orderId)} → $newStatus');

    try {
      final db = ref.read(supabaseClientProvider);
      final payload = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
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

      await _voRetry(
        () => db.from('orders').update(payload).eq('id', orderId),
        label: 'updateOrderStatus[$orderId → $newStatus]',
      );

      ref.invalidate(vendorAllOrdersProvider(_filter));
      ref.invalidate(vendorAllOrdersProvider(null));

      if (mounted) {
        final status = _getOrderStatus(newStatus);
        _showSuccess('${context.voT('Statut', 'Status')} → ${status.label(context)}');
      }
      debugPrint('[VendorOrders] ✓ Status updated to $newStatus');
    } catch (e) {
      debugPrint('[VendorOrders] ❌ Update status error: $e');
      if (mounted) _showError(_VoValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _updatingOrders.remove(orderId));
    }
  }

  // ============================================================
  // CONFIRMATIONS
  // ============================================================
  Future<bool> _confirmAction({
    required String title,
    required String content,
    required Color actionColor,
    required String actionLabel,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text(content, style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.voT('Annuler', 'Cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white),
            child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmStatusChange(String orderId, String newStatus) async {
    final status = _getOrderStatus(newStatus);
    final short = _VoValidators.shortId(orderId);

    final confirmed = await _confirmAction(
      title: context.voT('Confirmer le changement', 'Confirm change'),
      content: context.voT(
        'Passer la commande #$short en "${status.label(context)}" ?',
        'Change order #$short to "${status.label(context)}"?',
      ),
      actionColor: status.color,
      actionLabel: context.voT('Confirmer', 'Confirm'),
    );

    if (confirmed && mounted) {
      await _updateStatus(orderId, newStatus);
    }
  }

  Future<void> _confirmCancel(String orderId) async {
    final short = _VoValidators.shortId(orderId);
    final ok = await _confirmAction(
      title: context.voT('Annuler la commande ?', 'Cancel order?'),
      content: context.voT(
        'Le client sera notifié et le paiement ne sera pas versé. Commande #$short',
        'Customer will be notified and payment will not be released. Order #$short',
      ),
      actionColor: ThixPolicy.danger,
      actionLabel: context.voT('Oui, annuler', 'Yes, cancel'),
    );
    if (ok && mounted) await _updateStatus(orderId, 'cancelled');
  }

  // ============================================================
  // QR SHEET
  // ============================================================
  void _showQrSheet(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final code = (order['receipt_code'] ?? orderId).toString();
    final short = _VoValidators.shortId(orderId);

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _QrCodeSheet(
        code: code,
        shortOrderId: short,
        titleLabel: context.voT('Code de livraison', 'Delivery code'),
        orderLabel: context.voT('Commande', 'Order'),
        instructionLabel: context.voT(
          'Présentez ce QR au client pour confirmer la réception.\nL\'argent ne sera versé qu\'après le scan.',
          'Show this QR to the customer to confirm receipt.\nFunds will be released after scan.',
        ),
        copyLabel: context.voT('Copier', 'Copy'),
        copiedLabel: context.voT('Code copié', 'Code copied'),
        closeLabel: context.voT('Fermer', 'Close'),
      ),
    );
  }

  // ============================================================
  // ORDER DETAILS SHEET
  // ============================================================
  void _showOrderDetails(Map<String, dynamic> order) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThixPolicy.card,
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
          onUpdateStatus: (id, status) => _confirmStatusChange(id, status),
          onShowQr: _showQrSheet,
          onCancel: _confirmCancel,
          isUpdating: _updatingOrders.contains(order['id']?.toString()),
        ),
      ),
    );
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorAllOrdersProvider(_filter));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.voT('Commandes vendeur', 'Vendor Orders'),
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
            color: ThixPolicy.textMain,
          ),
        ),
        iconTheme: IconThemeData(color: ThixPolicy.textMain),
        actions: [
          Semantics(
            button: true,
            label: context.voT('Actualiser', 'Refresh'),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.voT('Actualiser', 'Refresh'),
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusTabsBar(
            tabs: _kStatusTabs,
            selectedFilter: _filter,
            onFilterChanged: (newFilter) {
              HapticFeedback.selectionClick();
              setState(() => _filter = newFilter);
              debugPrint('[VendorOrders] 🔍 Filter changed to $newFilter');
            },
          ),
          Expanded(
            child: async.when(
              loading: () => const _SkeletonOrders(),
              error: (e, _) => _ErrorState(
                message: _VoValidators.friendlyError(e),
                onRetry: _refresh,
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return _EmptyState(
                    message: context.voT('Aucune commande', 'No orders'),
                    subtitle: context.voT(
                      'Les commandes apparaîtront ici',
                      'Orders will appear here',
                    ),
                  );
                }
                return RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OrderCard(
                      order: orders[i],
                      isUpdating: _updatingOrders.contains(orders[i]['id']?.toString()),
                      onTap: () => _showOrderDetails(orders[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _StatusTabsBar extends StatelessWidget {
  final List<_StatusTab> tabs;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _StatusTabsBar({
    required this.tabs,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = selectedFilter == tab.key;
            return Semantics(
              button: true,
              selected: isSelected,
              label: tab.label(context),
              child: GestureDetector(
                onTap: () => onFilterChanged(tab.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ThixPolicy.primary : ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? null : Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                  ),
                  child: Text(
                    tab.label(context),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 12,
                      fontWeight: ThixPolicy.bold,
                      color: isSelected ? Colors.white : ThixPolicy.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isUpdating;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isUpdating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final short = _VoValidators.shortId(id);
    final statusKey = (order['status'] ?? 'pending').toString().toLowerCase();
    final statusConfig = _getOrderStatus(statusKey);
    final total = _VoValidators.safeDouble(order['total']);
    final currency = _VoValidators.normalizeCurrency(order['currency']?.toString());
    final symbol = _VoValidators.currencySymbol(currency);
    final formattedTotal = _VoValidators.formatAmount(total, context.localeCode, isUSD: currency == 'USD');

    final dateStr = order['created_at']?.toString();
    final formattedDate = dateStr != null
        ? DateFormat('dd MMM yyyy, HH:mm', context.localeCode).format(DateTime.tryParse(dateStr) ?? DateTime.now())
        : '';

    final payout = (order['payout_status'] ?? 'held').toString();
    final refund = order['refund_requested'] == true;
    final paymentStatus = (order['payment_status'] ?? '').toString();

    final orderLabel = context.voT('Commande', 'Order');
    final paidVendorLabel = context.voT('Payé vendeur', 'Paid to vendor');
    final refundedLabel = context.voT('Remboursé', 'Refunded');
    final fundsHeldLabel = context.voT('Fonds bloqués', 'Funds held');
    final clientPaidLabel = context.voT('Client payé', 'Client paid');
    final cashDeliveryLabel = context.voT('Cash livraison', 'Cash on delivery');
    final claimLabel = context.voT('Réclamation', 'Claim');
    final tapLabel = context.voT('Appuyer pour voir les détails', 'Tap to view details');
    final detailsLabel = context.voT('Détails', 'Details');

    return Semantics(
      button: true,
      label: '$orderLabel #$short, ${statusConfig.label(context)}, $formattedTotal $symbol',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isUpdating ? 0.6 : 1.0,
        child: Material(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isUpdating ? null : onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: refund ? ThixPolicy.gold.withOpacity(0.5) : ThixPolicy.border.withOpacity(0.6),
                ),
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$orderLabel #$short',
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 14,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                      ),
                      if (isUpdating)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusConfig.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusConfig.label(context),
                            style: ThixPolicy.captionStyle.copyWith(
                              fontSize: 11,
                              fontWeight: ThixPolicy.bold,
                              color: statusConfig.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$formattedTotal $symbol',
                        style: ThixPolicy.titleStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 16,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                      const Spacer(),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(
                        label: payout == 'released'
                            ? paidVendorLabel
                            : payout == 'refunded'
                                ? refundedLabel
                                : fundsHeldLabel,
                        color: payout == 'released'
                            ? ThixPolicy.success
                            : payout == 'refunded'
                                ? ThixPolicy.danger
                                : ThixPolicy.gold,
                      ),
                      if (paymentStatus.isNotEmpty)
                        _Badge(
                          label: paymentStatus == 'paid'
                              ? clientPaidLabel
                              : paymentStatus == 'pending_delivery'
                                  ? cashDeliveryLabel
                                  : paymentStatus,
                          color: paymentStatus == 'paid' ? ThixPolicy.success : ThixPolicy.textMuted,
                        ),
                      if (refund)
                        _Badge(label: claimLabel, color: ThixPolicy.danger),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        tapLabel,
                        style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted),
                      ),
                      const Spacer(),
                      Text(
                        '$detailsLabel ›',
                        style: ThixPolicy.captionStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: ThixPolicy.microStyle.copyWith(
          fontSize: 10,
          fontWeight: ThixPolicy.bold,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// QR CODE SHEET
// ============================================================================
class _QrCodeSheet extends StatelessWidget {
  final String code;
  final String shortOrderId;
  final String titleLabel;
  final String orderLabel;
  final String instructionLabel;
  final String copyLabel;
  final String copiedLabel;
  final String closeLabel;

  const _QrCodeSheet({
    required this.code,
    required this.shortOrderId,
    required this.titleLabel,
    required this.orderLabel,
    required this.instructionLabel,
    required this.copyLabel,
    required this.copiedLabel,
    required this.closeLabel,
  });

  void _copy(BuildContext context) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(copiedLabel),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            titleLabel,
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            '$orderLabel #$shortOrderId',
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            instructionLabel,
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: code,
              width: 200,
              height: 200,
              drawText: false,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Code: $code',
            child: SelectableText(
              code,
              style: ThixPolicy.labelStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 12,
                color: ThixPolicy.textMain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: copyLabel,
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(copyLabel),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: ThixPolicy.textMain,
                      side: BorderSide(color: ThixPolicy.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: closeLabel,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(closeLabel, style: const TextStyle(fontWeight: ThixPolicy.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORDER DETAILS SHEET
// ============================================================================
class _OrderDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final ScrollController scrollController;
  final Future<void> Function(String, String) onUpdateStatus;
  final void Function(Map<String, dynamic>) onShowQr;
  final Future<void> Function(String) onCancel;
  final bool isUpdating;

  const _OrderDetailsSheet({
    required this.order,
    required this.scrollController,
    required this.onUpdateStatus,
    required this.onShowQr,
    required this.onCancel,
    required this.isUpdating,
  });

  @override
  ConsumerState<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends ConsumerState<_OrderDetailsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    try {
      final db = ref.read(supabaseClientProvider);
      final orderId = widget.order['id']?.toString();
      final userId = widget.order['user_id']?.toString();

      if (!_VoValidators.isValidId(orderId)) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final futures = <Future>[
        _voRetry(
          () => db
              .from('order_items')
              .select('*, product:products(title, image_url, currency)')
              .eq('order_id', orderId!),
          label: 'loadOrderItems',
        ),
      ];

      if (_VoValidators.isValidId(userId)) {
        futures.add(_voRetry(
          () => db.from('profiles').select().eq('id', userId!).maybeSingle(),
          label: 'loadCustomerProfile',
        ));
      }

      final results = await Future.wait(futures);

      _items = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (results.length > 1 && results[1] != null) {
        _profile = Map<String, dynamic>.from(results[1] as Map);
      }

      debugPrint('[VendorOrders] ✓ Loaded ${_items.length} order items');
    } catch (e) {
      debugPrint('[VendorOrders] ❌ Load extra data error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final orderId = o['id']?.toString() ?? '';
    final short = _VoValidators.shortId(orderId);
    final statusKey = (o['status'] ?? 'pending').toString().toLowerCase();
    final total = _VoValidators.safeDouble(o['total']);
    final currency = _VoValidators.normalizeCurrency(o['currency']?.toString());
    final symbol = _VoValidators.currencySymbol(currency);
    final formattedTotal = _VoValidators.formatAmount(total, context.localeCode, isUSD: currency == 'USD');

    final dateStr = o['created_at']?.toString();
    final formattedDate = dateStr != null
        ? DateFormat('dd MMM yyyy, HH:mm', context.localeCode).format(DateTime.tryParse(dateStr) ?? DateTime.now())
        : '';

    final shippingMethod = _VoValidators.sanitize(o['shipping_method']?.toString(), maxLength: 60);
    final shippingAddress = _VoValidators.sanitize(o['shipping_address']?.toString(), maxLength: 200);

    final clientName = _VoValidators.sanitize(
      _profile?['full_name'] ?? o['customer_name'] ?? _profile?['name'] ?? context.voT('Client', 'Customer'),
      maxLength: _kMaxNameLength,
    );
    final clientPhone = _VoValidators.sanitize(
      _profile?['phone'] ?? o['customer_phone'] ?? _profile?['phone_number'] ?? context.voT('Non renseigné', 'Not provided'),
      maxLength: 20,
    );
    final clientEmail = _VoValidators.sanitize(
      _profile?['email'] ?? o['customer_email'] ?? context.voT('Non renseigné', 'Not provided'),
      maxLength: 80,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.voT('Détails Commande', 'Order Details')} #$short',
                  style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18, color: ThixPolicy.textMain),
                ),
              ),
              Semantics(
                button: true,
                label: context.voT('Fermer', 'Close'),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          if (formattedDate.isNotEmpty)
            Text(
              '${context.voT('Commandé le', 'Ordered on')} $formattedDate',
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 20),

          _SectionTitle(title: context.voT('Client & Livraison', 'Customer & Delivery')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(icon: Icons.person_outline_rounded, label: context.voT('Client', 'Customer'), value: clientName),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.phone_outlined, label: context.voT('Téléphone', 'Phone'), value: clientPhone),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: clientEmail),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                ),
                _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  label: context.voT('Mode', 'Method'),
                  value: shippingMethod.isEmpty ? 'Standard' : shippingMethod,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: context.voT('Adresse', 'Address'),
                  value: shippingAddress.isEmpty ? context.voT('Non spécifiée', 'Not specified') : shippingAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle(title: context.voT('Articles commandés', 'Order items')),
          const SizedBox(height: 8),
          _isLoading
              ? const _ItemsSkeleton()
              : _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.voT('Aucun article trouvé', 'No items found'),
                        style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: _items
                          .map((item) => _OrderItemTile(item: item, currency: currency, locale: context.localeCode))
                          .toList(),
                    ),
          const SizedBox(height: 20),

          _SectionTitle(title: context.voT('Facturation', 'Billing')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                _BillingRow(
                  label: context.voT('Méthode de paiement', 'Payment method'),
                  value: (o['payment_method']?.toString().toUpperCase() ?? 'N/A'),
                ),
                const SizedBox(height: 6),
                _BillingRow(
                  label: context.voT('Statut paiement', 'Payment status'),
                  value: o['payment_status']?.toString() ?? 'N/A',
                  valueColor: ThixPolicy.success,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                ),
                _BillingRow(
                  label: context.voT('Total', 'Total'),
                  value: '$formattedTotal $symbol',
                  isBold: true,
                  valueColor: ThixPolicy.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: context.voT('Actions', 'Actions')),
          const SizedBox(height: 10),
          if (statusKey == 'pending')
            _ActionButton(
              icon: Icons.kitchen_rounded,
              label: context.voT('Passer en préparation', 'Mark as processing'),
              color: ThixPolicy.primary,
              isDisabled: widget.isUpdating,
              onTap: () {
                Navigator.pop(context);
                widget.onUpdateStatus(orderId, 'processing');
              },
            ),
          if (statusKey == 'pending' || statusKey == 'processing' || statusKey == 'confirmed')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActionButton(
                icon: Icons.local_shipping_rounded,
                label: context.voT('Marquer comme expédiée', 'Mark as shipped'),
                color: ThixPolicy.primary,
                isDisabled: widget.isUpdating,
                onTap: () {
                  Navigator.pop(context);
                  widget.onUpdateStatus(orderId, 'shipped');
                  widget.onShowQr({...o, 'status': 'shipped', 'receipt_code': orderId});
                },
              ),
            ),
          if (statusKey == 'shipped')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActionButton(
                icon: Icons.qr_code_2_rounded,
                label: context.voT('Afficher le QR de livraison', 'Show delivery QR'),
                color: ThixPolicy.primary,
                isDisabled: widget.isUpdating,
                onTap: () {
                  Navigator.pop(context);
                  widget.onShowQr(o);
                },
              ),
            ),
          if (statusKey != 'delivered' && statusKey != 'cancelled')
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: context.voT('Annuler la commande', 'Cancel order'),
              color: ThixPolicy.danger,
              isDisabled: widget.isUpdating,
              onTap: () {
                Navigator.pop(context);
                widget.onCancel(orderId);
              },
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: ThixPolicy.titleStyle.copyWith(
        fontWeight: ThixPolicy.bold,
        fontSize: 15,
        color: ThixPolicy.textMain,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ThixPolicy.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: ThixPolicy.captionStyle.copyWith(fontSize: 13, color: ThixPolicy.textMuted),
        ),
        Expanded(
          child: Text(
            value,
            style: ThixPolicy.captionStyle.copyWith(
              fontSize: 13,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BillingRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _BillingRow({required this.label, required this.value, this.isBold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: ThixPolicy.captionStyle.copyWith(
            color: ThixPolicy.textMuted,
            fontSize: 13,
            fontWeight: isBold ? ThixPolicy.bold : ThixPolicy.regular,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: isBold ? ThixPolicy.bold : ThixPolicy.semiBold,
              fontSize: isBold ? 15 : 13,
              color: valueColor ?? ThixPolicy.textMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String currency;
  final String locale;

  const _OrderItemTile({required this.item, required this.currency, required this.locale});

  @override
  Widget build(BuildContext context) {
    final product = item['product'] as Map? ?? {};
    final title = _VoValidators.sanitize(
      (product['title'] ?? item['title'] ?? context.voT('Produit', 'Product')).toString(),
      maxLength: _kMaxTitleLength,
    );
    final qty = _VoValidators.safeInt(item['quantity'], fallback: 1);
    final price = _VoValidators.safeDouble(item['price']);
    final variant = _VoValidators.sanitize(item['variant']?.toString(), maxLength: 30);
    final color = _VoValidators.sanitize(item['color']?.toString(), maxLength: 30);
    final imageUrl = _VoValidators.sanitizeUrl(product['image_url']?.toString());

    final symbol = _VoValidators.currencySymbol(currency);
    final formattedPrice = _VoValidators.formatAmount(price, locale, isUSD: currency == 'USD');
    final formattedTotal = _VoValidators.formatAmount(price * qty, locale, isUSD: currency == 'USD');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 50,
                      height: 50,
                      color: ThixPolicy.surfaceSoft,
                      child: const Center(
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: ThixPolicy.surfaceSoft,
                      child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 20),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13,
                    color: ThixPolicy.textMain,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant.isNotEmpty || color.isNotEmpty)
                  Text(
                    [if (variant.isNotEmpty) 'Var: $variant', if (color.isNotEmpty) '${context.voT('Couleur', 'Color')}: $color'].join(' | '),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${context.voT('Qté', 'Qty')}: $qty × $formattedPrice $symbol = $formattedTotal $symbol',
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 12,
                    fontWeight: ThixPolicy.semiBold,
                    color: ThixPolicy.primary,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: !isDisabled,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isDisabled
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onTap();
                },
          icon: isDisabled
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 18, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.5),
            minimumSize: const Size(0, 48),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON & ERROR STATES
// ============================================================================

class _SkeletonOrders extends StatelessWidget {
  const _SkeletonOrders();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(height: 14, width: 140, color: Colors.grey.shade200),
                const Spacer(),
                Container(height: 20, width: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(height: 16, width: 100, color: Colors.grey.shade200),
                const Spacer(),
                Container(height: 11, width: 120, color: Colors.grey.shade200),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                2,
                (_) => Container(
                  height: 20,
                  width: 70,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(height: 12, width: 200, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

class _ItemsSkeleton extends StatelessWidget {
  const _ItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 13, width: double.infinity, color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 100, color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 140, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String subtitle;

  const _EmptyState({required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined, size: 64, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              context.voT('Erreur de chargement', 'Loading error'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: context.voT('Réessayer', 'Retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  context.voT('Réessayer', 'Retry'),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
