import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import '../../providers/bus_search_provider.dart';
import '../../providers/agency_dashboard_provider.dart';
import '../../data/services/bus_public_service.dart';
import '../widgets/trip_search_card.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/popular_route_card.dart';
import '../widgets/agency_banner.dart';
import '../widgets/amenity_row.dart';
import '../widgets/domain_category_bar.dart';
import '../widgets/skeleton/popular_route_skeleton.dart';

class BusHomePage extends ConsumerStatefulWidget {
  const BusHomePage({super.key});
  @override
  ConsumerState<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends ConsumerState<BusHomePage> {
  final _publicService = BusPublicService();
  List<Map<String, dynamic>> _popularRoutes = [];
  bool _loadingPopular = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await Future.wait([
      _loadUserName(),
      _loadPopularRoutes(),
      ref.read(agencyDashboardProvider.notifier).init(),
    ]);
  }

  Future<void> _loadUserName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !mounted) return;

    try {
      final p = await Supabase.instance.client
          .from("profiles")
          .select("full_name")
          .eq("id", user.id)
          .maybeSingle();

      if (!mounted) return;
      final full = (p?["full_name"] as String?)?.trim() ?? "";
      if (full.isNotEmpty) {
        setState(() => _userName = full.split(" ").first);
      }
    } catch (e) {
      debugPrint('[BusHome] loadUserName error: $e');
    }
  }

  Future<void> _loadPopularRoutes() async {
    if (!mounted) return;
    setState(() => _loadingPopular = true);

    try {
      final routes = await _publicService
          .getPopularRoutes()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _popularRoutes = routes;
        _loadingPopular = false;
      });
    } catch (e) {
      debugPrint('[BusHome] loadPopularRoutes error: $e');
      if (!mounted) return;
      setState(() => _loadingPopular = false);
    }
  }

  void _openAgencySpace() {
    final hasAgency = ref.read(agencyDashboardProvider).hasAgency;
    if (!mounted) return;
    context.push(hasAgency ? "/agency/dashboard" : "/agency/onboarding");
  }

  void _onSearch() async {
    await ref.read(busSearchProvider.notifier).search();
    if (!mounted) return;
    context.push("/thix-reservation/bus/search");
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final agencyState = ref.watch(agencyDashboardProvider);
    final hasAgency = agencyState.hasAgency;
    final domainColor = ThixPolicy.domainReservation;
    final displayName = _userName ?? l10n.defaultUserName;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(hasAgency: hasAgency, domainColor: domainColor),
      body: RefreshIndicator(
        color: domainColor,
        backgroundColor: Colors.white,
        onRefresh: _init,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ThixPolicy.s16,
            ThixPolicy.s12,
            ThixPolicy.s16,
            ThixPolicy.bottomNavHeight + ThixPolicy.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingHeader(displayName),
              SizedBox(height: ThixPolicy.s16),
              HeroCarousel(domainColor: domainColor, userName: displayName),
              SizedBox(height: ThixPolicy.s16),
              AgencyBanner(
                hasAgency: hasAgency,
                agencyName: agencyState.myAgency?.name,
                onTap: _openAgencySpace,
              ),
              SizedBox(height: ThixPolicy.s16),
              const DomainCategoryBar(activeDomain: 'bus'),
              SizedBox(height: ThixPolicy.s20),
              TripSearchCard(
                domainColor: domainColor,
                onSearch: _onSearch,
              ),
              SizedBox(height: ThixPolicy.s24),
              _buildSectionHeader(
                title: l10n.busPopularRoutes,
                onSeeAll: () => context.push("/thix-reservation/bus/routes"),
              ),
              SizedBox(height: ThixPolicy.s12),
              _buildPopularRoutesSection(),
              SizedBox(height: ThixPolicy.s24),
              _buildSectionHeader(title: l10n.busComfortTitle),
              SizedBox(height: ThixPolicy.s12),
              const AmenityRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(String userName) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.busHomeGreeting(userName),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.busHomeGreeting(userName),
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
                SizedBox(height: ThixPolicy.s2),
                Text(l10n.busHomeHeading, style: ThixPolicy.h3Style),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.notificationsTooltip,
            onPressed: () => context.push("/notifications"),
            icon: Badge(
              backgroundColor: ThixPolicy.danger,
              label: const Text("3", style: TextStyle(fontSize: 8, color: Colors.white)),
              child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    VoidCallback? onSeeAll,
  }) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(title, style: ThixPolicy.h3Style),
        const Spacer(),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            child: Padding(
              padding: EdgeInsets.all(ThixPolicy.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.commonSeeAll,
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.domainReservation,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                  SizedBox(width: ThixPolicy.s2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: ThixPolicy.domainReservation,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPopularRoutesSection() {
    final l10n = context.l10n;
    if (_loadingPopular) {
      return const PopularRouteSkeletonList();
    }
    if (_popularRoutes.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, color: ThixPolicy.textMuted, size: 28),
            SizedBox(height: ThixPolicy.s4),
            Text(
              l10n.busNoPopularRoutes,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _popularRoutes.length,
        padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s2),
        separatorBuilder: (_, __) => SizedBox(width: ThixPolicy.s12),
        itemBuilder: (_, i) {
          final r = _popularRoutes[i];
          return PopularRouteCard(
            from: (r["departure_city"] as String?) ?? "Kinshasa",
            to: (r["arrival_city"] as String?) ?? "Matadi",
            date: (r["next_departure_label"] as String?) ?? "08:00",
            price: r["min_price"] ?? 5000,
            imageUrl: (r["arrival_city_image"] as String?) ??
                "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=400",
            onTap: () {
              ref.read(busSearchProvider.notifier)
                ..setDeparture(r["departure_city"] as String)
                ..setArrival(r["arrival_city"] as String);
              _onSearch();
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required bool hasAgency,
    required Color domainColor,
  }) {
    final l10n = context.l10n;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: ThixPolicy.textMain),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: domainColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: ThixPolicy.s8),
          RichText(
            text: TextSpan(
              style: ThixPolicy.labelStyle.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
              children: [
                const TextSpan(text: "THIX ", style: TextStyle(color: ThixPolicy.textMain)),
                TextSpan(text: l10n.busHomeTitle.split(" ").last, style: TextStyle(color: domainColor)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: hasAgency ? l10n.agencyTooltipActive : l10n.agencyTooltipInactive,
          onPressed: _openAgencySpace,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasAgency ? ThixPolicy.tint : ThixPolicy.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasAgency ? Icons.storefront_rounded : Icons.add_business_rounded,
              size: 18,
              color: hasAgency ? domainColor : ThixPolicy.warning,
            ),
          ),
        ),
        SizedBox(width: ThixPolicy.s4),
      ],
    );
  }
}
