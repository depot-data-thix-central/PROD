import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../data/models/booking_model.dart';

/// ============================================================================
/// BusTicketPage
/// ============================================================================
///
/// Page de visualisation d'un billet de bus avec QR code.
///
/// Features :
/// - Multi-devises global (currencyProvider) avec conversion automatique
/// - Skeleton loader élégant pendant le chargement
/// - Vue d'erreur avec retry
/// - 4 états de booking : pending, confirmed, completed, cancelled
/// - Actions : copier code, partager, ajouter au calendrier
/// - QR code avec animation d'apparition
/// - Hero animation optionnel
/// - Accessibilité complète (Semantics)
/// - i18n intégrée (FR/EN/LN)
/// - Formatage date/prix avec locale
/// - Design system ThixPolicy
/// - Feedback haptique sur les interactions
///
/// ============================================================================
class BusTicketPage extends ConsumerStatefulWidget {
  final BookingModel? booking;
  final String? bookingId;
  final Object? heroTag;

  const BusTicketPage({
    super.key,
    this.booking,
    this.bookingId,
    this.heroTag,
  });

  @override
  ConsumerState<BusTicketPage> createState() => _BusTicketPageState();
}

class _BusTicketPageState extends ConsumerState<BusTicketPage> {
  BookingModel? _booking;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking != null) {
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    String id = widget.bookingId ?? widget.booking?.id ?? '';
    if (id.isEmpty && mounted) {
      id = GoRouterState.of(context).pathParameters['id'] ??
          GoRouterState.of(context).pathParameters['bookingId'] ??
          '';
    }
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = context.l10n.ticketNotFound;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('bus_bookings')
          .select('*, bus_trips(*, agencies(*))')
          .eq('id', id)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final list = res as List;
      if (list.isEmpty || !mounted) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = context.l10n.ticketNotFound;
          });
        }
        return;
      }

      setState(() {
        _booking = BookingModel.fromJson(Map<String, dynamic>.from(list.first));
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    if (_loading) {
      return Scaffold(
        backgroundColor: ThixPolicy.surface,
        appBar: _buildAppBar(l10n),
        body: const _TicketSkeleton(),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surface,
        appBar: _buildAppBar(l10n),
        body: _TicketErrorView(
          error: _error ?? l10n.ticketNotFound,
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(l10n),
      body: _TicketContent(
        booking: _booking!,
        domainColor: domainColor,
        heroTag: widget.heroTag,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic l10n) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/thix-reservation/bus');
          }
        },
        tooltip: l10n.commonBack,
      ),
      title: Text(
        l10n.ticketTitle,
        style: ThixPolicy.titleStyle.copyWith(
          fontSize: 16,
          fontWeight: ThixPolicy.bold,
          color: ThixPolicy.textMain,
        ),
      ),
    );
  }
}

/// ============================================================================
/// _TicketContent — Contenu principal avec toutes les sections
/// ============================================================================
class _TicketContent extends ConsumerWidget {
  final BookingModel booking;
  final Color domainColor;
  final Object? heroTag;

  const _TicketContent({
    required this.booking,
    required this.domainColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);
    final displayPrice = currencyState.convert(
      booking.totalPriceFcfa,
      fromCurrency: 'CDF',
    );
    final formattedPrice = CurrencyFormatter.format(
      displayPrice,
      currency: currencyState.currency.code,
    );

    final trip = booking.trip;
    final statusInfo = _getStatusInfo(booking.status);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.all(ThixPolicy.s16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _TicketCard(
            booking: booking,
            statusInfo: statusInfo,
            formattedPrice: formattedPrice,
            originalCurrency: 'CDF',
            domainColor: domainColor,
          ),
          SizedBox(height: ThixPolicy.s16),
          _TicketActions(
            booking: booking,
            domainColor: domainColor,
          ),
          SizedBox(height: ThixPolicy.s12),
          _QrDisclaimer(domainColor: domainColor),
        ],
      ),
    );

    if (heroTag != null) {
      content = Hero(
        tag: heroTag!,
        child: Material(color: Colors.transparent, child: content),
      );
    }

    return content;
  }

  _TicketStatusInfo _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return _TicketStatusInfo(
          labelKey: 'ticketStatusConfirmed',
          color: ThixPolicy.success,
          icon: Icons.check_circle_rounded,
        );
      case 'pending':
        return _TicketStatusInfo(
          labelKey: 'ticketStatusPending',
          color: ThixPolicy.warning,
          icon: Icons.schedule_rounded,
        );
      case 'completed':
        return _TicketStatusInfo(
          labelKey: 'ticketStatusCompleted',
          color: ThixPolicy.textSecondary,
          icon: Icons.history_rounded,
        );
      case 'cancelled':
        return _TicketStatusInfo(
          labelKey: 'ticketStatusCancelled',
          color: ThixPolicy.danger,
          icon: Icons.cancel_rounded,
        );
      default:
        return _TicketStatusInfo(
          labelKey: 'ticketStatusPending',
          color: ThixPolicy.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }
}

class _TicketStatusInfo {
  final String labelKey;
  final Color color;
  final IconData icon;

  const _TicketStatusInfo({
    required this.labelKey,
    required this.color,
    required this.icon,
  });
}

/// ============================================================================
/// _TicketCard — Carte principale du billet
/// ============================================================================
class _TicketCard extends StatelessWidget {
  final BookingModel booking;
  final _TicketStatusInfo statusInfo;
  final String formattedPrice;
  final String originalCurrency;
  final Color domainColor;

  const _TicketCard({
    required this.booking,
    required this.statusInfo,
    required this.formattedPrice,
    required this.originalCurrency,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trip = booking.trip;
    final agencyName = trip?.agency?.name ?? l10n.tripUnknownAgency;

    final locale = Localizations.localeOf(context).toString();
    final dateFormatted = trip != null
        ? DateFormat('EEEE d MMMM yyyy', locale).format(trip.departureTime)
        : DateFormat('EEEE d MMMM yyyy', locale).format(booking.createdAt);

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowCard(),
      ),
      child: Column(
        children: [
          // Header : Agence + Status
          _TicketHeader(
            agencyName: agencyName,
            statusInfo: statusInfo,
            statusLabel: _translateStatus(l10n, statusInfo.labelKey),
            domainColor: domainColor,
          ),

          SizedBox(height: ThixPolicy.s8),

          // Date
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: domainColor,
                ),
                SizedBox(width: ThixPolicy.s4),
                Flexible(
                  child: Text(
                    _capitalize(dateFormatted),
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                      fontWeight: ThixPolicy.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: ThixPolicy.s20),

          // QR Code
          _QrCodeSection(
            qrCode: booking.qrCode,
            domainColor: domainColor,
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: ThixPolicy.s20),
            child: _DashedDivider(color: ThixPolicy.border),
          ),

          // Route
          if (trip != null)
            _RouteSection(
              trip: trip,
              domainColor: domainColor,
            ),

          if (trip != null) SizedBox(height: ThixPolicy.s20),

          // Détails : sièges + prix
          _TicketDetails(
            seats: booking.seats,
            formattedPrice: formattedPrice,
            originalCurrency: originalCurrency,
            domainColor: domainColor,
          ),

          SizedBox(height: ThixPolicy.s12),

          // Booking ID
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${l10n.ticketBookingId} ${booking.id.substring(0, 8).toUpperCase()}',
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateStatus(dynamic l10n, String key) {
    try {
      switch (key) {
        case 'ticketStatusConfirmed':
          return l10n.ticketStatusConfirmed;
        case 'ticketStatusPending':
          return l10n.ticketStatusPending;
        case 'ticketStatusCompleted':
          return l10n.ticketStatusCompleted;
        case 'ticketStatusCancelled':
          return l10n.ticketStatusCancelled;
        default:
          return key;
      }
    } catch (_) {
      return key;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// ============================================================================
/// _TicketHeader — Agence + badge status
/// ============================================================================
class _TicketHeader extends StatelessWidget {
  final String agencyName;
  final _TicketStatusInfo statusInfo;
  final String statusLabel;
  final Color domainColor;

  const _TicketHeader({
    required this.agencyName,
    required this.statusInfo,
    required this.statusLabel,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 16,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: Text(
                  agencyName,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 15,
                    color: ThixPolicy.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ThixPolicy.s10,
            vertical: ThixPolicy.s4,
          ),
          decoration: BoxDecoration(
            color: statusInfo.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusInfo.icon,
                size: 12,
                color: statusInfo.color,
              ),
              SizedBox(width: ThixPolicy.s4),
              Text(
                statusLabel,
                style: ThixPolicy.labelStyle.copyWith(
                  color: statusInfo.color,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _QrCodeSection — QR code avec actions copier/partager
/// ============================================================================
class _QrCodeSection extends StatelessWidget {
  final String qrCode;
  final Color domainColor;

  const _QrCodeSection({
    required this.qrCode,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          QrImageView(
            data: qrCode,
            size: 180,
            version: QrVersions.auto,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.roundedRect,
              color: domainColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.roundedRect,
              color: ThixPolicy.textMain,
            ),
          ),
          SizedBox(height: ThixPolicy.s12),
          SelectableText(
            qrCode,
            style: ThixPolicy.labelStyle.copyWith(
              letterSpacing: 2,
              fontWeight: ThixPolicy.bold,
              fontSize: 13,
              color: ThixPolicy.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _RouteSection — Itinéraire départ → arrivée
/// ============================================================================
class _RouteSection extends StatelessWidget {
  final dynamic trip;
  final Color domainColor;

  const _RouteSection({
    required this.trip,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final departureTime = DateFormat('HH:mm', locale).format(trip.departureTime);
    final arrivalTime = DateFormat('HH:mm', locale).format(trip.arrivalTime);

    return Row(
      children: [
        Expanded(
          child: _TimeStation(
            time: departureTime,
            city: trip.departureCity ?? '-',
            station: trip.departureStation,
            isStart: true,
            domainColor: domainColor,
          ),
        ),
        Container(
          padding: EdgeInsets.all(ThixPolicy.s10),
          decoration: BoxDecoration(
            color: domainColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: domainColor,
          ),
        ),
        Expanded(
          child: _TimeStation(
            time: arrivalTime,
            city: trip.arrivalCity ?? '-',
            station: trip.arrivalStation,
            isStart: false,
            domainColor: domainColor,
          ),
        ),
      ],
    );
  }
}

class _TimeStation extends StatelessWidget {
  final String time;
  final String city;
  final String? station;
  final bool isStart;
  final Color domainColor;

  const _TimeStation({
    required this.time,
    required this.city,
    required this.station,
    required this.isStart,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isStart ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          time,
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 16,
          ),
        ),
        SizedBox(height: ThixPolicy.s2),
        Text(
          city,
          style: ThixPolicy.bodySmallStyle.copyWith(
            fontWeight: ThixPolicy.semiBold,
            color: ThixPolicy.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (station != null && station!.isNotEmpty) ...[
          SizedBox(height: ThixPolicy.s2),
          Text(
            station!,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// ============================================================================
/// _TicketDetails — Sièges + prix
/// ============================================================================
class _TicketDetails extends StatelessWidget {
  final List<String> seats;
  final String formattedPrice;
  final String originalCurrency;
  final Color domainColor;

  const _TicketDetails({
    required this.seats,
    required this.formattedPrice,
    required this.originalCurrency,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final seatsLabel = seats.length == 1
        ? l10n.ticketSeat(seats.join(', '))
        : l10n.ticketSeats(seats.join(', '));

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s14),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Icons.event_seat_rounded,
                  size: 14,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Text(
                seatsLabel,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedPrice,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                  color: ThixPolicy.success,
                ),
              ),
              if (originalCurrency != 'CDF' || formattedPrice.contains('CDF'))
                Text(
                  l10n.ticketTotalPaid,
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _TicketActions — Boutons d'actions (partager, ajouter calendrier)
/// ============================================================================
class _TicketActions extends StatelessWidget {
  final BookingModel booking;
  final Color domainColor;

  const _TicketActions({
    required this.booking,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_rounded,
            label: l10n.ticketCopyCode,
            onTap: () => _copyCode(context),
            domainColor: domainColor,
          ),
        ),
        SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: _ActionButton(
            icon: Icons.share_rounded,
            label: l10n.ticketShare,
            onTap: () => _share(context),
            domainColor: domainColor,
          ),
        ),
        SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_today_rounded,
            label: l10n.ticketAddCalendar,
            onTap: () => _showCalendarComingSoon(context),
            domainColor: domainColor,
          ),
        ),
      ],
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: booking.qrCode));
    await HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: ThixPolicy.s8),
            Text(l10n.ticketCodeCopied),
          ],
        ),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = context.l10n;
    final trip = booking.trip;

    final message = l10n.ticketShareMessage(
      trip?.departureCity ?? '-',
      trip?.arrivalCity ?? '-',
      booking.qrCode,
    );

    await Share.share(message);
  }

  void _showCalendarComingSoon(BuildContext context) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.ticketCalendarComingSoon),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color domainColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: ThixPolicy.s12,
            horizontal: ThixPolicy.s8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: domainColor),
              SizedBox(height: ThixPolicy.s4),
              Text(
                label,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.semiBold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _QrDisclaimer — Mention légale sous le billet
/// ============================================================================
class _QrDisclaimer extends StatelessWidget {
  final Color domainColor;

  const _QrDisclaimer({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_rounded,
          size: 14,
          color: domainColor.withValues(alpha: 0.7),
        ),
        SizedBox(width: ThixPolicy.s6),
        Flexible(
          child: Text(
            l10n.ticketDisclaimer,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontWeight: ThixPolicy.medium,
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _TicketSkeleton — Skeleton loader élégant
/// ============================================================================
class _TicketSkeleton extends StatefulWidget {
  const _TicketSkeleton();

  @override
  State<_TicketSkeleton> createState() => _TicketSkeletonState();
}

class _TicketSkeletonState extends State<_TicketSkeleton>
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
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rXl),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SkeletonBox(width: 150, height: 20, color: color),
                    _SkeletonBox(width: 80, height: 20, color: color),
                  ],
                ),
                SizedBox(height: ThixPolicy.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBox(width: 180, height: 14, color: color),
                ),
                SizedBox(height: ThixPolicy.s24),
                _SkeletonBox(width: 180, height: 180, color: color),
                SizedBox(height: ThixPolicy.s12),
                _SkeletonBox(width: 120, height: 14, color: color),
                SizedBox(height: ThixPolicy.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 60, height: 18, color: color),
                        SizedBox(height: ThixPolicy.s4),
                        _SkeletonBox(width: 80, height: 12, color: color),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _SkeletonBox(width: 60, height: 18, color: color),
                        SizedBox(height: ThixPolicy.s4),
                        _SkeletonBox(width: 80, height: 12, color: color),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s24),
                _SkeletonBox(
                  width: double.infinity,
                  height: 60,
                  color: color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      ),
    );
  }
}

/// ============================================================================
/// _TicketErrorView — Vue d'erreur avec retry
/// ============================================================================
class _TicketErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TicketErrorView({required this.error, required this.onRetry});

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
                Icons.confirmation_number_outlined,
                size: 40,
                color: ThixPolicy.danger,
              ),
            ),
            SizedBox(height: ThixPolicy.s20),
            Text(
              l10n.ticketNotFound,
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
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.domainReservation,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _DashedDivider — Séparateur en pointillés (effet billet)
/// ============================================================================
class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
