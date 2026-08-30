// lib/presentation/thix_market/pages/market_home_page.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';

import '../l10n/market_strings.dart';
import '../providers/market_providers.dart';
import '../widgets/products/product_card.dart';
import '../widgets/market/flash_sale_timer.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kBannerAutoPlay = Duration(seconds: 4);
const Duration _kBannerResumeDelay = Duration(seconds: 2);
const int _kMaxTitleLength = 120;
const int _kMaxDescriptionLength = 300;
const int _kMaxNameLength = 50;
const int _kMaxLiveCards = 10;
const int _kMaxFeaturedShops = 4;

class _MarketValidators {
  _MarketValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    try {
      final doc = html_parser.parse(input);
      var sanitized = doc.body?.text ?? input;
      sanitized = sanitized
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
          .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();
      return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
    } catch (e) {
      debugPrint('[Market] ⚠️ sanitize error: $e');
      return '';
    }
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String parseError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('unauthorized')) return 'Session expirée. Reconnectez-vous.';
    return 'Erreur inattendue';
  }
}

// ============================================================================
// PROVIDER — LIVE SESSIONS (avec retry + error handling)
// ============================================================================
final activeMarketLiveSessionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(_kMaxLiveCards)
        .handleError((e) {
      debugPrint('[Market] ⚠️ Live stream error: $e');
    });
  } catch (e) {
    debugPrint('[Market] ❌ Live provider error: $e');
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});

// ============================================================================
// PROVIDER — EXPIRY TICKER (remplace le Timer.periodic 30s global)
// ============================================================================
final marketTickerProvider = StreamProvider.autoDispose<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (tick) => tick);
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MarketHomePage extends ConsumerStatefulWidget {
  const MarketHomePage({super.key});
  @override
  ConsumerState<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends ConsumerState<MarketHomePage> {
  final ScrollController _scroll = ScrollController();
  final PageController _bannerCtrl = PageController(viewportFraction: 0.94);
  Timer? _bannerTimer;
  bool _bannerReady = false;
  int _currentBanner = 0;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    debugPrint('[Market] 🏠 Home opened');
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 700) {
      ref.read(forYouProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    debugPrint('[Market] 🏠 Home disposed');
    super.dispose();
  }

  void _safeNavigate(String name, String path) {
    HapticFeedback.selectionClick();
    try {
      context.pushNamed(name);
      debugPrint('[Market] 🧭 Nav via name: $name');
    } catch (_) {
      try {
        context.push(path);
        debugPrint('[Market] 🧭 Nav via path: $path');
      } catch (e) {
        debugPrint('[Market] ❌ Nav failed: $e');
      }
    }
  }

  void _startBannerAuto(int count) {
    if (_bannerReady || count <= 1) return;
    _bannerReady = true;
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(_kBannerAutoPlay, (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;
      _currentBanner = (_currentBanner + 1) % count;
      _bannerCtrl.animateToPage(
        _currentBanner,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _extractImage(Map<String, dynamic> p) {
    final url1 = p['image_url']?.toString();
    if (url1 != null && url1.isNotEmpty) return _MarketValidators.sanitizeUrl(url1);
    if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      return _MarketValidators.sanitizeUrl((p['images'] as List).first.toString());
    }
    return null;
  }

  String _greetingName(MarketStrings t) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final full = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
      if (full != null && (full as String).trim().isNotEmpty) {
        return _MarketValidators.sanitize(full.trim().split(' ').first, maxLength: _kMaxNameLength);
      }
      final email = user?.email;
      if (email != null && email.contains('@')) {
        return _MarketValidators.sanitize(email.split('@').first, maxLength: _kMaxNameLength);
      }
    } catch (e) {
      debugPrint('[Market] ⚠️ greetingName error: $e');
    }
    return _MarketValidators.sanitize(t.client, maxLength: _kMaxNameLength);
  }

  void _showComing(String feature) {
    final t = context.mkt;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.comingSoon(feature)),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final hour = DateTime.now().toIso8601String().substring(0, 13); // Par heure (plus dynamique)
    return '$uid-$hour';
  }

  List<Map<String, dynamic>> _smartMix(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return items;
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
    return IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mkt;
    final featuredAsync = ref.watch(featuredProductsProvider);
    final flashAsync = ref.watch(flashSalesProvider);
    final forYouAsync = ref.watch(forYouProvider);
    final liveSessionsAsync = ref.watch(activeMarketLiveSessionsProvider);

    final all = ref.watch(allMarketProductsProvider);
    final hasMore = ref.read(forYouProvider.notifier).hasMore;
    final mixedAll = _smartMix(all);

    // Watch le ticker pour refresh flash sales uniquement (pas toute la page)
    ref.watch(marketTickerProvider);

    featuredAsync.whenData((b) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerAuto(b.length));
    });

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      extendBody: true,
      body: Stack(
        children: [
          Positioned(top: -100, right: -50, child: _buildBlurOrb(ThixPolicy.domainMarket.withOpacity(0.1), 250)),
          Positioned(bottom: 200, left: -100, child: _buildBlurOrb(ThixPolicy.primary.withOpacity(0.05), 300)),

          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              debugPrint('[Market] 🔄 Pull-to-refresh');
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
                SliverToBoxAdapter(child: _buildTopSection(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                SliverToBoxAdapter(child: _buildHero(featuredAsync, t)),
                SliverToBoxAdapter(child: _buildFeaturedStrip(featuredAsync, t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                SliverToBoxAdapter(child: _buildTrustBadges(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
                SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, t)),
                SliverToBoxAdapter(child: _buildSupermarketSection(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),
                SliverToBoxAdapter(child: _buildPromoBannersRow(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                SliverToBoxAdapter(child: _buildB2BTools(t)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),
                SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, t)),
                SliverToBoxAdapter(child: _buildSectionHeader(t.allProducts)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
                _buildGrid(forYouAsync, mixedAll, hasMore, t),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNavBar(t)),
        ],
      ),
    );
  }

  Widget _buildTopSection(MarketStrings t) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  border: Border.all(color: Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                  Text(
                    _MarketValidators.sanitize(t.appTagline, maxLength: 50),
                    style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Notifications',
                child: InkWell(
                  onTap: () => _safeNavigate('marketNotifications', '/market/notifications'),
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 20, color: ThixPolicy.textMain),
                  ),
                ),
              ),
              const SizedBox(width: ThixPolicy.s8),
              Semantics(
                button: true,
                label: 'Profil',
                child: InkWell(
                  onTap: () => _safeNavigate('userDashboard', '/user/dashboard'),
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
            child: Semantics(
              button: true,
              label: t.searchHint,
              child: GestureDetector(
                onTap: () => _safeNavigate('marketSearch', '/market/search'),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
                      const SizedBox(width: ThixPolicy.s12),
                      Expanded(
                        child: Text(
                          _MarketValidators.sanitize(t.searchHint, maxLength: 80),
                          style: const TextStyle(fontSize: 13, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s8),
          Semantics(
            button: true,
            label: 'Filtres',
            child: InkWell(
              onTap: () => _safeNavigate('marketSearch', '/market/search'),
              borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                decoration: BoxDecoration(
                  color: ThixPolicy.primaryDeep.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
                  boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Center(child: Icon(Icons.tune_rounded, color: Colors.white, size: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const _HeroSkeleton(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e),
        onRetry: () => ref.invalidate(featuredProductsProvider),
      ),
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
                Future.delayed(_kBannerResumeDelay, () {
                  if (mounted) _startBannerAuto(products.length);
                });
              }
              return false;
            },
            child: PageView.builder(
              controller: _bannerCtrl,
              itemCount: products.length,
              onPageChanged: (i) {
                if (mounted) setState(() => _currentBanner = i);
              },
              itemBuilder: (_, index) {
                final p = products[index];
                final imageUrl = _extractImage(p);
                final title = _MarketValidators.sanitize(p['title']?.toString(), maxLength: _kMaxTitleLength);
                final subtitle = _MarketValidators.sanitize(p['description']?.toString(), maxLength: _kMaxDescriptionLength);
                final id = p['id']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Semantics(
                    button: true,
                    label: title.isEmpty ? 'Offre en vedette' : title,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) context.push('/market/product/$id');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(ThixPolicy.s24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: ThixPolicy.heroGradient,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                          image: imageUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: ThixPolicy.inkDeep),
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
                                child: Text(
                                  '${_MarketValidators.sanitize(t.greeting)}, ${_greetingName(t)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            const SizedBox(height: ThixPolicy.s12),
                            Text(
                              title.isEmpty ? '—' : title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: ThixPolicy.s8),
                              SizedBox(
                                width: 240,
                                child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                            ],
                            const SizedBox(height: ThixPolicy.s16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shopping_cart_rounded, size: 16, color: ThixPolicy.inkDeep),
                                  const SizedBox(width: 8),
                                  Text(_MarketValidators.sanitize(t.viewOffer, maxLength: 30), style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
          children: List.generate(products.length, (i) {
            final active = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 20 : 6,
              decoration: BoxDecoration(
                color: active ? ThixPolicy.domainMarket : ThixPolicy.borderStrong,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
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
        return _AutoScrollProductStrip(
          products: products,
          badgeType: _StripBadge.featured,
          title: _MarketValidators.sanitize(t.featuredProducts, maxLength: 50),
          icon: Icons.star_rounded,
        );
      },
    );
  }

  Widget _buildTrustBadges(MarketStrings t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _trustItem(Icons.lock_outline_rounded, _MarketValidators.sanitize(t.securePayment, maxLength: 20)),
          _trustItem(Icons.verified_user_outlined, _MarketValidators.sanitize(t.verifiedSellers, maxLength: 20)),
          _trustItem(Icons.local_shipping_outlined, _MarketValidators.sanitize(t.reliableDelivery, maxLength: 20)),
          _trustItem(Icons.headset_mic_outlined, _MarketValidators.sanitize(t.support247, maxLength: 20)),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Semantics(
      label: label,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ThixPolicy.domainMarket.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: ThixPolicy.domainMarket),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        ],
      ),
    );
  }

  Widget _buildLiveSection(AsyncValue<List<Map<String, dynamic>>> liveAsync, MarketStrings t) {
    return liveAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        child: _MarketErrorCard(
          message: _MarketValidators.parseError(e),
          onRetry: () => ref.invalidate(activeMarketLiveSessionsProvider),
          compact: true,
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              child: Row(
                children: [
                  const _PulsingDot(),
                  const SizedBox(width: 8),
                  const Text(
                    'Live en cours...',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${sessions.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ThixPolicy.danger),
                    ),
                  ),
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
                itemBuilder: (ctx, i) => _buildLiveCard(sessions[i], t),
              ),
            ),
            const SizedBox(height: ThixPolicy.s24),
          ],
        );
      },
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> s, MarketStrings t) {
    final hostAvatar = _MarketValidators.sanitizeUrl(s['host_avatar']?.toString());
    final shopName = _MarketValidators.sanitize(
      s['channel_name']?.toString() ?? s['host_name']?.toString() ?? t.client,
      maxLength: _kMaxNameLength,
    );

    return Semantics(
      button: true,
      label: 'Live: $shopName',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          try {
            final liveSession = LiveSession(
              id: s['id']?.toString() ?? '',
              channelName: s['channel_name']?.toString() ?? '',
              title: _MarketValidators.sanitize(s['title']?.toString(), maxLength: _kMaxTitleLength),
              hostId: s['host_id']?.toString() ?? '',
              hostName: shopName,
              hostAvatarUrl: hostAvatar,
            );
            Navigator.push(context, MaterialPageRoute(builder: (context) => LiveViewerScreen(session: liveSession)));
          } catch (e) {
            debugPrint('[Market] ❌ Live nav error: $e');
          }
        },
        child: Container(
          width: 110,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.danger.withOpacity(0.5), width: 1.2),
            boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: hostAvatar != null
                      ? CachedNetworkImage(
                          imageUrl: hostAvatar,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: ThixPolicy.surfaceSoft, child: const Icon(Icons.storefront, color: ThixPolicy.textSecondary, size: 40)),
                        )
                      : Container(color: ThixPolicy.surfaceSoft, child: const Icon(Icons.storefront, color: ThixPolicy.textSecondary, size: 40)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
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
                      Text(_MarketValidators.sanitize(t.live, maxLength: 10).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildSupermarketSection(MarketStrings t) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _MarketValidators.sanitize(t.homeSupermarkets, maxLength: 50),
            onSeeAll: () => _safeNavigate('marketShops', '/market/shops'),
          ),
          const SizedBox(height: ThixPolicy.s16),
          shopsAsync.when(
            loading: () => const _ShopsSkeleton(),
            error: (e, _) => _MarketErrorCard(
              message: _MarketValidators.parseError(e),
              onRetry: () => ref.invalidate(featuredShopsProvider),
              compact: true,
            ),
            data: (shops) {
              if (shops.isEmpty) {
                return Text(
                  _MarketValidators.sanitize(t.noSupermarket, maxLength: 100),
                  style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: shops.take(_kMaxFeaturedShops).map((s) {
                  final id = s['id']?.toString() ?? '';
                  final name = _MarketValidators.sanitize(s['name']?.toString() ?? 'Shop', maxLength: _kMaxNameLength);
                  final logoUrl = _MarketValidators.sanitizeUrl(s['logo_url']?.toString());
                  return Semantics(
                    button: true,
                    label: 'Boutique: $name',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) context.push('/market/shop/$id');
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 64, width: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.6),
                              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                              boxShadow: ThixPolicy.shadowSoft(),
                              image: logoUrl != null
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(logoUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => null,
                                    )
                                  : null,
                            ),
                            child: logoUrl == null ? const Icon(Icons.storefront_rounded, color: ThixPolicy.textMuted, size: 28) : null,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 70,
                            child: Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                          ),
                        ],
                      ),
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
            child: Semantics(
              button: true,
              label: 'Offres exclusives',
              child: GestureDetector(
                onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  decoration: BoxDecoration(
                    gradient: ThixPolicy.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ThixPolicy.shadowSoft(),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(4)),
                        child: Text(_MarketValidators.sanitize(t.exclusiveOffers, maxLength: 30), style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontSize: 9)),
                      ),
                      const SizedBox(height: 8),
                      Text(_MarketValidators.sanitize(t.upTo50, maxLength: 50), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
                      Text(_MarketValidators.sanitize(t.onPremiumSelection, maxLength: 60), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Row(
                        children: [
                          Text(_MarketValidators.sanitize(t.discover, maxLength: 20), style: const TextStyle(color: ThixPolicy.gold, fontWeight: FontWeight.w800, fontSize: 11)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: ThixPolicy.gold),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Vendre sur THIX',
              child: GestureDetector(
                onTap: () => _safeNavigate('vendorDashboard', '/market/vendor/dashboard'),
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_MarketValidators.sanitize(t.sellWithThix, maxLength: 30), style: const TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800, fontSize: 10)),
                      const SizedBox(height: 6),
                      Text(_MarketValidators.sanitize(t.growBusiness, maxLength: 60), style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w900, fontSize: 14, height: 1.2)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: ThixPolicy.primaryDeep.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                        child: Text(_MarketValidators.sanitize(t.start, maxLength: 20), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
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
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _b2bItem(Icons.compare_arrows_rounded, _MarketValidators.sanitize(t.compare, maxLength: 20), () => _safeNavigate('marketProductComparator', '/market/compare')),
            _b2bItem(Icons.notifications_active_rounded, _MarketValidators.sanitize(t.priceAlert, maxLength: 20), () => _safeNavigate('marketPriceAlerts', '/market/price-alerts')),
            _b2bItem(Icons.request_quote_rounded, _MarketValidators.sanitize(t.b2bQuote, maxLength: 20), () => _showComing(t.b2bQuote)),
            _b2bItem(Icons.favorite_rounded, _MarketValidators.sanitize(t.wishlist, maxLength: 20), () => _safeNavigate('marketWishlist', '/market/wishlist')),
          ],
        ),
      ),
    );
  }

  Widget _b2bItem(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                child: Icon(icon, color: ThixPolicy.primaryDeep, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashSaleSection(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e),
        onRetry: () => ref.invalidate(flashSalesProvider),
      ),
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
                    Expanded(child: ClipRect(child: _MarqueeText(text: _MarketValidators.sanitize(t.flashSaleBannerText, maxLength: 100)))),
                  ],
                ),
              ),
            _AutoScrollProductStrip(
              products: active,
              badgeType: _StripBadge.flash,
              title: _MarketValidators.sanitize(t.flashOffers, maxLength: 50),
              icon: Icons.bolt_rounded,
              liveLabel: _MarketValidators.sanitize(t.live, maxLength: 10),
            ),
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
            Semantics(
              button: true,
              label: 'Voir tout',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSeeAll();
                },
                child: const Text('Voir tout', style: TextStyle(color: ThixPolicy.primary, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(AsyncValue<List<Map<String, dynamic>>> forYouAsync, List<Map<String, dynamic>> mixedAll, bool hasMore, MarketStrings t) {
    return forYouAsync.when(
      loading: () => const SliverToBoxAdapter(child: _GridSkeleton()),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _MarketErrorCard(
            message: _MarketValidators.parseError(e),
            onRetry: () => ref.read(forYouProvider.notifier).refresh(),
          ),
        ),
      ),
      data: (_) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.65),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= mixedAll.length) {
                return const Center(child: CircularProgressIndicator(color: ThixPolicy.domainMarket));
              }
              return ProductCard(product: mixedAll[i]);
            },
            childCount: mixedAll.length + (hasMore ? 1 : 0),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(MarketStrings t) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navItem(Icons.home_rounded, _MarketValidators.sanitize(t.home, maxLength: 20), 0),
                        _navItem(Icons.receipt_long_rounded, _MarketValidators.sanitize(t.orders, maxLength: 20), 1),
                        const SizedBox(width: 60),
                        _navItem(Icons.favorite_rounded, _MarketValidators.sanitize(t.wishlist, maxLength: 20), 3),
                        _navItem(Icons.notifications_active_rounded, _MarketValidators.sanitize(t.alerts, maxLength: 20), 4),
                      ],
                    ),
                    Positioned(
                      top: -18,
                      child: Semantics(
                        button: true,
                        label: 'Panier',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            context.push('/market/cart');
                          },
                          child: Container(
                            width: 56, height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: ThixPolicy.brandGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
                              boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 24),
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

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _selectedNav == index;
    return Semantics(
      button: true,
      label: label,
      selected: sel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedNav = index);
          if (index == 0) _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
          if (index == 1) context.push('/market/orders');
          if (index == 3) context.push('/market/wishlist');
          if (index == 4) context.push('/market/price-alerts');
        },
        child: Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? ThixPolicy.domainMarket : ThixPolicy.textSecondary.withOpacity(0.8), size: 22),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, style: TextStyle(fontSize: 9, color: sel ? ThixPolicy.domainMarket : ThixPolicy.textSecondary.withOpacity(0.8), fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

/// Carte d'erreur réutilisable avec retry
class _MarketErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool compact;

  const _MarketErrorCard({required this.message, required this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: compact ? 20 : 28),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: ThixPolicy.danger, fontSize: compact ? 12 : 14))),
          if (!compact)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
            ),
        ],
      ),
    );
  }
}

/// Skeleton pour Hero banner
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

/// Skeleton pour shops
class _ShopsSkeleton extends StatelessWidget {
  const _ShopsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (_) => Column(
        children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Container(width: 60, height: 12, color: Colors.grey.shade200),
        ],
      )),
    );
  }
}

/// Skeleton pour grille produits
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.65),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle)),
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
    if (_active) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
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
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || !_ctrl.hasClients || _paused) return;
      final maxExt = _ctrl.position.maxScrollExtent;
      final next = _ctrl.offset + _step;
      _ctrl.jumpTo(next >= maxExt ? 0 : next);
    });
  }

  void _pause() => _paused = true;
  void _resumeAfterDelay() => Future.delayed(_kBannerResumeDelay, () {
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
              if (n is ScrollStartNotification) _pause();
              if (n is ScrollEndNotification) _resumeAfterDelay();
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

/// Marquee optimisé : utilise AnimatedBuilder + transform (pas de Timer)
class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  static const double _itemWidth = 400; // Largeur estimée d'un item

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _anim = Tween<double>(begin: 0, end: _itemWidth).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Row(
            children: List.generate(4, (i) {
              final offset = (_anim.value + i * _itemWidth) % (_itemWidth * 2) - _itemWidth;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: SizedBox(
                  width: _itemWidth,
                  child: Center(
                    child: Text(
                      widget.text,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
