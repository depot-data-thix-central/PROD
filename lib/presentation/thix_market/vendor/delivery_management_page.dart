// lib/presentation/thix_market/vendor/delivery_management_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxOrderIdDisplay = 8;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _DeliveryValidators {
  _DeliveryValidators._();

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

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String shortId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= _kMaxOrderIdDisplay) return id.toUpperCase();
    return id.substring(0, _kMaxOrderIdDisplay).toUpperCase();
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    return 'Une erreur est survenue. Réessayez.';
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

  static String formatSmartDate(String? dateStr, String locale) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Aujourd\'hui ${DateFormat('HH:mm', locale).format(date)}';
      } else if (dateOnly == yesterday) {
        return 'Hier ${DateFormat('HH:mm', locale).format(date)}';
      } else {
        return DateFormat('dd MMM yyyy, HH:mm', locale).format(date);
      }
    } catch (_) {
      return dateStr;
    }
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _DeliveryMgmtL10n on BuildContext {
  String dmT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
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
        debugPrint('[DeliveryMgmt] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[DeliveryMgmt] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[DeliveryMgmt] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// STATUT CONFIGURATION
// ============================================================================
class _DeliveryStatus {
  final String key;
  final String labelFr;
  final String labelEn;
  final IconData icon;
  final Color color;

  const _DeliveryStatus({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
    required this.color,
  });

  String label(BuildContext context) => context.dmT(labelFr, labelEn);
}

const List<_DeliveryStatus> _kStatuses = [
  _DeliveryStatus(
    key: 'pending',
    labelFr: 'En attente',
    labelEn: 'Pending',
    icon: Icons.pending_actions_rounded,
    color: ThixPolicy.gold,
  ),
  _DeliveryStatus(
    key: 'shipped',
    labelFr: 'Expédiée',
    labelEn: 'Shipped',
    icon: Icons.local_shipping_rounded,
    color: ThixPolicy.primary,
  ),
  _DeliveryStatus(
    key: 'in_transit',
    labelFr: 'En transit',
    labelEn: 'In transit',
    icon: Icons.directions_car_rounded,
    color: ThixPolicy.primary,
  ),
  _DeliveryStatus(
    key: 'delivered',
    labelFr: 'Livrée',
    labelEn: 'Delivered',
    icon: Icons.check_circle_rounded,
    color: ThixPolicy.success,
  ),
];

_DeliveryStatus _getStatus(String key) {
  return _kStatuses.firstWhere(
    (s) => s.key == key,
    orElse: () => _kStatuses.first,
  );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class DeliveryManagementPage extends StatefulWidget {
  const DeliveryManagementPage({super.key});

  @override
  State<DeliveryManagementPage> createState() => _DeliveryManagementPageState();
}

class _DeliveryManagementPageState extends State<DeliveryManagementPage> {
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;
  String? _updatingOrderId;

  @override
  void initState() {
    super.initState();
    debugPrint('[DeliveryMgmt] 🚚 Page opened');
    _loadDeliveries();
  }

  @override
  void dispose() {
    debugPrint('[DeliveryMgmt] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    if (_isLoading && _deliveries.isNotEmpty) return; // Pull-to-refresh garde la liste

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (!_DeliveryValidators.isValidId(userId)) {
        debugPrint('[DeliveryMgmt] ⚠️ No authenticated user');
        setState(() {
          _error = context.dmT('Veuillez vous connecter', 'Please sign in');
          _isLoading = false;
        });
        return;
      }

      // 1. Récupérer les shops de l'utilisateur (CORRECTION DU BUG)
      final shopsResponse = await _withRetry(
        () => Supabase.instance.client.from('shops').select('id').eq('owner_id', userId!),
        label: 'fetchUserShops',
      );

      final shopIds = (shopsResponse as List)
          .map((e) => (e as Map)['id']?.toString())
          .whereType<String>()
          .where(_DeliveryValidators.isValidId)
          .toList();

      if (shopIds.isEmpty) {
        debugPrint('[DeliveryMgmt] ℹ️ No shops owned by user');
        setState(() {
          _deliveries = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Récupérer les commandes des shops avec delivery_status != delivered
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('orders')
            .select('id, total, currency, status, delivery_status, created_at')
            .inFilter('shop_id', shopIds)
            .neq('delivery_status', 'delivered')
            .order('created_at', ascending: false),
        label: 'loadDeliveries[${shopIds.length} shops]',
      );

      final deliveries = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _deliveries = deliveries;
          _isLoading = false;
        });
      }
      debugPrint('[DeliveryMgmt] ✓ Loaded ${deliveries.length} deliveries');
    } catch (e) {
      debugPrint('[DeliveryMgmt] ❌ Load deliveries error: $e');
      if (mounted) {
        setState(() {
          _error = _DeliveryValidators.friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showStatusSheet(Map<String, dynamic> delivery) async {
    if (_isUpdating) return;

    final orderId = delivery['id']?.toString();
    if (!_DeliveryValidators.isValidId(orderId)) {
      _showError(context.dmT('Identifiant de commande invalide', 'Invalid order ID'));
      return;
    }

    final currentStatus = delivery['delivery_status']?.toString() ?? 'pending';

    HapticFeedback.selectionClick();

    final newStatus = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StatusBottomSheet(
        currentStatus: currentStatus,
        orderIdShort: _DeliveryValidators.shortId(orderId),
      ),
    );

    if (newStatus == null || newStatus == currentStatus || !mounted) return;

    // Confirmation avant changement
    final statusConfig = _getStatus(newStatus);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusConfig.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusConfig.icon, color: statusConfig.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.dmT('Changer le statut ?', 'Change status?'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.dmT(
            'Passer la commande #${_DeliveryValidators.shortId(orderId)} en "${statusConfig.label(context)}" ?',
            'Change order #${_DeliveryValidators.shortId(orderId)} to "${statusConfig.label(context)}"?',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.dmT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: statusConfig.color,
              foregroundColor: Colors.white,
            ),
            child: Text(context.dmT('Confirmer', 'Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _updateDeliveryStatus(orderId!, newStatus);
  }

  Future<void> _updateDeliveryStatus(String orderId, String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _updatingOrderId = orderId;
    });

    HapticFeedback.mediumImpact();
    debugPrint('[DeliveryMgmt] 🔄 Updating ${_DeliveryValidators.shortId(orderId)} → $newStatus');

    try {
      await _withRetry(
        () => Supabase.instance.client
            .from('orders')
            .update({
              'delivery_status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId),
        label: 'updateDeliveryStatus[$orderId]',
      );

      debugPrint('[DeliveryMgmt] ✓ Status updated to $newStatus');

      if (mounted) {
        _showSuccess(context.dmT('Statut mis à jour', 'Status updated'));
        await _loadDeliveries();
      }
    } catch (e) {
      debugPrint('[DeliveryMgmt] ❌ Update status error: $e');
      if (mounted) {
        _showError(_DeliveryValidators.friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _updatingOrderId = null;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          context.dmT('Gestion des livraisons', 'Delivery Management'),
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: context.dmT('Retour', 'Back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            tooltip: context.dmT('Retour', 'Back'),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: context.dmT('Actualiser', 'Refresh'),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
              tooltip: context.dmT('Actualiser', 'Refresh'),
              onPressed: _isLoading ? null : () {
                HapticFeedback.selectionClick();
                _loadDeliveries();
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _deliveries.isEmpty) {
      return const _SkeletonDelivery();
    }

    if (_error != null && _deliveries.isEmpty) {
      return _ErrorState(
        message: _error!,
        onRetry: _loadDeliveries,
        isRetrying: _isLoading,
      );
    }

    if (_deliveries.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _loadDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) {
          final delivery = _deliveries[index];
          return _DeliveryCard(
            delivery: delivery,
            isUpdating: _updatingOrderId == delivery['id']?.toString(),
            onTap: () => _showStatusSheet(delivery),
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final bool isUpdating;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.delivery,
    required this.isUpdating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = delivery['id']?.toString();
    final shortId = _DeliveryValidators.shortId(orderId);
    final total = _DeliveryValidators.safeDouble(delivery['total']);
    final currency = delivery['currency']?.toString() ?? 'FC';
    final isUSD = currency.toUpperCase() == 'USD';
    final formattedTotal = _DeliveryValidators.formatAmount(total, context.localeCode, isUSD: isUSD);
    final createdAt = _DeliveryValidators.formatSmartDate(delivery['created_at']?.toString(), context.localeCode);
    final currentStatus = delivery['delivery_status']?.toString() ?? 'pending';
    final statusConfig = _getStatus(currentStatus);

    final orderLabel = context.dmT('Commande', 'Order');
    final orderedOnLabel = context.dmT('Commandé le', 'Ordered on');
    final changeStatusLabel = context.dmT('Changer le statut', 'Change status');

    return Semantics(
      button: true,
      label: '$orderLabel $shortId, ${statusConfig.label(context)}, $formattedTotal $currency',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isUpdating ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isUpdating ? null : onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône statut
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusConfig.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isUpdating
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: ThixPolicy.primary),
                              ),
                            )
                          : Icon(statusConfig.icon, color: statusConfig.color, size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusConfig.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusConfig.color.withOpacity(0.25)),
                                ),
                                child: Text(
                                  statusConfig.label(context),
                                  style: ThixPolicy.captionStyle.copyWith(
                                    color: statusConfig.color,
                                    fontSize: 11,
                                    fontWeight: ThixPolicy.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.payments_rounded, size: 12, color: ThixPolicy.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '$formattedTotal $currency',
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  color: ThixPolicy.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: ThixPolicy.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$orderedOnLabel $createdAt',
                                  style: ThixPolicy.captionStyle.copyWith(
                                    fontSize: 11,
                                    color: ThixPolicy.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 14, color: ThixPolicy.primary),
                              const SizedBox(width: 6),
                              Text(
                                changeStatusLabel,
                                style: ThixPolicy.captionStyle.copyWith(
                                  color: ThixPolicy.primary,
                                  fontWeight: ThixPolicy.semiBold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBottomSheet extends StatelessWidget {
  final String currentStatus;
  final String orderIdShort;

  const _StatusBottomSheet({
    required this.currentStatus,
    required this.orderIdShort,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.dmT('Statut de livraison', 'Delivery status'),
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            '${context.dmT('Commande', 'Order')} #$orderIdShort',
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          ..._kStatuses.map((status) {
            final isSelected = status.key == currentStatus;
            return Semantics(
              button: true,
              selected: isSelected,
              label: status.label(context),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(isSelected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(status.icon, color: status.color, size: 18),
                ),
                title: Text(
                  status.label(context),
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: isSelected ? status.color : ThixPolicy.textMain,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: ThixPolicy.success)
                    : const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, status.key);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SkeletonDelivery extends StatelessWidget {
  const _SkeletonDelivery();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 180, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 160, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 100, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined, size: 64, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              context.dmT('Aucune livraison en cours', 'No ongoing deliveries'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.dmT(
                'Les livraisons en cours apparaîtront ici',
                'Ongoing deliveries will appear here',
              ),
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
  final bool isRetrying;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isRetrying,
  });

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
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              context.dmT('Erreur de chargement', 'Loading error'),
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
              label: context.dmT('Réessayer', 'Retry'),
              child: ElevatedButton.icon(
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  context.dmT('Réessayer', 'Retry'),
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
