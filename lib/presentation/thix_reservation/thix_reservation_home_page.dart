import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/nav.dart';

import 'providers/reservation_home_provider.dart';

/// ============================================================================
/// CATÉGORIES (toutes visibles dès l'ouverture, aucune dépendance à un mapping
/// texte → icône : l'icône est directement un IconData)
/// ============================================================================
class _Category {
  final String id;
  final String labelKey;
  final String fallback;
  final IconData icon;

  /// null = pas encore disponible (affiche "Bientôt disponible")
  final String? route;

  const _Category({
    required this.id,
    required this.labelKey,
    required this.fallback,
    required this.icon,
    this.route,
  });
}

final List<_Category> _kCategories = [
  const _Category(
    id: 'bus',
    labelKey: 'reservationCatBus',
    fallback: 'Bus',
    icon: Icons.directions_bus_filled_rounded,
    route: '/thix-reservation/bus',
  ),
  const _Category(
    id: 'flight',
    labelKey: 'reservationCatFlight',
    fallback: 'Vol',
    icon: Icons.flight_takeoff_rounded,
    route: '/thix-reservation/flights',
  ),
  const _Category(
    id: 'hotel',
    labelKey: 'reservationCatHotel',
    fallback: 'Hôtel',
    icon: Icons.king_bed_rounded,
    route: '/thix-reservation/hotels',
  ),
  const _Category(
    id: 'taxi',
    labelKey: 'reservationCatTaxi',
    fallback: 'Taxi',
    icon: Icons.local_taxi_rounded,
    route: '/thix-reservation/taxi',
  ),
  _Category(
    id: 'delivery',
    labelKey: 'reservationCatDelivery',
    fallback: 'Livraison',
    icon: Icons.delivery_dining_rounded,
    route: AppRoutes.deliveryHome,
  ),
  const _Category(
    id: 'restaurant',
    labelKey: 'reservationMoreRestaurant',
    fallback: 'Restaurant',
    icon: Icons.restaurant_rounded,
    route: null,
  ),
  _Category(
    id: 'ads',
    labelKey: 'reservationMoreAds',
    fallback: 'Annonces',
    icon: Icons.storefront_rounded,
    route: AppRoutes.thixMarket,
  ),
  const _Category(
    id: 'events',
    labelKey: 'reservationMoreEvents',
    fallback: 'Événement',
    icon: Icons.event_rounded,
    route: '/thix-event',
  ),
];

/// Libellé traduit, avec repli si la clé l10n n'existe pas
String _label(BuildContext context, _Category c) {
  final v = context.l10n.t(c.labelKey);
  if (v.isEmpty || v == c.labelKey) return c.fallback;
  return v;
}

/// Ouvre la route d'une catégorie (ou informe qu'elle arrive bientôt)
void _openCategory(BuildContext context, _Category c) {
  HapticFeedback.selectionClick();
  final route = c.route;
  if (route == null || route.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${_label(context, c)} · Bientôt disponible'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    return;
  }
  context.push(route);
}

/// ============================================================================
/// ThixReservationHomePage
/// ============================================================================
class ThixReservationHomePage extends ConsumerStatefulWidget {
  const ThixReservationHomePage({super.key});

  @override
  ConsumerState<ThixReservationHomePage> createState() =>
      _ThixReservationHomePageState();
}

class _ThixReservationHomePageState
    extends ConsumerState<ThixReservationHomePage> {
  final PageController _heroController = PageController();
  Timer? _heroTimer;

  static const Duration _heroAutoScrollDelay = Duration(seconds: 5);
  static const Duration _heroAnimationDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservationHomeProvider.notifier).init();
      _startHeroAutoScroll();
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  void _startHeroAutoScroll() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(_heroAutoScrollDelay, (_) {
      if (!mounted || !_heroController.hasClients) return;
      final state = ref.read(reservationHomeProvider);
      final nextIndex = (state.heroIndex + 1) % _kHeroSlides.length;
      _heroController.animateToPage(
        nextIndex,
        duration: _heroAnimationDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(reservationHomeProvider.notifier).loadCounts();
  }

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();
    ref.read(reservationHomeProvider.notifier).setSelectedNav(index);

    switch (index) {
      case 0:
        break;
      case 1:
        context.push('/thix-reservation/explore');
        break;
      case 3:
        context.push('/thix-reservation/bookings');
        break;
      case 4:
        context.push('/thix-reservation/profile');
        break;
    }
  }

  void _onCentralAction() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _QuickActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationHomeProvider);
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _HomeAppBar(
        notificationsCount: state.notificationsCount,
        domainColor: domainColor,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _TravelAmbientBackground()),
          RefreshIndicator(
            color: domainColor,
            backgroundColor: Colors.white,
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                ThixPolicy.s14,
                MediaQuery.paddingOf(context).top + 66,
                ThixPolicy.s14,
                110.0,
              ),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCarousel(
                    controller: _heroController,
                    currentIndex: state.heroIndex,
                    onPageChanged: (i) => ref
                        .read(reservationHomeProvider.notifier)
                        .setHeroIndex(i),
                    domainColor: domainColor,
                  ),
                  SizedBox(height: ThixPolicy.s16),

                  _CategoriesGrid(domainColor: domainColor),
                  SizedBox(height: ThixPolicy.s20),

                  _BookingsSection(
                    state: state,
                    domainColor: domainColor,
                  ),
                  SizedBox(height: ThixPolicy.s20),

                  _SpecialOffersSection(domainColor: domainColor),
                  SizedBox(height: ThixPolicy.s20),

                  _ReferralCard(domainColor: domainColor),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassBottomBar(
        selectedIndex: state.selectedNav,
        onTap: _onNavTap,
        onCentralTap: _onCentralAction,
        domainColor: domainColor,
      ),
    );
  }
}

/// ============================================================================
/// _HomeAppBar
/// ============================================================================
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int notificationsCount;
  final Color domainColor;

  const _HomeAppBar({
    required this.notificationsCount,
    required this.domainColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 52,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          _BrandLogo(domainColor: domainColor),
          SizedBox(width: ThixPolicy.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'THIX ',
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 13,
                      color: ThixPolicy.textMain,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    l10n.t('reservationBrandSuffix'),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 13,
                      color: domainColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Text(
                l10n.t('reservationBrandTagline'),
                style: ThixPolicy.microStyle.copyWith(
                  fontSize: 9,
                  color: ThixPolicy.textSecondary,
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Semantics(
          button: true,
          label: '${l10n.t('reservationNotifications')} ($notificationsCount)',
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/thix-reservation/notifications');
            },
            icon: Badge(
              isLabelVisible: notificationsCount > 0,
              label: Text(
                notificationsCount > 9 ? '9+' : '$notificationsCount',
                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
              ),
              backgroundColor: ThixPolicy.danger,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: ThixPolicy.textMain,
                size: 19,
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('reservationProfile'),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/thix-reservation/profile');
            },
            icon: const Icon(
              Icons.account_circle_outlined,
              color: ThixPolicy.textMain,
              size: 19,
            ),
          ),
        ),
        SizedBox(width: ThixPolicy.s2),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final Color domainColor;
  const _BrandLogo({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: domainColor,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: domainColor.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'R',
          style: TextStyle(
            color: Colors.white,
            fontWeight: ThixPolicy.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _HeroCarousel
/// ============================================================================
class _HeroCarousel extends StatelessWidget {
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final Color domainColor;

  const _HeroCarousel({
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: _kHeroSlides.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, index) {
              final slide = _kHeroSlides[index];
              return _HeroSlideCard(
                slide: slide,
                domainColor: domainColor,
              );
            },
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: _HeroIndicators(
              count: _kHeroSlides.length,
              current: currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  final _HeroSlide slide;
  final Color domainColor;

  const _HeroSlideCard({required this.slide, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${slide.titleKey}, ${slide.subtitleKey}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(slide.route);
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: ThixPolicy.s2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: slide.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: slide.gradient.first.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -8,
                child: Opacity(
                  opacity: 0.12,
                  child: Icon(
                    slide.backgroundIcon,
                    size: 110,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(ThixPolicy.s14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ThixPolicy.s8,
                              vertical: ThixPolicy.s4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rSm),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 11,
                                  color: ThixPolicy.gold,
                                ),
                                SizedBox(width: ThixPolicy.s4),
                                Text(
                                  slide.badgeKey,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: ThixPolicy.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            slide.titleKey,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: ThixPolicy.bold,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            slide.subtitleKey,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: ThixPolicy.semiBold,
                            ),
                          ),
                          SizedBox(height: ThixPolicy.s4),
                          Text(
                            slide.validityKey,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 8.5,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 27,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context.push(slide.route);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: domainColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(ThixPolicy.rSm - 3),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ThixPolicy.s14,
                                ),
                              ),
                              child: Text(
                                slide.ctaKey,
                                style: TextStyle(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s6),
                    Icon(
                      slide.foregroundIcon,
                      size: 64,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIndicators extends StatelessWidget {
  final int count;
  final int current;

  const _HeroIndicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: ThixPolicy.s4),
          width: i == current ? 18 : 5,
          height: 4.5,
          decoration: BoxDecoration(
            color: i == current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _CategoriesGrid — TOUTES les catégories visibles dès l'ouverture
/// (2 lignes de 4, largeur égale, aucun bouton "Plus", rien de caché)
/// ============================================================================
class _CategoriesGrid extends StatelessWidget {
  final Color domainColor;
  const _CategoriesGrid({required this.domainColor});

  static const int _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_Category>>[];
    for (var i = 0; i < _kCategories.length; i += _perRow) {
      rows.add(_kCategories.sublist(
        i,
        math.min(i + _perRow, _kCategories.length),
      ));
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ThixPolicy.s12,
        horizontal: ThixPolicy.s6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: ThixPolicy.s12),
            Row(
              children: [
                for (var c = 0; c < _perRow; c++)
                  Expanded(
                    child: c < rows[r].length
                        ? _CategoryItem(
                            category: rows[r][c],
                            domainColor: domainColor,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final _Category category;
  final Color domainColor;

  const _CategoryItem({
    required this.category,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = _label(context, category);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openCategory(context, category),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(category.icon, color: domainColor, size: 21),
            ),
            SizedBox(height: ThixPolicy.s6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 10,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _BookingsSection
/// ============================================================================
class _BookingsSection extends StatelessWidget {
  final ReservationHomeState state;
  final Color domainColor;

  const _BookingsSection({required this.state, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('reservationMyBookings'),
          onSeeAll: () {
            HapticFeedback.lightImpact();
            context.push('/thix-reservation/bookings');
          },
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s10),
        Row(
          children: [
            _BookingStatTile(
              label: l10n.t('reservationUpcoming'),
              count: state.getCount('upcoming'),
              color: domainColor,
              icon: Icons.luggage_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.t('reservationOngoing'),
              count: state.getCount('ongoing'),
              color: ThixPolicy.warning,
              icon: Icons.access_time_filled_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.t('reservationCompleted'),
              count: state.getCount('completed'),
              color: ThixPolicy.success,
              icon: Icons.check_circle_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.t('reservationCancelled'),
              count: state.getCount('cancelled'),
              color: ThixPolicy.textSecondary,
              icon: Icons.cancel_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _BookingStatTile extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  final IconData icon;

  const _BookingStatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ThixPolicy.s10,
          horizontal: ThixPolicy.s6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            SizedBox(height: ThixPolicy.s6),
            Text(
              count,
              style: ThixPolicy.titleStyle.copyWith(
                fontSize: 15,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                fontSize: 9,
                color: ThixPolicy.textSecondary.withValues(alpha: 0.8),
                fontWeight: ThixPolicy.bold,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _SpecialOffersSection
/// ============================================================================
class _SpecialOffersSection extends StatelessWidget {
  final Color domainColor;
  const _SpecialOffersSection({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('reservationSpecialOffers'),
          onSeeAll: () {
            HapticFeedback.lightImpact();
            context.push('/thix-reservation/offers');
          },
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s10),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              _OfferCard(
                title: l10n.t('reservationOfferHotels'),
                discount: '-30%',
                subtitle: l10n.t('reservationOfferHotelsSub'),
                colors: _kOfferColors[0],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.t('reservationOfferFlights'),
                discount: '-20%',
                subtitle: l10n.t('reservationOfferFlightsSub'),
                colors: _kOfferColors[1],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.t('reservationOfferBus'),
                discount: '-15%',
                subtitle: l10n.t('reservationOfferBusSub'),
                colors: _kOfferColors[2],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.t('reservationOfferDelivery'),
                discount: '-10%',
                subtitle: l10n.t('reservationOfferDeliverySub'),
                colors: _kOfferColors[3],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String title;
  final String discount;
  final String subtitle;
  final List<Color> colors;

  const _OfferCard({
    required this.title,
    required this.discount,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title $discount, $subtitle',
      child: GestureDetector(
        onTap: () => HapticFeedback.lightImpact(),
        child: Container(
          width: 128,
          padding: EdgeInsets.all(ThixPolicy.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rMd + 2),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: ThixPolicy.bold,
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: ThixPolicy.s4),
              Text(
                discount,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 20,
                  letterSpacing: -0.8,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: ThixPolicy.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _ReferralCard
/// ============================================================================
class _ReferralCard extends StatelessWidget {
  final Color domainColor;
  const _ReferralCard({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.t('reservationReferralTitle'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/thix-reservation/referral');
        },
        child: Container(
          padding: EdgeInsets.all(ThixPolicy.s14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd + 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s8),
                decoration: BoxDecoration(
                  color: domainColor,
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  boxShadow: [
                    BoxShadow(
                      color: domainColor.withValues(alpha: 0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('reservationReferralTitle'),
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        color: domainColor,
                        fontSize: 12,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: ThixPolicy.s2),
                    Text.rich(
                      TextSpan(
                        style: ThixPolicy.microStyle.copyWith(
                          fontSize: 10,
                          color: ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.medium,
                        ),
                        children: [
                          TextSpan(text: l10n.t('reservationReferralPrefix')),
                          TextSpan(
                            text: '10.000 FC',
                            style: TextStyle(
                              color: domainColor,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                          TextSpan(text: l10n.t('reservationReferralSuffix')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: domainColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _SectionHeader
/// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final Color domainColor;

  const _SectionHeader({
    required this.title,
    this.onSeeAll,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Text(
          title,
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 14,
            color: ThixPolicy.textMain,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ThixPolicy.s6,
                vertical: ThixPolicy.s4,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.t('common_see_all'),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontSize: 11,
                      color: domainColor,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: domainColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ============================================================================
/// _GlassBottomBar
/// ============================================================================
class _GlassBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCentralTap;
  final Color domainColor;

  const _GlassBottomBar({
    required this.selectedIndex,
    required this.onTap,
    required this.onCentralTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ThixPolicy.s14,
            0,
            ThixPolicy.s14,
            ThixPolicy.s10,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          icon: Icons.home_rounded,
                          label: l10n.t('reservationNavHome'),
                          index: 0,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        _NavItem(
                          icon: Icons.explore_outlined,
                          label: l10n.t('reservationNavExplore'),
                          index: 1,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        const SizedBox(width: 60),
                        _NavItem(
                          icon: Icons.receipt_long_rounded,
                          label: l10n.t('reservationNavBookings'),
                          index: 3,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        _NavItem(
                          icon: Icons.person_outline_rounded,
                          label: l10n.t('reservationNavProfile'),
                          index: 4,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                      ],
                    ),
                    Positioned(
                      top: -18,
                      child: Semantics(
                        button: true,
                        label: l10n.t('reservationNavQuickBook'),
                        child: GestureDetector(
                          onTap: onCentralTap,
                          child: Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: ThixPolicy.brandGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: domainColor.withValues(alpha: 0.35),
                                  blurRadius: 9,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color domainColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex == index;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          width: 52,
          padding: EdgeInsets.symmetric(vertical: ThixPolicy.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? domainColor
                    : ThixPolicy.textSecondary.withValues(alpha: 0.8),
                size: 20,
              ),
              SizedBox(height: ThixPolicy.s4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8,
                  color: selected
                      ? domainColor
                      : ThixPolicy.textSecondary.withValues(alpha: 0.8),
                  fontWeight:
                      selected ? ThixPolicy.bold : ThixPolicy.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _TravelAmbientBackground
/// ============================================================================
class _TravelAmbientBackground extends StatefulWidget {
  const _TravelAmbientBackground();

  @override
  State<_TravelAmbientBackground> createState() =>
      _TravelAmbientBackgroundState();
}

class _TravelAmbientBackgroundState extends State<_TravelAmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPerformanceOrb(
    double left,
    double top,
    double width,
    double height,
    Color color,
    double angle,
  ) {
    return Positioned(
      left: left - (width / 2),
      top: top - (height / 2),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.all(Radius.elliptical(width, height)),
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.1, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final domainColor = ThixPolicy.domainReservation;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          listenable: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            final globeX = size.width * 0.7 + math.cos(t * 0.7) * 130.0;
            final globeY = size.height * 0.48 + math.sin(t * 0.9) * 160.0;

            final ticketX =
                size.width * 0.15 + math.sin(t * 0.6 + 1.2) * 90.0;
            final ticketY =
                size.height * 0.82 + math.cos(t * 0.5) * 110.0;

            final busX = size.width * 0.3 +
                math.sin(t * 1.1) * (size.width * 0.45);
            final busY = size.height * 0.62 +
                math.cos(t) * (size.height * 0.14);

            final planeX = size.width * 0.5 +
                math.cos(t * 1.4) * (size.width * 0.38);
            final planeY = size.height * 0.28 +
                math.sin(t * 1.8) * (size.height * 0.19);

            final planeSmallX =
                size.width * 0.85 + math.sin(t * 1.6 + 2.0) * 80.0;
            final planeSmallY =
                size.height * 0.16 + math.cos(t * 1.3) * 60.0;

            return Stack(
              children: [
                _buildPerformanceOrb(
                  globeX,
                  globeY,
                  600,
                  600,
                  domainColor.withValues(alpha: 0.18),
                  t * 0.35,
                ),
                _buildPerformanceOrb(
                  ticketX,
                  ticketY,
                  450,
                  550,
                  ThixPolicy.gold.withValues(alpha: 0.15),
                  -t * 0.25,
                ),
                _buildPerformanceOrb(
                  busX,
                  busY,
                  600,
                  450,
                  ThixPolicy.gold.withValues(alpha: 0.20),
                  -t * 0.3,
                ),
                _buildPerformanceOrb(
                  planeX,
                  planeY,
                  550,
                  350,
                  domainColor.withValues(alpha: 0.25),
                  t * 0.5,
                ),
                _buildPerformanceOrb(
                  planeSmallX,
                  planeSmallY,
                  350,
                  200,
                  domainColor.withValues(alpha: 0.18),
                  -t * 0.6 + 1.0,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.25),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ============================================================================
/// _QuickActionSheet (bouton central) — mêmes catégories, défilement si besoin
/// ============================================================================
class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          padding: EdgeInsets.fromLTRB(
            ThixPolicy.s24,
            ThixPolicy.s12,
            ThixPolicy.s24,
            ThixPolicy.s32,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: ThixPolicy.s20),
              Text(
                l10n.t('reservationQuickBookTitle'),
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ThixPolicy.s6),
              Text(
                l10n.t('reservationQuickBookSubtitle'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
              SizedBox(height: ThixPolicy.s20),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      for (final cat in _kCategories)
                        _QuickActionTile(
                          category: cat,
                          domainColor: domainColor,
                          onTap: () {
                            Navigator.pop(context);
                            _openCategory(context, cat);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _Category category;
  final Color domainColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.category,
    required this.domainColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = _label(context, category);

    return Padding(
      padding: EdgeInsets.only(bottom: ThixPolicy.s8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(
                color: domainColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  ),
                  child: Icon(category.icon, color: domainColor, size: 18),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Text(
                    label,
                    style: ThixPolicy.bodyStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: domainColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// Données statiques
/// ============================================================================
class _HeroSlide {
  final String badgeKey;
  final String titleKey;
  final String subtitleKey;
  final String validityKey;
  final String ctaKey;
  final String route;
  final List<Color> gradient;
  final IconData backgroundIcon;
  final IconData foregroundIcon;

  const _HeroSlide({
    required this.badgeKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.validityKey,
    required this.ctaKey,
    required this.route,
    required this.gradient,
    required this.backgroundIcon,
    required this.foregroundIcon,
  });
}

const _kHeroSlides = [
  _HeroSlide(
    badgeKey: 'PROMO FLASH',
    titleKey: "Jusqu'à -20%",
    subtitleKey: 'bus & vols nationaux',
    validityKey: 'Valable jusqu\'au 30 Juin 2027',
    ctaKey: 'Réserver',
    route: '/thix-reservation/bus',
    gradient: [Color(0xFF0A2F6B), Color(0xFF0B4FE3)],
    backgroundIcon: Icons.directions_bus_filled_rounded,
    foregroundIcon: Icons.airport_shuttle_rounded,
  ),
  _HeroSlide(
    badgeKey: 'CONFIANCE',
    titleKey: 'Paiement Sécurisé',
    subtitleKey: 'Mobile Money & Carte',
    validityKey: 'Transactions 100% garanties',
    ctaKey: 'Découvrir',
    route: '/thix-reservation/bus',
    gradient: [Color(0xFF0A1F3F), Color(0xFF0A2F6B)],
    backgroundIcon: Icons.verified_user_rounded,
    foregroundIcon: Icons.shield_rounded,
  ),
];

const _kOfferColors = [
  [Color(0xFF0A3D91), Color(0xFF2A7FFF)],
  [Color(0xFF123B7A), Color(0xFF3A8DFF)],
  [Color(0xFF0E4DA4), Color(0xFF4A90E2)],
  [Color(0xFF0A2F6B), Color(0xFF2D6CDF)],
];

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
