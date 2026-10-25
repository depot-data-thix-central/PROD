// lib/presentation/thix_market/pages/market_home_page.dart
// ============================================================================
// MARKET HOME PAGE — Production Enterprise v9
// ----------------------------------------------------------------------------
//  • ✅ Hero Banner style capture : multi-images produit + compteur X/10 + NEW
//  • ✅ Couleurs standard marketplace (neutres + accents)
//  • ✅ Conservation des 2 cartes promo (Offres exclusives + Produits locaux)
//  • ✅ Animations d’attraction (fade, slide, scale)
//  • ✅ 10 produits les plus récents en auto-scroll
//  • ✅ Section Produits Locaux teaser conservée
// ============================================================================

import 'dart:async';
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
import 'package:thix_id/l10n/app_localizations.dart';

import '../core/african_currencies.dart';
import '../core/currency_service.dart';
import '../core/local_sectors.dart';
import '../providers/market_providers.dart';
import '../providers/market_badges_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/products/product_card.dart';
import '../widgets/products/local_product_card.dart';
import '../widgets/market/flash_sale_timer.dart';
import '../widgets/market/currency_selector.dart';
import 'all_shops_and_supermarkets_page.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kBannerAutoPlay = Duration(seconds: 5);
const Duration _kBannerResumeDelay = Duration(seconds: 2);
const int _kMaxTitleLength = 120;
const int _kMaxDescriptionLength = 300;
const int _kMaxNameLength = 50;
const int _kMaxLiveCards = 10;
const int _kMaxFeaturedShops = 4;
const int _kMaxLocalTeaser = 6;
const int _kMaxNewestProducts = 10;
const double _kGridCardHeight = 250;

// Couleurs standard marketplace
const Color _kMarketBlue = Color(0xFF1E3A5F);
const Color _kMarketBlueDeep = Color(0xFF0F2744);
const Color _kAccentGold = Color(0xFFF59E0B);
const Color _kLocalGreen = Color(0xFF0F7A37);
const Color _kLocalGreenSoft = Color(0xFF149A4A);

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

  static String parseError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return l10n.t('error_timeout');
    if (msg.contains('network') || msg.contains('socket')) return l10n.t('error_network');
    if (msg.contains('unauthorized')) return l10n.t('error_session_expired');
    return l10n.t('error_generic');
  }
}

// ============================================================================
// PROVIDERS
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

final marketTickerProvider = StreamProvider.autoDispose<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (tick) => tick);
});

/// 10 produits les plus récents (Hero Banner)
final newestProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('*, shop:shops!inner(id, name, logo_url, city, type)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(_kMaxNewestProducts)
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    debugPrint('[Market] ⚠️ Newest products error: $e');
    return const <Map<String, dynamic>>[];
  }
});

final localTeaserProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('*, shop:shops!inner(id, name, logo_url, city, type)')
        .eq('status', 'active')
        .eq('is_local', true)
        .order('created_at', ascending: false)
        .limit(_kMaxLocalTeaser)
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    debugPrint('[Market] ⚠️ Local teaser error: $e');
    return const <Map<String, dynamic>>[];
  }
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MarketHomePage extends ConsumerStatefulWidget {
  const MarketHomePage({super.key});
  @override
  ConsumerState<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends ConsumerState<MarketHomePage>
    with RouteAware, TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final PageController _bannerCtrl = PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  bool _bannerReady = false;
  int _currentBanner = 0;
  ModalRoute? _currentRoute;

  // Animations d’entrée
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    debugPrint('[Market] 🏠 Home opened');
    _refreshCurrencyRates();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceCtrl.forward();
    });
  }

  Future<void> _refreshCurrencyRates() async {
    try {
      await CurrencyService.instance.refreshRates();
      debugPrint('[Market] 💱 Currency rates refreshed');
    } catch (e) {
      debugPrint('[Market] ⚠️ Currency refresh failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _currentRoute = route;
  }

  @override
  void didPopNext() {
    debugPrint('[Market] 🔙 Returned from pushed route — silent refresh');
    invalidateAllMarketProviders(ref);
    ref.read(forYouProvider.notifier).refresh();
    ref.read(marketBadgesProvider.notifier).refresh();
    ref.invalidate(localTeaserProvider);
    ref.invalidate(newestProductsProvider);
    _refreshCurrencyRates();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 700) {
      ref.read(forYouProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    _entranceCtrl.dispose();
    debugPrint('[Market] 🏠 Home disposed');
    super.dispose();
  }

  String _t(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  void _safeNavigate(String name, String path) {
    HapticFeedback.selectionClick();
    try {
      context.pushNamed(name);
    } catch (_) {
      try {
        context.push(path);
      } catch (e) {
        debugPrint('[Market] ❌ Nav failed: $e');
      }
    }
  }

  Future<void> _go(MarketBadge kind, Future<dynamic> Function() nav) async {
    HapticFeedback.lightImpact();
    final badges = ref.read(marketBadgesProvider.notifier);
    badges.markSeen(kind);
    try {
      await nav();
    } catch (e) {
      debugPrint('[Market] ❌ Nav failed ($kind): $e');
    }
    if (mounted) badges.refresh();
  }

  Future<void> _openNotifications() => _go(MarketBadge.alerts, () async {
        try {
          await context.pushNamed('marketNotifications');
        } catch (_) {
          await context.push('/market/notifications');
        }
      });

  Future<void> _openOrders() =>
      _go(MarketBadge.orders, () => context.push('/market/orders'));

  Future<void> _openWishlist() => _go(MarketBadge.wishlist, () async {
        try {
          await context.pushNamed('marketWishlist');
        } catch (_) {
          await context.push('/market/wishlist');
        }
      });

  Future<void> _openShops(bool hasShop) => _go(MarketBadge.shops, () async {
        if (hasShop) {
          try {
            await context.pushNamed('vendorDashboard');
          } catch (_) {
            await context.push('/market/vendor/dashboard');
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AllShopsAndSupermarketsPage()),
          );
        }
      });

  void _startBannerAuto(int count) {
    if (_bannerReady || count <= 1) return;
    _bannerReady = true;
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(_kBannerAutoPlay, (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;
      _currentBanner = (_currentBanner + 1) % count;
      _bannerCtrl.animateToPage(
        _currentBanner,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _extractImage(Map<String, dynamic> p, {int index = 0}) {
    if (p['images'] is List && (p['images'] as List).length > index) {
      return _MarketValidators.sanitizeUrl((p['images'] as List)[index].toString());
    }
    final url1 = p['image_url']?.toString();
    if (url1 != null && url1.isNotEmpty) return _MarketValidators.sanitizeUrl(url1);
    return null;
  }

  List<String> _extractImages(Map<String, dynamic> p) {
    final List<String> urls = [];
    if (p['images'] is List) {
      for (final img in (p['images'] as List)) {
        final u = _MarketValidators.sanitizeUrl(img.toString());
        if (u != null) urls.add(u);
      }
    }
    if (urls.isEmpty) {
      final main = _extractImage(p);
      if (main != null) urls.add(main);
    }
    if (urls.isEmpty) urls.add('');
    return urls;
  }

  String _greetingName(AppLocalizations l10n) {
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
    return _MarketValidators.sanitize(l10n.t('market_client_default'), maxLength: _kMaxNameLength);
  }

  void _showComing(String feature) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('market_coming_soon', args: [feature])),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> _stableSort(List<Map<String, dynamic>> items) {
    return stableSortProducts(items);
  }

  bool _isExpired(Map<String, dynamic> p) {
    final exp = p['expires_at'];
    if (exp == null) return false;
    final dt = DateTime.tryParse(exp.toString());
    if (dt == null) return false;
    return !dt.isAfter(DateTime.now());
  }

  String _allProductsTitle(AppLocalizations l10n) {
    final t = l10n.t('market_all_products');
    if (t.trim().isEmpty || t == 'market_all_products') {
      return _t('Tous les produits', 'All products', 'Bidhaa zote');
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final newestAsync = ref.watch(newestProductsProvider);
    final flashAsync = ref.watch(flashSalesProvider);
    final forYouAsync = ref.watch(forYouProvider);
    final liveSessionsAsync = ref.watch(activeMarketLiveSessionsProvider);
    final fallbackProducts = ref.watch(allMarketProductsProvider);
    final badges = ref.watch(marketBadgesProvider);
    final localAsync = ref.watch(localTeaserProvider);
    ref.watch(currencyProvider);
    ref.watch(exchangeRatesProvider);

    final hasMore = ref.read(forYouProvider.notifier).hasMore;
    ref.watch(marketTickerProvider);

    newestAsync.whenData((b) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerAuto(b.length));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            children: [
              RefreshIndicator(
                color: ThixPolicy.primary,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  HapticFeedback.mediumImpact();
                  invalidateAllMarketProviders(ref);
                  ref.read(marketBadgesProvider.notifier).refresh();
                  ref.invalidate(localTeaserProvider);
                  ref.invalidate(newestProductsProvider);
                  await ref.read(forYouProvider.notifier).refresh();
                  await _refreshCurrencyRates();
                },
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopSection(l10n, badges)),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // Greeting + NEW badge
                    SliverToBoxAdapter(child: _buildGreetingRow(l10n)),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // HERO style capture
                    SliverToBoxAdapter(child: _buildHero(newestAsync, l10n)),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, l10n)),
                    SliverToBoxAdapter(child: _buildSupermarketSection(l10n)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // LES DEUX CARTES PROMO (conservées)
                    SliverToBoxAdapter(child: _buildPromoBannersRow(l10n)),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    SliverToBoxAdapter(child: _buildB2BTools(l10n, badges)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // Teaser Produits Locaux
                    SliverToBoxAdapter(child: _buildLocalTeaser(localAsync, l10n)),
                    SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, l10n)),
                    SliverToBoxAdapter(child: _buildSectionHeader(_allProductsTitle(l10n))),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    _buildGrid(forYouAsync, fallbackProducts, hasMore, l10n),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNavBar(l10n, badges)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP SECTION
  // ---------------------------------------------------------------------------
  Widget _buildTopSection(AppLocalizations l10n, MarketBadges badges) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTopBar(l10n, badges),
          _buildSearchBar(l10n),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, MarketBadges badges) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 8),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kLocalGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THIX.',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: Color(0xFF111111),
                  ),
                ),
                Text(
                  _MarketValidators.sanitize(l10n.t('market_app_tagline'), maxLength: 40),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const CurrencySelector(),
          const SizedBox(width: 8),
          // Notifications
          Semantics(
            button: true,
            label: badges.alerts > 0
                ? '${l10n.t('common_notifications')}, ${badges.alerts}'
                : l10n.t('common_notifications'),
            child: InkWell(
              onTap: _openNotifications,
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      badges.alerts > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      size: 20,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Positioned(top: -3, right: -3, child: _CountBadge(count: badges.alerts)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Profile
          Semantics(
            button: true,
            label: l10n.t('common_profile'),
            child: InkWell(
              onTap: () => _safeNavigate('userDashboard', '/user/dashboard'),
              borderRadius: BorderRadius.circular(99),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _kLocalGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('market_search_hint'),
              child: GestureDetector(
                onTap: () => _safeNavigate('marketSearch', '/market/search'),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _MarketValidators.sanitize(l10n.t('market_search_hint'), maxLength: 80),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: l10n.t('market_filters'),
            child: InkWell(
              onTap: () => _safeNavigate('marketSearch', '/market/search'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _t('Filtres', 'Filters', 'Vichujio'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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

  // ---------------------------------------------------------------------------
  // GREETING ROW
  // ---------------------------------------------------------------------------
  Widget _buildGreetingRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Bonjour', 'Hello', 'Habari'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _greetingName(l10n),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kLocalGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kLocalGreen.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _kLocalGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'NEW · $_kMaxNewestProducts',
                  style: const TextStyle(
                    color: _kLocalGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO BANNER — Style capture (multi-images + compteur + NEW)
  // ---------------------------------------------------------------------------
  Widget _buildHero(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const _HeroSkeleton(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e, l10n),
        onRetry: () => ref.invalidate(newestProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _buildHeroContent(products, l10n);
      },
    );
  }

  Widget _buildHeroContent(List<Map<String, dynamic>> products, AppLocalizations l10n) {
    return Column(
      children: [
        SizedBox(
          height: 340,
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
                final images = _extractImages(p);
                final title = _MarketValidators.sanitize(p['title']?.toString(), maxLength: _kMaxTitleLength);
                final subtitle = _MarketValidators.sanitize(p['description']?.toString(), maxLength: 80);
                final id = p['id']?.toString() ?? '';
                final price = p['price'];
                final currency = p['currency']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Semantics(
                    button: true,
                    label: title.isEmpty ? l10n.t('market_featured_offer') : title,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) context.push('/market/product/$id');
                      },
                      child: _HeroProductCard(
                        images: images,
                        title: title,
                        subtitle: subtitle,
                        price: price,
                        currency: currency,
                        index: index,
                        total: products.length,
                        l10n: l10n,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Indicateurs
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(products.length.clamp(0, 10), (i) {
            final active = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: active ? 20 : 6,
              decoration: BoxDecoration(
                color: active ? _kLocalGreen : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LIVE
  // ---------------------------------------------------------------------------
  Widget _buildLiveSection(AsyncValue<List<Map<String, dynamic>>> liveAsync, AppLocalizations l10n) {
    return liveAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _MarketErrorCard(
          message: _MarketValidators.parseError(e, l10n),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const _PulsingDot(),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('market_live_ongoing'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Color(0xFF111111),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${sessions.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ThixPolicy.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _buildLiveCard(sessions[i], l10n),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> s, AppLocalizations l10n) {
    final hostAvatar = _MarketValidators.sanitizeUrl(s['host_avatar']?.toString());
    final shopName = _MarketValidators.sanitize(
      s['channel_name']?.toString() ?? s['host_name']?.toString() ?? l10n.t('market_client_default'),
      maxLength: _kMaxNameLength,
    );

    return Semantics(
      button: true,
      label: l10n.t('market_shop_semantics', args: [shopName]),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LiveViewerScreen(session: liveSession)),
            );
          } catch (e) {
            debugPrint('[Market] ❌ Live nav error: $e');
          }
        },
        child: Container(
          width: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.danger.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.danger.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.storefront, color: Colors.grey, size: 36),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.storefront, color: Colors.grey, size: 36),
                        ),
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
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _MarketValidators.sanitize(l10n.t('market_live_badge'), maxLength: 10).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUPERMARKETS
  // ---------------------------------------------------------------------------
  Widget _buildSupermarketSection(AppLocalizations l10n) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _MarketValidators.sanitize(l10n.t('market_home_supermarkets'), maxLength: 50),
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AllShopsAndSupermarketsPage()),
              );
            },
            l10n: l10n,
          ),
          const SizedBox(height: 14),
          shopsAsync.when(
            loading: () => const _ShopsSkeleton(),
            error: (e, _) => _MarketErrorCard(
              message: _MarketValidators.parseError(e, l10n),
              onRetry: () => ref.invalidate(featuredShopsProvider),
              compact: true,
            ),
            data: (shops) {
              if (shops.isEmpty) {
                return Text(
                  _MarketValidators.sanitize(l10n.t('market_no_supermarket'), maxLength: 100),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                    label: l10n.t('market_shop_semantics', args: [name]),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) context.push('/market/shop/$id');
                      },
                      child: Column(
                        children: [
                          Container(
                            height: 62,
                            width: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              image: logoUrl != null
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(logoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: logoUrl == null
                                ? Icon(Icons.storefront_rounded, color: Colors.grey.shade400, size: 26)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 68,
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
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

  // ---------------------------------------------------------------------------
  // LES DEUX CARTES PROMO (Offres exclusives + Produits locaux) — CONSERVÉES
  // ---------------------------------------------------------------------------
  Widget _buildPromoBannersRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Carte Offres exclusives (bleue)
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('market_exclusive_offers_tag'),
              child: GestureDetector(
                onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
                child: Container(
                  height: 150,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E3A5F),
                        Color(0xFF0F2744),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kAccentGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _MarketValidators.sanitize(l10n.t('market_exclusive_offers_tag'), maxLength: 30),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _MarketValidators.sanitize(l10n.t('market_up_to_50'), maxLength: 50),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _MarketValidators.sanitize(l10n.t('market_premium_selection'), maxLength: 60),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            _MarketValidators.sanitize(l10n.t('market_discover'), maxLength: 20),
                            style: const TextStyle(
                              color: _kAccentGold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: _kAccentGold),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Carte Produits locaux (verte)
          Expanded(
            child: _LocalPromoCard(
              onTap: () => _safeNavigate('marketLocalHome', '/market/local'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // B2B TOOLS
  // ---------------------------------------------------------------------------
  Widget _buildB2BTools(AppLocalizations l10n, MarketBadges badges) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _b2bItem(
              Icons.compare_arrows_rounded,
              _MarketValidators.sanitize(l10n.t('market_compare'), maxLength: 20),
              () => _safeNavigate('marketProductComparator', '/market/compare'),
            ),
            _b2bItem(
              Icons.notifications_active_rounded,
              _MarketValidators.sanitize(l10n.t('market_price_alert'), maxLength: 20),
              () => _safeNavigate('marketPriceAlerts', '/market/price-alerts'),
            ),
            _b2bItem(
              Icons.request_quote_rounded,
              _MarketValidators.sanitize(l10n.t('market_b2b_quote'), maxLength: 20),
              () => _showComing(l10n.t('market_b2b_quote')),
            ),
            _b2bItem(
              Icons.favorite_rounded,
              _MarketValidators.sanitize(l10n.t('market_wishlist'), maxLength: 20),
              _openWishlist,
              badge: badges.wishlist,
            ),
          ],
        ),
      ),
    );
  }

  Widget _b2bItem(IconData icon, String label, VoidCallback onTap, {int badge = 0}) {
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: const Color(0xFF1A1A2E), size: 20),
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: _CountBadge(count: badge),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEASER PRODUITS LOCAUX
  // ---------------------------------------------------------------------------
  Widget _buildLocalTeaser(
    AsyncValue<List<Map<String, dynamic>>> async,
    AppLocalizations l10n,
  ) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kLocalGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kLocalGreen.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulsingLocalBadge(),
                        const SizedBox(width: 6),
                        Text(
                          _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: Color(0xFF111111),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: _t('Voir tout', 'Show all', 'Ona zote'),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _safeNavigate('marketLocalHome', '/market/local');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kLocalGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _t('Voir tout', 'Show all', 'Ona zote'),
                              style: const TextStyle(
                                color: _kLocalGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kLocalGreen),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 275,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = products[i];
                  return SizedBox(
                    width: 180,
                    child: LocalProductCard(product: p, width: 180, height: 275),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FLASH SALE
  // ---------------------------------------------------------------------------
  Widget _buildFlashSaleSection(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e, l10n),
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FlashSaleTimer(endTime: timerEnd!),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: _MarqueeText(
                          text: _MarketValidators.sanitize(l10n.t('market_flash_sale_banner'), maxLength: 100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _AutoScrollProductStrip(
              products: active,
              badgeType: _StripBadge.flash,
              title: _MarketValidators.sanitize(l10n.t('market_flash_offers'), maxLength: 50),
              icon: Icons.bolt_rounded,
              liveLabel: _MarketValidators.sanitize(l10n.t('market_live_badge'), maxLength: 10),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll, AppLocalizations? l10n}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF111111),
              letterSpacing: -0.4,
            ),
          ),
          if (onSeeAll != null && l10n != null)
            Semantics(
              button: true,
              label: l10n.t('common_see_all'),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSeeAll();
                },
                child: Text(
                  l10n.t('common_see_all'),
                  style: TextStyle(
                    color: ThixPolicy.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRID
  // ---------------------------------------------------------------------------
  Widget _buildGrid(
    AsyncValue<List<Map<String, dynamic>>> forYouAsync,
    List<Map<String, dynamic>> fallback,
    bool hasMore,
    AppLocalizations l10n,
  ) {
    return forYouAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () {
        if (fallback.isNotEmpty) return _productGridSliver(fallback, false);
        return const SliverToBoxAdapter(child: _GridSkeleton());
      },
      error: (e, _) {
        if (fallback.isNotEmpty) return _productGridSliver(fallback, false);
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _MarketErrorCard(
              message: _MarketValidators.parseError(e, l10n),
              onRetry: () => ref.read(forYouProvider.notifier).refresh(),
            ),
          ),
        );
      },
      data: (items) {
        final source = items.isNotEmpty ? items : fallback;

        if (source.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('market_no_products'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('Tirez vers le bas pour actualiser', 'Pull down to refresh', 'Vuta chini ili kuburudisha'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(forYouProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.t('common_retry')),
                    style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
                  ),
                ],
              ),
            ),
          );
        }

        return _productGridSliver(source, hasMore);
      },
    );
  }

  Widget _productGridSliver(List<Map<String, dynamic>> source, bool hasMore) {
    final sorted = _stableSort(source);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: _kGridCardHeight,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            if (i >= sorted.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = sorted[i];
            return LayoutBuilder(
              builder: (context, box) {
                return SizedBox(
                  width: box.maxWidth,
                  height: _kGridCardHeight,
                  child: ProductCard(
                    key: ValueKey('grid_${p['id']}'),
                    product: p,
                    variant: ProductCardVariant.horizontal,
                    width: box.maxWidth,
                  ),
                );
              },
            );
          },
          childCount: sorted.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAV
  // ---------------------------------------------------------------------------
  Widget _buildBottomNavBar(AppLocalizations l10n, MarketBadges badges) {
    const barH = 56.0;
    const fabSize = 58.0;
    const lift = 20.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: barH + lift,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: barH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _navItem(
                            icon: Icons.home_rounded,
                            label: _MarketValidators.sanitize(l10n.t('common_home'), maxLength: 20),
                            selected: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (_scroll.hasClients) {
                                _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                              }
                            },
                          ),
                          _navItem(
                            icon: Icons.receipt_long_rounded,
                            label: _MarketValidators.sanitize(l10n.t('market_orders'), maxLength: 20),
                            badge: badges.orders,
                            onTap: _openOrders,
                          ),
                          const SizedBox(width: fabSize + 4),
                          _navItem(
                            icon: Icons.favorite_rounded,
                            label: _MarketValidators.sanitize(l10n.t('market_wishlist'), maxLength: 20),
                            badge: badges.wishlist,
                            onTap: _openWishlist,
                          ),
                          _navItem(
                            icon: Icons.storefront_rounded,
                            label: _t('Boutiques', 'Shops', 'Maduka'),
                            badge: badges.shops,
                            onTap: () => _openShops(badges.hasShop),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Semantics(
                  button: true,
                  label: l10n.t('market_cart_semantics'),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push('/market/cart');
                    },
                    child: Container(
                      width: fabSize,
                      height: fabSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kLocalGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _kLocalGreen.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    int badge = 0,
  }) {
    final color = selected ? _kLocalGreen : Colors.grey.shade500;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 22),
                    Positioned(
                      top: -5,
                      right: -10,
                      child: _CountBadge(count: badge),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HERO PRODUCT CARD (style capture)
// ============================================================================
class _HeroProductCard extends StatelessWidget {
  final List<String> images;
  final String title;
  final String subtitle;
  final dynamic price;
  final String currency;
  final int index;
  final int total;
  final AppLocalizations l10n;

  const _HeroProductCard({
    required this.images,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.currency,
    required this.index,
    required this.total,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    // On affiche jusqu’à 3 images côte à côte (front / side / back)
    final displayImages = images.take(3).toList();
    while (displayImages.length < 3 && displayImages.isNotEmpty) {
      displayImages.add(displayImages.last);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Multi-images côte à côte
            Row(
              children: List.generate(displayImages.length, (i) {
                final url = displayImages[i];
                return Expanded(
                  child: url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        )
                      : Container(color: Colors.grey.shade200),
                );
              }),
            ),

            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Compteur 02 / 10
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ),

            // Badge NEW
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kLocalGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenu bas
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (price != null)
                    Text(
                      '$price',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    title.isEmpty ? '—' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 14),
                  // Bouton Découvrir
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF111111)),
                        const SizedBox(width: 8),
                        Text(
                          _MarketValidators.sanitize(l10n.t('market_view_offer'), maxLength: 20).isEmpty
                              ? 'Découvrir'
                              : _MarketValidators.sanitize(l10n.t('market_view_offer'), maxLength: 20),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF111111)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE PRODUITS LOCAUX (conservée)
// ============================================================================
class _LocalPromoCard extends StatefulWidget {
  final VoidCallback onTap;
  const _LocalPromoCard({required this.onTap});

  @override
  State<_LocalPromoCard> createState() => _LocalPromoCardState();
}

class _LocalPromoCardState extends State<_LocalPromoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _arrowSlide = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = lang == 'sw'
        ? 'BIDHAA ZA NDANI'
        : lang == 'en'
            ? 'LOCAL GOODS'
            : 'PRODUITS LOCAUX';
    final subtitle = lang == 'sw'
        ? 'Moja kwa moja kutoka kwa wakulima'
        : lang == 'en'
            ? 'Direct from local producers'
            : 'Direct producteurs locaux';
    final ctaLabel = lang == 'sw' ? 'Gundua' : lang == 'en' ? 'Discover' : 'Découvrir';

    return Semantics(
      button: true,
      label: 'Produits locaux',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) {
            return Container(
              height: 150,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F7A37),
                    Color(0xFF149A4A),
                    Color(0xFF0B6B31),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF149A4A).withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Pattern dots
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotsPatternPainter(
                        color: Colors.white.withOpacity(0.06),
                        spacing: 14,
                        dotSize: 1.2,
                      ),
                    ),
                  ),
                  // Shimmer
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (rect) {
                          final position = _shimmerCtrl.value;
                          return LinearGradient(
                            begin: Alignment(-2 + position * 4, -0.5),
                            end: Alignment(2 + position * 4, 0.5),
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.0),
                            ],
                          ).createShader(rect);
                        },
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                  // Emoji
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('🌱', style: TextStyle(fontSize: 22))),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                        ),
                        child: const Text(
                          '100% LOCAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // CTA
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedBuilder(
                          animation: _arrowSlide,
                          builder: (_, child) {
                            return Transform.translate(
                              offset: Offset(_arrowSlide.value, 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctaLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF0B6B31),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF0B6B31)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================
class _DotsPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double dotSize;

  _DotsPatternPainter({required this.color, required this.spacing, required this.dotSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ThixPolicy.danger,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1.1),
      ),
    );
  }
}

class _MarketErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool compact;

  const _MarketErrorCard({required this.message, required this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
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
              label: Text(l10n.t('common_retry')),
              style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
            ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _ShopsSkeleton extends StatelessWidget {
  const _ShopsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        4,
        (_) => Column(
          children: [
            Container(width: 62, height: 62, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
            const SizedBox(height: 8),
            Container(width: 56, height: 11, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: _kGridCardHeight,
        ),
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

class _PulsingLocalBadge extends StatefulWidget {
  const _PulsingLocalBadge();
  @override
  State<_PulsingLocalBadge> createState() => _PulsingLocalBadgeState();
}

class _PulsingLocalBadgeState extends State<_PulsingLocalBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _kLocalGreen.withOpacity(0.15 + _ctrl.value * 0.15),
                shape: BoxShape.circle,
              ),
            ),
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _kLocalGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _kLocalGreen.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            ),
          ],
        );
      },
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
    final wasActive = old.products.length > 4;
    final isActiveNow = widget.products.length > 4;
    if (!wasActive && isActiveNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    } else if (wasActive && !isActiveNow) {
      _timer?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || !_ctrl.hasClients || _paused) return;
      final position = _ctrl.position;
      final maxExt = position.maxScrollExtent;
      if (maxExt <= 0) return;
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(widget.icon, color: isFlash ? ThixPolicy.danger : const Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Color(0xFF111111),
                  letterSpacing: -0.4,
                ),
              ),
              if (_active && widget.liveLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.liveLabel!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ThixPolicy.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _itemWidth = 300;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth.isFinite ? box.maxWidth : 300.0;
          final count = (w / _itemWidth).ceil() + 2;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final shift = _ctrl.value * _itemWidth;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: List.generate(count, (i) {
                  return Positioned(
                    left: i * _itemWidth - shift,
                    top: 0,
                    bottom: 0,
                    width: _itemWidth,
                    child: Center(
                      child: Text(
                        widget.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}
