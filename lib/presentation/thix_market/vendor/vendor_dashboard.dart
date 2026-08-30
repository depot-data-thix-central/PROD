// lib/presentation/thix_market/vendor/vendor_dashboard.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/shop_provider.dart';
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
// PROVIDERS
// ============================================================================
final vendorOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (!_VdValidators.isValidId(uid)) return [];

  try {
    final shopsRes = await _vdRetry(
      () => db.from('shops').select('id').eq('owner_id', uid!),
      label: 'fetchVendorShops',
    );
    final shopIds = (shopsRes as List)
        .map((s) => (s as Map)['id']?.toString())
        .whereType<String>()
        .where(_VdValidators.isValidId)
        .toList();

    if (shopIds.isEmpty) return [];

    final res = await _vdRetry(
      () => db
          .from('orders')
          .select(
            'id, total, status, payment_status, payout_status, payment_method, '
            'currency, created_at, user_id, receipt_code, refund_requested, '
            'refund_reason, received_at, shipping_method, shipping_address, '
            'customer_name, customer_phone, customer_email',
          )
          .inFilter('shop_id', shopIds)
          .order('created_at', ascending: false)
          .limit(50),
      label: 'fetchVendorOrders',
    );

    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('[VendorDashboard] ❌ Orders load error: $e');
    return [];
  }
});

final vendorProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (!_VdValidators.isValidId(uid)) return [];

  try {
    final shopsRes = await _vdRetry(
      () => db.from('shops').select('id').eq('owner_id', uid!),
      label: 'fetchVendorShops[products]',
    );
    final shopIds = (shopsRes as List)
        .map((s) => (s as Map)['id']?.toString())
        .whereType<String>()
        .where(_VdValidators.isValidId)
        .toList();

    if (shopIds.isEmpty) return [];

    final res = await _vdRetry(
      () => db
          .from('products')
          .select('id, title, price, status, stock')
          .inFilter('shop_id', shopIds)
          .order('created_at', ascending: false),
      label: 'fetchVendorProducts',
    );

    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('[VendorDashboard] ❌ Products load error: $e');
    return [];
  }
});

// ============================================================================
// VALIDATEURS
// ============================================================================
class _VdValidators {
  _VdValidators._();

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
extension _VdL10n on BuildContext {
  String vdT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _vdRetry<T>(
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
        debugPrint('[VendorDashboard] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[VendorDashboard] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[VendorDashboard] ❌ $label error: $e');
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

  String label(BuildContext context) => context.vdT(labelFr, labelEn);
}

const List<_OrderStatus> _kOrderStatuses = [
  _OrderStatus(
    key: 'pending',
    labelFr: 'En attente',
    labelEn: 'Pending',
    icon: Icons.hourglass_top_rounded,
    color: ThixPolicy.gold,
  ),
  _OrderStatus(
    key: 'processing',
    labelFr: 'En préparation',
    labelEn: 'Processing',
    icon: Icons.kitchen_rounded,
    color: ThixPolicy.primary,
  ),
  _OrderStatus(
    key: 'shipped',
    labelFr: 'Expédiée',
    labelEn: 'Shipped',
    icon: Icons.local_shipping_rounded,
    color: ThixPolicy.primary,
  ),
  _OrderStatus(
    key: 'delivered',
    labelFr: 'Livrée',
    labelEn: 'Delivered',
    icon: Icons.check_circle_rounded,
    color: ThixPolicy.success,
  ),
  _OrderStatus(
    key: 'cancelled',
    labelFr: 'Annulée',
    labelEn: 'Cancelled',
    icon: Icons.cancel_rounded,
    color: ThixPolicy.danger,
  ),
];

_OrderStatus _getOrderStatus(String key) {
  return _kOrderStatuses.firstWhere(
    (s) => s.key == key,
    orElse: () => const _OrderStatus(
      key: 'unknown',
      labelFr: 'Inconnu',
      labelEn: 'Unknown',
      icon: Icons.help_outline_rounded,
      color: ThixPolicy.textMuted,
    ),
  );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  bool _isRefreshing = false;
  final Set<String> _updatingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    debugPrint('[VendorDashboard] 🏪 Page opened');
    Future.microtask(() {
      ref.invalidate(myShopsProvider);
      ref.invalidate(vendorOrdersProvider);
      ref.invalidate(vendorProductsProvider);
    });
  }

  @override
  void dispose() {
    debugPrint('[VendorDashboard] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    debugPrint('[VendorDashboard] 🔄 Refresh triggered');

    try {
      ref.invalidate(myShopsProvider);
      ref.invalidate(vendorOrdersProvider);
      ref.invalidate(vendorProductsProvider);

      await Future.wait([
        ref.read(myShopsProvider.future),
        ref.read(vendorOrdersProvider.future),
        ref.read(vendorProductsProvider.future),
      ]);
    } catch (e) {
      debugPrint('[VendorDashboard] ❌ Refresh error: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================
  Future<void> _updateStatus(String orderId, String newStatus) async {
    if (!_VdValidators.isValidId(orderId)) {
      _showError(context.vdT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    if (_updatingOrders.contains(orderId)) {
      debugPrint('[VendorDashboard] ⚠️ Update already in progress for ${_VdValidators.shortId(orderId)}');
      return;
    }

    setState(() => _updatingOrders.add(orderId));
    HapticFeedback.mediumImpact();
    debugPrint('[VendorDashboard] 🔄 Update ${_VdValidators.shortId(orderId)} → $newStatus');

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

      await _vdRetry(
        () => db.from('orders').update(payload).eq('id', orderId),
        label: 'updateOrderStatus[$orderId → $newStatus]',
      );

      ref.invalidate(vendorOrdersProvider);

      if (mounted) {
        final status = _getOrderStatus(newStatus);
        _showSuccess('${context.vdT('Statut', 'Status')} → ${status.label(context)}');
      }
      debugPrint('[VendorDashboard] ✓ Status updated to $newStatus');
    } catch (e) {
      debugPrint('[VendorDashboard] ❌ Update status error: $e');
      if (mounted) _showError(_VdValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _updatingOrders.remove(orderId));
    }
  }

  // ============================================================
  // QR SHEET
  // ============================================================
  void _showQrSheet(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final code = (order['receipt_code'] ?? orderId).toString();
    final short = _VdValidators.shortId(orderId);

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
        titleLabel: context.vdT('Code de livraison', 'Delivery code'),
        orderLabel: context.vdT('Commande', 'Order'),
        instructionLabel: context.vdT(
          'Présentez ce QR au client pour confirmer la réception.\nL\'argent ne sera versé qu\'après le scan.',
          'Show this QR to the customer to confirm receipt.\nFunds will be released after scan.',
        ),
        copyLabel: context.vdT('Copier', 'Copy'),
        copiedLabel: context.vdT('Code copié', 'Code copied'),
        closeLabel: context.vdT('Fermer', 'Close'),
      ),
    );
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
            child: Text(context.vdT('Annuler', 'Cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
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
    final short = _VdValidators.shortId(orderId);

    final confirmed = await _confirmAction(
      title: context.vdT('Confirmer le changement', 'Confirm change'),
      content: context.vdT(
        'Passer la commande #$short en "${status.label(context)}" ?',
        'Change order #$short to "${status.label(context)}"?',
      ),
      actionColor: status.color,
      actionLabel: context.vdT('Confirmer', 'Confirm'),
    );

    if (confirmed && mounted) {
      await _updateStatus(orderId, newStatus);
    }
  }

  Future<void> _confirmCancel(String orderId) async {
    final short = _VdValidators.shortId(orderId);
    final ok = await _confirmAction(
      title: context.vdT('Annuler la commande ?', 'Cancel order?'),
      content: context.vdT(
        'Le client sera notifié et le paiement ne sera pas versé. Commande #$short',
        'Customer will be notified and payment will not be released. Order #$short',
      ),
      actionColor: ThixPolicy.danger,
      actionLabel: context.vdT('Oui, annuler', 'Yes, cancel'),
    );
    if (ok && mounted) await _updateStatus(orderId, 'cancelled');
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
        builder: (_, scrollController) => _DashboardOrderDetailsSheet(
          order: order,
          scrollController: scrollController,
          onUpdateStatus: (id, status) => _confirmStatusChange(id, status),
          onShowQr: _showQrSheet,
          onCancel: _confirmCancel,
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

  void _showInfo(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(myShopsProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final productsAsync = ref.watch(vendorProductsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          context.vdT('Espace vendeur', 'Vendor Dashboard'),
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
            color: ThixPolicy.textMain,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ThixPolicy.textMain),
        actions: [
          Semantics(
            button: true,
            label: context.vdT('Actualiser', 'Refresh'),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.vdT('Actualiser', 'Refresh'),
              onPressed: _isRefreshing ? null : _refresh,
            ),
          ),
        ],
      ),
      body: shopsAsync.when(
        loading: () => const _SkeletonDashboard(),
        error: (e, _) => _ErrorState(
          message: _VdValidators.friendlyError(e),
          onRetry: _refresh,
        ),
        data: (shops) {
          final hasShop = shops.isNotEmpty;
          final shop = hasShop ? shops.first : null;

          return ordersAsync.when(
            loading: () => const _SkeletonDashboard(),
            error: (e, _) => _ErrorState(
              message: _VdValidators.friendlyError(e),
              onRetry: _refresh,
            ),
            data: (orders) {
              final products = productsAsync.valueOrNull ?? [];
              final pending = orders.where((o) => o['status'] == 'pending').length;
              final processing = orders.where((o) => o['status'] == 'processing').length;
              final rating = _VdValidators.safeDouble(shop?['rating']);

              return RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      hasShop
                          ? _ShopHeader(
                              shop: shop!,
                              onSettingsTap: () {
                                HapticFeedback.selectionClick();
                                context.pushNamed(
                                  'marketManageShop',
                                  pathParameters: {'shopId': shop['id'].toString()},
                                );
                              },
                            )
                          : _NoShopHeader(
                              onCreateTap: () {
                                HapticFeedback.mediumImpact();
                                context.pushNamed('marketCreateShop');
                              },
                            ),
                      const SizedBox(height: 20),
                      if (hasShop) ...[
                        _KpiGrid(
                          ordersCount: orders.length,
                          pending: pending,
                          processing: processing,
                          productsCount: products.length,
                          rating: rating,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _ActionGrid(
                        hasShop: hasShop,
                        shop: shop,
                        onNeedShop: () => _showInfo(
                          context.vdT('Créez d\'abord une boutique', 'Create a shop first'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (hasShop)
                        _RecentOrders(
                          orders: orders,
                          onOrderTap: _showOrderDetails,
                          onViewAll: () {
                            HapticFeedback.selectionClick();
                            try {
                              context.push('/market/vendor/orders');
                            } catch (_) {
                              context.pushNamed('marketSell', queryParameters: {'tab': 'orders'});
                            }
                          },
                        ),
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
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _NoShopHeader extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _NoShopHeader({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_rounded, size: 40, color: ThixPolicy.primary),
          ),
          const SizedBox(height: 16),
          Text(
            context.vdT('Créez votre boutique', 'Create your shop'),
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            context.vdT(
              'Pour vendre sur THIX Market, créez d\'abord votre boutique.',
              'To sell on THIX Market, create your shop first.',
            ),
            textAlign: TextAlign.center,
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: context.vdT('Créer une boutique', 'Create shop'),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add_business_rounded, color: Colors.white),
                label: Text(
                  context.vdT('Créer une boutique', 'Create shop'),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onSettingsTap;

  const _ShopHeader({required this.shop, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final logoUrl = _VdValidators.sanitizeUrl(shop['logo_url']?.toString());
    final name = _VdValidators.sanitize(shop['name']?.toString(), maxLength: _kMaxNameLength);
    final city = _VdValidators.sanitize(shop['city']?.toString(), maxLength: 40);
    final displayName = name.isEmpty ? context.vdT('Ma boutique', 'My shop') : name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ThixPolicy.primary, ThixPolicy.inkDeep]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.1),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Logo $displayName',
            child: CircleAvatar(
              radius: 28,
              backgroundColor: ThixPolicy.card,
              child: ClipOval(
                child: logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(Icons.store_rounded, color: ThixPolicy.primary, size: 28),
                      )
                    : Icon(Icons.store_rounded, color: ThixPolicy.primary, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: ThixPolicy.titleStyle.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: ThixPolicy.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (city.isNotEmpty)
                  Text(
                    city,
                    style: ThixPolicy.captionStyle.copyWith(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: context.vdT('Paramètres boutique', 'Shop settings'),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              tooltip: context.vdT('Paramètres', 'Settings'),
              onPressed: onSettingsTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final int ordersCount;
  final int pending;
  final int processing;
  final int productsCount;
  final double rating;

  const _KpiGrid({
    required this.ordersCount,
    required this.pending,
    required this.processing,
    required this.productsCount,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final kpis = [
      {
        'label': context.vdT('Commandes', 'Orders'),
        'value': '$ordersCount',
        'icon': Icons.shopping_bag_outlined,
        'color': ThixPolicy.primary,
      },
      {
        'label': context.vdT('En attente', 'Pending'),
        'value': '$pending',
        'icon': Icons.pending_actions_rounded,
        'color': ThixPolicy.gold,
      },
      {
        'label': context.vdT('Produits', 'Products'),
        'value': '$productsCount',
        'icon': Icons.inventory_2_outlined,
        'color': ThixPolicy.success,
      },
      {
        'label': context.vdT('Note', 'Rating'),
        'value': rating > 0 ? rating.toStringAsFixed(1) : '-',
        'icon': Icons.star_rounded,
        'color': ThixPolicy.gold,
      },
    ];

    return Semantics(
      label: context.vdT('Statistiques', 'Statistics'),
      child: GridView.count(
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
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
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
                        style: ThixPolicy.titleStyle.copyWith(
                          fontSize: 18,
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                      Text(
                        kpi['label'] as String,
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final bool hasShop;
  final Map<String, dynamic>? shop;
  final VoidCallback onNeedShop;

  const _ActionGrid({required this.hasShop, required this.shop, required this.onNeedShop});

  @override
  Widget build(BuildContext context) {
    final shopId = shop?['id']?.toString();

    final actions = <Map<String, dynamic>>[
      {
        'icon': Icons.inventory_2_outlined,
        'label': context.vdT('Produits', 'Products'),
        'onTap': () => context.pushNamed('marketSell'),
        'needShop': true,
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'label': context.vdT('Commandes', 'Orders'),
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
        'label': context.vdT('Annonce', 'Listing'),
        'onTap': () => context.pushNamed('marketPublishAnnouncement'),
        'needShop': true,
      },
      {
        'icon': Icons.live_tv_outlined,
        'label': context.vdT('Live', 'Live'),
        'onTap': () => context.pushNamed('marketCreateLive'),
        'needShop': true,
      },
      {
        'icon': Icons.bar_chart_rounded,
        'label': context.vdT('Stats', 'Stats'),
        'onTap': () {
          if (shopId != null && _VdValidators.isValidId(shopId)) {
            context.push('/market/shop/$shopId/stats');
          }
        },
        'needShop': true,
      },
      {
        'icon': Icons.local_shipping_outlined,
        'label': context.vdT('Livraisons', 'Deliveries'),
        'onTap': () => context.pushNamed('deliveryManagement'),
        'needShop': true,
      },
      {
        'icon': Icons.storefront_outlined,
        'label': context.vdT('Boutique', 'Shop'),
        'onTap': () {
          if (shopId != null && _VdValidators.isValidId(shopId)) {
            context.pushNamed('marketManageShop', pathParameters: {'shopId': shopId});
          } else {
            context.pushNamed('marketCreateShop');
          }
        },
        'needShop': false,
      },
      {
        'icon': Icons.settings_outlined,
        'label': context.vdT('Réglages', 'Settings'),
        'onTap': () {
          if (shopId != null && _VdValidators.isValidId(shopId)) {
            context.pushNamed('marketManageShop', pathParameters: {'shopId': shopId});
          }
        },
        'needShop': true,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.vdT('Actions rapides', 'Quick actions'),
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 16,
            color: ThixPolicy.textMain,
          ),
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
            final needShop = a['needShop'] == true;
            final enabled = !needShop || hasShop;
            return Semantics(
              button: true,
              label: a['label'] as String,
              enabled: enabled,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (!enabled) {
                    onNeedShop();
                    return;
                  }
                  (a['onTap'] as VoidCallback)();
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled ? 1.0 : 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThixPolicy.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a['icon'] as IconData, size: 26, color: ThixPolicy.primary),
                        const SizedBox(height: 6),
                        Text(
                          a['label'] as String,
                          textAlign: TextAlign.center,
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 11,
                            fontWeight: ThixPolicy.semiBold,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final ValueChanged<Map<String, dynamic>> onOrderTap;
  final VoidCallback onViewAll;

  const _RecentOrders({
    required this.orders,
    required this.onOrderTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = orders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.vdT('Dernières commandes', 'Recent orders'),
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 16,
                color: ThixPolicy.textMain,
              ),
            ),
            Semantics(
              button: true,
              label: context.vdT('Voir toutes les commandes', 'View all orders'),
              child: TextButton(
                onPressed: onViewAll,
                child: Text(
                  context.vdT('Voir tout', 'View all'),
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                context.vdT('Aucune commande pour le moment', 'No orders yet'),
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              itemBuilder: (c, i) {
                final o = recent[i];
                final id = o['id']?.toString() ?? '';
                final shortId = _VdValidators.shortId(id);
                final total = _VdValidators.safeDouble(o['total']);
                final currency = _VdValidators.normalizeCurrency(o['currency']?.toString());
                final symbol = _VdValidators.currencySymbol(currency);
                final formattedTotal = _VdValidators.formatAmount(total, context.localeCode, isUSD: currency == 'USD');
                final statusKey = (o['status'] ?? 'pending').toString().toLowerCase();
                final statusConfig = _getOrderStatus(statusKey);

                return Semantics(
                  button: true,
                  label: '${context.vdT('Commande', 'Order')} #$shortId, ${statusConfig.label(context)}, $formattedTotal $symbol',
                  child: ListTile(
                    onTap: () => onOrderTap(o),
                    leading: CircleAvatar(
                      backgroundColor: statusConfig.color.withOpacity(0.15),
                      radius: 18,
                      child: Icon(statusConfig.icon, color: statusConfig.color, size: 18),
                    ),
                    title: Text(
                      '${context.vdT('Commande', 'Order')} #$shortId',
                      style: ThixPolicy.labelStyle.copyWith(
                        fontSize: 13,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                    subtitle: Text(
                      '$formattedTotal $symbol',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                    ),
                    trailing: Container(
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
                  ),
                );
              },
            ),
          ),
      ],
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
  ConsumerState<_DashboardOrderDetailsSheet> createState() => _DashboardOrderDetailsSheetState();
}

class _DashboardOrderDetailsSheetState extends ConsumerState<_DashboardOrderDetailsSheet> {
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

      if (!_VdValidators.isValidId(orderId)) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Batch load : items + profile en parallèle
      final futures = <Future>[
        _vdRetry(
          () => db
              .from('order_items')
              .select('*, product:products(title, image_url, currency)')
              .eq('order_id', orderId!),
          label: 'loadOrderItems',
        ),
      ];

      if (_VdValidators.isValidId(userId)) {
        futures.add(_vdRetry(
          () => db.from('profiles').select().eq('id', userId!).maybeSingle(),
          label: 'loadCustomerProfile',
        ));
      }

      final results = await Future.wait(futures);

      _items = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (results.length > 1 && results[1] != null) {
        _profile = Map<String, dynamic>.from(results[1] as Map);
      }

      debugPrint('[VendorDashboard] ✓ Loaded ${_items.length} order items');
    } catch (e) {
      debugPrint('[VendorDashboard] ❌ Load extra data error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final orderId = o['id']?.toString() ?? '';
    final short = _VdValidators.shortId(orderId);
    final statusKey = (o['status'] ?? 'pending').toString().toLowerCase();
    final statusConfig = _getOrderStatus(statusKey);
    final total = _VdValidators.safeDouble(o['total']);
    final currency = _VdValidators.normalizeCurrency(o['currency']?.toString());
    final symbol = _VdValidators.currencySymbol(currency);
    final formattedTotal = _VdValidators.formatAmount(total, context.localeCode, isUSD: currency == 'USD');
    final dateStr = o['created_at']?.toString();
    final formattedDate = dateStr != null
        ? DateFormat('dd MMM yyyy, HH:mm', context.localeCode).format(DateTime.tryParse(dateStr) ?? DateTime.now())
        : '';
    final shippingMethod = _VdValidators.sanitize(o['shipping_method']?.toString(), maxLength: 60);
    final shippingAddress = _VdValidators.sanitize(o['shipping_address']?.toString(), maxLength: 200);

    final clientName = _VdValidators.sanitize(
      _profile?['full_name'] ?? o['customer_name'] ?? _profile?['name'] ?? context.vdT('Client', 'Customer'),
      maxLength: _kMaxNameLength,
    );
    final clientPhone = _VdValidators.sanitize(
      _profile?['phone'] ?? o['customer_phone'] ?? _profile?['phone_number'] ?? context.vdT('Non renseigné', 'Not provided'),
      maxLength: 20,
    );
    final clientEmail = _VdValidators.sanitize(
      _profile?['email'] ?? o['customer_email'] ?? context.vdT('Non renseigné', 'Not provided'),
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
                  '${context.vdT('Détails Commande', 'Order Details')} #$short',
                  style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18, color: ThixPolicy.textMain),
                ),
              ),
              Semantics(
                button: true,
                label: context.vdT('Fermer', 'Close'),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          if (formattedDate.isNotEmpty)
            Text(
              '${context.vdT('Commandé le', 'Ordered on')} $formattedDate',
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 20),

          // 1. CLIENT & LIVRAISON
          _SectionTitle(title: context.vdT('Client & Livraison', 'Customer & Delivery')),
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
                _InfoRow(icon: Icons.person_outline_rounded, label: context.vdT('Client', 'Customer'), value: clientName),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.phone_outlined, label: context.vdT('Téléphone', 'Phone'), value: clientPhone),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: clientEmail),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                ),
                _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  label: context.vdT('Mode', 'Method'),
                  value: shippingMethod.isEmpty ? 'Standard' : shippingMethod,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: context.vdT('Adresse', 'Address'),
                  value: shippingAddress.isEmpty ? context.vdT('Non spécifiée', 'Not specified') : shippingAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. ARTICLES
          _SectionTitle(title: context.vdT('Articles commandés', 'Order items')),
          const SizedBox(height: 8),
          _isLoading
              ? const _ItemsSkeleton()
              : _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.vdT('Aucun article trouvé', 'No items found'),
                        style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: _items.map((item) => _OrderItemTile(item: item, currency: currency, locale: context.localeCode)).toList(),
                    ),
          const SizedBox(height: 20),

          // 3. FACTURATION
          _SectionTitle(title: context.vdT('Facturation', 'Billing')),
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
                  label: context.vdT('Méthode de paiement', 'Payment method'),
                  value: (o['payment_method']?.toString().toUpperCase() ?? 'N/A'),
                ),
                const SizedBox(height: 6),
                _BillingRow(
                  label: context.vdT('Statut paiement', 'Payment status'),
                  value: o['payment_status']?.toString() ?? 'N/A',
                  valueColor: ThixPolicy.success,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                ),
                _BillingRow(
                  label: context.vdT('Total', 'Total'),
                  value: '$formattedTotal $symbol',
                  isBold: true,
                  valueColor: ThixPolicy.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. ACTIONS
          _SectionTitle(title: context.vdT('Actions', 'Actions')),
          const SizedBox(height: 10),
          if (statusKey == 'pending')
            _ActionButton(
              icon: Icons.kitchen_rounded,
              label: context.vdT('Passer en préparation', 'Mark as processing'),
              color: ThixPolicy.primary,
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
                label: context.vdT('Marquer comme expédiée', 'Mark as shipped'),
                color: ThixPolicy.primary,
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
                label: context.vdT('Afficher le QR de livraison', 'Show delivery QR'),
                color: ThixPolicy.primary,
                onTap: () {
                  Navigator.pop(context);
                  widget.onShowQr(o);
                },
              ),
            ),
          if (statusKey != 'delivered' && statusKey != 'cancelled')
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: context.vdT('Annuler la commande', 'Cancel order'),
              color: ThixPolicy.danger,
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
    final title = _VdValidators.sanitize(
      (product['title'] ?? item['title'] ?? context.vdT('Produit', 'Product')).toString(),
      maxLength: _kMaxTitleLength,
    );
    final qty = _VdValidators.safeInt(item['quantity'], fallback: 1);
    final price = _VdValidators.safeDouble(item['price']);
    final variant = _VdValidators.sanitize(item['variant']?.toString(), maxLength: 30);
    final color = _VdValidators.sanitize(item['color']?.toString(), maxLength: 30);
    final imageUrl = _VdValidators.sanitizeUrl(product['image_url']?.toString());

    final symbol = _VdValidators.currencySymbol(currency);
    final formattedPrice = _VdValidators.formatAmount(price, locale, isUSD: currency == 'USD');
    final formattedTotal = _VdValidators.formatAmount(price * qty, locale, isUSD: currency == 'USD');

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
                    [if (variant.isNotEmpty) 'Var: $variant', if (color.isNotEmpty) '${context.vdT('Couleur', 'Color')}: $color'].join(' | '),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${context.vdT('Qté', 'Qty')}: $qty × $formattedPrice $symbol = $formattedTotal $symbol',
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

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
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
class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop header skeleton
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.inkDeep.withOpacity(0.2)]),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          // KPI grid skeleton
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: List.generate(
              4,
              (_) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 16, width: 40, color: Colors.grey.shade200),
                          const SizedBox(height: 6),
                          Container(height: 12, width: 70, color: Colors.grey.shade200),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Actions grid skeleton
          Container(height: 16, width: 120, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: List.generate(
              8,
              (_) => Container(
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 40, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              context.vdT('Erreur de chargement', 'Loading error'),
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
              label: context.vdT('Réessayer', 'Retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  context.vdT('Réessayer', 'Retry'),
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
