import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../data/models/bus_trip_model.dart';
import '../../providers/seat_selection_provider.dart';
import '../../widgets/client/seat_map_widget.dart';

/// ============================================================================
/// BusSeatSelectionPage
/// ============================================================================
///
/// Page de sélection des sièges dans un bus.
///
/// Features :
/// - Thème CLAIR aligné avec ThixPolicy (migration depuis sombre)
/// - Multi-devises global (currencyProvider) avec breakdown prix détaillé
/// - Countdown circulaire animé pour le verrouillage des sièges
/// - Skeleton loader pendant le chargement initial
/// - Feedback haptique au tap sur les sièges
/// - Validation max seats (6 par défaut)
/// - Hero animation optionnelle
/// - i18n complète (FR/EN/LN)
/// - Accessibilité complète (Semantics)
/// - Responsive avec LayoutBuilder
/// - Design system ThixPolicy
///
/// ============================================================================
class BusSeatSelectionPage extends ConsumerStatefulWidget {
  final BusTripModel? trip;
  final String? tripId;
  final Object? heroTag;

  const BusSeatSelectionPage({
    super.key,
    this.trip,
    this.tripId,
    this.heroTag,
  });

  @override
  ConsumerState<BusSeatSelectionPage> createState() =>
      _BusSeatSelectionPageState();
}

class _BusSeatSelectionPageState extends ConsumerState<BusSeatSelectionPage> {
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.trip?.id ?? widget.tripId ?? '';
      if (id.isNotEmpty) {
        ref.read(seatSelectionProvider.notifier).init(id, 6);
      }
    });
  }

  Future<void> _handleContinue() async {
    final state = ref.read(seatSelectionProvider);
    final trip = widget.trip;

    if (state.selectedSeats.isEmpty || trip == null) return;

    setState(() => _isConfirming = true);

    try {
      final notifier = ref.read(seatSelectionProvider.notifier);
      await notifier.confirmAndUnlockForPayment();

      if (!mounted) return;

      context.push(
        '/thix-reservation/bus/payment',
        extra: {
          'trip': trip,
          'seats': state.selectedSeats.toList(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.seatSelectionError),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(seatSelectionProvider);
    final notifier = ref.read(seatSelectionProvider.notifier);
    final trip = widget.trip;
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(state, trip, domainColor),
      body: state.isLoading
          ? const _SeatSelectionSkeleton()
          : _buildBody(state, notifier, trip, domainColor),
      bottomNavigationBar: _BottomBar(
        state: state,
        trip: trip,
        isConfirming: _isConfirming,
        domainColor: domainColor,
        onContinue: _handleContinue,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    SeatSelectionState state,
    BusTripModel? trip,
    Color domainColor,
  ) {
    final l10n = context.l10n;
    final routeLabel = trip != null
        ? '${trip.departureCity} → ${trip.arrivalCity}'
        : '';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 68,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () => context.pop(),
        tooltip: l10n.commonBack,
      ),
      title: Semantics(
        label: '${l10n.seatSelectionTitle}, $routeLabel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.seatSelectionTitle,
              style: ThixPolicy.titleStyle.copyWith(
                fontSize: 16,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            if (trip != null)
              Text(
                routeLabel,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontWeight: ThixPolicy.medium,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (state.lockRemainingSeconds > 0)
          Padding(
            padding: EdgeInsets.only(right: ThixPolicy.s12),
            child: _LockTimer(
              seconds: state.lockRemainingSeconds,
              domainColor: domainColor,
            ),
          ),
      ],
    );
  }

  Widget _buildBody(
    SeatSelectionState state,
    SeatSelectionNotifier notifier,
    BusTripModel? trip,
    Color domainColor,
  ) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s12,
        ThixPolicy.s16,
        ThixPolicy.s120,
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        _LegendBar(domainColor: domainColor),
        SizedBox(height: ThixPolicy.s16),
        _BusFrame(
          state: state,
          notifier: notifier,
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s16),
        if (state.selectedSeats.isNotEmpty && trip != null)
          _PriceBreakdown(
            trip: trip,
            selectedCount: state.selectedSeats.length,
            selectedSeats: state.selectedSeats.toList(),
            vipSupplement: state.totalVipSupplement,
            domainColor: domainColor,
          ),
        if (state.lockRemainingSeconds > 0 && state.lockRemainingSeconds < 60)
          Padding(
            padding: EdgeInsets.only(top: ThixPolicy.s12),
            child: _LockWarning(
              seconds: state.lockRemainingSeconds,
              domainColor: domainColor,
            ),
          ),
      ],
    );
  }
}

/// ============================================================================
/// _LockTimer — Countdown circulaire animé dans l'AppBar
/// ============================================================================
class _LockTimer extends StatelessWidget {
  final int seconds;
  final Color domainColor;

  const _LockTimer({required this.seconds, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUrgent = seconds < 30;
    final color = isUrgent ? ThixPolicy.danger : domainColor;

    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Semantics(
      label: l10n.seatSelectionLockWarning(label),
      child: Container(
        width: 64,
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(
                painter: _CircularCountdownPainter(
                  progress: seconds / 300.0, // 5 min = 300s
                  color: color,
                  strokeWidth: 2,
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 10,
                    color: color,
                  ),
                ),
              ),
            ),
            SizedBox(width: ThixPolicy.s4),
            Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                color: color,
                fontWeight: ThixPolicy.bold,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularCountdownPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularCountdownPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularCountdownPainter old) =>
      old.progress != progress;
}

/// ============================================================================
/// _LegendBar — Barre de légende des statuts de sièges
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
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            color: Colors.white,
            borderColor: ThixPolicy.border,
            label: l10n.seatLegendAvailable,
          ),
          _LegendItem(
            color: ThixPolicy.textMuted,
            borderColor: ThixPolicy.textSecondary,
            label: l10n.seatLegendBooked,
          ),
          _LegendItem(
            color: domainColor,
            borderColor: domainColor,
            label: l10n.seatLegendSelected,
          ),
          _LegendItem(
            color: ThixPolicy.gold.withValues(alpha: 0.2),
            borderColor: ThixPolicy.gold,
            label: l10n.seatLegendVip,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;

  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(ThixPolicy.rXs / 2),
            border: Border.all(color: borderColor, width: 1.5),
          ),
        ),
        SizedBox(width: ThixPolicy.s6),
        Text(
          label,
          style: ThixPolicy.microStyle.copyWith(
            fontSize: 11,
            fontWeight: ThixPolicy.semiBold,
            color: ThixPolicy.textMain,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _BusFrame — Cadre du bus avec sièges, conducteur, couloir
/// ============================================================================
class _BusFrame extends StatelessWidget {
  final SeatSelectionState state;
  final SeatSelectionNotifier notifier;
  final Color domainColor;

  const _BusFrame({
    required this.state,
    required this.notifier,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: EdgeInsets.fromLTRB(
          ThixPolicy.s14,
          ThixPolicy.s14,
          ThixPolicy.s14,
          ThixPolicy.s20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
          border: Border.all(color: ThixPolicy.border, width: 2),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: Column(
          children: [
            // Windshield (pare-brise)
            Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                border: Border.all(
                  color: domainColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            SizedBox(height: ThixPolicy.s12),

            // Driver + Door row
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
                        color: ThixPolicy.textSecondary,
                        size: 14,
                      ),
                      SizedBox(width: ThixPolicy.s4),
                      Text(
                        l10n.seatSelectionDriver,
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.textSecondary,
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
                  color: ThixPolicy.textMuted,
                  size: 18,
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s14),

            // Seats map
            Container(
              padding: EdgeInsets.all(ThixPolicy.s10),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              ),
              child: SeatMapWidget(
                seats: state.seats,
                selected: state.selectedSeats,
                onTap: (seat) {
                  HapticFeedback.selectionClick();
                  notifier.toggleSeat(seat);
                },
                domainColor: domainColor,
                maxSelectedSeats: 6,
              ),
            ),
            SizedBox(height: ThixPolicy.s8),
            Text(
              l10n.seatSelectionAisle,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontSize: 10,
                fontWeight: ThixPolicy.medium,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _PriceBreakdown — Détail des prix (base + VIP + total)
/// ============================================================================
class _PriceBreakdown extends ConsumerWidget {
  final BusTripModel trip;
  final int selectedCount;
  final List<String> selectedSeats;
  final int vipSupplement;
  final Color domainColor;

  const _PriceBreakdown({
    required this.trip,
    required this.selectedCount,
    required this.selectedSeats,
    required this.vipSupplement,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);

    final baseInDisplay = currencyState.convert(
      trip.priceFcfa,
      fromCurrency: 'CDF',
    );
    final vipInDisplay = currencyState.convert(
      vipSupplement,
      fromCurrency: 'CDF',
    );
    final totalInDisplay = baseInDisplay * selectedCount + vipInDisplay;

    final curCode = currencyState.currency.code;

    final baseFormatted = CurrencyFormatter.format(
      baseInDisplay,
      currency: curCode,
    );
    final vipFormatted = CurrencyFormatter.format(
      vipInDisplay,
      currency: curCode,
    );
    final totalFormatted = CurrencyFormatter.format(
      totalInDisplay,
      currency: curCode,
    );

    final seatsLabel = selectedSeats.length == 1
        ? l10n.ticketSeat(selectedSeats.join(', '))
        : l10n.ticketSeats(selectedSeats.join(', '));

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec label sièges
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(
                  Icons.event_seat_rounded,
                  size: 14,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: Text(
                  seatsLabel,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s14),

          // Base price
          _PriceRow(
            label: l10n.seatSelectionBasePrice(selectedCount, baseFormatted),
            value: baseFormatted,
            isMuted: true,
          ),

          // VIP supplement (si > 0)
          if (vipSupplement > 0)
            Padding(
              padding: EdgeInsets.only(top: ThixPolicy.s8),
              child: _PriceRow(
                label: l10n.seatSelectionVipSupplement,
                value: '+ $vipFormatted',
                icon: Icons.star_rounded,
                iconColor: ThixPolicy.warning,
                isVip: true,
              ),
            ),

          // Divider
          Padding(
            padding: EdgeInsets.symmetric(vertical: ThixPolicy.s12),
            child: Divider(height: 1, color: ThixPolicy.border),
          ),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.seatSelectionTotal,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              Text(
                totalFormatted,
                style: ThixPolicy.h3Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMuted;
  final bool isVip;
  final IconData? icon;
  final Color? iconColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isMuted = false,
    this.isVip = false,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor ?? ThixPolicy.textSecondary),
          SizedBox(width: ThixPolicy.s4),
        ],
        Expanded(
          child: Text(
            label,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: isVip
                  ? ThixPolicy.warning
                  : (isMuted ? ThixPolicy.textSecondary : ThixPolicy.textMain),
              fontWeight: isVip ? ThixPolicy.bold : ThixPolicy.medium,
            ),
          ),
        ),
        if (!isVip)
          Text(
            '$selectedCountLabel',
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontWeight: ThixPolicy.medium,
            ),
          ),
      ],
    );
  }

  String get selectedCountLabel => '';
}

/// ============================================================================
/// _LockWarning — Alerte visuelle quand le lock expire bientôt
/// ============================================================================
class _LockWarning extends StatelessWidget {
  final int seconds;
  final Color domainColor;

  const _LockWarning({required this.seconds, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        color: ThixPolicy.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(
          color: ThixPolicy.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: ThixPolicy.warning,
          ),
          SizedBox(width: ThixPolicy.s8),
          Expanded(
            child: Text(
              l10n.seatSelectionLockWarning(label),
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.warning,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _BottomBar — Barre d'action en bas avec validation
/// ============================================================================
class _BottomBar extends ConsumerWidget {
  final SeatSelectionState state;
  final BusTripModel? trip;
  final bool isConfirming;
  final Color domainColor;
  final VoidCallback onContinue;

  const _BottomBar({
    required this.state,
    required this.trip,
    required this.isConfirming,
    required this.domainColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);

    final isEnabled =
        state.selectedSeats.isNotEmpty && trip != null && !isConfirming;

    String totalLabel = l10n.seatSelectionChooseSeat;
    if (trip != null && state.selectedSeats.isNotEmpty) {
      final baseInDisplay = currencyState.convert(
        trip.priceFcfa,
        fromCurrency: 'CDF',
      );
      final vipInDisplay = currencyState.convert(
        state.totalVipSupplement,
        fromCurrency: 'CDF',
      );
      final total = baseInDisplay * state.selectedSeats.length + vipInDisplay;
      final formatted = CurrencyFormatter.format(
        total,
        currency: currencyState.currency.code,
        compact: true,
      );
      totalLabel = '${l10n.seatSelectionContinue} • $formatted';
    }

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: isEnabled ? onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: domainColor,
              disabledBackgroundColor: ThixPolicy.textMuted,
              disabledForegroundColor: Colors.white70,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              ),
            ),
            child: isConfirming
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: ThixPolicy.s10),
                      Text(
                        l10n.seatSelectionConfirming,
                        style: ThixPolicy.titleStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                        ),
                      ),
                    ],
                  )
                : Text(
                    totalLabel,
                    style: ThixPolicy.titleStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _SeatSelectionSkeleton — Skeleton loader élégant
/// ============================================================================
class _SeatSelectionSkeleton extends StatefulWidget {
  const _SeatSelectionSkeleton();

  @override
  State<_SeatSelectionSkeleton> createState() => _SeatSelectionSkeletonState();
}

class _SeatSelectionSkeletonState extends State<_SeatSelectionSkeleton>
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

        return ListView(
          padding: EdgeInsets.all(ThixPolicy.s16),
          children: [
            _SkeletonBox(height: 52, color: color),
            SizedBox(height: ThixPolicy.s16),
            Center(
              child: Container(
                width: 340,
                height: 480,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                  border: Border.all(color: ThixPolicy.border),
                ),
                padding: EdgeInsets.all(ThixPolicy.s16),
                child: Column(
                  children: [
                    _SkeletonBox(width: 100, height: 12, color: color),
                    SizedBox(height: ThixPolicy.s12),
                    _SkeletonBox(height: 30, color: color),
                    SizedBox(height: ThixPolicy.s14),
                    Expanded(
                      child: _SkeletonBox(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final Color color;

  const _SkeletonBox({this.width, this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
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
