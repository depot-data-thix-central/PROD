// lib/presentation/thix_market/pages/market_home_page.dart
// ============================================================================
// MARKET HOME PAGE — Production Enterprise v10 "Ultra Modern Standard"
// ----------------------------------------------------------------------------
//  • ✅ Palette STANDARD marketplace : blanc / encre / slate + vert en ACCENT
//    (bleu + or pour promo exclusive, rouge pour live/flash)
//  • ✅ Hero banner "Nouveautés" : 10 produits AUTO-SCROLL, compteur 02/10,
//    badge NEW, pill prix glass, CTA Découvrir, pagination dashes animée
//    → EXCLUT les produits locaux (is_local) et supermarchés (shop.type)
//  • ✅ Greeting header : "Bonjour / Nom" + pill "NEW · 10"
//  • ✅ LES 2 CARTES PROMO CONSERVÉES + hauteur BORNÉE (fix page blanche)
//  • ✅ Supprimés : trust badges card, bouton "Vendre local"
//  • ✅ Animations : reveal staggered, Ken Burns, tap-scale, FAB pulsant,
//    shimmer promos, marquee flash, dots animés
//  • ✅ Support FR / EN / SW, devises, badges notifications, panier central
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

import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';
import 'package:thix_id/l10n/app_localizations.dart';

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
// DESIGN TOKENS — PALETTE STANDARD MARKETPLACE
// ============================================================================
const Color kBg = Color(0xFFF6F8FB);
const Color kInk = Color(0xFF0F172A);
const Color kInkSoft = Color(0xFF475569);
const Color kInkMuted = Color(0xFF94A3B8);
const Color kBorder = Color(0xFFE2E8F0);
const Color kBrand = Color(0xFF16A34A); // vert THIX (accent de marque uniquement)
const Color kBrandDark = Color(0xFF15803D);
const Color kBrandSoft = Color(0xFFDCFCE7);
const Color kPromoBlue1 = Color(0xFF1E3A8A);
const Color kPromoBlue2 = Color(0xFF2563EB);
const Color kGold = Color(0xFFE3B848);
const Color kDanger = Color(0xFFEF4444);
const Color kLocalGreen1 = Color(0xFF0F7A37);
const Color kLocalGreen2 = Color(0xFF149A4A);

const Duration _kBannerAutoPlay = Duration(seconds: 5);
const Duration _kBannerResumeDelay = Duration(seconds: 2);
const int _kMaxTitleLength = 120;
const int _kMaxDescriptionLength = 300;
const int _kMaxNameLength = 50;
const int _kMaxLiveCards = 10;
const int _kMaxHeroSlides = 10;
const int _kMaxFeaturedShops = 4;
const int _kMaxLocalTeaser = 6;
const double _kGridCardHeight = 250;
const double _kPromoRowHeight = 190; // ✅ hauteur bornée (fix crash layout)

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

  static String groupNumber(num v) {
    final s = v.round().abs().toString();
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
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

/// ✅ HERO : 10 nouveautés — EXCLUT produits locaux & produits supermarchés
final heroNewArrivalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('*, shop:shops!inner(id, name, type)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(40) // on prend large, puis filtre côté Dart
        .timeout(const Duration(seconds: 10));

    final all = List<Map<String, dynamic>>.from(res as List);

    final filtered = all.where((p) {
      // ❌ Exclut les produits de la section PRODUITS LOCAUX
      if (p['is_local'] == true) return false;
      // ❌ Exclut les produits de la section SUPERMARCHÉS & BOUTIQUES
      final shopType = (p['shop']?['type'] ?? '').toString().toLowerCase();
      if (shopType.contains('super')) return false;
      return true;
    }).take(_kMaxHeroSlides).toList();

    debugPrint('[Market] 🎬 Hero: ${filtered.length} nouveautés (hors local/supermarché)');
    return filtered;
  } catch (e) {
    debugPrint('[Market] ⚠️ Hero arrivals error: $e');
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

class _MarketHomePageState extends ConsumerState<MarketHomePage> with RouteAware {
  final ScrollController _scroll = ScrollController();
  final PageController _bannerCtrl = PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  bool _bannerReady = false;
  int _currentBanner = 0;

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
  void didPopNext() {
    debugPrint('[Market] 🔙 Returned from pushed route — silent refresh');
    invalidateAllMarketProviders(ref);
    ref.read(forYouProvider.notifier).refresh();
    ref.read(marketBadgesProvider.notifier).refresh();
    ref.invalidate(localTeaserProvider);
    ref.invalidate(heroNewArrivalsProvider);
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

  Future<void> _openOrders() => _go(MarketBadge.orders, () => context.push('/market/orders'));

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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AllShopsAndSupermarketsPage()));
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
        backgroundColor: kInk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> _stableSort(List<Map<String, dynamic>> items) => stableSortProducts(items);

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
    final heroAsync = ref.watch(heroNewArrivalsProvider);
    final featuredAsync = ref.watch(featuredProductsProvider);
    final flashAsync = ref.watch(flashSalesProvider);
    final forYouAsync = ref.watch(forYouProvider);
    final liveSessionsAsync = ref.watch(activeMarketLiveSessionsProvider);
    final fallbackProducts = ref.watch(allMarketProductsProvider);
    final badges = ref.watch(marketBadgesProvider);
    final localAsync = ref.watch(localTeaserProvider);
    ref.watch(currencyProvider);
    ref.watch(exchangeRatesProvider);
    ref.watch(marketTickerProvider);

    final hasMore = ref.read(forYouProvider.notifier).hasMore;

    heroAsync.whenData((b) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerAuto(b.length));
    });

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: Stack(
        children: [
          RefreshIndicator(
            color: kBrand,
            backgroundColor: Colors.white,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              invalidateAllMarketProviders(ref);
              ref.read(marketBadgesProvider.notifier).refresh();
              ref.invalidate(localTeaserProvider);
              ref.invalidate(heroNewArrivalsProvider);
              await ref.read(forYouProvider.notifier).refresh();
              await _refreshCurrencyRates();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildTopSection(l10n, badges)),
                SliverToBoxAdapter(child: _buildGreetingRow(l10n, heroAsync)),
                SliverToBoxAdapter(child: _buildHero(heroAsync, l10n)),
                SliverToBoxAdapter(child: _buildFeaturedStrip(featuredAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, l10n)),
                SliverToBoxAdapter(child: _buildSupermarketSection(l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 60, child: _buildPromoBannersRow(l10n))),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 100, child: _buildB2BTools(l10n, badges))),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 60, child: _buildLocalTeaser(localAsync, l10n))),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _buildSectionHeader(_allProductsTitle(l10n))),
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

  // ──────────────────────────────────────────────────────────────────────────
  // TOPBAR + SEARCH
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopSection(AppLocalizations l10n, MarketBadges badges) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTopBar(l10n, badges),
          _buildSearchBar(l10n),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, MarketBadges badges) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kBrand,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: kBrand.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
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
                        TextSpan(
                          text: 'THIX',
                          style: TextStyle(color: kInk, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: -0.5),
                        ),
                        TextSpan(text: '.', style: TextStyle(color: kBrand, fontWeight: FontWeight.w900, fontSize: 19)),
                      ],
                    ),
                  ),
                  Text(
                    _MarketValidators.sanitize(l10n.t('market_app_tagline'), maxLength: 50),
                    style: const TextStyle(color: kInkMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              const CurrencySelector(),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: badges.alerts > 0
                    ? '${l10n.t('common_notifications')}, ${badges.alerts}'
                    : l10n.t('common_notifications'),
                child: _TapScale(
                  onTap: _openNotifications,
                  radius: BorderRadius.circular(14),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            badges.alerts > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            size: 20,
                            color: kInkSoft,
                          ),
                        ),
                        Positioned(top: -3, right: -3, child: _CountBadge(count: badges.alerts)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: l10n.t('common_profile'),
                child: _TapScale(
                  onTap: () => _safeNavigate('userDashboard', '/user/dashboard'),
                  radius: BorderRadius.circular(14),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kBrand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: kBrand.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 19),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              child: _TapScale(
                onTap: () => _safeNavigate('marketSearch', '/market/search'),
                radius: BorderRadius.circular(16),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: kBrandSoft, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.search_rounded, size: 19, color: kBrandDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _MarketValidators.sanitize(l10n.t('market_search_hint'), maxLength: 80),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: kInkMuted, fontWeight: FontWeight.w500),
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
            child: _TapScale(
              onTap: () => _safeNavigate('marketSearch', '/market/search'),
              radius: BorderRadius.circular(16),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: kInk.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.white, size: 19),
                    const SizedBox(width: 8),
                    Text(
                      _MarketValidators.sanitize(l10n.t('market_filters'), maxLength: 20),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
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

  // ──────────────────────────────────────────────────────────────────────────
  // GREETING ROW — "Bonjour / Nom" + pill "NEW · 10"
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildGreetingRow(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> heroAsync) {
    final count = heroAsync.valueOrNull?.length ?? 0;
    return _Reveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _MarketValidators.sanitize(l10n.t('market_greeting'), maxLength: 30),
                    style: const TextStyle(color: kInkMuted, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _greetingName(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kBrandSoft.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kBrand.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingDot(color: kBrand, size: 7),
                    const SizedBox(width: 7),
                    Text(
                      'NEW · $count',
                      style: const TextStyle(color: kBrandDark, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ✅ HERO BANNER — 10 nouveautés, auto-scroll, compteur, NEW, prix, CTA
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHero(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const _HeroSkeleton(),
      error: (e, _) => _MarketErrorCard(
        message: _MarketValidators.parseError(e, l10n),
        onRetry: () => ref.invalidate(heroNewArrivalsProvider),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _buildHeroContent(products, l10n);
      },
    );
  }

  Widget _buildHeroContent(List<Map<String, dynamic>> products, AppLocalizations l10n) {
    final heroH = (MediaQuery.sizeOf(context).height * 0.52).clamp(360.0, 480.0);
    return _Reveal(
      delayMs: 80,
      child: Column(
        children: [
          SizedBox(
            height: heroH,
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
                  final price = (p['price'] as num?)?.toDouble();
                  final id = p['id']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Semantics(
                      button: true,
                      label: title.isEmpty ? l10n.t('market_featured_offer') : title,
                      child: _TapScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (id.isNotEmpty) context.push('/market/product/$id');
                        },
                        radius: BorderRadius.circular(28),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: const Color(0xFFE5E7EB),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                _KenBurnsImage(url: imageUrl)
                              else
                                const Center(child: Icon(Icons.image_outlined, size: 64, color: kInkMuted)),

                              // Dégradé bas pour lisibilité du texte
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.05),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.55),
                                        ],
                                        stops: const [0.0, 0.45, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Rangée haute : compteur animé + badge NEW
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (c, a) => FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                                          child: c,
                                        ),
                                      ),
                                      child: Container(
                                        key: ValueKey('ctr_$_currentBanner'),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
                                        ),
                                        child: Text(
                                          '${(_currentBanner + 1).toString().padLeft(2, '0')} / ${products.length.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: kBrand,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [BoxShadow(color: kBrand.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _PulsingDot(color: Colors.white, size: 6),
                                          SizedBox(width: 7),
                                          Text(
                                            'NEW',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Contenu bas : prix glass + titre + sous-titre + CTA
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: 22,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (price != null && price > 0)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.16),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.white.withOpacity(0.45)),
                                            ),
                                            child: Text(
                                              _MarketValidators.groupNumber(price),
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Text(
                                      title.isEmpty ? '—' : title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.05),
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 5))],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shopping_bag_rounded, size: 17, color: kInk),
                                          const SizedBox(width: 10),
                                          Text(
                                            _t('Découvrir', 'Discover', 'Gundua'),
                                            style: const TextStyle(color: kInk, fontWeight: FontWeight.w900, fontSize: 14.5),
                                          ),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.arrow_forward_rounded, size: 16, color: kInk),
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
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Pagination dashes animée
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(products.length, (i) {
              final active = i == _currentBanner;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                width: active ? 26 : 10,
                decoration: BoxDecoration(
                  color: active ? kBrand : const Color(0xFFD8DEE7),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFeaturedStrip(AsyncValue<List<Map<String, dynamic>>> async, AppLocalizations l10n) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _AutoScrollProductStrip(
          products: products,
          badgeType: _StripBadge.featured,
          title: _MarketValidators.sanitize(l10n.t('market_featured_products'), maxLength: 50),
          icon: Icons.star_rounded,
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LIVE SHOPPING
  // ──────────────────────────────────────────────────────────────────────────
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
              child: Row(
                children: [
                  const _AccentBar(color: kDanger),
                  const SizedBox(width: 10),
                  const _PulsingDot(color: kDanger, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('market_live_ongoing'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: kInk, letterSpacing: -0.4),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: kDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${sessions.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kDanger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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

    return Semantics(
      button: true,
      label: l10n.t('market_shop_semantics', args: [shopName]),
      child: _TapScale(
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
        radius: BorderRadius.circular(20),
        child: Container(
          width: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFE5E7EB),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hostAvatar != null)
                CachedNetworkImage(
                  imageUrl: hostAvatar,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.storefront, color: kInkMuted, size: 36)),
                )
              else
                const Center(child: Icon(Icons.storefront, color: kInkMuted, size: 36)),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 9,
                left: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(color: Colors.white, size: 5),
                      SizedBox(width: 5),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUPERMARCHÉS & BOUTIQUES
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSupermarketSection(AppLocalizations l10n) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _MarketValidators.sanitize(l10n.t('market_home_supermarkets'), maxLength: 50),
            onSeeAll: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AllShopsAndSupermarketsPage()));
            },
            l10n: l10n,
          ),
          const SizedBox(height: 18),
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
                  style: const TextStyle(color: kInkMuted, fontSize: 12.5),
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
                    child: _TapScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) context.push('/market/shop/$id');
                      },
                      radius: BorderRadius.circular(18),
                      child: Column(
                        children: [
                          Container(
                            height: 68,
                            width: 68,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: kBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF1F5F9),
                                image: logoUrl != null
                                    ? DecorationImage(image: CachedNetworkImageProvider(logoUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: logoUrl == null ? const Icon(Icons.storefront_rounded, color: kInkMuted, size: 26) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 74,
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kInkSoft),
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

  // ──────────────────────────────────────────────────────────────────────────
  // ✅ LES 2 CARTES PROMO CONSERVÉES — hauteur BORNÉE (fix page blanche)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPromoBannersRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: _kPromoRowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ExclusivePromoCard(
                tag: _MarketValidators.sanitize(l10n.t('market_exclusive_offers_tag'), maxLength: 30),
                title: _MarketValidators.sanitize(l10n.t('market_up_to_50'), maxLength: 50),
                subtitle: _MarketValidators.sanitize(l10n.t('market_premium_selection'), maxLength: 60),
                cta: _MarketValidators.sanitize(l10n.t('market_discover'), maxLength: 20),
                onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LocalPromoCard(onTap: () => _safeNavigate('marketLocalHome', '/market/local')),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OUTILS B2B (sans bouton "vendre local")
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildB2BTools(AppLocalizations l10n, MarketBadges badges) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _b2bItem(Icons.compare_arrows_rounded, _MarketValidators.sanitize(l10n.t('market_compare'), maxLength: 20),
                () => _safeNavigate('marketProductComparator', '/market/compare')),
            _b2bItem(Icons.notifications_active_rounded, _MarketValidators.sanitize(l10n.t('market_price_alert'), maxLength: 20),
                () => _safeNavigate('marketPriceAlerts', '/market/price-alerts')),
            _b2bItem(Icons.request_quote_rounded, _MarketValidators.sanitize(l10n.t('market_b2b_quote'), maxLength: 20),
                () => _showComing(l10n.t('market_b2b_quote'))),
            _b2bItem(Icons.favorite_rounded, _MarketValidators.sanitize(l10n.t('market_wishlist'), maxLength: 20), _openWishlist,
                badge: badges.wishlist),
          ],
        ),
      ),
    );
  }

  Widget _b2bItem(IconData icon, String label, VoidCallback onTap, {int badge = 0}) {
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      child: _TapScale(
        onTap: onTap,
        radius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: kInkSoft, size: 20),
                  ),
                  Positioned(top: -4, right: -4, child: _CountBadge(count: badge)),
                ],
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kInkSoft)),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TEASER PRODUITS LOCAUX
  // ──────────────────────────────────────────────────────────────────────────
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
              child: Row(
                children: [
                  const _AccentBar(color: kBrand),
                  const SizedBox(width: 10),
                  const _PulsingDot(color: kBrand, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: kInk, letterSpacing: -0.4),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: _t('Voir tout', 'Show all', 'Ona zote'),
                    child: _TapScale(
                      onTap: () => _safeNavigate('marketLocalHome', '/market/local'),
                      radius: BorderRadius.circular(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _t('Voir tout', 'Show all', 'Ona zote'),
                            style: const TextStyle(color: kBrandDark, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kBrandDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 275,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: 180,
                  child: LocalProductCard(product: products[i], width: 180, height: 275),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLASH SALES
  // ──────────────────────────────────────────────────────────────────────────
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
                decoration: const BoxDecoration(color: kDanger),
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.only(bottom: 14),
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
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: _MarqueeText(text: _MarketValidators.sanitize(l10n.t('market_flash_sale_banner'), maxLength: 100)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const _AccentBar(color: kBrand),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: kInk, letterSpacing: -0.4),
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null && l10n != null)
            Semantics(
              button: true,
              label: l10n.t('common_see_all'),
              child: _TapScale(
                onTap: onSeeAll,
                radius: BorderRadius.circular(10),
                child: Text(
                  l10n.t('common_see_all'),
                  style: const TextStyle(color: kBrandDark, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GRILLE PRODUITS
  // ──────────────────────────────────────────────────────────────────────────
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
                  const Icon(Icons.inventory_2_outlined, size: 56, color: kInkMuted),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('market_no_products'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('Tirez vers le bas pour actualiser', 'Pull down to refresh', 'Vuta chini ili kuburudisha'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: kInkMuted),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(forYouProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.t('common_retry')),
                    style: TextButton.styleFrom(foregroundColor: kBrandDark),
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
              return const Center(child: CircularProgressIndicator(color: kBrand, strokeWidth: 2.5));
            }
            final p = sorted[i];
            return LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: box.maxWidth,
                height: _kGridCardHeight,
                child: ProductCard(
                  key: ValueKey('grid_${p['id']}'),
                  product: p,
                  variant: ProductCardVariant.horizontal,
                  width: box.maxWidth,
                ),
              ),
            );
          },
          childCount: sorted.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV — barre blanche + FAB vert central pulsant
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavBar(AppLocalizations l10n, MarketBadges badges) {
    const barH = 58.0;
    const fabSize = 60.0;
    const lift = 22.0;

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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10))],
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
                            _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
                          }
                        },
                      ),
                      _navItem(
                        icon: Icons.receipt_long_rounded,
                        label: _MarketValidators.sanitize(l10n.t('market_orders'), maxLength: 20),
                        badge: badges.orders,
                        onTap: _openOrders,
                      ),
                      const SizedBox(width: fabSize + 6),
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
              Positioned(
                top: 0,
                child: _PulsingFab(
                  label: l10n.t('market_cart_semantics'),
                  onTap: () => context.push('/market/cart'),
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
    final color = selected ? kBrand : kInkMuted;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      selected: selected,
      child: _TapScale(
        onTap: onTap,
        radius: BorderRadius.circular(14),
        child: SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 22),
                    Positioned(top: -5, right: -10, child: _CountBadge(count: badge)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
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
// ✅ CARTE PROMO 1 — OFFRES EXCLUSIVES (bleu + badge or) avec shimmer
// ============================================================================
class _ExclusivePromoCard extends StatefulWidget {
  final String tag, title, subtitle, cta;
  final VoidCallback onTap;
  const _ExclusivePromoCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  State<_ExclusivePromoCard> createState() => _ExclusivePromoCardState();
}

class _ExclusivePromoCardState extends State<_ExclusivePromoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.title,
      child: _TapScale(
        onTap: widget.onTap,
        radius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPromoBlue1, kPromoBlue2]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: kPromoBlue2.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _DotsPatternPainter(color: Colors.white.withOpacity(0.06), spacing: 16, dotSize: 1.2)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (rect) {
                        final p = _shimmer.value;
                        return LinearGradient(
                          begin: Alignment(-2 + p * 4, -0.5),
                          end: Alignment(2 + p * 4, 0.5),
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.14),
                            Colors.white.withOpacity(0.0),
                          ],
                        ).createShader(rect);
                      },
                      child: Container(color: Colors.white),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        widget.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF3B2F0B), fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, height: 1.1, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5, fontWeight: FontWeight.w500),
                    ),
                    // ✅ Expanded sûr (remplace Spacer : jamais de crash de contraintes)
                    const Expanded(child: SizedBox.shrink()),
                    Row(
                      children: [
                        Text(widget.cta, style: const TextStyle(color: kGold, fontWeight: FontWeight.w800, fontSize: 11.5)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 13, color: kGold),
                      ],
                    ),
                  ],
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
// ✅ CARTE PROMO 2 — PRODUITS LOCAUX (vert) avec shimmer + CTA animé
// ============================================================================
class _LocalPromoCard extends StatefulWidget {
  final VoidCallback onTap;
  const _LocalPromoCard({required this.onTap});

  @override
  State<_LocalPromoCard> createState() => _LocalPromoCardState();
}

class _LocalPromoCardState extends State<_LocalPromoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat();
  late final Animation<double> _arrowSlide = Tween<double>(begin: 0, end: 4).animate(
    CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = lang == 'sw' ? 'BIDHAA ZA NDANI' : lang == 'en' ? 'LOCAL GOODS' : 'PRODUITS LOCAUX';
    final subtitle = lang == 'sw'
        ? 'Moja kwa moja kutoka kwa wakulima'
        : lang == 'en'
            ? 'Direct from local producers'
            : 'Direct producteurs locaux';
    final ctaLabel = lang == 'sw' ? 'Gundua' : lang == 'en' ? 'Discover' : 'Découvrir';

    return Semantics(
      button: true,
      label: 'Produits locaux, tous secteurs',
      child: _TapScale(
        onTap: widget.onTap,
        radius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kLocalGreen1, kLocalGreen2, Color(0xFF0B6B31)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: kLocalGreen2.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _DotsPatternPainter(color: Colors.white.withOpacity(0.06), spacing: 14, dotSize: 1.2)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (rect) {
                        final p = _shimmerCtrl.value;
                        return LinearGradient(
                          begin: Alignment(-2 + p * 4, -0.5),
                          end: Alignment(2 + p * 4, 0.5),
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
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.0)]),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Center(child: Text('🌱', style: TextStyle(fontSize: 20))),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.55)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text(
                            '100% LOCAL',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 8.5, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.2),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9.5, fontWeight: FontWeight.w500),
                    ),
                    // ✅ Expanded sûr (remplace Spacer)
                    const Expanded(child: SizedBox.shrink()),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _sectorIcon(Icons.eco_rounded, const Color(0xFFA7F3D0)),
                            const SizedBox(width: 4),
                            _sectorIcon(Icons.brush_rounded, const Color(0xFFFDE68A)),
                            const SizedBox(width: 4),
                            _sectorIcon(Icons.handshake_rounded, const Color(0xFFBFDBFE)),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                '+${kLocalSectors.length - 3}',
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: AnimatedBuilder(
                            animation: _arrowSlide,
                            builder: (_, child) => Transform.translate(offset: Offset(_arrowSlide.value, 0), child: child),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(ctaLabel, style: const TextStyle(color: Color(0xFF0B6B31), fontWeight: FontWeight.w900, fontSize: 10)),
                                const SizedBox(width: 3),
                                const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF0B6B31)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectorIcon(IconData icon, Color bgColor) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

// ============================================================================
// ✅ ANIMATIONS D'ATTRACTION
// ============================================================================

/// Reveal staggered : fade + slide up à l'entrée dans le viewport
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Reveal({required this.child, this.delayMs = 0});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, 22 * (1 - _curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Feedback tactile : scale down/up au tap
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? radius;
  const _TapScale({required this.child, this.onTap, this.radius});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: _pressed ? 0.96 : 1),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: widget.radius != null ? ClipRRect(borderRadius: widget.radius!, child: widget.child) : widget.child,
      ),
    );
  }
}

/// Ken Burns : zoom lent alterné sur l'image du hero
class _KenBurnsImage extends StatefulWidget {
  final String url;
  const _KenBurnsImage({required this.url});

  @override
  State<_KenBurnsImage> createState() => _KenBurnsImageState();
}

class _KenBurnsImageState extends State<_KenBurnsImage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 60, color: kInkMuted)),
        ),
      ),
    );
  }
}

/// FAB panier avec anneau pulsant
class _PulsingFab extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _PulsingFab({required this.onTap, required this.label});

  @override
  State<_PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<_PulsingFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60 + t * 14,
              height: 60 + t * 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kBrand.withOpacity(0.18 * (1 - t))),
            ),
            child!,
          ],
        );
      },
      child: Semantics(
        button: true,
        label: widget.label,
        child: _TapScale(
          onTap: widget.onTap,
          radius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kBrand, kBrandDark]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: kBrand.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS UTILITAIRES
// ============================================================================
class _AccentBar extends StatelessWidget {
  final Color color;
  const _AccentBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, this.size = 8});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 0.7, end: 1.25).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
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
        color: kDanger,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1.1)),
    );
  }
}

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
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: kDanger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDanger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: kDanger, size: compact ? 20 : 28),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: kDanger, fontSize: compact ? 12 : 14))),
          if (!compact)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.t('common_retry')),
              style: TextButton.styleFrom(foregroundColor: kBrandDark),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 400,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(28)),
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
            Container(width: 68, height: 68, decoration: const BoxDecoration(color: Color(0xFFE5E7EB), shape: BoxShape.circle)),
            const SizedBox(height: 8),
            Container(width: 60, height: 12, color: const Color(0xFFE5E7EB)),
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
          decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(16)),
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
          child: Row(
            children: [
              _AccentBar(color: isFlash ? kDanger : kGold),
              const SizedBox(width: 10),
              Icon(widget.icon, color: isFlash ? kDanger : kGold, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: kInk, letterSpacing: -0.4),
                ),
              ),
              if (_active && widget.liveLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.liveLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kDanger)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  static const double _itemWidth = 300;

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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
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
