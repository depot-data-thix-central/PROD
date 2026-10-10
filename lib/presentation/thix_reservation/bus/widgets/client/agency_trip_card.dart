import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../data/models/bus_trip_model.dart';

/// ============================================================================
/// AgencyTripCard
/// ============================================================================
///
/// Carte de trajet de bus affichée dans les résultats de recherche.
///
/// Features :
/// - Multi-devises global (conversion automatique via currencyProvider)
/// - CachedNetworkImage avec placeholder et error widget élégants
/// - Hero animation optionnel vers la page détail
/// - Badge "Presque complet" si < 5 places restantes
/// - Badge "Complet" avec overlay désactivé
/// - Badge "Vérifié" pour les agences certifiées
/// - Animation scale au tap avec feedback haptique
/// - Accessibilité complète (Semantics)
/// - i18n intégrée (FR/EN/LN)
/// - Design system ThixPolicy
/// - Responsive avec contraintes adaptatives
/// - Gestion d'erreurs robuste
///
/// ============================================================================
class AgencyTripCard extends ConsumerStatefulWidget {
  final BusTripModel trip;
  final VoidCallback onTap;
  final Object? heroTag;
  final bool compact;

  const AgencyTripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.heroTag,
    this.compact = false,
  });

  @override
  ConsumerState<AgencyTripCard> createState() => _AgencyTripCardState();
}

class _AgencyTripCardState extends ConsumerState<AgencyTripCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.forward();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.reverse();
  void _onTapCancel() => _scaleCtrl.reverse();

  void _handleTap() {
    if (widget.trip.isFull) return;
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);
    final domainColor = ThixPolicy.domainReservation;

    // Conversion du prix vers la devise globale
    final displayPrice = currencyState.convert(
      widget.trip.priceFcfa,
      fromCurrency: 'CDF',
    );
    final formattedPrice = CurrencyFormatter.format(
      displayPrice,
      currency: currencyState.currency.code,
      compact: false,
    );

    final agencyName = widget.trip.agency?.name ?? l10n.t('common_unknown');
    final initial = agencyName.isNotEmpty ? agencyName[0].toUpperCase() : 'A';
    final logo = widget.trip.agency?.logoUrl;

    final locale = Localizations.localeOf(context).toString();
    final departureTime = DateFormat('HH:mm', locale).format(widget.trip.departureTime);
    final arrivalTime = DateFormat('HH:mm', locale).format(widget.trip.arrivalTime);

    final semanticLabel = _buildSemanticLabel(
      l10n,
      agencyName,
      formattedPrice,
      departureTime,
      arrivalTime,
    );

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Overlay "Complet"
          if (widget.trip.isFull)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.03),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(ThixPolicy.s14),
            child: Opacity(
              opacity: widget.trip.isFull ? 0.5 : 1.0,
              child: Column(
                children: [
                  // Header : Agence + Prix
                  _CardHeader(
                    agencyName: agencyName,
                    initial: initial,
                    logo: logo,
                    busType: widget.trip.busType,
                    duration: widget.trip.durationLabel,
                    isVerified: widget.trip.agency?.isVerified ?? false,
                    price: formattedPrice,
                    availableSeats: widget.trip.availableSeats,
                    isAlmostFull: widget.trip.isAlmostFull,
                    isFull: widget.trip.isFull,
                    domainColor: domainColor,
                  ),

                  SizedBox(height: ThixPolicy.s16),
                  Divider(height: 1, color: ThixPolicy.border),
                  SizedBox(height: ThixPolicy.s16),

                  // Route : Départ → Arrivée
                  _RouteSection(
                    departureTime: departureTime,
                    departureCity: widget.trip.departureCity,
                    arrivalTime: arrivalTime,
                    arrivalCity: widget.trip.arrivalCity,
                    domainColor: domainColor,
                  ),

                  // Amenities (si pas compact)
                  if (!widget.compact && widget.trip.amenities.isNotEmpty) ...[
                    SizedBox(height: ThixPolicy.s12),
                    _AmenitiesRow(
                      amenities: widget.trip.amenities.take(4).toList(),
                      domainColor: domainColor,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Badge "Complet" en overlay
          if (widget.trip.isFull)
            Positioned(
              top: ThixPolicy.s12,
              right: ThixPolicy.s12,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s10,
                  vertical: ThixPolicy.s4,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Text(
                  l10n.t('events_sold_out'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Hero animation si tag fourni
    if (widget.heroTag != null) {
      cardContent = Hero(
        tag: widget.heroTag!,
        child: Material(color: Colors.transparent, child: cardContent),
      );
    }

    return Semantics(
      button: !widget.trip.isFull,
      enabled: !widget.trip.isFull,
      label: semanticLabel,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _handleTap,
        child: AnimatedBuilder(
          listenable: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: widget.trip.isFull ? 1.0 : _scaleAnim.value,
            child: child,
          ),
          child: cardContent,
        ),
      ),
    );
  }

  String _buildSemanticLabel(
    dynamic l10n,
    String agencyName,
    String price,
    String depTime,
    String arrTime,
  ) {
    return '$agencyName: ${widget.trip.departureCity} → ${widget.trip.arrivalCity} • $depTime - $arrTime • ${l10n.t('events_ticket_price')}: $price';
  }
}

/// ============================================================================
/// _CardHeader — En-tête avec logo agence + prix
/// ============================================================================
class _CardHeader extends StatelessWidget {
  final String agencyName;
  final String initial;
  final String? logo;
  final String busType;
  final String duration;
  final bool isVerified;
  final String price;
  final int availableSeats;
  final bool isAlmostFull;
  final bool isFull;
  final Color domainColor;

  const _CardHeader({
    required this.agencyName,
    required this.initial,
    required this.logo,
    required this.busType,
    required this.duration,
    required this.isVerified,
    required this.price,
    required this.availableSeats,
    required this.isAlmostFull,
    required this.isFull,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        // Logo agence
        _AgencyLogo(
          logo: logo,
          initial: initial,
          domainColor: domainColor,
        ),
        SizedBox(width: ThixPolicy.s12),

        // Infos agence
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      agencyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.bodyStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    SizedBox(width: ThixPolicy.s4),
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: domainColor,
                    ),
                  ],
                ],
              ),
              SizedBox(height: ThixPolicy.s2),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s6,
                      vertical: ThixPolicy.s2,
                    ),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                    ),
                    child: Text(
                      busType.toUpperCase(),
                      style: ThixPolicy.microStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  SizedBox(width: ThixPolicy.s6),
                  Icon(
                    Icons.schedule_rounded,
                    size: 11,
                    color: ThixPolicy.textSecondary,
                  ),
                  SizedBox(width: ThixPolicy.s2),
                  Text(
                    duration,
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                      fontWeight: ThixPolicy.medium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Prix + Places
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: domainColor,
                fontSize: 15,
              ),
            ),
            SizedBox(height: ThixPolicy.s4),
            if (isFull)
              Text(
                l10n.t('events_sold_out'),
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.danger,
                  fontWeight: ThixPolicy.bold,
                ),
              )
            else if (isAlmostFull)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s6,
                  vertical: ThixPolicy.s2,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 10,
                      color: ThixPolicy.danger,
                    ),
                    SizedBox(width: ThixPolicy.s2),
                    Text(
                      l10n.t('event_remaining_seats', args: [availableSeats.toString()]),
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.danger,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_seat_rounded,
                    size: 11,
                    color: ThixPolicy.textSecondary,
                  ),
                  SizedBox(width: ThixPolicy.s2),
                  Text(
                    l10n.t('event_remaining_seats', args: [availableSeats.toString()]),
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                      fontWeight: ThixPolicy.medium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// ============================================================================
/// _AgencyLogo — Logo avec fallback élégant
/// ============================================================================
class _AgencyLogo extends StatelessWidget {
  final String? logo;
  final String initial;
  final Color domainColor;

  const _AgencyLogo({
    required this.logo,
    required this.initial,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ThixPolicy.tint,
        border: Border.all(color: ThixPolicy.border, width: 1.5),
      ),
      child: ClipOval(
        child: logo != null && logo!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logo!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _LogoPlaceholder(
                  initial: initial,
                  domainColor: domainColor,
                ),
                errorWidget: (_, __, ___) => _LogoPlaceholder(
                  initial: initial,
                  domainColor: domainColor,
                ),
                fadeInDuration: const Duration(milliseconds: 200),
              )
            : _LogoPlaceholder(initial: initial, domainColor: domainColor),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  final String initial;
  final Color domainColor;

  const _LogoPlaceholder({
    required this.initial,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: domainColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            color: domainColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _RouteSection — Section Départ → Arrivée avec timeline
/// ============================================================================
class _RouteSection extends StatelessWidget {
  final String departureTime;
  final String departureCity;
  final String arrivalTime;
  final String arrivalCity;
  final Color domainColor;

  const _RouteSection({
    required this.departureTime,
    required this.departureCity,
    required this.arrivalTime,
    required this.arrivalCity,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Départ
        Expanded(
          child: _TimeCity(
            time: departureTime,
            city: departureCity,
            alignEnd: false,
            domainColor: domainColor,
          ),
        ),

        // Timeline centrale
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s8),
            child: _RouteTimeline(domainColor: domainColor),
          ),
        ),

        // Arrivée
        Expanded(
          child: _TimeCity(
            time: arrivalTime,
            city: arrivalCity,
            alignEnd: true,
            domainColor: domainColor,
          ),
        ),
      ],
    );
  }
}

class _TimeCity extends StatelessWidget {
  final String time;
  final String city;
  final bool alignEnd;
  final Color domainColor;

  const _TimeCity({
    required this.time,
    required this.city,
    required this.alignEnd,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
          style: ThixPolicy.microStyle.copyWith(
            color: ThixPolicy.textSecondary,
            fontWeight: ThixPolicy.medium,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  final Color domainColor;

  const _RouteTimeline({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                domainColor.withValues(alpha: 0.3),
                domainColor,
                domainColor.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(ThixPolicy.s4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: domainColor, width: 1.5),
          ),
          child: Icon(
            Icons.directions_bus_rounded,
            size: 12,
            color: domainColor,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _AmenitiesRow — Équipements du bus (Wi-Fi, Clim, etc.)
/// ============================================================================
class _AmenitiesRow extends StatelessWidget {
  final List<String> amenities;
  final Color domainColor;

  const _AmenitiesRow({
    required this.amenities,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: amenities.map((a) => _AmenityIcon(amenity: a, domainColor: domainColor)).toList(),
    );
  }
}

class _AmenityIcon extends StatelessWidget {
  final String amenity;
  final Color domainColor;

  const _AmenityIcon({
    required this.amenity,
    required this.domainColor,
  });

  IconData _getIcon() {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ThixPolicy.s4),
      padding: EdgeInsets.all(ThixPolicy.s6),
      decoration: BoxDecoration(
        color: domainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      ),
      child: Icon(
        _getIcon(),
        size: 14,
        color: domainColor,
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
