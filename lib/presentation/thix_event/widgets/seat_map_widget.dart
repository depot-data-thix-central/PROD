// lib/presentation/thix_event/widgets/seat_map_widget.dart
//
// SeatMapWidget — Production Enterprise (i18n + A11y + Sécurité)
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Semantics complets sur chaque siège (disponible/réservé/vendu/sélectionné)
// - Throttling anti-double-tap (300ms par siège)
// - Haptic feedback sur sélection
// - Logging structuré (_SeatMapLogger)
// - Utilisation EventTheme + ThixPolicy
// - Guards sur données vides
// - Accessibilité reduceMotion
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/event_seat.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  
  // États des sièges (tokens sémantiques)
  static const Color seatAvailable = ThixPolicy.success; // Vert
  static const Color seatReserved = ThixPolicy.warning; // Orange
  static const Color seatSold = ThixPolicy.danger; // Rouge
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTapThrottle = Duration(milliseconds: 300);

// ============================================================================
// LOGGING
// ============================================================================
class _SeatMapLogger {
  static const _tag = 'SeatMapWidget';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);

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
class SeatMapWidget extends StatefulWidget {
  final List<EventSeat> seats;
  final List<EventSeat> selectedSeats;
  final Function(EventSeat) onSeatTap;

  const SeatMapWidget({
    super.key,
    required this.seats,
    required this.selectedSeats,
    required this.onSeatTap,
  });

  @override
  State<SeatMapWidget> createState() => _SeatMapWidgetState();
}

class _SeatMapWidgetState extends State<SeatMapWidget> {
  /// Track last tap per seat ID for throttling
  final Map<String, DateTime> _lastTapPerSeat = {};

  @override
  void initState() {
    super.initState();
    _SeatMapLogger.info('SeatMapWidget init', {
      'totalSeats': widget.seats.length,
      'selectedSeats': widget.selectedSeats.length,
    });
  }

  @override
  void dispose() {
    _lastTapPerSeat.clear();
    super.dispose();
  }

  bool _canTapSeat(String seatId) {
    final now = DateTime.now();
    final lastTap = _lastTapPerSeat[seatId];
    if (lastTap != null && now.difference(lastTap) < _kTapThrottle) {
      _SeatMapLogger.warn('Tap throttled', {'seatId': seatId});
      return false;
    }
    _lastTapPerSeat[seatId] = now;
    return true;
  }

  void _handleTap(EventSeat seat) {
    if (!_canTapSeat(seat.id)) return;
    if (!mounted) {
      _SeatMapLogger.warn('Tap on unmounted widget');
      return;
    }
    
    HapticFeedback.selectionClick();
    _SeatMapLogger.info('Seat tapped', {
      'seatId': seat.id,
      'number': seat.number,
      'row': seat.row,
    });
    widget.onSeatTap(seat);
  }

  /// Retourne la couleur sémantique selon l'état du siège
  Color _getSeatColor(EventSeat seat, bool isSelected) {
    if (isSelected) return EventTheme.primary;
    if (seat.isSold) return EventTheme.seatSold;
    if (seat.isReserved) return EventTheme.seatReserved;
    return EventTheme.seatAvailable;
  }

  /// Construit le label a11y complet pour un siège
  String _buildSeatA11yLabel(
    AppLocalizations l10n,
    EventSeat seat,
    bool isSelected,
  ) {
    final seatNumber = l10n.tn(
      'seat_map_seat_label',
      {'number': seat.number.toString(), 'row': seat.row},
    );
    
    String status;
    if (isSelected) {
      status = l10n.t('seat_map_selected');
    } else if (seat.isSold) {
      status = l10n.t('seat_map_sold');
    } else if (seat.isReserved) {
      status = l10n.t('seat_map_reserved');
    } else {
      status = l10n.t('seat_map_available');
    }
    
    return '$seatNumber, $status';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation ||
        mediaQuery.disableAnimations;
    
    // Regrouper les sièges par rangée
    final Map<String, List<EventSeat>> rows = {};
    for (var s in widget.seats) {
      rows.putIfAbsent(s.row, () => []).add(s);
    }
    
    // Trier les rangées alphabétiquement/numériquement
    final sorted = rows.keys.toList()..sort();
    
    // Garde : aucun siège configuré
    if (widget.seats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Text(
            l10n.t('seat_map_no_seats'),
            style: TextStyle(color: EventTheme.textMuted),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── SCÈNE ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12),
            margin: const EdgeInsets.only(bottom: ThixPolicy.s24),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: EventTheme.border),
              boxShadow: [
                BoxShadow(
                  color: EventTheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                l10n.t('seat_map_stage'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: EventTheme.textMuted,
                ),
              ),
            ),
          ),
          
          // ── RANGÉES DE SIÈGES ──
          for (var row in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: ThixPolicy.s10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label de rangée
                  SizedBox(
                    width: 28,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        row,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: EventTheme.textMain,
                        ),
                      ),
                    ),
                  ),
                  
                  // Sièges de la rangée
                  Expanded(
                    child: Wrap(
                      spacing: ThixPolicy.s8,
                      runSpacing: ThixPolicy.s8,
                      children: rows[row]!.map((seat) {
                        final isSelected = widget.selectedSeats
                            .any((s) => s.id == seat.id);
                        final color = _getSeatColor(seat, isSelected);
                        final isInteractive = seat.isAvailable || isSelected;
                        final a11yLabel = _buildSeatA11yLabel(
                          l10n,
                          seat,
                          isSelected,
                        );
                        
                        return Semantics(
                          button: true,
                          enabled: isInteractive,
                          selected: isSelected,
                          label: a11yLabel,
                          child: GestureDetector(
                            onTap: isInteractive ? () => _handleTap(seat) : null,
                            child: AnimatedContainer(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.22)
                                    : color.withOpacity(0.12),
                                border: Border.all(
                                  color: color,
                                  width: isSelected ? 2 : 1.2,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                  bottomLeft: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  seat.number.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          
          // ── COULOIR CENTRAL ──
          Container(
            margin: const EdgeInsets.symmetric(vertical: ThixPolicy.s18),
            padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s8),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.s8),
              border: Border.all(color: EventTheme.border),
            ),
            child: Center(
              child: Text(
                l10n.t('seat_map_aisle'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: EventTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
