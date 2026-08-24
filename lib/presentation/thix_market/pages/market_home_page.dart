// lib/presentation/thix_market/pages/market_home_page.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; 

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ✅ IMPORTS LIVE
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';

import '../l10n/market_strings.dart';
import '../providers/market_providers.dart';
import '../providers/featured_products_provider.dart';
import '../widgets/products/product_card.dart';
import '../widgets/market/flash_sale_timer.dart';

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES POUR LE MARKET
// ============================================================================
final activeMarketLiveSessionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(10);
  } catch (_) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});

class MarketHomePage extends ConsumerStatefulWidget {
  const MarketHomePage({super.key});
  @override
  ConsumerState<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends ConsumerState<MarketHomePage> {
  final ScrollController _scroll = ScrollController();
  final PageController _bannerCtrl = PageController(viewportFraction: 0.94);
  Timer? _bannerTimer;
  Timer? _expiryTicker; 
  bool _bannerReady = false;
  int _currentBanner = 0;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 700) {
      ref.read(forYouProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    _expiryTicker?.cancel();
    super.dispose();
  }

  void _safeNavigate(String name, String path) {
    try {
      context.pushNamed(name);
    } catch (_) {
      try {
        context.push(path);
      } catch (_) {}
    }
  }

  void _startBannerAuto(int count) {
    if (_bannerReady) return;
    if (count <= 1) return;
    _bannerReady = true;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerCtrl.hasClients) return;
      _currentBanner = (_currentBanner + 1) % count;
      _bannerCtrl.animateToPage(_currentBanner, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
      if (mounted) setState(() {});
    });
  }

  String? _extractImage(Map<String, dynamic> p) {
    if (p['image_url'] != null && p['image_url'].toString().isNotEmpty) return p['image_url'].toString();
    if (p['images'] is List && (p['images'] as List).isNotEmpty) return (p['images'] as List).first.toString();
    return null;
  }

  String _greetingName(MarketStrings t) {
    final user = Supabase.instance.client.auth.currentUser;
    final full = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
    if (full != null && (full as String).trim().isNotEmpty) return full.trim().split(' ').first;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return t.client;
  }

  void _showComing(String feature) {
    final t = context.mkt;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.comingSoon(feature)), backgroundColor: ThixPolicy.warning));
  }

  int _stableHash(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }

  String _mixSeed() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return '$uid-$day';
  }

  List<Map<String, dynamic>> _smartMix(List<Map<String, dynamic>> items) {
    final seed = _mixSeed();
    final scored = items.map((p) {
      final id = p['id']?.toString() ?? Random().nextInt(999999).toString();
      return MapEntry(_stableHash('$seed-$id'), p);
    }).toList();
    scored.sort((a, b) => a.key.compareTo(b.key));
    return scored.map((e) => e.value).toList();
  }

  bool _isExpired(Map<String, dynamic> p) {
    final exp = p['expires_at'];
    if (exp == null) return false;
    final dt = DateTime.tryParse(exp.toString());
    if (dt == null) return false;
    return !dt.isAfter(DateTime.now());
  }

  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mkt;
    final featuredAsync = ref.watch(featuredProductsProvider);
    final flashAsync = ref.watch(flashSalesProvider);
    final forYouAsync = ref.watch(forYouProvider);
    final liveSessionsAsync = ref.watch(activeMarketLiveSessionsProvider); // NOUVEAU
    
    final all = ref.watch(allMarketProductsProvider);
    final hasMore = ref.read(forYouProvider.notifier).hasMore;
    final mixedAll = _smartMix(all);

    featuredAsync.whenData((b) => WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerAuto(b.length)));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      extendBody: true, // Pour que la liste passe sous la bottom nav bar flottante
      body: Stack(
        children: [
          // Orbes d'arrière-plan Glassmorphism
          Positioned(top: -100, right: -50, child: _buildBlurOrb(ThixPolicy.domainMarket.withValues(alpha: 0.1), 250)),
          Positioned(bottom: 200, left: -100, child: _buildBlurOrb(ThixPolicy.primary.withValues(alpha: 0.05), 300)),

          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: () async {
              ref.invalidate(featuredProductsProvider);
              ref.invalidate(flashSalesProvider);
              ref.invalidate(featuredShopsProvider);
              ref.invalidate(activeMarketLiveSessionsProvider);
              await ref.read(forYouProvider.notifier).refresh();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ─── Header & Search (Glassmorphism) ───
                SliverToBoxAdapter(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rXl)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            _buildTopBar(t),
                            _buildSearchBar(t),
                            const SizedBox(height: ThixPolicy.s16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                
                // ─── Hero Banner ───
                SliverToBoxAdapter(child: _buildHero(featuredAsync, t)),
                
                // ─── Featured Products ───
                SliverToBoxAdapter(child: _buildFeaturedStrip(featuredAsync, t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                
                // ─── Trust Badges ───
                SliverToBoxAdapter(child: _buildTrustBadges(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
                
                // ─── LIVES EN COURS (NOUVEAU) ───
                SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, t)),

                // ─── Supermarchés ───
                SliverToBoxAdapter(child: _buildSupermarketSection(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),
                
                // ─── Bannières Promo & B2B ───
                SliverToBoxAdapter(child: _buildPromoBannersRow(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                SliverToBoxAdapter(child: _buildB2BTools(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),
                
                // ─── Ventes Flash ───
                SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, t)),
                
                // ─── Pour Vous (Grille) ───
                SliverToBoxAdapter(child: _buildSectionHeader(t.allProducts)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
                _buildGrid(forYouAsync, mixedAll, hasMore, t),
                
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // ─── BOTTOM NAV BAR REDUITE ───
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomNavBar(t),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(MarketStrings t) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(ThixPolicy.s16, MediaQuery.paddingOf(context).top + 12, ThixPolicy.s16, ThixPolicy.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  border: Border.all(color: Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.storefront_rounded, color: ThixPolicy.domainMarket, size: 24),
              ),
              const SizedBox(width: ThixPolicy.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'THIX ', style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                        TextSpan(text: 'MARKET', style: TextStyle(color: ThixPolicy.domainMarket, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                  Text(t.appTagline, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () => context.push('/market/notifications'),
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle, 
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5)
                  ),
                  child: const Icon(Icons.notifications_none_rounded, size: 20, color: ThixPolicy.textMain),
                ),
              ),
              const SizedBox(width: ThixPolicy.s8),
              InkWell(
                onTap: () => context.push('/user/dashboard'),
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: ThixPolicy.brandGradient, 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(MarketStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/market/search'),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), 
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
                    const SizedBox(width: ThixPolicy.s12),
                    Expanded(child: Text(t.searchHint, style: const TextStyle(fontSize: 13, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s8),
          InkWell(
            onTap: () => context.push('/market/search'),
            borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
              decoration: BoxDecoration(
                color: ThixPolicy.primaryDeep.withValues(alpha: 0.9), 
                borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
                boxShadow: [BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]
              ),
              child: const Center(child: Icon(Icons.tune_rounded, color: Colors.white, size: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainMarket))),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _buildHeroContent(products, t);
      },
    );
  }

  Widget _buildHeroContent(List<Map<String, dynamic>> products, MarketStrings t) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                _bannerTimer?.cancel();
                _bannerReady = false;
              } else if (n is ScrollEndNotification) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _startBannerAuto(products.length);
                });
              }
              return false;
            },
            child: PageView.builder(
              controller: _bannerCtrl,
              itemCount: products.length,
              onPageChanged: (i) => setState(() => _currentBanner = i),
              itemBuilder: (_, index) {
                final p = products[index];
                final imageUrl = _extractImage(p);
                final title = (p['title'] ?? '').toString();
                final subtitle = (p['description'] ?? '').toString();
                final id = p['id']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => context.push('/market/product/$id'),
                    child: Container(
                      padding: const EdgeInsets.all(ThixPolicy.s24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: ThixPolicy.heroGradient,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                        image: imageUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(imageUrl),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                              )
                            : null,
                        boxShadow: ThixPolicy.shadowCard(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (index == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: ThixPolicy.domainMarket, borderRadius: BorderRadius.circular(6)),
                              child: Text('${t.greeting}, ${_greetingName(t)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          const SizedBox(height: ThixPolicy.s12),
                          Text(title.isEmpty ? '—' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5)),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: ThixPolicy.s8),
                            SizedBox(width: 240, child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500))),
                          ],
                          const SizedBox(height: ThixPolicy.s16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_cart_rounded, size: 16, color: ThixPolicy.inkDeep),
                                const SizedBox(width: 8),
                                Text(t.viewOffer, style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            products.length,
            (i) {
              final a = i == _currentBanner;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: a ? 20 : 6,
                decoration: BoxDecoration(color: a ? ThixPolicy.domainMarket : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(10)),
              );
            },
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
      ],
    );
  }

  Widget _buildFeaturedStrip(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _AutoScrollProductStrip(products: products, badgeType: _StripBadge.featured, title: t.featuredProducts, icon: Icons.star_rounded);
      },
    );
  }

  Widget _buildTrustBadges(MarketStrings t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5), // Glassmorphism
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _trustItem(Icons.lock_outline_rounded, t.securePayment),
          _trustItem(Icons.verified_user_outlined, t.verifiedSellers),
          _trustItem(Icons.local_shipping_outlined, t.reliableDelivery),
          _trustItem(Icons.headset_mic_outlined, t.support247),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: ThixPolicy.domainMarket.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: ThixPolicy.domainMarket),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
      ],
    );
  }

  // ─────────────────────────── NOUVELLE SECTION LIVE ───────────────────────────
  Widget _buildLiveSection(AsyncValue<List<Map<String, dynamic>>> liveAsync, MarketStrings t) {
    return liveAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(t.live, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5)),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                itemBuilder: (ctx, i) {
                  final s = sessions[i];
                  final hostAvatar = s['host_avatar']?.toString();
                  final shopName = s['channel_name']?.toString() ?? s['host_name']?.toString() ?? t.client;
                  
                  return GestureDetector(
                    onTap: () {
                      final liveSession = LiveSession(
                        id: s['id']?.toString() ?? '',
                        channelName: s['channel_name']?.toString() ?? '',
                        title: s['title']?.toString() ?? 'Live Market',
                        hostId: s['host_id']?.toString() ?? '',
                        hostName: s['host_name']?.toString() ?? t.client,
                        hostAvatarUrl: hostAvatar,
                      );
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LiveViewerScreen(session: liveSession)));
                    },
                    child: Container(
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThixPolicy.danger.withValues(alpha: 0.5), width: 1.2),
                        boxShadow: [BoxShadow(color: ThixPolicy.danger.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: hostAvatar != null && hostAvatar.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: hostAvatar, fit: BoxFit.cover)
                                  : Container(color: ThixPolicy.surfaceSoft, child: const Icon(Icons.storefront, color: ThixPolicy.textSecondary, size: 40)),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)]),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(t.live.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8, left: 8, right: 8,
                            child: Text(shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: ThixPolicy.s24),
          ],
        );
      },
    );
  }

  Widget _buildSupermarketSection(MarketStrings t) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(t.homeSupermarkets, onSeeAll: () => _safeNavigate('marketShops', '/market/shops')),
          const SizedBox(height: ThixPolicy.s16),
          shopsAsync.when(
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainMarket))),
            error: (_, __) => const SizedBox.shrink(),
            data: (shops) {
              if (shops.isEmpty) return Text(t.noSupermarket, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12));
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: shops.take(4).map((s) {
                  return GestureDetector(
                    onTap: () => context.push('/market/shop/${s['id']}'),
                    child: Column(
                      children: [
                        Container(
                          height: 64, width: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.6), // Glass
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                            boxShadow: ThixPolicy.shadowSoft(),
                            image: s['logo_url'] != null ? DecorationImage(image: CachedNetworkImageProvider(s['logo_url']), fit: BoxFit.cover) : null,
                          ),
                          child: s['logo_url'] == null ? const Icon(Icons.storefront_rounded, color: ThixPolicy.textMuted, size: 28) : null,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 70,
                          child: Text((s['name'] ?? 'Shop').toString(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBannersRow(MarketStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(
                  gradient: ThixPolicy.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ThixPolicy.shadowSoft(),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(4)), child: Text(t.exclusiveOffers, style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontSize: 9))),
                    const SizedBox(height: 8),
                    Text(t.upTo50, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
                    Text(t.onPremiumSelection, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Row(
                      children: [
                        Text(t.discover, style: const TextStyle(color: ThixPolicy.gold, fontWeight: FontWeight.w800, fontSize: 11)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: ThixPolicy.gold)
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: GestureDetector(
              onTap: () => _safeNavigate('vendorDashboard', '/market/vendor/dashboard'),
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5), // Glass
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.sellWithThix, style: const TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800, fontSize: 10)),
                    const SizedBox(height: 6),
                    Text(t.growBusiness, style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w900, fontSize: 14, height: 1.2)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: ThixPolicy.primaryDeep.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                      child: Text(t.start, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildB2BTools(MarketStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16, horizontal: ThixPolicy.s8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5), // Glass
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _b2bItem(Icons.compare_arrows_rounded, t.compare, () => _safeNavigate('marketProductComparator', '/market/compare')),
            _b2bItem(Icons.notifications_active_rounded, t.priceAlert, () => _safeNavigate('marketPriceAlerts', '/market/price-alerts')),
            _b2bItem(Icons.request_quote_rounded, t.b2bQuote, () => _showComing(t.b2bQuote)),
            _b2bItem(Icons.favorite_rounded, t.wishlist, () => _safeNavigate('marketWishlist', '/market/wishlist')),
          ],
        ),
      ),
    );
  }

  Widget _b2bItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle), child: Icon(icon, color: ThixPolicy.primaryDeep, size: 20)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashSaleSection(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final active = list.where((p) => !_isExpired(p)).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        DateTime? timerEnd;
        for (final p in active) {
          final dt = DateTime.tryParse(p['expires_at']?.toString() ?? '');
          if (dt != null && (timerEnd == null || dt.isBefore(timerEnd))) timerEnd = dt;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timerEnd != null)
              Container(
                decoration: const BoxDecoration(color: ThixPolicy.danger),
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: FlashSaleTimer(endTime: timerEnd!),
                      ),
                    ),
                    Expanded(child: ClipRect(child: _MarqueeText(text: t.flashSaleBannerText))),
                  ],
                ),
              ),
            _AutoScrollProductStrip(products: active, badgeType: _StripBadge.flash, title: t.flashOffers, icon: Icons.bolt_rounded, liveLabel: t.live),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('Voir tout', style: TextStyle(color: ThixPolicy.primary, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(AsyncValue<List<Map<String, dynamic>>> forYouAsync, List<Map<String, dynamic>> mixedAll, bool hasMore, MarketStrings t) {
    return forYouAsync.when(
      loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainMarket)))),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('${t.error}: $e', style: const TextStyle(color: ThixPolicy.textSecondary)))),
      data: (_) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.65),
          delegate: SliverChildBuilderDelegate((_, i) {
            if (i >= mixedAll.length) return const Center(child: CircularProgressIndicator(color: ThixPolicy.domainMarket));
            return ProductCard(product: mixedAll[i]);
          }, childCount: mixedAll.length + (hasMore ? 1 : 0)),
        ),
      ),
    );
  }

  // ─────────────────────────── NOUVELLE BOTTOM NAV BAR ───────────────────────────
  Widget _buildBottomNavBar(MarketStrings t) {
    return Container(
      color: Colors.transparent, // Obligatoire pour le Glassmorphism flottant
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 56, // HAUTEUR RÉDUITE
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navItem(Icons.home_rounded, t.home, 0),
                        _navItem(Icons.receipt_long_rounded, t.orders, 1),
                        const SizedBox(width: 60), // Espace pour le FAB central
                        _navItem(Icons.favorite_rounded, t.wishlist, 3),
                        _navItem(Icons.notifications_active_rounded, t.alerts, 4),
                      ],
                    ),
                    Positioned(
                      top: -18, // Ajustement dû à la hauteur réduite
                      child: GestureDetector(
                        onTap: () => context.push('/market/cart'),
                        child: Container(
                          width: 56, height: 56, // TAILLE RÉDUITE DU BOUTON CENTRAL
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: ThixPolicy.brandGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                            boxShadow: [BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 24),
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

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _selectedNav == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedNav = index);
        if (index == 0) _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        if (index == 1) context.push('/market/orders');
        if (index == 3) context.push('/market/wishlist');
        if (index == 4) context.push('/market/price-alerts');
      },
      child: Container(
        width: 54, // TAILLE RÉDUITE
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? ThixPolicy.domainMarket : ThixPolicy.textSecondary.withValues(alpha: 0.8), size: 22),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, style: TextStyle(fontSize: 9, color: sel ? ThixPolicy.domainMarket : ThixPolicy.textSecondary.withValues(alpha: 0.8), fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

enum _StripBadge { flash, featured, none }

class _AutoScrollProductStrip extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final _StripBadge badgeType;
  final String title;
  final IconData icon;
  final String? liveLabel;

  const _AutoScrollProductStrip({
    required this.products,
    required this.badgeType,
    required this.title,
    required this.icon,
    this.liveLabel,
  });

  @override
  State<_AutoScrollProductStrip> createState() => _AutoScrollProductStripState();
}

class _AutoScrollProductStripState extends State<_AutoScrollProductStrip> {
  final ScrollController _ctrl = ScrollController();
  Timer? _timer;
  bool _paused = false;
  static const double _step = 1.1;
  static const Duration _tick = Duration(milliseconds: 16);

  bool get _active => widget.products.length > 4;

  @override
  void initState() {
    super.initState();
    if (_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(covariant _AutoScrollProductStrip old) {
    super.didUpdateWidget(old);
    if (old.products.length != widget.products.length) {
      _timer?.cancel();
      if (_active) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _start() {
    _timer = Timer.periodic(_tick, (_) {
      if (!_ctrl.hasClients || _paused) return;
      final maxExt = _ctrl.position.maxScrollExtent;
      final next = _ctrl.offset + _step;
      _ctrl.jumpTo(next >= maxExt ? 0 : next);
    });
  }

  void _pause() => _paused = true;
  void _resumeAfterDelay() => Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _paused = false;
      });

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFlash = widget.badgeType == _StripBadge.flash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
          child: Row(
            children: [
              Icon(widget.icon, color: isFlash ? ThixPolicy.danger : ThixPolicy.gold, size: 22),
              const SizedBox(width: 8),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5)),
              if (_active && widget.liveLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.liveLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ThixPolicy.danger)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        SizedBox(
          height: 220,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_active) return false;
              if (n is ScrollStartNotification) {
                _pause();
              } else if (n is ScrollEndNotification) {
                _resumeAfterDelay();
              }
              return false;
            },
            child: ListView.separated(
              controller: _ctrl,
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
              itemBuilder: (_, i) => ProductCard(
                product: widget.products[i],
                variant: ProductCardVariant.horizontal,
                width: 140,
                isFlashSale: widget.badgeType == _StripBadge.flash,
                isFeatured: widget.badgeType == _StripBadge.featured,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_ctrl.hasClients) return;
      final maxScroll = _ctrl.position.maxScrollExtent;
      final current = _ctrl.offset;
      _ctrl.jumpTo(current >= maxScroll ? 0 : current + 2.0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Center(child: Text(widget.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))),
        ),
      ),
    );
  }
}
