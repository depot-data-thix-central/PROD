import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import 'providers/reservation_home_provider.dart';

/// ============================================================================
/// ThixReservationHomePage
/// ============================================================================
///
/// Page d'accueil unifiée de THIX Reservation.
///
/// Features :
/// - Riverpod (ConsumerStatefulWidget)
/// - Background animé GPU-optimized (RadialGradient)
/// - Hero carousel auto-scroll (5s)
/// - Counts en temps réel (Supabase Realtime)
/// - Glassmorphism cohérent
/// - Bottom nav avec action centrale
/// - i18n FR/EN/LN complète
/// - Accessibilité (Semantics)
/// - Haptic feedback
/// - Pull-to-refresh
/// - Design system ThixPolicy
///
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
    final l10n = context.l10n;
    HapticFeedback.lightImpact();
    ref.read(reservationHomeProvider.notifier).setSelectedNav(index);

    switch (index) {
      case 0:
        // Accueil : déjà sur la page
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
    // Ouvre le sélecteur de service rapide
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _QuickActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                ThixPolicy.s110,
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
/// _HomeAppBar — AppBar glassmorphique
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
            color: Colors.white.withValues(alpha: 0.65),
            decoration: BoxDecoration(
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
                    l10n.reservationBrandSuffix,
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
                l10n.reservationBrandTagline,
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
          label: '${l10n.reservationNotifications} ($notificationsCount)',
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
          label: l10n.reservationProfile,
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
/// _HeroCarousel — Carrousel hero auto-scroll
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
    final l10n = context.l10n;

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
              // Background icon
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
                              vertical: ThixPolicy.s3,
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
                                SizedBox(width: ThixPolicy.s3),
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
                                  horizontal: ThixPolicy.s13,
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
          margin: EdgeInsets.symmetric(horizontal: ThixPolicy.s3),
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
/// _CategoriesGrid — Grille des catégories
/// ============================================================================
class _CategoriesGrid extends StatelessWidget {
  final Color domainColor;
  const _CategoriesGrid({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...kReservationCategories.map(
            (cat) => _CategoryItem(
              category: cat,
              domainColor: domainColor,
            ),
          ),
          _CategoryItem(
            category: const ReservationCategory(
              id: 'more',
              labelKey: 'reservationCatMore',
              route: '',
              icon: 'apps',
              isPrimary: false,
            ),
            isMore: true,
            domainColor: domainColor,
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ReservationCategory category;
  final bool isMore;
  final Color domainColor;

  const _CategoryItem({
    required this.category,
    required this.domainColor,
    this.isMore = false,
  });

  IconData get _icon {
    switch (category.icon) {
      case 'directions_bus_filled':
        return Icons.directions_bus_filled_rounded;
      case 'flight_takeoff':
        return Icons.flight_takeoff_rounded;
      case 'king_bed':
        return Icons.king_bed_rounded;
      case 'local_taxi':
        return Icons.local_taxi_rounded;
      case 'delivery_dining':
        return Icons.delivery_dining_rounded;
      case 'apps':
        return Icons.apps_rounded;
      default:
        return Icons.circle;
    }
  }

  String _translateLabel(dynamic l10n, String key) {
    try {
      switch (key) {
        case 'reservationCatBus':
          return l10n.reservationCatBus;
        case 'reservationCatFlights':
          return l10n.reservationCatFlights;
        case 'reservationCatHotels':
          return l10n.reservationCatHotels;
        case 'reservationCatTaxi':
          return l10n.reservationCatTaxi;
        case 'reservationCatDelivery':
          return l10n.reservationCatDelivery;
        case 'reservationCatMore':
          return l10n.reservationCatMore;
        default:
          return key;
      }
    } catch (_) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _translateLabel(l10n, category.labelKey);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (isMore) {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const _MoreSheet(),
            );
          } else {
            context.push(category.route);
          }
        },
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
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
              child: Icon(
                _icon,
                color: isMore ? ThixPolicy.textSecondary : domainColor,
                size: 19,
              ),
            ),
            SizedBox(height: ThixPolicy.s6),
            Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 9.5,
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
/// _BookingsSection — Section "Mes réservations"
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
          title: l10n.reservationMyBookings,
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
              label: l10n.reservationUpcoming,
              count: state.getCount('upcoming'),
              color: domainColor,
              icon: Icons.luggage_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.reservationOngoing,
              count: state.getCount('ongoing'),
              color: ThixPolicy.warning,
              icon: Icons.access_time_filled_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.reservationCompleted,
              count: state.getCount('completed'),
              color: ThixPolicy.success,
              icon: Icons.check_circle_rounded,
            ),
            SizedBox(width: ThixPolicy.s8),
            _BookingStatTile(
              label: l10n.reservationCancelled,
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
          horizontal: ThixPolicy.s5,
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
/// _SpecialOffersSection — Offres spéciales
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
          title: l10n.reservationSpecialOffers,
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
                title: l10n.reservationOfferHotels,
                discount: '-30%',
                subtitle: l10n.reservationOfferHotelsSub,
                colors: _kOfferColors[0],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.reservationOfferFlights,
                discount: '-20%',
                subtitle: l10n.reservationOfferFlightsSub,
                colors: _kOfferColors[1],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.reservationOfferBus,
                discount: '-15%',
                subtitle: l10n.reservationOfferBusSub,
                colors: _kOfferColors[2],
              ),
              SizedBox(width: ThixPolicy.s10),
              _OfferCard(
                title: l10n.reservationOfferDelivery,
                discount: '-10%',
                subtitle: l10n.reservationOfferDeliverySub,
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
              SizedBox(height: ThixPolicy.s3),
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
/// _ReferralCard — Carte parrainage
/// ============================================================================
class _ReferralCard extends StatelessWidget {
  final Color domainColor;
  const _ReferralCard({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.reservationReferralTitle,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/thix-reservation/referral');
        },
        child: Container(
          padding: EdgeInsets.all(ThixPolicy.s13),
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
                      l10n.reservationReferralTitle,
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
                          TextSpan(text: l10n.reservationReferralPrefix),
                          TextSpan(
                            text: '10.000 FC',
                            style: TextStyle(
                              color: domainColor,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                          TextSpan(text: l10n.reservationReferralSuffix),
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
/// _SectionHeader — Header de section avec "Voir tout"
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
                    l10n.commonSeeAll,
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
/// _GlassBottomBar — Bottom navigation glassmorphique
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
                          label: l10n.reservationNavHome,
                          index: 0,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        _NavItem(
                          icon: Icons.explore_outlined,
                          label: l10n.reservationNavExplore,
                          index: 1,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        const SizedBox(width: 60),
                        _NavItem(
                          icon: Icons.receipt_long_rounded,
                          label: l10n.reservationNavBookings,
                          index: 3,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          domainColor: domainColor,
                        ),
                        _NavItem(
                          icon: Icons.person_outline_rounded,
                          label: l10n.reservationNavProfile,
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
                        label: l10n.reservationNavQuickBook,
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
          padding: EdgeInsets.symmetric(vertical: ThixPolicy.s3),
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
              SizedBox(height: ThixPolicy.s3),
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
/// _TravelAmbientBackground — Background animé GPU-optimized
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
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            final globeX = size.width * 0.7 + math.cos(t * 0.7) * 130.0;
            final globeY = size.height * 0.48 + math.sin(t * 0.9) * 160.0;

            final ticketX = size.width * 0.15 + math.sin(t * 0.6 + 1.2) * 90.0;
            final ticketY = size.height * 0.82 + math.cos(t * 0.5) * 110.0;

            final busX = size.width * 0.3 + math.sin(t * 1.1) * (size.width * 0.45);
            final busY = size.height * 0.62 + math.cos(t) * (size.height * 0.14);

            final planeX = size.width * 0.5 + math.cos(t * 1.4) * (size.width * 0.38);
            final planeY = size.height * 0.28 + math.sin(t * 1.8) * (size.height * 0.19);

            final planeSmallX = size.width * 0.85 + math.sin(t * 1.6 + 2.0) * 80.0;
            final planeSmallY = size.height * 0.16 + math.cos(t * 1.3) * 60.0;

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
/// _MoreSheet — Bottom sheet "Plus"
/// ============================================================================
class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            ThixPolicy.s24,
            ThixPolicy.s12,
            ThixPolicy.s24,
            ThixPolicy.s32,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
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
              SizedBox(height: ThixPolicy.s32),
              Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  _MoreSheetItem(
                    icon: Icons.restaurant_rounded,
                    label: l10n.reservationMoreRestaurant,
                    onTap: () => Navigator.pop(context),
                  ),
                  _MoreSheetItem(
                    icon: Icons.storefront_rounded,
                    label: l10n.reservationMoreAds,
                    onTap: () => Navigator.pop(context),
                  ),
                  _MoreSheetItem(
                    icon: Icons.event_rounded,
                    label: l10n.reservationMoreEvents,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/thix-event');
                    },
                  ),
                  _MoreSheetItem(
                    icon: Icons.delivery_dining_rounded,
                    label: l10n.reservationMoreDelivery,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/delivery');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final domainColor = ThixPolicy.domainReservation;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
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
              child: Icon(icon, color: domainColor, size: 19),
            ),
            SizedBox(height: ThixPolicy.s6),
            Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 9.5,
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
/// _QuickActionSheet — Action rapide centrale
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
                l10n.reservationQuickBookTitle,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ThixPolicy.s6),
              Text(
                l10n.reservationQuickBookSubtitle,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
              SizedBox(height: ThixPolicy.s24),
              ...kReservationCategories.map(
                (cat) => _QuickActionTile(
                  category: cat,
                  domainColor: domainColor,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(cat.route);
                  },
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
  final ReservationCategory category;
  final Color domainColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.category,
    required this.domainColor,
    required this.onTap,
  });

  IconData get _icon {
    switch (category.icon) {
      case 'directions_bus_filled':
        return Icons.directions_bus_filled_rounded;
      case 'flight_takeoff':
        return Icons.flight_takeoff_rounded;
      case 'king_bed':
        return Icons.king_bed_rounded;
      case 'local_taxi':
        return Icons.local_taxi_rounded;
      case 'delivery_dining':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.circle;
    }
  }

  String _translateLabel(dynamic l10n, String key) {
    try {
      switch (key) {
        case 'reservationCatBus':
          return l10n.reservationCatBus;
        case 'reservationCatFlights':
          return l10n.reservationCatFlights;
        case 'reservationCatHotels':
          return l10n.reservationCatHotels;
        case 'reservationCatTaxi':
          return l10n.reservationCatTaxi;
        case 'reservationCatDelivery':
          return l10n.reservationCatDelivery;
        default:
          return key;
      }
    } catch (_) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _translateLabel(l10n, category.labelKey);

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
                  child: Icon(_icon, color: domainColor, size: 18),
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
/// Données statiques (hero slides, offres, couleurs)
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
    titleKey: "Jusqu'à -40%",
    subtitleKey: 'bus & vols nationaux',
    validityKey: 'Valable jusqu\'au 30 Juin 2026',
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
  [Color(0xFF0A3D91), Color(0xFF2A7FFF)], // Hôtels
  [Color(0xFF123B7A), Color(0xFF3A8DFF)], // Vols
  [Color(0xFF0E4DA4), Color(0xFF4A90E2)], // Bus
  [Color(0xFF0A2F6B), Color(0xFF2D6CDF)], // Livraison
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
