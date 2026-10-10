import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import '../../data/models/seat_model.dart';

/// Helper de traduction tolérant.
/// Si la clé n'existe pas encore dans le dictionnaire, `l10n.t()` retourne la clé elle-même.
/// Cette méthode détecte ce cas et retourne le texte de secours pour ne pas casser l'UI.
String _tr(BuildContext context, String key, String fallback) {
  final translated = context.l10n.t(key);
  return translated == key ? fallback : translated;
}

/// ============================================================================
/// SeatMapWidget
/// ============================================================================
///
/// Composant de visualisation et sélection des sièges dans un bus.
///
/// Features :
/// - Layout 2+2 avec couloir central
/// - 4 états visuels : libre, réservé, sélectionné, VIP
/// - Accessibilité complète (Semantics sur chaque siège)
/// - Feedback haptique au tap
/// - Animation fluide sur les transitions d'état
/// - i18n intégrée (FR/EN/LN)
/// - Responsive (taille adaptée selon la largeur)
///
/// ============================================================================
class SeatMapWidget extends StatelessWidget {
  final List<SeatModel> seats;
  final Set<String> selected;
  final ValueChanged<SeatModel> onTap;
  final Color? domainColor;
  final int maxSelectedSeats;

  const SeatMapWidget({
    super.key,
    required this.seats,
    required this.selected,
    required this.onTap,
    this.domainColor,
    this.maxSelectedSeats = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return _buildEmptyState(context);
    }

    final rows = _buildRows();
    final accent = domainColor ?? ThixPolicy.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Taille de siège responsive : s'adapte à la largeur disponible
        final availableWidth = constraints.maxWidth - 40; // 28 couloir + 12 padding
        final seatWidth = (availableWidth / 4).clamp(36.0, 52.0);
        final seatHeight = seatWidth * 1.1;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              _SeatRow(
                row: row,
                selected: selected,
                onTap: onTap,
                accent: accent,
                seatWidth: seatWidth,
                seatHeight: seatHeight,
                maxSelectedSeats: maxSelectedSeats,
                currentSelectedCount: selected.length,
              ),
          ],
        );
      },
    );
  }

  List<List<SeatModel>> _buildRows() {
    final rows = <List<SeatModel>>[];
    for (var i = 0; i < seats.length; i += 4) {
      final end = (i + 4).clamp(0, seats.length);
      rows.add(seats.sublist(i, end));
    }
    return rows;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ThixPolicy.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 40,
            color: ThixPolicy.textMuted,
          ),
          SizedBox(height: ThixPolicy.s8),
          Text(
            _tr(context, 'admin_seat_no_seats', 'Aucun siège disponible'),
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _SeatRow — Une rangée de 4 sièges (2 + couloir + 2)
/// ============================================================================
class _SeatRow extends StatelessWidget {
  final List<SeatModel> row;
  final Set<String> selected;
  final ValueChanged<SeatModel> onTap;
  final Color accent;
  final double seatWidth;
  final double seatHeight;
  final int maxSelectedSeats;
  final int currentSelectedCount;

  const _SeatRow({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.seatWidth,
    required this.seatHeight,
    required this.maxSelectedSeats,
    required this.currentSelectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final left = row.length >= 2 ? row.sublist(0, 2) : row;
    final right = row.length > 2 ? row.sublist(2) : <SeatModel>[];

    return Padding(
      padding: EdgeInsets.only(bottom: ThixPolicy.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...left.map((s) => _SeatCell(
                seat: s,
                selected: selected.contains(s.seatNumber),
                onTap: onTap,
                accent: accent,
                width: seatWidth,
                height: seatHeight,
                canSelect: currentSelectedCount < maxSelectedSeats,
              )),
          SizedBox(
            width: 28,
            child: Center(
              child: _AisleIndicator(accent: accent),
            ),
          ),
          ...right.map((s) => _SeatCell(
                seat: s,
                selected: selected.contains(s.seatNumber),
                onTap: onTap,
                accent: accent,
                width: seatWidth,
                height: seatHeight,
                canSelect: currentSelectedCount < maxSelectedSeats,
              )),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _AisleIndicator — Indicateur visuel du couloir central
/// ============================================================================
class _AisleIndicator extends StatelessWidget {
  final Color accent;
  const _AisleIndicator({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// ============================================================================
/// _SeatCell — Un siège individuel avec tous ses états visuels
/// ============================================================================
class _SeatCell extends StatelessWidget {
  final SeatModel seat;
  final bool selected;
  final ValueChanged<SeatModel> onTap;
  final Color accent;
  final double width;
  final double height;
  final bool canSelect;

  const _SeatCell({
    required this.seat,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.width,
    required this.height,
    required this.canSelect,
  });

  @override
  Widget build(BuildContext context) {
    final state = _computeState();
    final isInteractive = state.isInteractive && (canSelect || selected);
    final semanticLabel = _buildSemanticLabel(context, state);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s2),
      child: Semantics(
        button: isInteractive,
        selected: selected,
        enabled: isInteractive,
        label: semanticLabel,
        child: Tooltip(
          message: semanticLabel,
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: isInteractive
                ? () async {
                    await HapticFeedback.lightImpact();
                    onTap(seat);
                  }
                : null,
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: state.backgroundColor,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                border: Border.all(color: state.borderColor, width: 1.5),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected
                        ? Icons.check_rounded
                        : seat.isVip
                            ? Icons.star_rounded
                            : Icons.airline_seat_recline_normal_rounded,
                    size: 16,
                    color: state.foregroundColor,
                  ),
                  SizedBox(height: ThixPolicy.s2),
                  Text(
                    seat.seatNumber,
                    style: ThixPolicy.microStyle.copyWith(
                      fontSize: 9,
                      fontWeight: ThixPolicy.bold,
                      color: state.foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _SeatVisualState _computeState() {
    if (!seat.isAvailable) {
      return _SeatVisualState(
        backgroundColor: ThixPolicy.textMuted,
        foregroundColor: Colors.white.withValues(alpha: 0.75),
        borderColor: ThixPolicy.textSecondary,
        isInteractive: false,
        stateLabelKey: 'booked',
      );
    }
    if (selected) {
      return _SeatVisualState(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        borderColor: accent,
        isInteractive: true,
        stateLabelKey: 'selected',
      );
    }
    if (seat.isVip) {
      return _SeatVisualState(
        backgroundColor: ThixPolicy.gold.withValues(alpha: 0.15),
        foregroundColor: ThixPolicy.premiumAccent,
        borderColor: ThixPolicy.gold,
        isInteractive: canSelect,
        stateLabelKey: 'vip',
      );
    }
    return _SeatVisualState(
      backgroundColor: Colors.white,
      foregroundColor: ThixPolicy.textMain,
      borderColor: ThixPolicy.border,
      isInteractive: canSelect,
      stateLabelKey: 'available',
    );
  }

  String _buildSemanticLabel(BuildContext context, _SeatVisualState state) {
    final statusLabel = _statusLabel(context, state.stateLabelKey);
    // Construction manuelle et universelle du label pour les lecteurs d'écran
    return '${seat.seatNumber} - $statusLabel';
  }

  String _statusLabel(BuildContext context, String key) {
    switch (key) {
      case 'available':
        return _tr(context, 'sos_available', 'Disponible');
      case 'booked':
        return _tr(context, 'admin_seat_legend_reserved', 'Réservé');
      case 'selected':
        return _tr(context, 'seat_status_selected', 'Sélectionné');
      case 'vip':
        return _tr(context, 'ticket_vip', 'VIP');
      default:
        return '';
    }
  }
}

/// ============================================================================
/// _SeatVisualState — État visuel calculé d'un siège
/// ============================================================================
class _SeatVisualState {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool isInteractive;
  final String stateLabelKey;

  const _SeatVisualState({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.isInteractive,
    required this.stateLabelKey,
  });
}
