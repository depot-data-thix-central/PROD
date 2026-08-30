// lib/presentation/thix_market/vendor/widgets/order_management_tile.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxNameLength = 80;
const int _kMaxAddressLength = 200;
const int _kMaxPhoneLength = 20;
const int _kMaxProductNameLength = 80;

// ============================================================================
// VALIDATORS
// ============================================================================
class _OtValidators {
  _OtValidators._();

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
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  static DateTime? safeParseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return null;
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
    if (msg.contains('not found') || msg.contains('404')) return 'Commande introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _OtL10n on BuildContext {
  String otT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
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
  final bool requiresConfirmation;

  const _OrderStatus({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
    required this.color,
    this.requiresConfirmation = false,
  });

  String label(BuildContext context) => context.otT(labelFr, labelEn);
}

const List<_OrderStatus> _kStatuses = [
  _OrderStatus(
    key: 'pending',
    labelFr: 'En attente',
    labelEn: 'Pending',
    icon: Icons.hourglass_top_rounded,
    color: ThixPolicy.gold,
  ),
  _OrderStatus(
    key: 'confirmed',
    labelFr: 'Confirmée',
    labelEn: 'Confirmed',
    icon: Icons.check_circle_outline_rounded,
    color: ThixPolicy.primary,
  ),
  _OrderStatus(
    key: 'preparing',
    labelFr: 'En préparation',
    labelEn: 'Preparing',
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
    requiresConfirmation: true,
  ),
  _OrderStatus(
    key: 'cancelled',
    labelFr: 'Annulée',
    labelEn: 'Cancelled',
    icon: Icons.cancel_rounded,
    color: ThixPolicy.danger,
    requiresConfirmation: true,
  ),
];

_OrderStatus _getStatus(String key) {
  return _kStatuses.firstWhere(
    (s) => s.key == key.toLowerCase(),
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
// HELPERS
// ============================================================================
Future<T> _otRetry<T>(
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
        debugPrint('[OrderTile] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[OrderTile] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[OrderTile] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class OrderManagementTile extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic>)? onStatusChanged;

  const OrderManagementTile({
    super.key,
    required this.order,
    this.onStatusChanged,
  });

  @override
  State<OrderManagementTile> createState() => _OrderManagementTileState();
}

class _OrderManagementTileState extends State<OrderManagementTile> {
  bool _isUpdating = false;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = (widget.order['status']?.toString() ?? 'pending').toLowerCase();
  }

  @override
  void didUpdateWidget(covariant OrderManagementTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newStatus = (widget.order['status']?.toString() ?? 'pending').toLowerCase();
    if (newStatus != _currentStatus) {
      setState(() => _currentStatus = newStatus);
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================
  Future<bool> _confirmStatusChange(_OrderStatus status, String shortId) async {
    if (!status.requiresConfirmation) return true;

    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(status.icon, color: status.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.otT('Confirmer le changement', 'Confirm change'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.otT(
            'Passer la commande #$shortId en "${status.label(context)}" ? Cette action est importante.',
            'Change order #$shortId to "${status.label(context)}"? This action is important.',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.otT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status.color,
              foregroundColor: Colors.white,
            ),
            child: Text(context.otT('Confirmer', 'Confirm')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================
  Future<void> _updateStatus(String newStatus) async {
    final orderId = widget.order['id']?.toString();
    if (!_OtValidators.isValidId(orderId)) {
      _showError(context.otT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    if (_isUpdating) {
      debugPrint('[OrderTile] ⚠️ Update already in progress for ${_OtValidators.shortId(orderId!)}');
      return;
    }

    final statusConfig = _getStatus(newStatus);
    final shortId = _OtValidators.shortId(orderId!);

    // Confirmation pour statuts critiques
    final confirmed = await _confirmStatusChange(statusConfig, shortId);
    if (!confirmed || !mounted) return;

    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();
    debugPrint('[OrderTile] 🔄 Updating ${_OtValidators.shortId(orderId)} → $newStatus');

    try {
      await _otRetry(
        () => Supabase.instance.client.from('orders').update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId),
        label: 'updateStatus[$orderId → $newStatus]',
      );

      if (!mounted) return;

      setState(() => _currentStatus = newStatus);
      widget.onStatusChanged?.call({...widget.order, 'status': newStatus});

      _showSuccess(
        '${context.otT('Commande', 'Order')} ${statusConfig.label(context)}',
      );
      debugPrint('[OrderTile] ✓ Status updated to $newStatus');
    } catch (e) {
      debugPrint('[OrderTile] ❌ Update status error: $e');
      if (mounted) _showError(_OtValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ============================================================
  // STATUS BOTTOM SHEET
  // ============================================================
  void _showStatusDialog() {
    if (_isUpdating) return;

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StatusBottomSheet(
        currentStatus: _currentStatus,
        title: context.otT('Changer le statut', 'Change status'),
        onStatusSelected: (newStatus) {
          Navigator.pop(ctx);
          _updateStatus(newStatus);
        },
      ),
    );
  }

  // ============================================================
  // VIEW DETAILS
  // ============================================================
  void _viewOrderDetail() {
    final orderId = widget.order['id']?.toString();
    if (!_OtValidators.isValidId(orderId)) {
      _showError(context.otT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    HapticFeedback.selectionClick();
    debugPrint('[OrderTile] 👁️ View details: ${_OtValidators.shortId(orderId!)}');
    try {
      context.pushNamed(
        'marketOrderDetail',
        pathParameters: {'orderId': orderId},
      );
    } catch (e) {
      debugPrint('[OrderTile] ❌ Navigation error: $e');
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
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

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['id']?.toString() ?? '';
    final shortId = _OtValidators.shortId(orderId);
    final statusConfig = _getStatus(_currentStatus);

    final customerName = _OtValidators.sanitize(
      widget.order['customer_name']?.toString(),
      maxLength: _kMaxNameLength,
    );
    final customerPhone = _OtValidators.sanitize(
      widget.order['customer_phone']?.toString(),
      maxLength: _kMaxPhoneLength,
    );
    final shippingAddress = _OtValidators.sanitize(
      widget.order['shipping_address']?.toString(),
      maxLength: _kMaxAddressLength,
    );

    final createdAt = _OtValidators.safeParseDate(widget.order['created_at']?.toString());
    final formattedDate = createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm', context.localeCode).format(createdAt)
        : '';

    final total = _OtValidators.safeDouble(widget.order['total']);
    final currency = (widget.order['currency']?.toString() ?? 'FC').toUpperCase();
    final symbol = currency == 'USD' ? '\$' : 'FC';
    final formattedTotal = _OtValidators.formatAmount(total, context.localeCode, isUSD: currency == 'USD');

    final rawItems = widget.order['items'];
    final items = rawItems is List
        ? rawItems.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : <Map<String, dynamic>>[];

    final isActionable = _currentStatus != 'cancelled' && _currentStatus != 'delivered';

    return Semantics(
      label: '${context.otT('Commande', 'Order')} #$shortId, ${statusConfig.label(context)}, $formattedTotal $symbol',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header : Order ID + Status badge
              _OrderHeader(
                shortId: shortId,
                status: statusConfig,
                orderLabel: context.otT('Commande', 'Order'),
              ),
              const SizedBox(height: 10),

              // Client info
              _CustomerInfo(
                name: customerName.isEmpty ? context.otT('Client', 'Customer') : customerName,
                phone: customerPhone,
                address: shippingAddress,
              ),

              if (formattedDate.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: ThixPolicy.microStyle.copyWith(
                        fontSize: 11,
                        color: ThixPolicy.textMuted,
                      ),
                    ),
                  ],
                ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              ),

              // Items
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.otT('Aucun article', 'No items'),
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                  ),
                )
              else
                ...items.map((item) => _OrderItemTile(
                      item: item,
                      currency: currency,
                      locale: context.localeCode,
                    )),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              ),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.otT('Total', 'Total'),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                  Text(
                    '$formattedTotal $symbol',
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Actions
              _OrderActions(
                isActionable: isActionable,
                isUpdating: _isUpdating,
                onChangeStatus: _showStatusDialog,
                onViewDetails: _viewOrderDetail,
                changeStatusLabel: context.otT('Changer statut', 'Change status'),
                detailsLabel: context.otT('Détails', 'Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _OrderHeader extends StatelessWidget {
  final String shortId;
  final _OrderStatus status;
  final String orderLabel;

  const _OrderHeader({
    required this.shortId,
    required this.status,
    required this.orderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '$orderLabel #$shortId',
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: status.color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 12, color: status.color),
              const SizedBox(width: 4),
              Text(
                status.label(context),
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 11,
                  fontWeight: ThixPolicy.bold,
                  color: status.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerInfo extends StatelessWidget {
  final String name;
  final String phone;
  final String address;

  const _CustomerInfo({
    required this.name,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline_rounded, size: 14, color: ThixPolicy.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.semiBold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(Icons.phone_outlined, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 4),
              Text(
                phone,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMain),
              ),
            ],
          ],
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String currency;
  final String locale;

  const _OrderItemTile({
    required this.item,
    required this.currency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final name = _OtValidators.sanitize(
      item['name']?.toString(),
      maxLength: _kMaxProductNameLength,
    );
    final quantity = _OtValidators.safeInt(item['quantity'], fallback: 1);
    final price = _OtValidators.safeDouble(item['price']);
    final imageUrl = _OtValidators.sanitizeUrl(item['image_url']?.toString());
    final subtotal = price * quantity;

    final symbol = currency == 'USD' ? '\$' : 'FC';
    final formattedSubtotal = _OtValidators.formatAmount(subtotal, locale, isUSD: currency == 'USD');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 40,
                      height: 40,
                      color: ThixPolicy.surfaceSoft,
                      child: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      color: ThixPolicy.surfaceSoft,
                      child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 20),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 20),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.otT('Produit', 'Product') : name,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '× $quantity',
                  style: ThixPolicy.microStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$formattedSubtotal $symbol',
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final bool isActionable;
  final bool isUpdating;
  final VoidCallback onChangeStatus;
  final VoidCallback onViewDetails;
  final String changeStatusLabel;
  final String detailsLabel;

  const _OrderActions({
    required this.isActionable,
    required this.isUpdating,
    required this.onChangeStatus,
    required this.onViewDetails,
    required this.changeStatusLabel,
    required this.detailsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isActionable) ...[
          Expanded(
            child: Semantics(
              button: true,
              label: changeStatusLabel,
              enabled: !isUpdating,
              child: OutlinedButton.icon(
                onPressed: isUpdating ? null : onChangeStatus,
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  changeStatusLabel,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.primary,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThixPolicy.primary,
                  side: BorderSide(color: ThixPolicy.primary.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Semantics(
            button: true,
            label: detailsLabel,
            child: OutlinedButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: Text(
                detailsLabel,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain,
                side: BorderSide(color: ThixPolicy.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS BOTTOM SHEET
// ============================================================================
class _StatusBottomSheet extends StatelessWidget {
  final String currentStatus;
  final String title;
  final ValueChanged<String> onStatusSelected;

  const _StatusBottomSheet({
    required this.currentStatus,
    required this.title,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: ThixPolicy.h3Style.copyWith(
              fontSize: 18,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 16),
          ..._kStatuses.map((status) {
            final isCurrent = currentStatus == status.key;
            return Semantics(
              button: true,
              selected: isCurrent,
              label: status.label(context),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(isCurrent ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(status.icon, color: status.color, size: 18),
                ),
                title: Text(
                  status.label(context),
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: isCurrent ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: isCurrent ? status.color : ThixPolicy.textMain,
                  ),
                ),
                trailing: isCurrent
                    ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success)
                    : const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onStatusSelected(status.key);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
