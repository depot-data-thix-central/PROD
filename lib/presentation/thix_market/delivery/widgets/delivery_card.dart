// lib/presentation/thix_market/delivery/delivery_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

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

  static DateTime? safeParseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }

  static String shortId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _DeliveryL10n on BuildContext {
  String delT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// STATUT CONFIGURATION
// ============================================================================
class _StatusConfig {
  final String labelFr;
  final String labelEn;
  final Color color;
  final IconData icon;

  const _StatusConfig({
    required this.labelFr,
    required this.labelEn,
    required this.color,
    required this.icon,
  });

  String label(BuildContext context) => context.delT(labelFr, labelEn);
}

const Map<String, _StatusConfig> _kStatusMap = {
  'preparing': _StatusConfig(
    labelFr: 'En préparation',
    labelEn: 'Preparing',
    color: ThixPolicy.gold,
    icon: Icons.kitchen_rounded,
  ),
  'picked_up': _StatusConfig(
    labelFr: 'Récupéré',
    labelEn: 'Picked up',
    color: ThixPolicy.primary,
    icon: Icons.inventory_2_rounded,
  ),
  'in_transit': _StatusConfig(
    labelFr: 'En transit',
    labelEn: 'In transit',
    color: ThixPolicy.primary,
    icon: Icons.local_shipping_rounded,
  ),
  'out_for_delivery': _StatusConfig(
    labelFr: 'En livraison',
    labelEn: 'Out for delivery',
    color: ThixPolicy.success,
    icon: Icons.delivery_dining_rounded,
  ),
  'delivered': _StatusConfig(
    labelFr: 'Livré',
    labelEn: 'Delivered',
    color: ThixPolicy.success,
    icon: Icons.check_circle_rounded,
  ),
  'cancelled': _StatusConfig(
    labelFr: 'Annulé',
    labelEn: 'Cancelled',
    color: ThixPolicy.danger,
    icon: Icons.cancel_rounded,
  ),
};

_StatusConfig _getStatusConfig(String status) {
  return _kStatusMap[status] ??
      _StatusConfig(
        labelFr: status,
        labelEn: status,
        color: ThixPolicy.textMuted,
        icon: Icons.help_outline_rounded,
      );
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    // Validation et sanitization
    final status = _DeliveryValidators.sanitize(delivery['status']?.toString(), maxLength: 30).toLowerCase();
    final statusConfig = _getStatusConfig(status.isEmpty ? 'preparing' : status);

    final orderId = delivery['order_id']?.toString();
    final shortOrderId = _DeliveryValidators.shortId(orderId);
    final isValidOrderId = _DeliveryValidators.isValidId(orderId);

    final trackingNumber = _DeliveryValidators.sanitize(
      delivery['tracking_number']?.toString(),
      maxLength: 50,
    );

    final createdAt = _DeliveryValidators.safeParseDate(delivery['created_at']?.toString());
    final formattedDate = createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm', context.localeCode).format(createdAt)
        : context.delT('Date inconnue', 'Unknown date');

    // Labels i18n
    final orderLabel = context.delT('Commande', 'Order');
    final trackingLabel = context.delT('N° suivi', 'Tracking');
    final orderedOnLabel = context.delT('Commandé le', 'Ordered on');
    final trackButtonLabel = context.delT('Suivre', 'Track');

    return Semantics(
      button: true,
      label: '$orderLabel $shortOrderId, ${statusConfig.label(context)}, $orderedOnLabel $formattedDate',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap != null
                ? () {
                    HapticFeedback.selectionClick();
                    debugPrint('[DeliveryCard] 👆 Card tapped: $shortOrderId');
                    onTap?.call();
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header : Order ID + Status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$orderLabel #$shortOrderId',
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
                      _StatusBadge(
                        label: statusConfig.label(context),
                        color: statusConfig.color,
                        icon: statusConfig.icon,
                      ),
                    ],
                  ),

                  if (trackingNumber.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 12, color: ThixPolicy.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SelectableText(
                            '$trackingLabel: $trackingNumber',
                            style: ThixPolicy.captionStyle.copyWith(
                              fontSize: 12,
                              color: ThixPolicy.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: ThixPolicy.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$orderedOnLabel $formattedDate',
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 11,
                          color: ThixPolicy.textMuted,
                        ),
                      ),
                    ],
                  ),

                  if (onTrack != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: Semantics(
                        button: true,
                        label: trackButtonLabel,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            debugPrint('[DeliveryCard] 🗺️ Track tapped: $shortOrderId');
                            onTrack?.call();
                          },
                          icon: Icon(Icons.map_rounded, size: 16, color: ThixPolicy.primary),
                          label: Text(
                            trackButtonLabel,
                            style: ThixPolicy.labelStyle.copyWith(
                              color: ThixPolicy.primary,
                              fontWeight: ThixPolicy.semiBold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: ThixPolicy.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: ThixPolicy.captionStyle.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ],
      ),
    );
  }
}
