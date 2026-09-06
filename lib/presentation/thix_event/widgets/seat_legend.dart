// lib/presentation/thix_event/widgets/seat_legend.dart
//
// SeatLegend — Production Enterprise (i18n + A11y + Design System)
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Utilisation EventTheme (couleurs sémantiques)
// - Semantics pour accessibilité
// - Spacing/radius via ThixPolicy
// - Logging structuré
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color surface = Color(0xFF101B30);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color textSecondary = Color(0xFFA8B6CC);
  
  // États des sièges (tokens sémantiques)
  static const Color seatAvailable = ThixPolicy.success; // Vert
  static const Color seatReserved = ThixPolicy.warning; // Orange
  static const Color seatSold = ThixPolicy.danger; // Rouge
}

// ============================================================================
// LOGGING
// ============================================================================
class _SeatLegendLogger {
  static const _tag = 'SeatLegend';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// WIDGET
// ============================================================================
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    _SeatLegendLogger.info('SeatLegend rendered');
    
    return Semantics(
      label: l10n.t('seat_legend_title'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s14,
          vertical: ThixPolicy.s14,
        ),
        margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        decoration: BoxDecoration(
          color: EventTheme.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: EventTheme.border),
        ),
        child: Wrap(
          spacing: ThixPolicy.s14,
          runSpacing: ThixPolicy.s10,
          alignment: WrapAlignment.center,
          children: [
            _LegendItem(
              color: EventTheme.seatAvailable,
              label: l10n.t('seat_legend_available'),
            ),
            _LegendItem(
              color: EventTheme.primary,
              label: l10n.t('seat_legend_selected'),
            ),
            _LegendItem(
              color: EventTheme.seatReserved,
              label: l10n.t('seat_legend_reserved'),
            ),
            _LegendItem(
              color: EventTheme.seatSold,
              label: l10n.t('seat_legend_sold'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LEGEND ITEM
// ============================================================================
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              border: Border.all(color: color, width: 1.2),
              borderRadius: BorderRadius.circular(ThixPolicy.s4),
            ),
          ),
          const SizedBox(width: ThixPolicy.s6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: EventTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
