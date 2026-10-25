// lib/presentation/thix_market/pages/market_home_page.dart
// ============================================================================
// MARKET HOME PAGE — Production Enterprise v8 "Ultra Modern" (FIXED)
// ----------------------------------------------------------------------------
//  • ✅ Design ultra-moderne, clean, magazine-like
//  • ✅ Hero Banner immersif (10 produits) auto-scroll avec Ken Burns effect
//  • ✅ Palette verte premium, typographie bold et aérée
//  • ✅ Glassmorphism subtil, ombres profondes, animations fluides
//  • ✅ Section "Trust Badges" supprimée
//  • ✅ Bouton "Vendre Local" supprimé
//  • ✅ Support FR / EN / SW automatique via Localizations
//  • ✅ Pastilles de notifications : cloche + Commandes / Favoris / Boutiques
//  • ✅ Remise à zéro à l'ouverture de la section
//  • ✅ Bouton panier central entier (n'est plus coupé)
//  • ✅ Espace PRODUITS LOCAUX (design professionnel moderne)
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
const int _kMaxHeroItems = 10;
const double _kGridCardHeight = 250;

// Palette verte ultra-moderne
const Color _kGreenPrimary = Color(0xFF0A8F5A);
const Color _kGreenDeep = Color(0xFF055F3C);
const Color _kGreenAccent = Color(0xFF10B981);
const Color _kGreenMist = Color(0xFFE8F7F0);
const Color _kInkPrimary = Color(0xFF0F172A);
const Color _kInkSecondary = Color(0xFF475569);
const Color _kInkMuted = Color(0xFF94A3B8);
const Color _kSurfaceBase = Color(0xFFF8FAFB);
const Color _kSurfaceElevated = Color(0xFFFFFFFF);

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

// Nouveau provider pour les 10 derniers produits (nouveautés)
final newArrivalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('*, shop:shops(id, name, logo_url)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(_kMaxHeroItems)
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    debugPrint('[Market] ⚠️ New arrivals error: $e');
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

class _MarketHomePageState extends ConsumerState<MarketHomePage> with RouteAware {
  final ScrollController _scroll = ScrollController();
  Timer? _bannerTimer;
  bool _bannerReady = false;
  int _currentBanner = 0;
  ModalRoute? _currentRoute;
  final PageController _heroCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    debugPrint('[Market] 🏠 Home opened');
    _refreshCurrencyRates();
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
    if (route != null) {
      _currentRoute = route;
    }
  }

  @override
  void didPopNext() {
    debugPrint('[Market] 🔙 Returned from pushed route — silent refresh');
    invalidateAllMarketProviders(ref);
    ref.read(forYouProvider.notifier).refresh();
    ref.read(marketBadgesProvider.notifier).refresh();
    ref.invalidate(localTeaserProvider);
    ref.invalidate(newArrivalsProvider);
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
    _heroCtrl.dispose();
    _bannerTimer?.cancel();
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

  void _startHeroAuto(int count) {
    if (_bannerReady || count <= 1) return;
    _bannerReady = true;
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(_kBannerAutoPlay, (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _currentBanner = (_currentBanner + 1) % count;
      _heroCtrl.animateToPage(
        _currentBanner,
        duration: const Duration(milliseconds: 900),
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
        backgroundColor: _kGreenDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildBlurOrb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final newArrivalsAsync = ref.watch(newArrivalsProvider);
    final featuredAsync = ref.watch(featuredProductsProvider);
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

    newArrivalsAsync.whenData((b) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startHeroAuto(b.length));
    });

    return Scaffold(
      backgroundColor: _kSurfaceBase,
      extendBody: true,
      body: Stack(
        children: [
          // Ambient glow subtil
          Positioned(top: -150, right: -100, child: _buildBlurOrb(_kGreenAccent.withOpacity(0.12), 320)),
          Positioned(top: 250, left: -150, child: _buildBlurOrb(_kGreenPrimary.withOpacity(0.06), 280)),

          RefreshIndicator(
            color: _kGreenPrimary,
            backgroundColor: _kSurfaceElevated,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              debugPrint('[Market] 🔄 Pull-to-refresh');
              invalidateAllMarketProviders(ref);
              ref.read(marketBadgesProvider.notifier).refresh();
              ref.invalidate(localTeaserProvider);
              ref.invalidate(newArrivalsProvider);
              await ref.read(forYouProvider.notifier).refresh();
              await _refreshCurrencyRates();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildTopSection(l10n, badges)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // ⭐ Hero Banner immersif avec les 10 derniers produits
                SliverToBoxAdapter(child: _buildImmersiveHero(newArrivalsAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // ⭐ Featured Strip (sélection éditoriale)
                SliverToBoxAdapter(child: _buildEditorialStrip(featuredAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                SliverToBoxAdapter(child: _buildSupermarketSection(l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(child: _buildLocalTeaser(localAsync, l10n)),
                SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, l10n)),
                SliverToBoxAdapter(child: _buildSectionHeader(_allProductsTitle(l10n), subtitle: _t('Découvrez notre sélection complète', 'Discover our full selection', 'Gundua uteuzi wetu kamili'))),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                _buildGrid(forYouAsync, fallbackProducts, hasMore, l10n),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNavBar(l10n, badges)),
        ],
      ),
    );
  }

  // ============================================================================
  // TOP BAR — Clean et premium
  // ============================================================================
  Widget _buildTopSection(AppLocalizations l10n, MarketBadges badges) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Column(
            children: [
              _buildTopBar(l10n, badges),
              _buildSearchBar(l10n),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, MarketBadges badges) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo et branding
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kGreenPrimary, _kGreenDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kGreenPrimary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'THIX', style: TextStyle(color: _kInkPrimary, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.8)),
                        TextSpan(text: '.', style: TextStyle(color: _kGreenPrimary, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
                      ],
                    ),
                  ),
                  Text(
                    _t('Marketplace panafricaine', 'Pan-African marketplace', 'Soko la Kiafrika'),
                    style: const TextStyle(color: _kInkMuted, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              const CurrencySelector(),
              const SizedBox(width: 8),
              _IconButton(
                icon: badges.alerts > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                badge: badges.alerts,
                onTap: _openNotifications,
                semanticsLabel: badges.alerts > 0
                    ? '${l10n.t('common_notifications')}, ${badges.alerts}'
                    : l10n.t('common_notifications'),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: l10n.t('common_profile'),
                child: GestureDetector(
                  onTap: () => _safeNavigate('userDashboard', '/user/dashboard'),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kGreenPrimary, _kGreenAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreenPrimary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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

  Widget _IconButton({required IconData icon, required VoidCallback onTap, int badge = 0, required String semanticsLabel}) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(icon, size: 19, color: _kInkPrimary),
            ),
            if (badge > 0)
              Positioned(
                top: -3,
                right: -3,
                child: _CountBadge(count: badge),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('market_search_hint'),
              child: GestureDetector(
                onTap: () => _safeNavigate('marketSearch', '/market/search'),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _kGreenMist,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.search_rounded, size: 17, color: _kGreenPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _MarketValidators.sanitize(l10n.t('market_search_hint'), maxLength: 80),
                          style: const TextStyle(fontSize: 14, color: _kInkMuted, fontWeight: FontWeight.w500, letterSpacing: 0.1),
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
            child: GestureDetector(
              onTap: () => _safeNavigate('marketSearch', '/market/search'),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _kInkPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _kInkPrimary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Filtres',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
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

  // ============================================================================
  // ⭐ HERO BANNER IMMERSIF — 10 derniers produits auto-scroll
  // ============================================================================
  Widget _buildImmersiveHero(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const _ImmersiveHeroSkeleton(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e, l10n),
        onRetry: () => ref.invalidate(newArrivalsProvider),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _ImmersiveHeroCarousel(
          products: products,
          controller: _heroCtrl,
          currentIndex: _currentBanner,
          onPageChanged: (i) {
            if (mounted) setState(() => _currentBanner = i);
          },
          onInteractionStart: () {
            _bannerTimer?.cancel();
            _bannerReady = false;
          },
          onInteractionEnd: () {
            Future.delayed(_kBannerResumeDelay, () {
              if (mounted) _startHeroAuto(products.length);
            });
          },
          greetingName: _greetingName(l10n),
          l10n: l10n,
        );
      },
    );
  }

  // ============================================================================
  // EDITORIAL STRIP — Sélection éditoriale
  // ============================================================================
  Widget _buildEditorialStrip(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _AutoScrollProductStrip(
          products: products,
          badgeType: _StripBadge.featured,
          title: _t('Sélection éditoriale', 'Editorial selection', 'Uteuzi wa mhariri'),
          icon: Icons.auto_awesome_rounded,
          subtitle: _t('Choisis pour vous', 'Handpicked for you', 'Imechaguliwa kwako'),
        );
      },
    );
  }

  Widget _buildLiveSection(AsyncValue<List<Map<String, dynamic>>> liveAsync, AppLocalizations l10n) {
    return liveAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeaderRow(
                title: _t('En direct maintenant', 'Live now', 'Moja kwa moja sasa'),
                subtitle: '${sessions.length} ${_t('vendeurs en live', 'vendors live', 'wauzaji wanaoendesha moja kwa moja')}',
                leading: const _LivePulseIndicator(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _buildLiveCard(sessions[i], l10n),
              ),
            ),
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
    final title = _MarketValidators.sanitize(s['title']?.toString(), maxLength: _kMaxTitleLength);

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
              title: title,
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
          width: 118,
          decoration: BoxDecoration(
            color: _kSurfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: hostAvatar != null
                    ? CachedNetworkImage(
                        imageUrl: hostAvatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: _kGreenMist, child: const Icon(Icons.storefront, color: _kGreenPrimary, size: 40)),
                      )
                    : Container(
                        color: _kGreenMist,
                        child: const Icon(Icons.storefront, color: _kGreenPrimary, size: 40),
                      ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // Badge LIVE
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.4), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LiveDot(),
                      const SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                    ],
                  ),
                ),
              ),
              // Info
              Positioned(
                left: 10, right: 10, bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? shopName : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupermarketSection(AppLocalizations l10n) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: _t('Supermarchés à la une', 'Featured supermarkets', 'Maduka makubwa maarufu'),
            subtitle: _t('Les enseignes de confiance', 'Trusted brands', 'Chapa za kuaminika'),
            trailing: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AllShopsAndSupermarketsPage()),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t('Voir tout', 'Show all', 'Ona zote'),
                    style: const TextStyle(color: _kGreenPrimary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.1),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: _kGreenPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  style: const TextStyle(color: _kInkMuted, fontSize: 12),
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
                            height: 72, width: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kSurfaceElevated,
                              border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                              image: logoUrl != null
                                  ? DecorationImage(image: CachedNetworkImageProvider(logoUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: logoUrl == null ? const Icon(Icons.storefront_rounded, color: _kInkMuted, size: 28) : null,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 76,
                            child: Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kInkPrimary, letterSpacing: -0.2)),
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

  Widget _buildB2BTools(AppLocalizations l10n, MarketBadges badges) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Outils Pro',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kInkPrimary, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              _t('Pour les acheteurs professionnels', 'For professional buyers', 'Kwa wanunuzi wa kitaalamu'),
              style: const TextStyle(fontSize: 11, color: _kInkMuted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _b2bItem(Icons.compare_arrows_rounded, _t('Comparer', 'Compare', 'Linganisha'), () => _safeNavigate('marketProductComparator', '/market/compare')),
                _b2bItem(Icons.notifications_active_rounded, _t('Alertes', 'Alerts', 'Arifa'), () => _safeNavigate('marketPriceAlerts', '/market/price-alerts')),
                _b2bItem(Icons.request_quote_rounded, _t('Devis', 'Quote', 'Nukuu'), () => _showComing(_t('Devis', 'Quote', 'Nukuu'))),
                _b2bItem(Icons.favorite_rounded, _t('Favoris', 'Wishlist', 'Orodha'), _openWishlist, badge: badges.wishlist),
              ],
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
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreenMist,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: _kGreenPrimary, size: 20),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: _CountBadge(count: badge),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kInkPrimary, letterSpacing: 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TEASER PRODUITS LOCAUX
  // ============================================================================
  Widget _buildLocalTeaser(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeaderRow(
                title: _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
                subtitle: _t('Soutenez les producteurs africains', 'Support African producers', 'Saidia wazalishaji wa Kiafrika'),
                leading: _GreenPulseDot(),
                trailing: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _safeNavigate('marketLocalHome', '/market/local');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kGreenMist,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('Explorer', 'Explore', 'Chunguza'),
                          style: const TextStyle(color: _kGreenDeep, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _kGreenDeep),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = products[i];
                  return SizedBox(
                    width: 185,
                    child: LocalProductCard(product: p, width: 185, height: 280),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

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
                margin: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: FlashSaleTimer(endTime: timerEnd!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _MarketValidators.sanitize(l10n.t('market_flash_sale_banner'), maxLength: 80),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.1),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            _AutoScrollProductStrip(
              products: active,
              badgeType: _StripBadge.flash,
              title: _t('Ventes flash', 'Flash sales', 'Mauzo ya haraka'),
              subtitle: _t('Offres limitées dans le temps', 'Limited-time offers', 'Ofa za muda mfupi'),
              icon: Icons.bolt_rounded,
              liveLabel: 'LIVE',
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: _kInkPrimary, letterSpacing: -0.6)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _kInkMuted, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: _kGreenMist, shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2_outlined, size: 36, color: _kGreenPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('market_no_products'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kInkPrimary, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('Tirez vers le bas pour actualiser', 'Pull down to refresh', 'Vuta chini ili kuburudisha'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: _kInkMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(forYouProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.t('common_retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreenPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              return const Center(child: CircularProgressIndicator(color: _kGreenPrimary));
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

  // ============================================================================
  // BOTTOM NAV — Clean et minimal
  // ============================================================================
  Widget _buildBottomNavBar(AppLocalizations l10n, MarketBadges badges) {
    const barH = 60.0;
    const fabSize = 58.0;
    const lift = 18.0;

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
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _navItem(
                            icon: Icons.home_rounded,
                            label: _t('Accueil', 'Home', 'Nyumbani'),
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
                            label: _t('Commandes', 'Orders', 'Maagizo'),
                            badge: badges.orders,
                            onTap: _openOrders,
                          ),
                          const SizedBox(width: fabSize + 4),
                          _navItem(
                            icon: Icons.favorite_rounded,
                            label: _t('Favoris', 'Wishlist', 'Orodha'),
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
                        gradient: const LinearGradient(
                          colors: [_kGreenPrimary, _kGreenDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: _kSurfaceBase, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: _kGreenPrimary.withOpacity(0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    int badge = 0,
  }) {
    final color = selected ? _kGreenPrimary : _kInkMuted;
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
                    if (badge > 0)
                      Positioned(
                        top: -5,
                        right: -10,
                        child: _CountBadge(count: badge),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, letterSpacing: 0.1),
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
// ⭐ IMMERSIVE HERO CAROUSEL — Design magazine premium (FIXED)
// ============================================================================
class _ImmersiveHeroCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final String greetingName;
  final AppLocalizations l10n;

  const _ImmersiveHeroCarousel({
    required this.products,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.greetingName,
    required this.l10n,
  });

  @override
  State<_ImmersiveHeroCarousel> createState() => _ImmersiveHeroCarouselState();
}

class _ImmersiveHeroCarouselState extends State<_ImmersiveHeroCarousel> {
  @override
  Widget build(BuildContext context) {
    // ✅ FIX: capturer la langue ici pour la passer à _ImmersiveHeroCard
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.l10n.t('market_greeting'),
                        style: const TextStyle(color: _kInkMuted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.greetingName,
                        style: const TextStyle(color: _kInkPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kGreenMist,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGreenPrimary.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: _kGreenPrimary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NEW · ${widget.products.length}',
                          style: const TextStyle(color: _kGreenDeep, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        SizedBox(
          height: 420,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) widget.onInteractionStart();
              if (n is ScrollEndNotification) widget.onInteractionEnd();
              return false;
            },
            child: PageView.builder(
              controller: widget.controller,
              itemCount: widget.products.length,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (_, index) {
                final p = widget.products[index];
                return _ImmersiveHeroCard(
                  product: p,
                  index: index,
                  total: widget.products.length,
                  isActive: widget.currentIndex == index,
                  l10n: widget.l10n,
                  lang: lang, // ✅ FIX: passage de la langue
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        _HeroIndicators(
          count: widget.products.length,
          currentIndex: widget.currentIndex,
        ),
      ],
    );
  }
}

class _ImmersiveHeroCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final int total;
  final bool isActive;
  final AppLocalizations l10n;
  final String lang; // ✅ FIX: ajout du paramètre lang

  const _ImmersiveHeroCard({
    required this.product,
    required this.index,
    required this.total,
    required this.isActive,
    required this.l10n,
    required this.lang, // ✅ FIX: obligatoire
  });

  // ✅ FIX: helper local de traduction pour la classe
  String _tr(String fr, String en, String sw) {
    if (lang == 'sw') return sw;
    return lang == 'fr' ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _extractImageFromProduct(product);
    final title = _MarketValidators.sanitize(product['title']?.toString(), maxLength: _kMaxTitleLength);
    final subtitle = _MarketValidators.sanitize(product['description']?.toString(), maxLength: _kMaxDescriptionLength);
    final id = product['id']?.toString() ?? '';
    final price = product['price']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        button: true,
        label: title.isEmpty ? l10n.t('market_featured_offer') : title,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (id.isNotEmpty) context.push('/market/product/$id');
          },
          child: Container(
            decoration: BoxDecoration(
              color: _kSurfaceElevated,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: _kGreenPrimary.withOpacity(0.06),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Image avec effet Ken Burns subtil
                Positioned.fill(
                  child: Hero(
                    tag: 'hero_product_$id',
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const _HeroImagePlaceholder(),
                          )
                        : const _HeroImagePlaceholder(),
                  ),
                ),
                // Overlay dégradé sophistiqué
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Numéro de l'item (style magazine)
                Positioned(
                  top: 22, left: 22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: _kInkPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        // ✅ FIX: fontFeatureSettings retiré, remplacé par fontFamily
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                // Badge NOUVEAU
                Positioned(
                  top: 22, right: 22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kGreenPrimary, _kGreenDeep],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: _kGreenPrimary.withOpacity(0.4), blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Contenu principal
                Positioned(
                  left: 24, right: 24, bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prix
                      if (price.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Text(
                            price,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              // ✅ FIX: fontFeatureSettings retiré, remplacé par fontFamily
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      // Titre
                      Text(
                        title.isEmpty ? '—' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.8,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // CTA
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_rounded, size: 16, color: _kInkPrimary),
                            const SizedBox(width: 8),
                            Text(
                              // ✅ FIX: utilisation du helper local _tr()
                              _tr('Découvrir', 'Discover', 'Gundua'),
                              style: const TextStyle(
                                color: _kInkPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 15, color: _kInkPrimary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _extractImageFromProduct(Map<String, dynamic> p) {
    final url1 = p['image_url']?.toString();
    if (url1 != null && url1.isNotEmpty) return _MarketValidators.sanitizeUrl(url1);
    if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      return _MarketValidators.sanitizeUrl((p['images'] as List).first.toString());
    }
    return null;
  }
}

class _HeroIndicators extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _HeroIndicators({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 3,
          width: active ? 28 : 8,
          decoration: BoxDecoration(
            color: active ? _kGreenPrimary : _kInkMuted.withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _HeroImagePlaceholder extends StatelessWidget {
  const _HeroImagePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreenMist, _kGreenPrimary.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, size: 56, color: _kGreenPrimary),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER COMPONENT
// ============================================================================
class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const _SectionHeaderRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _kInkPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _kInkMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ============================================================================
// SKELETONS & PLACEHOLDERS
// ============================================================================
class _ImmersiveHeroSkeleton extends StatelessWidget {
  const _ImmersiveHeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(height: 14, width: 80, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(height: 24, width: 180, color: Colors.grey.shade200),
          const SizedBox(height: 18),
          Container(
            height: 420,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 18),
          Center(child: Container(height: 3, width: 80, color: Colors.grey.shade200)),
        ],
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
      children: List.generate(4, (_) => Column(
        children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(height: 10),
          Container(width: 60, height: 10, color: Colors.grey.shade200),
        ],
      )),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENTS
// ============================================================================
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 6),
        ],
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600))),
          if (!compact)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_retry')),
              style: TextButton.styleFrom(foregroundColor: _kGreenPrimary),
            ),
        ],
      ),
    );
  }
}

class _LivePulseIndicator extends StatefulWidget {
  const _LivePulseIndicator();
  @override
  State<_LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<_LivePulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2 * (1 - _ctrl.value)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            ),
          ],
        );
      },
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 5, height: 5,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

class _GreenPulseDot extends StatefulWidget {
  @override
  State<_GreenPulseDot> createState() => _GreenPulseDotState();
}

class _GreenPulseDotState extends State<_GreenPulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
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
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: _kGreenPrimary.withOpacity(0.2 * (1 - _ctrl.value)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _kGreenPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _kGreenPrimary.withOpacity(0.5), blurRadius: 6),
                ],
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
  final String? subtitle;
  final IconData icon;
  final String? liveLabel;

  const _AutoScrollProductStrip({
    required this.products,
    required this.badgeType,
    required this.title,
    this.subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeaderRow(
            title: widget.title,
            subtitle: widget.subtitle,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFlash ? const Color(0xFFFEF2F2) : _kGreenMist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: isFlash ? const Color(0xFFEF4444) : _kGreenPrimary, size: 18),
            ),
            trailing: isFlash && widget.liveLabel != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LiveDot(),
                        const SizedBox(width: 4),
                        Text(widget.liveLabel!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 225,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_active) return false;
              if (n is ScrollStartNotification) _pause();
              if (n is ScrollEndNotification) _resumeAfterDelay();
              return false;
            },
            child: ListView.separated(
              controller: _ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ProductCard(
                product: widget.products[i],
                variant: ProductCardVariant.horizontal,
                width: 145,
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
