// lib/presentation/thix_market/delivery/delivery_status_timeline.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _TimelineValidators {
  _TimelineValidators._();

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

  static String formatSmartDate(DateTime? date, String locale) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    try {
      if (dateOnly == today) {
        return 'Aujourd\'hui ${DateFormat('HH:mm', locale).format(date)}';
      } else if (dateOnly == yesterday) {
        return 'Hier ${DateFormat('HH:mm', locale).format(date)}';
      } else {
        return DateFormat('dd MMM yyyy, HH:mm', locale).format(date);
      }
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _TimelineL10n on BuildContext {
  String timeT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// STATUT CONFIGURATION
// ============================================================================
class _StatusConfig {
  final String key;
  final String labelFr;
  final String labelEn;
  final IconData icon;
  final Color color;
  final String subtitleFr;
  final String subtitleEn;

  const _StatusConfig({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
    required this.color,
    this.subtitleFr = 'En cours de traitement',
    this.subtitleEn = 'In progress',
  });

  String label(BuildContext context) => context.timeT(labelFr, labelEn);
  String subtitle(BuildContext context) => context.timeT(subtitleFr, subtitleEn);
}

const List<_StatusConfig> _kDefaultStatuses = [
  _StatusConfig(
    key: 'preparing',
    labelFr: 'Préparation',
    labelEn: 'Preparing',
    icon: Icons.inventory_2_rounded,
    color: ThixPolicy.gold,
    subtitleFr: 'Votre commande est en préparation',
    subtitleEn: 'Your order is being prepared',
  ),
  _StatusConfig(
    key: 'picked_up',
    labelFr: 'Récupéré',
    labelEn: 'Picked up',
    icon: Icons.task_alt_rounded,
    color: ThixPolicy.primary,
    subtitleFr: 'Colis récupéré par le livreur',
    subtitleEn: 'Package picked up by courier',
  ),
  _StatusConfig(
    key: 'in_transit',
    labelFr: 'En transit',
    labelEn: 'In transit',
    icon: Icons.local_shipping_rounded,
    color: ThixPolicy.primary,
    subtitleFr: 'Votre colis est en route',
    subtitleEn: 'Your package is on its way',
  ),
  _StatusConfig(
    key: 'out_for_delivery',
    labelFr: 'En livraison',
    labelEn: 'Out for delivery',
    icon: Icons.delivery_dining_rounded,
    color: ThixPolicy.primary,
    subtitleFr: 'Le livreur arrive bientôt',
    subtitleEn: 'Courier arriving soon',
  ),
  _StatusConfig(
    key: 'delivered',
    labelFr: 'Livré',
    labelEn: 'Delivered',
    icon: Icons.home_rounded,
    color: ThixPolicy.success,
    subtitleFr: 'Commande livrée avec succès',
    subtitleEn: 'Order successfully delivered',
  ),
];

const _StatusConfig _kCancelledStatus = _StatusConfig(
  key: 'cancelled',
  labelFr: 'Annulé',
  labelEn: 'Cancelled',
  icon: Icons.cancel_rounded,
  color: ThixPolicy.danger,
  subtitleFr: 'Livraison annulée',
  subtitleEn: 'Delivery cancelled',
);

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class DeliveryStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final List<Map<String, dynamic>>? customStatuses;
  /// Map optionnelle des timestamps par status key
  final Map<String, String?>? statusTimestamps;

  const DeliveryStatusTimeline({
    super.key,
    required this.currentStatus,
    this.customStatuses,
    this.statusTimestamps,
  });

  /// Construit la liste des statuts (custom ou défaut)
  List<_StatusConfig> _buildStatuses() {
    if (customStatuses != null && customStatuses!.isNotEmpty) {
      return customStatuses!.map((e) {
        final key = e['key']?.toString() ?? '';
        final defaultConfig = _kDefaultStatuses.where((s) => s.key == key).firstOrNull;

        return _StatusConfig(
          key: key,
          labelFr: e['label_fr']?.toString() ?? defaultConfig?.labelFr ?? _TimelineValidators.sanitize(e['label']?.toString(), maxLength: 40),
          labelEn: e['label_en']?.toString() ?? defaultConfig?.labelEn ?? _TimelineValidators.sanitize(e['label']?.toString(), maxLength: 40),
          icon: e['icon'] as IconData? ?? defaultConfig?.icon ?? Icons.circle_outlined,
          color: defaultConfig?.color ?? ThixPolicy.primary,
          subtitleFr: defaultConfig?.subtitleFr ?? 'En cours de traitement',
          subtitleEn: defaultConfig?.subtitleEn ?? 'In progress',
        );
      }).toList();
    }
    return _kDefaultStatuses;
  }

  /// Détermine l'état d'un statut par rapport au courant
  _ItemState _getItemState(String statusKey, List<_StatusConfig> statuses) {
    // Cas spécial : cancelled
    if (currentStatus == 'cancelled') {
      if (statusKey == 'cancelled') return _ItemState.current;
      return _ItemState.incomplete;
    }

    final keys = statuses.map((s) => s.key).toList();
    final currentIndex = keys.indexOf(currentStatus);
    final statusIndex = keys.indexOf(statusKey);

    // Status courant non trouvé dans la liste → tout incomplet
    if (currentIndex == -1) return _ItemState.incomplete;
    // Status non trouvé → incomplet
    if (statusIndex == -1) return _ItemState.incomplete;

    if (statusIndex < currentIndex) return _ItemState.completed;
    if (statusIndex == currentIndex) return _ItemState.current;
    return _ItemState.incomplete;
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _buildStatuses();

    // Si cancelled, on ajoute le statut cancelled à la fin
    final effectiveStatuses = currentStatus == 'cancelled'
        ? [...statuses, _kCancelledStatus]
        : statuses;

    final sanitizedCurrentStatus = _TimelineValidators.sanitize(currentStatus, maxLength: 30).toLowerCase();

    return Semantics(
      label: context.timeT('Statut de la livraison', 'Delivery status'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.timeT('Statut de la livraison', 'Delivery status'),
            style: ThixPolicy.h3Style.copyWith(
              fontSize: 18,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 16),
          ...effectiveStatuses.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final state = _getItemState(status.key, effectiveStatuses);
            final isLast = index == effectiveStatuses.length - 1;

            // Timestamp si disponible
            final timestampStr = statusTimestamps?[status.key];
            final timestamp = _TimelineValidators.safeParseDate(timestampStr);
            final formattedTimestamp = _TimelineValidators.formatSmartDate(timestamp, context.localeCode);

            return _TimelineItem(
              config: status,
              state: state,
              isLast: isLast,
              timestamp: formattedTimestamp,
              currentIndex: sanitizedCurrentStatus == status.key ? index : null,
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAT D'UN ITEM
// ============================================================================
enum _ItemState {
  completed,
  current,
  incomplete,
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _TimelineItem extends StatelessWidget {
  final _StatusConfig config;
  final _ItemState state;
  final bool isLast;
  final String timestamp;
  final int? currentIndex;

  const _TimelineItem({
    required this.config,
    required this.state,
    required this.isLast,
    required this.timestamp,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = state == _ItemState.completed;
    final isCurrent = state == _ItemState.current;
    final isIncomplete = state == _ItemState.incomplete;

    // Couleurs selon état
    final circleColor = isCompleted
        ? ThixPolicy.success.withOpacity(0.12)
        : isCurrent
            ? config.color.withOpacity(0.12)
            : ThixPolicy.border.withOpacity(0.3);
    final iconColor = isCompleted
        ? ThixPolicy.success
        : isCurrent
            ? config.color
            : ThixPolicy.textDisabled;
    final labelColor = isCompleted
        ? ThixPolicy.success
        : isCurrent
            ? config.color
            : ThixPolicy.textMuted;
    final connectorColor = isCompleted
        ? ThixPolicy.success.withOpacity(0.4)
        : ThixPolicy.border.withOpacity(0.4);

    return Semantics(
      label: '${config.label(context)}, ${isCompleted ? context.timeT("complété", "completed") : isCurrent ? context.timeT("en cours", "in progress") : context.timeT("à venir", "upcoming")}',
      selected: isCurrent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne gauche : cercle + connecteur
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: config.color.withOpacity(0.4), width: 2)
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check_rounded, color: ThixPolicy.success, size: 20)
                    : Icon(config.icon, color: iconColor, size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 24,
                  color: connectorColor,
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Colonne droite : contenu
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label(context),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: isCurrent ? ThixPolicy.bold : ThixPolicy.semiBold,
                      color: labelColor,
                      fontSize: 14,
                    ),
                  ),
                  if (isCurrent || timestamp.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    if (isCurrent && timestamp.isEmpty)
                      Text(
                        config.subtitle(context),
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 12,
                          color: config.color.withOpacity(0.8),
                        ),
                      ),
                    if (timestamp.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: isCurrent ? config.color.withOpacity(0.7) : ThixPolicy.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timestamp,
                            style: ThixPolicy.captionStyle.copyWith(
                              fontSize: 11,
                              color: isCurrent ? config.color.withOpacity(0.8) : ThixPolicy.textMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
