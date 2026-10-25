// lib/presentation/thix_market/pages/market_home_page.dart
// ============================================================================
// MARKET HOME PAGE — Production Enterprise v12 "PROMO PHOTOS"
// ----------------------------------------------------------------------------
//  • ✅ Fond BLANC PUR, typographies RÉDUITES pour lisibilité maximale
//  • ✅ Accent ORANGE standard marketplace (vert UNIQUEMENT carte locale)
//  • ✅ Topbar compacte : recherche = icône seule, icon COMPTE SUPPRIMÉE
//  • ✅ NOUVEAU : cartes promo (bleue + verte) avec PHOTOS de fond multiples
//       + défilement automatique (4 s) — table promo_card_banners + bucket
//  • ✅ NOUVEAU : bouton d'ajout de photos visible UNIQUEMENT pour les ADMIN
//       (RPC is_thix_admin + RLS côté base)
//  • ✅ FIX : overflow du bouton "Découvrir" (carte verte), shimmer plein-carte
//  • ✅ Hero : compteur de banner SUPPRIMÉ, textes réduits, Ken Burns
//  • ✅ Hero = 10 nouveautés (hors produits locaux & supermarchés)
//  • ✅ Animations : reveal, Ken Burns, tap-scale, FAB pulsant, shimmer, marquee
//  • ✅ v12.1 : Cartes promo avec photo floutée + voiles renforcés + texte épuré
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
import 'package:image_picker/image_picker.dart';

import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../core/currency_service.dart';
import '../providers/market_providers.dart';
import '../providers/market_badges_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/products/product_card.dart';
import '../widgets/products/local_product_card.dart';
import '../widgets/market/flash_sale_timer.dart';
import '../widgets/market/currency_selector.dart';
import 'all_shops_and_supermarkets_page.dart';

// ============================================================================
// DESIGN TOKENS — FOND BLANC PUR + ACCENT ORANGE (vert = carte locale seule)
// ============================================================================
const Color kBg = Colors.white; // ✅ fond blanc pur
const Color kInk = Color(0xFF0F172A);
const Color kInkSoft = Color(0xFF475569);
const Color kInkMuted = Color(0xFF94A3B8);
const Color kBorder = Color(0xFFE2E8F0);
const Color kSurface = Color(0xFFF8FAFC);

// ✅ Nouvel accent standard marketplace (orange) — remplace le vert
const Color kAccent = Color(0xFFF97316);
const Color kAccentDark = Color(0xFFC2410C);
const Color kAccentSoft = Color(0xFFFFEDD5);

const Color kPromoBlue1 = Color(0xFF1E3A8A);
const Color kPromoBlue2 = Color(0xFF2563EB);
const Color kGold = Color(0xFFE3B848);
const Color kDanger = Color(0xFFEF4444);

// ✅ Vert réservé UNIQUEMENT à la carte produits locaux
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
const double _kPromoRowHeight = 184;

// ✅ Photos de fond des cartes promo
const String _kPromoBucket = 'promo-banners';
const String _kPromoTable = 'promo_card_banners';
const String _kCardExclusive = 'exclusive';
const String _kCardLocal = 'local';
const int _kMaxPromoPhotos = 8;
const int _kMaxPromoFileBytes = 5 * 1024 * 1024;
const Duration _kPromoSlide = Duration(seconds: 4);

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
        .limit(40)
        .timeout(const Duration(seconds: 10));

    final all = List<Map<String, dynamic>>.from(res as List);

    final filtered = all.where((p) {
      if (p['is_local'] == true) return false;
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

// ----------------------------------------------------------------------------
// ✅ ADMIN : source unique = fonction SQL is_thix_admin() (même logique que RLS)
// ----------------------------------------------------------------------------
final marketIsAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return false;
  try {
    final res = await client.rpc('is_thix_admin').timeout(const Duration(seconds: 8));
    return res == true;
  } catch (e) {
    debugPrint('[Market] ⚠️ is_thix_admin error: $e');
    return false;
  }
});

// ----------------------------------------------------------------------------
// ✅ PHOTOS DES CARTES PROMO
// ----------------------------------------------------------------------------
class PromoBanner {
  final String id;
  final String imageUrl;
  final String storagePath;
  final int sortOrder;
  const PromoBanner({
    required this.id,
    required this.imageUrl,
    required this.storagePath,
    required this.sortOrder,
  });
}

final promoBannersProvider = FutureProvider.autoDispose.family<List<PromoBanner>, String>((ref, cardKey) async {
  try {
    final res = await Supabase.instance.client
        .from(_kPromoTable)
        .select('id, image_url, storage_path, sort_order')
        .eq('card_key', cardKey)
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true)
        .limit(_kMaxPromoPhotos)
        .timeout(const Duration(seconds: 10));

    final out = <PromoBanner>[];
    for (final row in List<Map<String, dynamic>>.from(res as List)) {
      final url = _MarketValidators.sanitizeUrl(row['image_url']?.toString());
      if (url == null) continue;
      out.add(PromoBanner(
        id: row['id']?.toString() ?? '',
        imageUrl: url,
        storagePath: row['storage_path']?.toString() ?? '',
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  } catch (e) {
    debugPrint('[Market] ⚠️ Promo banners ($cardKey) error: $e');
    return const <PromoBanner>[];
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
    _refreshCurrencyRates();
  }

  Future<void> _refreshCurrencyRates() async {
    try {
      await CurrencyService.instance.refreshRates();
    } catch (e) {
      debugPrint('[Market] ⚠️ Currency refresh failed: $e');
    }
  }

  void _invalidatePromo() {
    ref.invalidate(promoBannersProvider(_kCardExclusive));
    ref.invalidate(promoBannersProvider(_kCardLocal));
    ref.invalidate(marketIsAdminProvider);
  }

  @override
  void didPopNext() {
    invalidateAllMarketProviders(ref);
    ref.read(forYouProvider.notifier).refresh();
    ref.read(marketBadgesProvider.notifier).refresh();
    ref.invalidate(localTeaserProvider);
    ref.invalidate(heroNewArrivalsProvider);
    _invalidatePromo();
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

  void _openPromoManager(String cardKey, String title) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromoBannerManagerSheet(cardKey: cardKey, title: title),
    );
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
            color: kAccent,
            backgroundColor: Colors.white,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              invalidateAllMarketProviders(ref);
              ref.read(marketBadgesProvider.notifier).refresh();
              ref.invalidate(localTeaserProvider);
              ref.invalidate(heroNewArrivalsProvider);
              _invalidatePromo();
              await ref.read(forYouProvider.notifier).refresh();
              await _refreshCurrencyRates();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar(l10n, badges)),
                SliverToBoxAdapter(child: _buildGreetingRow(l10n, heroAsync)),
                SliverToBoxAdapter(child: _buildHero(heroAsync, l10n)),
                SliverToBoxAdapter(child: _buildFeaturedStrip(featuredAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildLiveSection(liveSessionsAsync, l10n)),
                SliverToBoxAdapter(child: _buildSupermarketSection(l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 60, child: _buildPromoBannersRow(l10n))),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 100, child: _buildB2BTools(l10n, badges))),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _Reveal(delayMs: 60, child: _buildLocalTeaser(localAsync, l10n))),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, l10n)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildSectionHeader(_allProductsTitle(l10n))),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
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
  // ✅ TOPBAR COMPACTE : recherche = icône seule, compte SUPPRIMÉ
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar(AppLocalizations l10n, MarketBadges badges) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kAccent, kAccentDark]),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: kAccent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'THIX', style: TextStyle(color: kInk, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.4)),
                      TextSpan(text: '.', style: TextStyle(color: kAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                Text(
                  _MarketValidators.sanitize(l10n.t('market_app_tagline'), maxLength: 40),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kInkMuted, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // ✅ Recherche = simple symbole
          Semantics(
            button: true,
            label: l10n.t('market_search_hint'),
            child: _TapScale(
              onTap: () => _safeNavigate('marketSearch', '/market/search'),
              radius: BorderRadius.circular(11),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: kAccentSoft, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.search_rounded, size: 18, color: kAccentDark),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const CurrencySelector(),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: badges.alerts > 0 ? '${l10n.t('common_notifications')}, ${badges.alerts}' : l10n.t('common_notifications'),
            child: _TapScale(
              onTap: _openNotifications,
              radius: BorderRadius.circular(11),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: kBorder),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        badges.alerts > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                        size: 17,
                        color: kInkSoft,
                      ),
                    ),
                    Positioned(top: -4, right: -4, child: _CountBadge(count: badges.alerts)),
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
  // GREETING ROW — textes réduits
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildGreetingRow(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> heroAsync) {
    final count = heroAsync.valueOrNull?.length ?? 0;
    return _Reveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
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
                    style: const TextStyle(color: kInkMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _greetingName(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.6, height: 1.1),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: kAccentSoft.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kAccent.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingDot(color: kAccent, size: 6),
                    const SizedBox(width: 6),
                    Text(
                      'NEW · $count',
                      style: const TextStyle(color: kAccentDark, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
  // ✅ HERO — compteur SUPPRIMÉ, textes réduits, Ken Burns, auto-scroll
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
    final heroH = (MediaQuery.sizeOf(context).height * 0.46).clamp(300.0, 420.0);
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Semantics(
                      button: true,
                      label: title.isEmpty ? l10n.t('market_featured_offer') : title,
                      child: _TapScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (id.isNotEmpty) context.push('/market/product/$id');
                        },
                        radius: BorderRadius.circular(22),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: const Color(0xFFE5E7EB),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 8))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                _KenBurnsImage(url: imageUrl)
                              else
                                const Center(child: Icon(Icons.image_outlined, size: 48, color: kInkMuted)),

                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.04),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.6),
                                        ],
                                        stops: const [0.0, 0.45, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ✅ Badge NEW seul (compteur supprimé)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kAccent,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [BoxShadow(color: kAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _PulsingDot(color: Colors.white, size: 5),
                                      SizedBox(width: 6),
                                      Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                                    ],
                                  ),
                                ),
                              ),

                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (price != null && price > 0)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.16),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white.withOpacity(0.45)),
                                            ),
                                            child: Text(
                                              _MarketValidators.groupNumber(price),
                                              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      title.isEmpty ? '—' : title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.15),
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shopping_bag_rounded, size: 14, color: kInk),
                                          const SizedBox(width: 8),
                                          Text(
                                            _t('Découvrir', 'Discover', 'Gundua'),
                                            style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 13, color: kInk),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(products.length, (i) {
              final active = i == _currentBanner;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 3.5,
                width: active ? 20 : 8,
                decoration: BoxDecoration(
                  color: active ? kAccent : const Color(0xFFD8DEE7),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
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
                  const _AccentBar(color: kDanger),
                  const SizedBox(width: 8),
                  const _PulsingDot(color: kDanger, size: 7),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      l10n.t('market_live_ongoing'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: kInk, letterSpacing: -0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${sessions.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kDanger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 136,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
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
        radius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFE5E7EB),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hostAvatar != null)
                CachedNetworkImage(
                  imageUrl: hostAvatar,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.storefront, color: kInkMuted, size: 30)),
                )
              else
                const Center(child: Icon(Icons.storefront, color: kInkMuted, size: 30)),
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
                top: 7,
                left: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(5)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(color: Colors.white, size: 4),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
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
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
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
                  style: const TextStyle(color: kInkMuted, fontSize: 11.5),
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
                      radius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          Container(
                            height: 58,
                            width: 58,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: kBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kSurface,
                                image: logoUrl != null
                                    ? DecorationImage(image: CachedNetworkImageProvider(logoUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: logoUrl == null ? const Icon(Icons.storefront_rounded, color: kInkMuted, size: 22) : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 68,
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kInkSoft),
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
  // ✅ LES 2 CARTES PROMO — photos de fond + bouton ADMIN
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPromoBannersRow(AppLocalizations l10n) {
    final isAdmin = ref.watch(marketIsAdminProvider).valueOrNull ?? false;
    final exclusivePhotos = (ref.watch(promoBannersProvider(_kCardExclusive)).valueOrNull ?? const <PromoBanner>[])
        .map((b) => b.imageUrl)
        .toList();
    final localPhotos = (ref.watch(promoBannersProvider(_kCardLocal)).valueOrNull ?? const <PromoBanner>[])
        .map((b) => b.imageUrl)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                photos: exclusivePhotos,
                isAdmin: isAdmin,
                onAdminTap: () => _openPromoManager(
                  _kCardExclusive,
                  _t('Offres exclusives', 'Exclusive offers', 'Ofa maalum'),
                ),
                onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LocalPromoCard(
                photos: localPhotos,
                isAdmin: isAdmin,
                onAdminTap: () => _openPromoManager(
                  _kCardLocal,
                  _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
                ),
                onTap: () => _safeNavigate('marketLocalHome', '/market/local'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildB2BTools(AppLocalizations l10n, MarketBadges badges) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 5))],
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
        radius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: kInkSoft, size: 17),
                  ),
                  Positioned(top: -4, right: -4, child: _CountBadge(count: badge)),
                ],
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kInkSoft)),
            ],
          ),
        ),
      ),
    );
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const _AccentBar(color: kLocalGreen2),
                  const SizedBox(width: 8),
                  const _PulsingDot(color: kLocalGreen2, size: 7),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: kInk, letterSpacing: -0.3),
                    ),
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
                            style: const TextStyle(color: kLocalGreen2, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: kLocalGreen2),
                        ],
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
                separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                padding: const EdgeInsets.symmetric(vertical: 7),
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                        child: FlashSaleTimer(endTime: timerEnd!),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const _AccentBar(color: kAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: kInk, letterSpacing: -0.3),
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
                  style: const TextStyle(color: kAccentDark, fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 44, color: kInkMuted),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('market_no_products'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kInk),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez vers le bas pour actualiser', 'Pull down to refresh', 'Vuta chini ili kuburudisha'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: kInkMuted),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(forYouProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.t('common_retry'), style: const TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(foregroundColor: kAccentDark),
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
              return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5));
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
  // BOTTOM NAV compacte + FAB orange pulsant
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavBar(AppLocalizations l10n, MarketBadges badges) {
    const barH = 54.0;
    const fabSize = 56.0;
    const lift = 20.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 8))],
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
                child: _PulsingFab(label: l10n.t('market_cart_semantics'), onTap: () => context.push('/market/cart')),
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
    final color = selected ? kAccent : kInkMuted;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      selected: selected,
      child: _TapScale(
        onTap: onTap,
        radius: BorderRadius.circular(12),
        child: SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 20),
                    Positioned(top: -5, right: -9, child: _CountBadge(count: badge)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8.5, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
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
// ✅ COQUILLE COMMUNE DES CARTES PROMO (v2 — LISIBILITÉ MAX)
//    Photo floutée + voile de couleur renforcé + assombrissement bas
// ============================================================================
class _PromoCardShell extends StatelessWidget {
  final List<Color> colors;
  final Color shadow;
  final List<String> photos;
  final bool isAdmin;
  final VoidCallback onAdminTap;
  final VoidCallback onTap;
  final String semanticsLabel;
  final double dotSpacing;
  final Widget child;

  const _PromoCardShell({
    required this.colors,
    required this.shadow,
    required this.photos,
    required this.isAdmin,
    required this.onAdminTap,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
    this.dotSpacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhotos = photos.isNotEmpty;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: _TapScale(
        onTap: onTap,
        radius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 7))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhotos) ...[
                // ✅ PHOTO FLOUTÉE + zoomée (cache les bords du blur)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: Transform.scale(
                      scale: 1.08,
                      child: _PromoPhotoCarousel(urls: photos),
                    ),
                  ),
                ),
                // ✅ VOILE RENFORCÉ : identité visuelle + lisibilité maximale
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.first.withOpacity(0.88),
                            colors.last.withOpacity(0.78),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Assombrissement léger en bas : détache titres & CTA
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotsPatternPainter(color: Colors.white.withOpacity(0.06), spacing: dotSpacing, dotSize: 1.1),
                  ),
                ),
              const Positioned.fill(child: _ShimmerSweep()),
              Padding(padding: const EdgeInsets.all(13), child: child),
              if (isAdmin)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _AdminPhotoButton(onTap: onAdminTap),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton d'ajout de photos — rendu UNIQUEMENT si isAdmin == true
class _AdminPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AdminPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Photos',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.add_photo_alternate_rounded, size: 16, color: kInk),
        ),
      ),
    );
  }
}

/// Carrousel de photos : défilement automatique infini (glissement horizontal)
class _PromoPhotoCarousel extends StatefulWidget {
  final List<String> urls;
  const _PromoPhotoCarousel({required this.urls});

  @override
  State<_PromoPhotoCarousel> createState() => _PromoPhotoCarouselState();
}

class _PromoPhotoCarouselState extends State<_PromoPhotoCarousel> {
  final PageController _ctrl = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _PromoPhotoCarousel old) {
    super.didUpdateWidget(old);
    if (old.urls.length != widget.urls.length) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.urls.length <= 1) return;
    _timer = Timer.periodic(_kPromoSlide, (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _ctrl.nextPage(duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _img(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) return _img(urls.first);
    return PageView.builder(
      controller: _ctrl,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) => _img(urls[i % urls.length]),
    );
  }
}

/// Reflet lumineux qui balaie toute la carte (remplace l'ancien ShaderMask)
class _ShimmerSweep extends StatefulWidget {
  const _ShimmerSweep();

  @override
  State<_ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<_ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, box) {
          final w = box.maxWidth.isFinite ? box.maxWidth : 200.0;
          final band = w * 0.55;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final x = -band + (w + band) * _ctrl.value;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 0,
                    bottom: 0,
                    width: band,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.13),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ✅ CARTE PROMO 1 — OFFRES EXCLUSIVES (bleue) — textes ombrés = lisibles
// ============================================================================
class _ExclusivePromoCard extends StatelessWidget {
  final String tag, title, subtitle, cta;
  final List<String> photos;
  final bool isAdmin;
  final VoidCallback onAdminTap;
  final VoidCallback onTap;

  const _ExclusivePromoCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.photos,
    required this.isAdmin,
    required this.onAdminTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PromoCardShell(
      colors: const [kPromoBlue1, kPromoBlue2],
      shadow: kPromoBlue2.withOpacity(0.28),
      photos: photos,
      isAdmin: isAdmin,
      onAdminTap: onAdminTap,
      onTap: onTap,
      semanticsLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF3B2F0B), fontWeight: FontWeight.w800, fontSize: 8.5),
                  ),
                ),
              ),
              if (isAdmin) const SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.15,
              letterSpacing: -0.2,
              shadows: [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 1))],
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
          Row(
            children: [
              Text(cta, style: const TextStyle(color: kGold, fontWeight: FontWeight.w800, fontSize: 10.5)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: kGold),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ CARTE PROMO 2 — PRODUITS LOCAUX (verte) — ÉPURÉE :
//    uniquement le titre + le bouton Découvrir (lisibilité maximale)
// ============================================================================
class _LocalPromoCard extends StatelessWidget {
  final List<String> photos;
  final bool isAdmin;
  final VoidCallback onAdminTap;
  final VoidCallback onTap;

  const _LocalPromoCard({
    required this.photos,
    required this.isAdmin,
    required this.onAdminTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = lang == 'sw' ? 'BIDHAA ZA NDANI' : lang == 'en' ? 'LOCAL GOODS' : 'PRODUITS LOCAUX';
    final ctaLabel = lang == 'sw' ? 'Gundua' : lang == 'en' ? 'Discover' : 'Découvrir';

    return _PromoCardShell(
      colors: const [kLocalGreen1, kLocalGreen2],
      shadow: kLocalGreen2.withOpacity(0.3),
      photos: photos,
      isAdmin: isAdmin,
      onAdminTap: onAdminTap,
      onTap: onTap,
      semanticsLabel: 'Produits locaux, tous secteurs',
      dotSpacing: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end, // ✅ contenu ancré en bas
        children: [
          // ✅ UNIQUEMENT le titre
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.2,
              height: 1.1,
              shadows: [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
          const SizedBox(height: 10),
          // ✅ UNIQUEMENT le bouton Découvrir
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ctaLabel,
                  style: const TextStyle(color: Color(0xFF0B6B31), fontWeight: FontWeight.w900, fontSize: 10.5),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF0B6B31)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ FEUILLE DE GESTION DES PHOTOS (ADMIN) — ajout multiple / suppression
// ============================================================================
class _PromoBannerManagerSheet extends ConsumerStatefulWidget {
  final String cardKey;
  final String title;
  const _PromoBannerManagerSheet({required this.cardKey, required this.title});

  @override
  ConsumerState<_PromoBannerManagerSheet> createState() => _PromoBannerManagerSheetState();
}

class _PromoBannerManagerSheetState extends ConsumerState<_PromoBannerManagerSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String _progress = '';

  String _t(String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? kDanger : kInk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('row-level security') || m.contains('403') || m.contains('unauthorized') || m.contains('not authorized')) {
      return _t('Accès refusé : réservé aux administrateurs.', 'Access denied: administrators only.');
    }
    if (m.contains('mime') || m.contains('not supported')) {
      return _t('Format non supporté (JPG, PNG ou WebP).', 'Unsupported format (JPG, PNG or WebP).');
    }
    if (m.contains('too large') || m.contains('413') || m.contains('size')) {
      return _t('Image trop lourde (5 Mo max).', 'Image too large (5 MB max).');
    }
    return _t('Échec de l\'envoi. Réessayez.', 'Upload failed. Please retry.');
  }

  Future<void> _addPhotos(List<PromoBanner> current) async {
    if (_busy) return;
    final remaining = _kMaxPromoPhotos - current.length;
    if (remaining <= 0) {
      _snack(_t('Maximum $_kMaxPromoPhotos photos par carte.', 'Maximum $_kMaxPromoPhotos photos per card.'), error: true);
      return;
    }

    List<XFile> picked;
    try {
      picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
    } catch (e) {
      debugPrint('[Market] ⚠️ pickMultiImage error: $e');
      _snack(_t('Impossible d\'ouvrir la galerie.', 'Unable to open the gallery.'), error: true);
      return;
    }
    if (picked.isEmpty) return;

    final files = picked.take(remaining).toList();
    final client = Supabase.instance.client;
    int ok = 0;
    int failed = 0;
    int nextOrder = current.fold<int>(-1, (m, b) => b.sortOrder > m ? b.sortOrder : m) + 1;
    Object? lastError;

    setState(() {
      _busy = true;
      _progress = '0/${files.length}';
    });

    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      String? uploadedPath;
      try {
        final bytes = await f.readAsBytes();
        if (bytes.length > _kMaxPromoFileBytes) {
          failed++;
          lastError = 'too large';
          continue;
        }
        var ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
        if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
        final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
        final path = '${widget.cardKey}/${DateTime.now().microsecondsSinceEpoch}_$i.$ext';

        await client.storage.from(_kPromoBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mime, upsert: false),
            );
        uploadedPath = path;

        final url = client.storage.from(_kPromoBucket).getPublicUrl(path);
        await client.from(_kPromoTable).insert({
          'card_key': widget.cardKey,
          'image_url': url,
          'storage_path': path,
          'sort_order': nextOrder++,
          'is_active': true,
        });
        ok++;
      } catch (e) {
        failed++;
        lastError = e;
        debugPrint('[Market] ❌ promo upload error: $e');
        if (uploadedPath != null) {
          try {
            await client.storage.from(_kPromoBucket).remove([uploadedPath]);
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _progress = '${i + 1}/${files.length}');
    }

    ref.invalidate(promoBannersProvider(widget.cardKey));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = '';
    });

    if (ok > 0 && failed == 0) {
      _snack(_t('$ok photo(s) ajoutée(s).', '$ok photo(s) added.'));
    } else if (ok > 0) {
      _snack(_t('$ok ajoutée(s), $failed échec(s).', '$ok added, $failed failed.'), error: true);
    } else {
      _snack(_friendlyError(lastError ?? ''), error: true);
    }
  }

  Future<void> _delete(PromoBanner b) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Supprimer cette photo ?', 'Delete this photo?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(_t('Elle disparaîtra de la carte.', 'It will be removed from the card.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kDanger),
            child: Text(_t('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final client = Supabase.instance.client;
    setState(() => _busy = true);
    try {
      await client.from(_kPromoTable).delete().eq('id', b.id);
      if (b.storagePath.isNotEmpty) {
        try {
          await client.storage.from(_kPromoBucket).remove([b.storagePath]);
        } catch (e) {
          debugPrint('[Market] ⚠️ storage remove error: $e');
        }
      }
      ref.invalidate(promoBannersProvider(widget.cardKey));
      _snack(_t('Photo supprimée.', 'Photo deleted.'));
    } catch (e) {
      debugPrint('[Market] ❌ promo delete error: $e');
      _snack(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(promoBannersProvider(widget.cardKey));
    final banners = async.valueOrNull ?? const <PromoBanner>[];
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kAccentSoft, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.photo_library_rounded, size: 16, color: kAccentDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_t('Photos', 'Photos')} — ${widget.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.3),
                        ),
                        Text(
                          _t(
                            '${banners.length}/$_kMaxPromoPhotos · défilement auto toutes les ${_kPromoSlide.inSeconds} s',
                            '${banners.length}/$_kMaxPromoPhotos · auto-scroll every ${_kPromoSlide.inSeconds} s',
                          ),
                          style: const TextStyle(fontSize: 10.5, color: kInkMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (async.isLoading && banners.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5)),
                )
              else if (banners.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.image_outlined, size: 30, color: kInkMuted),
                      const SizedBox(height: 8),
                      Text(
                        _t('Aucune photo : la carte garde son dégradé.', 'No photo: the card keeps its gradient.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: kInkSoft, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < banners.length; i++) _thumb(banners[i], i),
                  ],
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _addPhotos(banners),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kAccent.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: Text(
                    _busy
                        ? '${_t('Envoi', 'Uploading')} $_progress'
                        : _t('Ajouter des photos', 'Add photos'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('JPG, PNG ou WebP · 5 Mo max par photo · Réservé aux administrateurs.',
                    'JPG, PNG or WebP · 5 MB max per photo · Administrators only.'),
                style: const TextStyle(fontSize: 10, color: kInkMuted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(PromoBanner b, int index) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: b.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: kSurface),
                errorWidget: (_, __, ___) => Container(
                  color: kSurface,
                  child: const Icon(Icons.broken_image_outlined, color: kInkMuted),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _busy ? null : () => _delete(b),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: kDanger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATIONS
// ============================================================================
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
        child: Transform.translate(offset: Offset(0, 18 * (1 - _curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

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
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 48, color: kInkMuted)),
        ),
      ),
    );
  }
}

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
              width: 56 + t * 12,
              height: 56 + t * 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withOpacity(0.16 * (1 - t))),
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
          radius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kAccent, kAccentDark]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: kAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
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
    return Container(width: 3.5, height: 15, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
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
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kDanger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1.1)),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: kDanger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDanger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: kDanger, size: compact ? 18 : 24),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: kDanger, fontSize: compact ? 11 : 12.5))),
          if (!compact)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_retry'), style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kAccentDark),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 340,
        decoration: BoxDecoration(color: const Color(0xFFE9EDF2), borderRadius: BorderRadius.circular(22)),
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
            Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0xFFE9EDF2), shape: BoxShape.circle)),
            const SizedBox(height: 6),
            Container(width: 52, height: 10, color: const Color(0xFFE9EDF2)),
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
          decoration: BoxDecoration(color: const Color(0xFFE9EDF2), borderRadius: BorderRadius.circular(14)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _AccentBar(color: isFlash ? kDanger : kGold),
              const SizedBox(width: 8),
              Icon(widget.icon, color: isFlash ? kDanger : kGold, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: kInk, letterSpacing: -0.3),
                ),
              ),
              if (_active && widget.liveLabel != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: kDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                  child: Text(widget.liveLabel!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kDanger)),
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
              separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.4),
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
