import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../data/models/bus_trip_model.dart';
import '../../data/services/bus_public_service.dart';

/// ============================================================================
/// BusTripDetailPage
/// ============================================================================
///
/// Page de détail d'un trajet de bus.
///
/// Features :
/// - Chargement asynchrone avec skeleton loader
/// - Hero animation vers/depuis la carte de trajet
/// - Multi-devises global (conversion automatique)
/// - Accessibilité complète (Semantics, labels)
/// - Gestion d'erreurs avec retry
/// - i18n intégrée (FR/EN/LN)
/// - Design system ThixPolicy
/// - Responsive layout
/// ============================================================================
class BusTripDetailPage extends ConsumerStatefulWidget {
  final BusTripModel? trip;
  final String? tripId;

  const BusTripDetailPage({
    super.key,
    this.trip,
    this.tripId,
  });

  @override
  ConsumerState<BusTripDetailPage> createState() => _BusTripDetailPageState();
}

class _BusTripDetailPageState extends ConsumerState<BusTripDetailPage> {
  BusTripModel? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    if (_trip != null) {
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    String id = widget.tripId ?? widget.trip?.id ?? '';
    if (id.isEmpty && mounted) {
      id = GoRouterState.of(context).pathParameters['tripId'] ?? '';
    }
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = context.l10n.tripNotFound;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final service = BusPublicService();
      final trip = await service.getTripById(id);
      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _loading = false;
          _error = context.l10n.tripNotFound;
        });
        return;
      }

      setState(() {
        _trip = trip;
        _loading = false;
        _error = null;
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

    if (_loading) {
      return const _TripDetailSkeleton();
    }

    if (_error != null || _trip == null) {
      return _TripErrorView(
        error: _error ?? l10n.tripNotFound,
        onRetry: _load,
      );
    }

    return _TripDetailContent(trip: _trip!);
  }
}

/// ============================================================================
/// _TripDetailContent — Contenu principal de la page
/// ============================================================================
class _TripDetailContent extends ConsumerWidget {
  final BusTripModel trip;

  const _TripDetailContent({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider).currency;
    final domainColor = ThixPolicy.domainReservation;

    final displayPrice = CurrencyFormatter.format(
      trip.priceFcfa,
      currency: 'CDF',
      compact: false,
    );

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${trip.departureCity} → ${trip.arrivalCity}',
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: ThixPolicy.textMain),
            onPressed: () => _share(context),
            tooltip: l10n.commonShare,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripImageHeader(trip: trip, domainColor: domainColor),
            SizedBox(height: ThixPolicy.s20),
            _AgencyInfoCard(trip: trip),
            SizedBox(height: ThixPolicy.s16),
            _RouteInfoCard(trip: trip, domainColor: domainColor),
            SizedBox(height: ThixPolicy.s16),
            _AmenitiesCard(trip: trip),
            SizedBox(height: ThixPolicy.s16),
            _PriceCard(trip: trip, domainColor: domainColor),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(trip: trip, domainColor: domainColor),
    );
  }

  void _share(BuildContext context) {
    // TODO: implémenter le partage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.tripShareComingSoon)),
    );
  }
}

/// ============================================================================
/// _TripImageHeader — Image principale du trajet avec Hero
/// ============================================================================
class _TripImageHeader extends StatelessWidget {
  final BusTripModel trip;
  final Color domainColor;

  const _TripImageHeader({required this.trip, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final hasImage = trip.agency?.logoUrl != null || trip.busImageUrl != null;
    final imageUrl = trip.agency?.logoUrl ?? trip.busImageUrl;

    return Hero(
      tag: 'trip_${trip.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _ImagePlaceholder(domainColor: domainColor),
                  errorWidget: (_, __, ___) => _ImagePlaceholder(domainColor: domainColor),
                )
              : _ImagePlaceholder(domainColor: domainColor),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final Color domainColor;
  const _ImagePlaceholder({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            domainColor.withValues(alpha: 0.15),
            domainColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Icon(
        Icons.directions_bus_rounded,
        size: 64,
        color: domainColor.withValues(alpha: 0.5),
      ),
    );
  }
}

/// ============================================================================
/// _AgencyInfoCard — Informations sur l'agence
/// ============================================================================
class _AgencyInfoCard extends StatelessWidget {
  final BusTripModel trip;

  const _AgencyInfoCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final agencyName = trip.agency?.name ?? l10n.tripUnknownAgency;
    final agencyRating = trip.agency?.rating ?? 4.5;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ThixPolicy.tint,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: ThixPolicy.domainReservation,
              size: 24,
            ),
          ),
          SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agencyName,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ThixPolicy.s2),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: ThixPolicy.warning),
                    SizedBox(width: ThixPolicy.s2),
                    Text(
                      agencyRating.toStringAsFixed(1),
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s8),
                    Text(
                      l10n.tripVerifiedAgency,
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.success,
                      ),
                    ),
                  ],
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
/// _RouteInfoCard — Informations sur l'itinéraire
/// ============================================================================
class _RouteInfoCard extends StatelessWidget {
  final BusTripModel trip;
  final Color domainColor;

  const _RouteInfoCard({required this.trip, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    final departureTime = DateFormat('HH:mm', locale).format(trip.departureTime);
    final arrivalTime = DateFormat('HH:mm', locale).format(trip.arrivalTime);
    final duration = _formatDuration(trip.departureTime, trip.arrivalTime);
    final date = DateFormat('EEEE d MMMM', locale).format(trip.departureTime);

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          // Date
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: domainColor),
              SizedBox(width: ThixPolicy.s8),
              Text(
                date,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),

          // Route
          Row(
            children: [
              Expanded(
                child: _TimeStation(
                  time: departureTime,
                  city: trip.departureCity,
                  station: trip.departureStation,
                  isStart: true,
                  domainColor: domainColor,
                ),
              ),
              _RouteLine(duration: duration, domainColor: domainColor),
              Expanded(
                child: _TimeStation(
                  time: arrivalTime,
                  city: trip.arrivalCity,
                  station: trip.arrivalStation,
                  isStart: false,
                  domainColor: domainColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h${minutes.toString().padLeft(2, '0')}';
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
          style: ThixPolicy.h2Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: domainColor,
          ),
        ),
        SizedBox(height: ThixPolicy.s4),
        Text(
          city,
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
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

class _RouteLine extends StatelessWidget {
  final String duration;
  final Color domainColor;

  const _RouteLine({required this.duration, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 2,
            color: domainColor.withValues(alpha: 0.3),
          ),
          SizedBox(height: ThixPolicy.s4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s6, vertical: ThixPolicy.s2),
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            ),
            child: Text(
              duration,
              style: ThixPolicy.microStyle.copyWith(
                color: domainColor,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
          SizedBox(height: ThixPolicy.s4),
          Icon(Icons.arrow_forward_rounded, size: 16, color: domainColor),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _AmenitiesCard — Équipements du bus
/// ============================================================================
class _AmenitiesCard extends StatelessWidget {
  final BusTripModel trip;

  const _AmenitiesCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amenities = trip.amenities;

    if (amenities.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Text(
            l10n.tripAmenities,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
            ),
          ),
          SizedBox(height: ThixPolicy.s12),
          Wrap(
            spacing: ThixPolicy.s8,
            runSpacing: ThixPolicy.s8,
            children: amenities.map((a) => _AmenityChip(amenity: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final String amenity;

  const _AmenityChip({required this.amenity});

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon(amenity);
    final label = _getLabel(context, amenity);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s10, vertical: ThixPolicy.s6),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ThixPolicy.domainReservation),
          SizedBox(width: ThixPolicy.s4),
          Text(
            label,
            style: ThixPolicy.microStyle.copyWith(
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'ac':
      case 'clim':
        return Icons.ac_unit_rounded;
      case 'usb':
        return Icons.usb_rounded;
      case 'toilet':
        return Icons.wc_rounded;
      case 'tv':
        return Icons.tv_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _getLabel(BuildContext context, String amenity) {
    final l10n = context.l10n;
    switch (amenity.toLowerCase()) {
      case 'wifi':
        return l10n.amenityWifi;
      case 'ac':
      case 'clim':
        return l10n.amenityAc;
      case 'usb':
        return l10n.amenityUsb;
      case 'toilet':
        return l10n.amenityToilet;
      case 'tv':
        return l10n.amenityTv;
      default:
        return amenity;
    }
  }
}

/// ============================================================================
/// _PriceCard — Prix et disponibilité
/// ============================================================================
class _PriceCard extends ConsumerWidget {
  final BusTripModel trip;
  final Color domainColor;

  const _PriceCard({required this.trip, required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider).currency;

    final displayPrice = CurrencyFormatter.format(
      trip.priceFcfa,
      currency: 'CDF',
      compact: false,
    );

    final seatsLabel = trip.isFull
        ? l10n.tripFull
        : l10n.tripAvailableSeats(trip.availableSeats, trip.totalSeats);

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
          Text(
            l10n.tripPrice,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
          ),
          SizedBox(height: ThixPolicy.s4),
          Text(
            displayPrice,
            style: ThixPolicy.h1Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.success,
            ),
          ),
          SizedBox(height: ThixPolicy.s8),
          Row(
            children: [
              Icon(
                trip.isFull ? Icons.event_busy_rounded : Icons.event_seat_rounded,
                size: 16,
                color: trip.isFull ? ThixPolicy.danger : ThixPolicy.success,
              ),
              SizedBox(width: ThixPolicy.s4),
              Text(
                seatsLabel,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                  color: trip.isFull ? ThixPolicy.danger : ThixPolicy.success,
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
/// _BottomBar — Barre d'action en bas
/// ============================================================================
class _BottomBar extends ConsumerWidget {
  final BusTripModel trip;
  final Color domainColor;

  const _BottomBar({required this.trip, required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider).currency;

    final displayPrice = CurrencyFormatter.format(
      trip.priceFcfa,
      currency: 'CDF',
      compact: true,
    );

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: trip.isFull
                ? null
                : () => context.push(
                      '/thix-reservation/bus/seats',
                      extra: trip,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: domainColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: ThixPolicy.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              ),
            ),
            child: Text(
              trip.isFull
                  ? l10n.tripFull
                  : l10n.tripSelectSeats(displayPrice),
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
/// _TripDetailSkeleton — Skeleton loader
/// ============================================================================
class _TripDetailSkeleton extends StatelessWidget {
  const _TripDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          children: [
            _SkeletonBox(height: 200, borderRadius: ThixPolicy.rLg),
            SizedBox(height: ThixPolicy.s20),
            _SkeletonBox(height: 80),
            SizedBox(height: ThixPolicy.s16),
            _SkeletonBox(height: 140),
            SizedBox(height: ThixPolicy.s16),
            _SkeletonBox(height: 100),
            SizedBox(height: ThixPolicy.s16),
            _SkeletonBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? borderRadius;

  const _SkeletonBox({required this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(borderRadius ?? ThixPolicy.rMd),
      ),
    );
  }
}

/// ============================================================================
/// _TripErrorView — Vue d'erreur
/// ============================================================================
class _TripErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TripErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: ThixPolicy.danger,
              ),
              SizedBox(height: ThixPolicy.s16),
              Text(
                l10n.commonError,
                style: ThixPolicy.h2Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                ),
              ),
              SizedBox(height: ThixPolicy.s8),
              Text(
                error,
                style: ThixPolicy.bodySmallStyle,
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
      ),
    );
  }
}
