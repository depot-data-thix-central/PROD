// lib/presentation/thix_event/admin/pages/seats/seat_map_admin_page.dart
//
// SeatMapAdminPage — Production Enterprise (i18n + Design System + A11y)
//
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';  
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// === IMPORTS ABSOLUS (Sécurisés pour les modèles, le design et les traductions) ===
import 'package:thix_id/models/event_seat.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// === IMPORTS LOCAUX (Basés sur votre ancienne structure qui fonctionne) ===
import '../../core/admin_constants.dart';
import '../../core/admin_guards.dart';
import '../../providers/admin_event_provider.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy — Admin Seats)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);

  // Tokens sémantiques pour les catégories de sièges
  static const Color seatStandard = ThixPolicy.success; // Vert
  static const Color seatVip = Color(0xFF8B5CF6);       // Violet
  static const Color seatGold = ThixPolicy.gold;        // Or
  static const Color seatFamily = Color(0xFF3B82F6);    // Bleu
  static const Color seatReserved = ThixPolicy.warning; // Orange
  static const Color seatSold = ThixPolicy.danger;      // Rouge
}

// ============================================================================
// LOGGING
// ============================================================================
class _SeatMapAdminLogger {
  static const _tag = 'SeatMapAdmin';
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
// PAGE
// ============================================================================
class SeatMapAdminPage extends ConsumerStatefulWidget {
  const SeatMapAdminPage({super.key});
  @override
  ConsumerState<SeatMapAdminPage> createState() => _SeatMapAdminPageState();
}

class _SeatMapAdminPageState extends ConsumerState<SeatMapAdminPage> {
  String? _eventId;
  int _rows = 10;
  int _perRow = 10;
  bool _hasAisle = true;
  Map<SeatCategory, double> _prices = {
    SeatCategory.standard: 10,
    SeatCategory.vip: 50,
    SeatCategory.gold: 100,
    SeatCategory.family: 25,
  };
  Map<String, SeatCategory> _catByRow = {};
  List<EventSeat> _seats = [];
  bool _generating = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initCats();
    _SeatMapAdminLogger.info('SeatMapAdminPage init');
  }

  void _initCats() {
    _catByRow.clear();
    for (int i = 0; i < _rows; i++) {
      final l = String.fromCharCode(65 + i);
      _catByRow[l] = i < 2
          ? SeatCategory.vip
          : i < 4
              ? SeatCategory.gold
              : SeatCategory.standard;
    }
  }

  Future<void> _loadSeats() async {
    if (_eventId == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _seats = await ref
          .read(adminEventServiceProvider)
          .getSeatMapForAdmin(_eventId!);
      _SeatMapAdminLogger.info('Seats loaded', {'count': _seats.length});
    } catch (e, stack) {
      _SeatMapAdminLogger.error('Load failed', {
        'error': '$e',
        'stack': '$stack',
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('admin_seat_load_error')),
            backgroundColor: EventTheme.seatSold,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context);

    if (_eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('admin_seat_select_event')),
          backgroundColor: EventTheme.seatReserved,
        ),
      );
      return;
    }

    final total = _rows * _perRow;
    if (total > AdminConstants.maxSeatGeneration) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tn(
            'admin_seat_max_limit',
            {'count': AdminConstants.maxSeatGeneration.toString()},
          )),
          backgroundColor: EventTheme.seatReserved,
        ),
      );
      return;
    }

    final role = await AdminGuard.getCurrentRole();
    if (!AdminGuard.canWrite(role)) {
      _SeatMapAdminLogger.warn('Generate denied', {'role': role.toString()});
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _generating = true);

    try {
      final cfg = _catByRow.map(
        (k, v) => MapEntry(k, v.toString().split('.').last),
      );
      final prc = _prices.map(
        (k, v) => MapEntry(k.toString().split('.').last, v),
      );

      await ref.read(adminEventServiceProvider).generateSeatMap(
            eventId: _eventId!,
            rows: _rows,
            seatsPerRow: _perRow,
            categoryConfig: cfg,
            categoryPrices: prc,
            hasCenterAisle: _hasAisle,
          );

      await _loadSeats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tn('admin_seat_generated', {
            'count': total.toString(),
          })),
          backgroundColor: EventTheme.seatStandard,
        ),
      );
      _SeatMapAdminLogger.info('Seat map generated', {'total': total});
    } catch (e) {
      _SeatMapAdminLogger.error('Generation failed', {'error': '$e'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: EventTheme.seatSold,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Color _catColor(SeatCategory c) {
    switch (c) {
      case SeatCategory.vip: return EventTheme.seatVip;
      case SeatCategory.gold: return EventTheme.seatGold;
      case SeatCategory.family: return EventTheme.seatFamily;
      default: return EventTheme.seatStandard;
    }
  }

  Color _statusColor(EventSeat s) {
    if (s.status == SeatStatus.sold) return EventTheme.seatSold;
    if (s.status == SeatStatus.reserved) return EventTheme.seatReserved;
    return _catColor(s.category);
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(adminEventProvider).eventsState.items;
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation ||
        mediaQuery.disableAnimations;

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0 : 20,
              sigmaY: reduceMotion ? 0 : 20,
            ),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                l10n.t('admin_seat_page_title'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: EventTheme.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(ThixPolicy.s16),
        children: [
          // ── SÉLECTEUR D'ÉVÉNEMENT ──
          Semantics(
            label: l10n.t('admin_seat_target_event'),
            child: DropdownButtonFormField<String>(
              value: _eventId,
              dropdownColor: EventTheme.surface,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              decoration: _deco(l10n.t('admin_seat_target_event')),
              items: events
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        e.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _eventId = v);
                _loadSeats();
              },
            ),
          ),
          SizedBox(height: ThixPolicy.s14),

          // ── TARIFICATION DYNAMIQUE ──
          Container(
            padding: EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: EventTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: EventTheme.accent,
                      size: 14,
                    ),
                    SizedBox(width: ThixPolicy.s6),
                    Text(
                      l10n.t('admin_seat_pricing_title'),
                      style: ThixPolicy.labelStyle.copyWith(
                        color: EventTheme.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s12),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_cat_standard'),
                        child: _priceField(
                          l10n.t('admin_seat_cat_standard'),
                          _prices[SeatCategory.standard]!,
                          (v) => _prices[SeatCategory.standard] = v,
                        ),
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s10),
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_cat_vip'),
                        child: _priceField(
                          l10n.t('admin_seat_cat_vip'),
                          _prices[SeatCategory.vip]!,
                          (v) => _prices[SeatCategory.vip] = v,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s10),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_cat_gold'),
                        child: _priceField(
                          l10n.t('admin_seat_cat_gold'),
                          _prices[SeatCategory.gold]!,
                          (v) => _prices[SeatCategory.gold] = v,
                        ),
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s10),
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_cat_family'),
                        child: _priceField(
                          l10n.t('admin_seat_cat_family'),
                          _prices[SeatCategory.family]!,
                          (v) => _prices[SeatCategory.family] = v,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: ThixPolicy.s12),

          // ── FORME & DISPOSITION ──
          Container(
            padding: EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: EventTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      color: EventTheme.primary,
                      size: 14,
                    ),
                    SizedBox(width: ThixPolicy.s6),
                    Text(
                      l10n.t('admin_seat_layout_title'),
                      style: ThixPolicy.labelStyle.copyWith(
                        color: EventTheme.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s12),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_rows'),
                        child: _numField(
                          l10n.t('admin_seat_rows'),
                          _rows,
                          (v) {
                            setState(() {
                              _rows = v;
                              _initCats();
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s10),
                    Expanded(
                      child: Semantics(
                        label: l10n.t('admin_seat_per_row'),
                        child: _numField(
                          l10n.t('admin_seat_per_row'),
                          _perRow,
                          (v) => setState(() => _perRow = v),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s10),
                Semantics(
                  toggled: _hasAisle,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: EventTheme.primary,
                    title: Text(
                      l10n.t('admin_seat_center_aisle'),
                      style: ThixPolicy.labelStyle.copyWith(
                        color: EventTheme.textMain,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.t('admin_seat_aisle_desc'),
                      style: ThixPolicy.microStyle.copyWith(
                        color: EventTheme.textMuted,
                      ),
                    ),
                    value: _hasAisle,
                    onChanged: (v) => setState(() => _hasAisle = v),
                  ),
                ),
                Divider(
                  color: EventTheme.border,
                  height: ThixPolicy.s24,
                ),
                Text(
                  l10n.t('admin_seat_cats_per_row'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: EventTheme.textMain,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: ThixPolicy.s8),
                Wrap(
                  spacing: ThixPolicy.s8,
                  runSpacing: ThixPolicy.s8,
                  children: List.generate(_rows, (i) {
                    final l = String.fromCharCode(65 + i);
                    final cat = _catByRow[l] ?? SeatCategory.standard;
                    return Semantics(
                      button: true,
                      label: '$l: ${_catLabel(l10n, cat)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(ThixPolicy.s8),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _catByRow[l] = cat == SeatCategory.standard
                                ? SeatCategory.vip
                                : cat == SeatCategory.vip
                                    ? SeatCategory.gold
                                    : cat == SeatCategory.gold
                                        ? SeatCategory.family
                                        : SeatCategory.standard;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s10,
                            vertical: ThixPolicy.s6,
                          ),
                          decoration: BoxDecoration(
                            color: _catColor(cat).withOpacity(0.14),
                            border: Border.all(
                              color: _catColor(cat).withOpacity(0.6),
                            ),
                            borderRadius: BorderRadius.circular(ThixPolicy.s8),
                          ),
                          child: Text(
                            '$l : ${_catLabel(l10n, cat).toUpperCase()}',
                            style: ThixPolicy.microStyle.copyWith(
                              color: _catColor(cat),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: ThixPolicy.s16),
                Semantics(
                  button: true,
                  enabled: !_generating,
                  label: _generating
                      ? l10n.t('admin_seat_generating')
                      : l10n.tn('admin_seat_generate_btn', {
                          'count': (_rows * _perRow).toString(),
                        }),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EventTheme.bg,
                              ),
                            )
                          : const Icon(
                              Icons.precision_manufacturing_rounded,
                              size: 16,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: EventTheme.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                        ),
                      ),
                      label: Text(
                        _generating
                            ? l10n.t('admin_seat_generating')
                            : l10n.tn('admin_seat_generate_btn', {
                                'count': (_rows * _perRow).toString(),
                              }),
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          // ── APERÇU ──
          Text(
            l10n.t('admin_seat_preview'),
            style: ThixPolicy.labelStyle.copyWith(
              color: EventTheme.textMain,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          SizedBox(height: ThixPolicy.s10),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: EventTheme.primary,
                strokeWidth: 2,
              ),
            )
          else if (_seats.isNotEmpty) ...[
            _buildMap(l10n),
            SizedBox(height: ThixPolicy.s12),
            _legend(l10n),
          ] else
            Container(
              padding: EdgeInsets.all(ThixPolicy.s20),
              decoration: BoxDecoration(
                color: EventTheme.surface,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: EventTheme.border),
              ),
              child: Center(
                child: Text(
                  l10n.t('admin_seat_no_seats'),
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: EventTheme.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // MAP
  // ────────────────────────────────────────────────────────────
  Widget _buildMap(AppLocalizations l10n) {
    final Map<String, List<EventSeat>> byRow = {};
    for (var s in _seats) byRow.putIfAbsent(s.row, () => []).add(s);
    final sorted = byRow.keys.toList()..sort();

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s14),
      decoration: BoxDecoration(
        color: EventTheme.surface,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: EventTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            Container(
              width: 220,
              padding: EdgeInsets.symmetric(vertical: ThixPolicy.s8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(ThixPolicy.s10),
                border: Border.all(color: EventTheme.border),
              ),
              child: Center(
                child: Text(
                  l10n.t('seat_map_stage'),
                  style: ThixPolicy.microStyle.copyWith(
                    color: EventTheme.textMain,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            SizedBox(height: ThixPolicy.s24),
            ...sorted.map((r) {
              final seats = byRow[r]!
                ..sort((a, b) => a.number.compareTo(b.number));
              final half = seats.length ~/ 2;
              return Padding(
                padding: EdgeInsets.only(bottom: ThixPolicy.s6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        r,
                        style: ThixPolicy.microStyle.copyWith(
                          color: EventTheme.textMain,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(seats.length, (idx) {
                        final s = seats[idx];
                        final w = Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(s).withOpacity(
                              s.isAvailable ? 0.18 : 1,
                            ),
                            borderRadius: BorderRadius.circular(ThixPolicy.s6),
                            border: Border.all(
                              color: _statusColor(s),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${s.number}',
                              style: ThixPolicy.microStyle.copyWith(
                                color: s.isAvailable
                                    ? _statusColor(s)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 7,
                              ),
                            ),
                          ),
                        );
                        if (_hasAisle && idx == half - 1) {
                          return Row(
                            children: [w, const SizedBox(width: 28)],
                          );
                        }
                        return w;
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // LEGEND
  // ────────────────────────────────────────────────────────────
  Widget _legend(AppLocalizations l10n) => Container(
        padding: EdgeInsets.all(ThixPolicy.s10),
        decoration: BoxDecoration(
          color: EventTheme.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(color: EventTheme.border),
        ),
        child: Wrap(
          spacing: ThixPolicy.s12,
          runSpacing: ThixPolicy.s6,
          children: [
            _dot(EventTheme.seatStandard, l10n.t('admin_seat_cat_standard')),
            _dot(EventTheme.seatVip, l10n.t('admin_seat_cat_vip')),
            _dot(EventTheme.seatGold, l10n.t('admin_seat_cat_gold')),
            _dot(EventTheme.seatReserved, l10n.t('admin_seat_legend_reserved')),
            _dot(EventTheme.seatSold, l10n.t('admin_seat_legend_sold')),
          ],
        ),
      );

  Widget _dot(Color c, String l) => Semantics(
        label: l,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              l,
              style: ThixPolicy.microStyle.copyWith(
                color: EventTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  // ────────────────────────────────────────────────────────────
  // INPUTS
  // ────────────────────────────────────────────────────────────
  Widget _numField(String label, int v, Function(int) onChange) =>
      TextFormField(
        initialValue: v.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
        decoration: _deco(label),
        keyboardType: TextInputType.number,
        onChanged: (x) {
          final n = int.tryParse(x);
          if (n != null) onChange(n);
        },
      );

  Widget _priceField(String label, double v, Function(double) onChange) =>
      TextFormField(
        initialValue: v.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
        decoration: _deco(label, prefix: '\$ '),
        keyboardType: TextInputType.number,
        onChanged: (x) {
          final n = double.tryParse(x);
          if (n != null) onChange(n);
        },
      );

  InputDecoration _deco(String l, {String? prefix}) => InputDecoration(
        labelText: l,
        prefixText: prefix,
        prefixStyle: ThixPolicy.labelStyle.copyWith(
          color: EventTheme.textMain,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        labelStyle: ThixPolicy.captionStyle.copyWith(
          color: EventTheme.textMuted,
          fontSize: 10,
        ),
        filled: true,
        fillColor: EventTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ThixPolicy.s12,
          vertical: ThixPolicy.s10,
        ),
      );

  // ────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────
  String _catLabel(AppLocalizations l10n, SeatCategory cat) {
    switch (cat) {
      case SeatCategory.vip:
        return l10n.t('admin_seat_cat_vip');
      case SeatCategory.gold:
        return l10n.t('admin_seat_cat_gold');
      case SeatCategory.family:
        return l10n.t('admin_seat_cat_family');
      default:
        return l10n.t('admin_seat_cat_standard');
    }
  }
}
