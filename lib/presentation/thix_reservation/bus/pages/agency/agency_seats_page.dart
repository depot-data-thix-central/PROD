import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

/// ============================================================================
/// AgencySeatsPage
/// ============================================================================
///
/// Page de gestion des sièges côté agence (admin).
///
/// Features :
/// - Plan de bus réaliste (layout 2+2 avec couloir)
/// - 4 statuts de siège : available, reserved, sold, blocked
/// - Actions : toggle blocked ↔ available (avec confirmation)
/// - Actions bulk : bloquer/débloquer plusieurs sièges
/// - Header avec stats temps réel (total, libres, réservés, vendus, bloqués)
/// - Légende des statuts claire
/// - Skeleton loader pendant le chargement
/// - Vue d'erreur avec retry
/// - Pull-to-refresh
/// - Haptic feedback sur toutes les interactions
/// - i18n complète (FR/EN/LN)
/// - Accessibilité complète (Semantics)
/// - Design system ThixPolicy
/// - Sélection multiple avec mode "bulk"
///
/// ============================================================================
class AgencySeatsPage extends ConsumerStatefulWidget {
  final String tripId;
  final String? tripLabel;

  const AgencySeatsPage({
    super.key,
    required this.tripId,
    this.tripLabel,
  });

  @override
  ConsumerState<AgencySeatsPage> createState() => _AgencySeatsPageState();
}

class _AgencySeatsPageState extends ConsumerState<AgencySeatsPage> {
  bool _loading = true;
  bool _isUpdating = false;
  String? _error;
  List<_SeatData> _seats = [];
  final Set<String> _bulkSelection = {};
  bool _bulkMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('bus_seats')
          .select()
          .eq('trip_id', widget.tripId)
          .order('seat_number')
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final list = (res as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _SeatData(
          id: m['id']?.toString() ?? '',
          seatNumber: m['seat_number']?.toString() ?? '',
          status: _parseStatus(m['status']?.toString()),
          isVip: (m['is_vip'] as bool?) ?? false,
        );
      }).toList();

      setState(() {
        _seats = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  _SeatStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'reserved':
        return _SeatStatus.reserved;
      case 'sold':
      case 'booked':
        return _SeatStatus.sold;
      case 'blocked':
        return _SeatStatus.blocked;
      default:
        return _SeatStatus.available;
    }
  }

  Future<void> _toggleSeat(_SeatData seat) async {
    if (seat.status == _SeatStatus.reserved || seat.status == _SeatStatus.sold) {
      return;
    }

    final l10n = context.l10n;
    final isBlocked = seat.status == _SeatStatus.blocked;
    final nextStatus = isBlocked ? _SeatStatus.available : _SeatStatus.blocked;

    // Confirmation si on bloque
    if (!isBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          ),
          title: Text(l10n.agencySeatsConfirmBlockTitle),
          content: Text(
            l10n.agencySeatsConfirmBlockMessage(seat.seatNumber),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: ThixPolicy.warning,
              ),
              child: Text(l10n.agencySeatsConfirmBlock),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _updateSeatStatus(seat.id, nextStatus);
  }

  Future<void> _updateSeatStatus(String seatId, _SeatStatus newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await Supabase.instance.client
          .from('bus_seats')
          .update({'status': newStatus.dbValue})
          .eq('id', seatId)
          .timeout(const Duration(seconds: 8));

      await HapticFeedback.mediumImpact();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: ThixPolicy.s8),
              Expanded(child: Text(context.l10n.agencySeatsUpdateError)),
            ],
          ),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _bulkBlock() async {
    if (_bulkSelection.isEmpty) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        title: Text(l10n.agencySeatsBulkBlockTitle),
        content: Text(
          l10n.agencySeatsBulkBlockMessage(_bulkSelection.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ThixPolicy.warning),
            child: Text(l10n.agencySeatsConfirmBlock),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _bulkUpdate(_SeatStatus.blocked);
  }

  Future<void> _bulkUnblock() async {
    if (_bulkSelection.isEmpty) return;

    await _bulkUpdate(_SeatStatus.available);
  }

  Future<void> _bulkUpdate(_SeatStatus newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final ids = _bulkSelection.toList();
      await Supabase.instance.client
          .from('bus_seats')
          .update({'status': newStatus.dbValue})
          .inFilter('id', ids)
          .timeout(const Duration(seconds: 15));

      await HapticFeedback.heavyImpact();
      setState(() {
        _bulkSelection.clear();
        _bulkMode = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.agencySeatsUpdateError),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _toggleBulkSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_bulkSelection.contains(id)) {
        _bulkSelection.remove(id);
        if (_bulkSelection.isEmpty) _bulkMode = false;
      } else {
        _bulkSelection.add(id);
      }
    });
  }

  void _enterBulkMode() {
    HapticFeedback.lightImpact();
    setState(() => _bulkMode = true);
  }

  void _exitBulkMode() {
    setState(() {
      _bulkMode = false;
      _bulkSelection.clear();
    });
  }

  _SeatStats get _stats {
    int available = 0, reserved = 0, sold = 0, blocked = 0;
    for (final s in _seats) {
      switch (s.status) {
        case _SeatStatus.available:
          available++;
          break;
        case _SeatStatus.reserved:
          reserved++;
          break;
        case _SeatStatus.sold:
          sold++;
          break;
        case _SeatStatus.blocked:
          blocked++;
          break;
      }
    }
    return _SeatStats(
      total: _seats.length,
      available: available,
      reserved: reserved,
      sold: sold,
      blocked: blocked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(domainColor),
      body: _loading
          ? const _SeatsSkeleton()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _seats.isEmpty
                  ? _EmptyView()
                  : RefreshIndicator(
                      color: domainColor,
                      onRefresh: _load,
                      child: _buildBody(domainColor),
                    ),
      bottomNavigationBar: _bulkMode
          ? _BulkActionBar(
              selectedCount: _bulkSelection.length,
              isUpdating: _isUpdating,
              onBlock: _bulkBlock,
              onUnblock: _bulkUnblock,
              onCancel: _exitBulkMode,
              domainColor: domainColor,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(Color domainColor) {
    final l10n = context.l10n;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () => context.pop(),
        tooltip: l10n.commonBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.agencySeatsTitle,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 15,
              color: ThixPolicy.textMain,
            ),
          ),
          if (widget.tripLabel != null)
            Text(
              widget.tripLabel!,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        if (!_bulkMode && !_loading && _seats.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.checklist_rounded,
              color: domainColor,
            ),
            tooltip: l10n.agencySeatsBulkMode,
            onPressed: _enterBulkMode,
          ),
        if (!_bulkMode)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            tooltip: l10n.commonRetry,
            onPressed: _isUpdating ? null : _load,
          ),
        SizedBox(width: ThixPolicy.s4),
      ],
    );
  }

  Widget _buildBody(Color domainColor) {
    final stats = _stats;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsHeader(stats: stats, domainColor: domainColor),
          SizedBox(height: ThixPolicy.s16),
          _LegendBar(domainColor: domainColor),
          SizedBox(height: ThixPolicy.s16),
          _BusLayout(
            seats: _seats,
            bulkMode: _bulkMode,
            bulkSelection: _bulkSelection,
            isUpdating: _isUpdating,
            onSeatTap: _handleSeatTap,
            domainColor: domainColor,
          ),
          SizedBox(height: ThixPolicy.s24),
          _CapacityInfo(stats: stats, domainColor: domainColor),
        ],
      ),
    );
  }

  void _handleSeatTap(_SeatData seat) {
    if (_bulkMode) {
      if (seat.status == _SeatStatus.reserved ||
          seat.status == _SeatStatus.sold) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.agencySeatsCannotSelectBooked),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      _toggleBulkSelection(seat.id);
    } else {
      _toggleSeat(seat);
    }
  }
}

/// ============================================================================
/// _SeatStatus — Enum des statuts de siège
/// ============================================================================
enum _SeatStatus {
  available('available'),
  reserved('reserved'),
  sold('sold'),
  blocked('blocked');

  final String dbValue;
  const _SeatStatus(this.dbValue);
}

/// ============================================================================
/// _SeatData — Représentation locale d'un siège
/// ============================================================================
class _SeatData {
  final String id;
  final String seatNumber;
  final _SeatStatus status;
  final bool isVip;

  const _SeatData({
    required this.id,
    required this.seatNumber,
    required this.status,
    this.isVip = false,
  });
}

/// ============================================================================
/// _SeatStats — Statistiques agrégées
/// ============================================================================
class _SeatStats {
  final int total;
  final int available;
  final int reserved;
  final int sold;
  final int blocked;

  const _SeatStats({
    required this.total,
    required this.available,
    required this.reserved,
    required this.sold,
    required this.blocked,
  });

  double get occupancyRate =>
      total > 0 ? ((reserved + sold) / total) * 100 : 0;
}

/// ============================================================================
/// _StatsHeader — Header avec stats temps réel
/// ============================================================================
class _StatsHeader extends StatelessWidget {
  final _SeatStats stats;
  final Color domainColor;

  const _StatsHeader({required this.stats, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  size: 14,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Text(
                l10n.agencySeatsStatsTitle,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                  color: ThixPolicy.textMain,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s10,
                  vertical: ThixPolicy.s4,
                ),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                ),
                child: Text(
                  '${stats.occupancyRate.toStringAsFixed(0)}%',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.agencySeatsStatAvailable,
                  value: stats.available,
                  color: ThixPolicy.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: _StatTile(
                  label: l10n.agencySeatsStatReserved,
                  value: stats.reserved,
                  color: ThixPolicy.warning,
                  icon: Icons.schedule_rounded,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: _StatTile(
                  label: l10n.agencySeatsStatSold,
                  value: stats.sold,
                  color: domainColor,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: _StatTile(
                  label: l10n.agencySeatsStatBlocked,
                  value: stats.blocked,
                  color: ThixPolicy.textMuted,
                  icon: Icons.block_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s12),
          // Progress bar occupation
          ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (stats.sold > 0)
                    Expanded(
                      flex: stats.sold,
                      child: Container(color: domainColor),
                    ),
                  if (stats.reserved > 0)
                    Expanded(
                      flex: stats.reserved,
                      child: Container(color: ThixPolicy.warning),
                    ),
                  if (stats.blocked > 0)
                    Expanded(
                      flex: stats.blocked,
                      child: Container(color: ThixPolicy.textMuted),
                    ),
                  if (stats.available > 0)
                    Expanded(
                      flex: stats.available,
                      child: Container(color: ThixPolicy.surfaceStrong),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ThixPolicy.s8,
        vertical: ThixPolicy.s10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              SizedBox(width: ThixPolicy.s4),
              Expanded(
                child: Text(
                  label,
                  style: ThixPolicy.microStyle.copyWith(
                    color: color,
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 9.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s4),
          Text(
            '$value',
            style: ThixPolicy.h3Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _LegendBar — Légende des statuts
/// ============================================================================
class _LegendBar extends StatelessWidget {
  final Color domainColor;

  const _LegendBar({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ThixPolicy.s10,
        horizontal: ThixPolicy.s12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            color: ThixPolicy.success,
            label: l10n.seatLegendAvailable,
          ),
          _LegendItem(
            color: ThixPolicy.warning,
            label: l10n.agencySeatsLegendReserved,
          ),
          _LegendItem(
            color: domainColor,
            label: l10n.agencySeatsLegendSold,
          ),
          _LegendItem(
            color: ThixPolicy.textMuted,
            label: l10n.agencySeatsLegendBlocked,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: ThixPolicy.s4),
        Text(
          label,
          style: ThixPolicy.microStyle.copyWith(
            fontSize: 10.5,
            fontWeight: ThixPolicy.semiBold,
            color: ThixPolicy.textMain,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _BusLayout — Plan de bus réaliste (2+2 avec couloir)
/// ============================================================================
class _BusLayout extends StatelessWidget {
  final List<_SeatData> seats;
  final bool bulkMode;
  final Set<String> bulkSelection;
  final bool isUpdating;
  final void Function(_SeatData) onSeatTap;
  final Color domainColor;

  const _BusLayout({
    required this.seats,
    required this.bulkMode,
    required this.bulkSelection,
    required this.isUpdating,
    required this.onSeatTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Regrouper les sièges par rangées de 4 (2 + couloir + 2)
    final rows = <List<_SeatData>>[];
    for (var i = 0; i < seats.length; i += 4) {
      final end = (i + 4).clamp(0, seats.length);
      rows.add(seats.sublist(i, end));
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
          border: Border.all(color: ThixPolicy.border, width: 2),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Windshield
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    border: Border.all(
                      color: domainColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                SizedBox(height: ThixPolicy.s12),

                // Driver + Door
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s10,
                        vertical: ThixPolicy.s6,
                      ),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_motorsports_rounded,
                            size: 14,
                            color: ThixPolicy.textSecondary,
                          ),
                          SizedBox(width: ThixPolicy.s4),
                          Text(
                            l10n.seatSelectionDriver,
                            style: ThixPolicy.microStyle.copyWith(
                              fontSize: 10,
                              fontWeight: ThixPolicy.semiBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.door_front_door_rounded,
                      size: 18,
                      color: ThixPolicy.textMuted,
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s14),

                // Seats
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s10),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  ),
                  child: Column(
                    children: rows.map((row) {
                      final left = row.length >= 2 ? row.sublist(0, 2) : row;
                      final right =
                          row.length > 2 ? row.sublist(2) : <_SeatData>[];

                      return Padding(
                        padding: EdgeInsets.only(bottom: ThixPolicy.s8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...left.map((s) => _SeatCell(
                                  seat: s,
                                  bulkMode: bulkMode,
                                  isSelected: bulkSelection.contains(s.id),
                                  isUpdating: isUpdating,
                                  onTap: () => onSeatTap(s),
                                  domainColor: domainColor,
                                )),
                            SizedBox(
                              width: 28,
                              child: Center(
                                child: Container(
                                  width: 2,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.borderStrong,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            ...right.map((s) => _SeatCell(
                                  seat: s,
                                  bulkMode: bulkMode,
                                  isSelected: bulkSelection.contains(s.id),
                                  isUpdating: isUpdating,
                                  onTap: () => onSeatTap(s),
                                  domainColor: domainColor,
                                )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: ThixPolicy.s8),
                Text(
                  l10n.seatSelectionAisle,
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontWeight: ThixPolicy.medium,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),

            // Overlay "Updating"
            if (isUpdating)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: domainColor,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: ThixPolicy.s12),
                        Text(
                          l10n.agencySeatsUpdating,
                          style: ThixPolicy.labelStyle.copyWith(
                            color: ThixPolicy.textMain,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ],
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

class _SeatCell extends StatelessWidget {
  final _SeatData seat;
  final bool bulkMode;
  final bool isSelected;
  final bool isUpdating;
  final VoidCallback onTap;
  final Color domainColor;

  const _SeatCell({
    required this.seat,
    required this.bulkMode,
    required this.isSelected,
    required this.isUpdating,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = _computeState();
    final isInteractive = state.isInteractive && !isUpdating;

    final statusLabel = _statusLabel(l10n, seat.status);
    final vipLabel = seat.isVip ? ' VIP' : '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s2),
      child: Semantics(
        button: isInteractive,
        selected: isSelected,
        enabled: isInteractive,
        label: '${l10n.agencySeatsSeatLabel(seat.seatNumber)} $statusLabel$vipLabel',
        child: Tooltip(
          message: '${seat.seatNumber} - $statusLabel$vipLabel',
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: isInteractive ? onTap : null,
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 52,
              decoration: BoxDecoration(
                color: state.backgroundColor,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                border: Border.all(
                  color: isSelected ? domainColor : state.borderColor,
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: domainColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconForStatus(seat.status, isSelected),
                          size: 14,
                          color: state.foregroundColor,
                        ),
                        SizedBox(height: ThixPolicy.s2),
                        Text(
                          seat.seatNumber,
                          style: ThixPolicy.microStyle.copyWith(
                            fontSize: 10,
                            fontWeight: ThixPolicy.bold,
                            color: state.foregroundColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (seat.isVip)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: ThixPolicy.warning,
                      ),
                    ),
                  if (bulkMode && isSelected)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: domainColor,
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

  IconData _iconForStatus(_SeatStatus status, bool isSelected) {
    if (isSelected) return Icons.check_rounded;
    switch (status) {
      case _SeatStatus.available:
        return Icons.airline_seat_recline_normal_rounded;
      case _SeatStatus.reserved:
        return Icons.schedule_rounded;
      case _SeatStatus.sold:
        return Icons.check_circle_rounded;
      case _SeatStatus.blocked:
        return Icons.block_rounded;
    }
  }

  _SeatVisualState _computeState() {
    switch (seat.status) {
      case _SeatStatus.available:
        return _SeatVisualState(
          backgroundColor: Colors.white,
          foregroundColor: ThixPolicy.textMain,
          borderColor: ThixPolicy.border,
          isInteractive: true,
        );
      case _SeatStatus.reserved:
        return _SeatVisualState(
          backgroundColor: ThixPolicy.warning.withValues(alpha: 0.15),
          foregroundColor: ThixPolicy.warning,
          borderColor: ThixPolicy.warning,
          isInteractive: false,
        );
      case _SeatStatus.sold:
        return _SeatVisualState(
          backgroundColor: domainColor.withValues(alpha: 0.15),
          foregroundColor: domainColor,
          borderColor: domainColor,
          isInteractive: false,
        );
      case _SeatStatus.blocked:
        return _SeatVisualState(
          backgroundColor: ThixPolicy.textMuted.withValues(alpha: 0.15),
          foregroundColor: ThixPolicy.textSecondary,
          borderColor: ThixPolicy.textMuted,
          isInteractive: true,
        );
    }
  }

  String _statusLabel(dynamic l10n, _SeatStatus status) {
    try {
      switch (status) {
        case _SeatStatus.available:
          return l10n.seatLegendAvailable;
        case _SeatStatus.reserved:
          return l10n.agencySeatsLegendReserved;
        case _SeatStatus.sold:
          return l10n.agencySeatsLegendSold;
        case _SeatStatus.blocked:
          return l10n.agencySeatsLegendBlocked;
      }
    } catch (_) {
      return status.dbValue;
    }
  }
}

class _SeatVisualState {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool isInteractive;

  const _SeatVisualState({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.isInteractive,
  });
}

/// ============================================================================
/// _CapacityInfo — Info capacité avec jauge
/// ============================================================================
class _CapacityInfo extends StatelessWidget {
  final _SeatStats stats;
  final Color domainColor;

  const _CapacityInfo({required this.stats, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: domainColor,
            ),
          ),
          SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.agencySeatsCapacityTitle,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                ),
                SizedBox(height: ThixPolicy.s2),
                Text(
                  l10n.agencySeatsCapacityMessage(
                    stats.sold + stats.reserved,
                    stats.total,
                  ),
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textSecondary,
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

/// ============================================================================
/// _BulkActionBar — Barre d'actions bulk en bas
/// ============================================================================
class _BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final bool isUpdating;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onCancel;
  final Color domainColor;

  const _BulkActionBar({
    required this.selectedCount,
    required this.isUpdating,
    required this.onBlock,
    required this.onUnblock,
    required this.onCancel,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s12,
        ThixPolicy.s16,
        ThixPolicy.s16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ThixPolicy.s10,
                    vertical: ThixPolicy.s6,
                  ),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: domainColor,
                      ),
                      SizedBox(width: ThixPolicy.s4),
                      Text(
                        '$selectedCount ${l10n.agencySeatsBulkSelected}',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: domainColor,
                          fontWeight: ThixPolicy.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: isUpdating ? null : onCancel,
                  child: Text(l10n.commonCancel),
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        selectedCount == 0 || isUpdating ? null : onUnblock,
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: Text(l10n.agencySeatsBulkUnblock),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThixPolicy.success,
                      side: BorderSide(color: ThixPolicy.success),
                      padding: EdgeInsets.symmetric(
                        vertical: ThixPolicy.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ThixPolicy.s8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        selectedCount == 0 || isUpdating ? null : onBlock,
                    icon: const Icon(Icons.lock_rounded, size: 16),
                    label: Text(l10n.agencySeatsBulkBlock),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.warning,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        vertical: ThixPolicy.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _SeatsSkeleton — Skeleton loader
/// ============================================================================
class _SeatsSkeleton extends StatefulWidget {
  const _SeatsSkeleton();

  @override
  State<_SeatsSkeleton> createState() => _SeatsSkeletonState();
}

class _SeatsSkeletonState extends State<_SeatsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final alpha = (0.5 + (_ctrl.value * 0.3)).clamp(0.0, 1.0);
        final color = ThixPolicy.surfaceStrong.withValues(alpha: alpha);

        return SingleChildScrollView(
          padding: EdgeInsets.all(ThixPolicy.s16),
          child: Column(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                ),
                padding: EdgeInsets.all(ThixPolicy.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 120, height: 14, color: color),
                    SizedBox(height: ThixPolicy.s12),
                    Row(
                      children: List.generate(
                        4,
                        (_) => Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: ThixPolicy.s4),
                            child: _SkeletonBox(height: 50, color: color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ThixPolicy.s16),
              _SkeletonBox(height: 40, color: color),
              SizedBox(height: ThixPolicy.s16),
              Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                  border: Border.all(color: ThixPolicy.border),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final Color color;

  const _SkeletonBox({this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
    );
  }
}

/// ============================================================================
/// _ErrorView — Vue d'erreur
/// ============================================================================
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: ThixPolicy.danger,
              ),
            ),
            SizedBox(height: ThixPolicy.s20),
            Text(
              l10n.commonError,
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThixPolicy.s8),
            Text(
              error,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThixPolicy.s24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.domainReservation,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _EmptyView — Vue vide (aucun siège)
/// ============================================================================
class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_seat_outlined,
                size: 40,
                color: ThixPolicy.domainReservation.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: ThixPolicy.s20),
            Text(
              l10n.agencySeatsEmptyTitle,
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThixPolicy.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                l10n.agencySeatsEmptyMessage,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// AnimatedBuilder — Polyfill
/// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
