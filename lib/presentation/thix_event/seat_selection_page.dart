// lib/presentation/thix_event/seat_selection_page.dart
//
// SeatSelectionPage — Production Enterprise (Sécurité + i18n + Sold Out)
//
// Features :
// - Validation UUID stricte
// - Sanitization et validation inputs
// - Throttling anti-double-tap (300ms)
// - Protection race condition (verrou par siège)
// - Timeout sur opérations DB (10s)
// - Intégration AppLocalizations (8 langues)
// - Semantics complet pour a11y
// - Logging structuré (_SeatLogger)
// - Gestion erreurs robuste avec retry
// - Utilisation ThixPolicy (couleurs centralisées)
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_model.dart';
import '../../models/event_seat.dart';
import '../../services/event_seat_service.dart';
import 'event_reservation_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kToggleThrottle = Duration(milliseconds: 300);
const Duration _kOperationTimeout = Duration(seconds: 10);
const int _kDefaultMaxSeats = 5;

// ============================================================================
// LOGGING
// ============================================================================

class _SeatLogger {
  static const _tag = 'SeatSelection';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS
// ============================================================================

class _Validators {
  _Validators._();
  
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  
  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);
}

// ============================================================================
// PAGE
// ============================================================================

class SeatSelectionPage extends ConsumerStatefulWidget {
  final String eventId;
  final Event? event;
  final int? requestedQuantity;
  
  const SeatSelectionPage({
    super.key,
    required this.eventId,
    this.event,
    this.requestedQuantity,
  });

  @override
  ConsumerState<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends ConsumerState<SeatSelectionPage> {
  late EventSeatService _svc;
  List<EventSeat> _seats = [];
  List<EventSeat> _selected = [];
  final Set<String> _processing = {};
  Map<String, List<EventSeat>> _grouped = {};
  List<String> _rows = [];
  bool _loading = true;
  bool _confirming = false;
  int _available = 0;
  String? _error;
  DateTime? _lastToggle;

  int get _max => widget.requestedQuantity != null && 
      widget.requestedQuantity! > 0 && 
      widget.requestedQuantity! < _kDefaultMaxSeats
      ? widget.requestedQuantity!
      : _kDefaultMaxSeats;

  @override
  void initState() {
    super.initState();
    
    // Validation UUID
    if (!_Validators.isValidUuid(widget.eventId)) {
      _SeatLogger.error('Invalid eventId', {'id': widget.eventId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showError('Invalid event ID');
          context.pop();
        }
      });
      return;
    }
    
    _svc = EventSeatService(Supabase.instance.client);
    _load();
    _SeatLogger.info('SeatSelectionPage init', {
      'eventId': widget.eventId,
      'maxSeats': _max,
    });
  }

  @override
  void dispose() {
    _release();
    _SeatLogger.info('SeatSelectionPage disposed');
    super.dispose();
  }

  Future<void> _release() async {
    if (_selected.isEmpty) return;
    
    try {
      await _svc.releaseSeats(
        widget.eventId,
        _selected.map((s) => s.id).toList(),
      ).timeout(const Duration(seconds: 5));
      _SeatLogger.info('Seats released on dispose', {
        'count': _selected.length,
      });
    } catch (e) {
      _SeatLogger.warn('Failed to release seats on dispose', {
        'error': '$e',
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final seats = await _svc
          .getSeatMap(widget.eventId)
          .timeout(_kOperationTimeout);
      
      final avail = await _svc
          .getAvailableSeatsCount(widget.eventId)
          .timeout(_kOperationTimeout);
      
      _grouped.clear();
      for (var s in seats) {
        _grouped.putIfAbsent(s.row, () => []).add(s);
      }
      
      _rows = _grouped.keys.toList()..sort();
      
      if (!mounted) return;
      
      setState(() {
        _seats = seats;
        _available = avail;
        _loading = false;
      });
      
      _SeatLogger.info('Seats loaded', {
        'total': seats.length,
        'available': avail,
        'rows': _rows.length,
      });
    } on TimeoutException {
      _SeatLogger.error('Load timeout');
      if (mounted) {
        setState(() {
          _error = 'Timeout';
          _loading = false;
        });
      }
    } catch (e, stack) {
      _SeatLogger.error('Load failed', {
        'error': '$e',
        'stack': stack.toString(),
      });
      if (mounted) {
        setState(() {
          _error = 'Failed to load seats';
          _loading = false;
        });
      }
    }
  }

  bool _canToggle() {
    final now = DateTime.now();
    if (_lastToggle != null && 
        now.difference(_lastToggle!) < _kToggleThrottle) {
      return false;
    }
    _lastToggle = now;
    return true;
  }

  Future<void> _toggle(EventSeat seat) async {
    if (!_canToggle()) {
      _SeatLogger.warn('Toggle throttled', {'seatId': seat.id});
      return;
    }
    
    if (_processing.contains(seat.id)) {
      _SeatLogger.warn('Seat already processing', {'seatId': seat.id});
      return;
    }
    
    HapticFeedback.selectionClick();
    setState(() => _processing.add(seat.id));
    
    try {
      final alreadySelected = _selected.any((s) => s.id == seat.id);
      
      if (alreadySelected) {
        // Release
        final success = await _svc
            .releaseSeats(widget.eventId, [seat.id])
            .timeout(_kOperationTimeout);
        
        if (success && mounted) {
          setState(() {
            _selected.removeWhere((s) => s.id == seat.id);
            _available++;
          });
          _SeatLogger.info('Seat released', {'seatId': seat.id});
        } else {
          _SeatLogger.warn('Release failed', {'seatId': seat.id});
          if (mounted) _showError('Failed to release seat');
        }
      } else {
        // Reserve
        if (_selected.length >= _max) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            _showError(l10n.t('event_max_seats', args: [_max.toString()]));
          }
          return;
        }
        
        final success = await _svc
            .reserveSeats(widget.eventId, [seat.id])
            .timeout(_kOperationTimeout);
        
        if (success && mounted) {
          setState(() {
            _selected.add(seat);
            _available--;
          });
          _SeatLogger.info('Seat reserved', {'seatId': seat.id});
        } else {
          _SeatLogger.warn('Reserve failed', {'seatId': seat.id});
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            _showError(l10n.t('event_seat_taken'));
            _load(); // Refresh to get current state
          }
        }
      }
    } on TimeoutException {
      _SeatLogger.error('Toggle timeout', {'seatId': seat.id});
      if (mounted) _showError('Operation timeout');
    } catch (e, stack) {
      _SeatLogger.error('Toggle failed', {
        'seatId': seat.id,
        'error': '$e',
        'stack': stack.toString(),
      });
      if (mounted) _showError('Operation failed');
    } finally {
      if (mounted) {
        setState(() => _processing.remove(seat.id));
      }
    }
  }

  double get _total => _selected.fold(
    0,
    (sum, s) => sum + (s.categoryPrice > 0 
        ? s.categoryPrice 
        : (widget.event?.price ?? 0)),
  );

  void _confirm() {
    if (_selected.isEmpty || _confirming) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _confirming = true);
    
    _SeatLogger.info('Confirming reservation', {
      'seats': _selected.length,
      'total': _total,
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventReservationPage(
          eventId: widget.eventId,
          selectedSeats: _selected,
          totalPrice: _total,
          quantity: _selected.length,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _confirming = false);
        _load();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: ThixPolicy.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: ThixPolicy.background.withOpacity(0.85),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Semantics(
                  button: true,
                  label: l10n.t('common_back'),
                  child: InkWell(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(
                l10n.t('event_seats_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              actions: [
                Container(
                  margin: const EdgeInsets.only(
                    right: 16,
                    top: 10,
                    bottom: 10,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThixPolicy.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_selected.length} / $_max',
                      style: TextStyle(
                        color: ThixPolicy.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: ThixPolicy.primary),
            )
          : _error != null
              ? _errorView(l10n)
              : Column(
                  children: [
                    // Disponibilité
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.event_seat_rounded,
                                  color: ThixPolicy.textSecondary,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.t('event_available'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Map
                    Expanded(child: _map(l10n)),
                    
                    // Legend
                    _legend(l10n),
                    
                    // Bottom
                    _bottom(l10n),
                  ],
                ),
    );
  }

  Widget _errorView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.red,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t(_error ?? 'error_generic'),
            style: TextStyle(
              color: ThixPolicy.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: l10n.t('common_retry'),
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(l10n.t('common_retry')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _leg(ThixPolicy.surfaceAlt, l10n.t('event_seat_available'), false),
          _leg(ThixPolicy.primary, l10n.t('event_seat_selected'), true),
          _leg(ThixPolicy.warning, l10n.t('event_seat_reserved'), true),
          _leg(ThixPolicy.danger, l10n.t('event_seat_sold'), true),
        ],
      ),
    );
  }

  Widget _leg(Color c, String label, bool filled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled ? c : Colors.transparent,
            border: Border.all(
              color: filled ? c : ThixPolicy.textMuted,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: ThixPolicy.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _map(AppLocalizations l10n) {
    if (_seats.isEmpty) {
      return Center(
        child: Text(
          l10n.t('event_no_seats_configured'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
      );
    }
    
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          children: [
            // Stage
            CustomPaint(
              size: const Size(220, 36),
              painter: _ScenePainter(),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('event_stage'),
              style: TextStyle(
                color: ThixPolicy.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 30),
            
            // Rows
            for (var row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        row,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _grouped[row]!.map((seat) {
                        final isSelected = _selected.any((s) => s.id == seat.id);
                        final isProcessing = _processing.contains(seat.id);
                        final isAvailable = seat.isAvailable;
                        
                        Color bgColor;
                        Color borderColor;
                        Color textColor = Colors.white;
                        
                        if (isSelected) {
                          bgColor = ThixPolicy.primary;
                          borderColor = ThixPolicy.primary;
                        } else if (seat.isSold) {
                          bgColor = ThixPolicy.danger;
                          borderColor = ThixPolicy.danger;
                        } else if (seat.isReserved && !isSelected) {
                          bgColor = ThixPolicy.warning;
                          borderColor = ThixPolicy.warning;
                        } else {
                          bgColor = Colors.transparent;
                          borderColor = ThixPolicy.borderStrong;
                          textColor = ThixPolicy.textSecondary;
                        }
                        
                        return Semantics(
                          button: true,
                          label: '${l10n.t('event_seat')} ${seat.number}, '
                              '${isSelected ? l10n.t('event_seat_selected') : isAvailable ? l10n.t('event_seat_available') : l10n.t('event_seat_unavailable')}',
                          enabled: (isAvailable || isSelected) && !_confirming,
                          child: GestureDetector(
                            onTap: (isAvailable || isSelected) && !_confirming
                                ? () => _toggle(seat)
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected || !isAvailable || seat.isReserved
                                    ? bgColor
                                    : Colors.transparent,
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.2,
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
                                          color: ThixPolicy.primary.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isProcessing
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        seat.number.toString(),
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottom(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceAlt.withOpacity(0.96),
        border: Border(top: BorderSide(color: ThixPolicy.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected.isEmpty
                        ? l10n.t('event_no_seats_selected')
                        : l10n.t('event_seats_count', args: [_selected.length.toString()]),
                    style: TextStyle(
                      color: ThixPolicy.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_total.toInt()} ${widget.event?.priceCurrency ?? 'FC'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Semantics(
                button: true,
                label: l10n.t('event_continue'),
                enabled: _selected.isNotEmpty && !_confirming,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: (_selected.isEmpty || _confirming) ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: ThixPolicy.surfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: _confirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            l10n.t('event_continue'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCENE PAINTER
// ============================================================================

class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, s.height)
      ..quadraticBezierTo(s.width / 2, -s.height, s.width, s.height)
      ..close();
    
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
