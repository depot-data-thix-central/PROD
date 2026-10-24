// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// HOME PRODUITS LOCAUX — v2 ULTRA MODERNE
// ============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../core/african_countries.dart';
import '../core/currency_service.dart';
import '../core/local_sectors.dart';
import '../providers/currency_provider.dart';
import '../providers/local_market_providers.dart';
import '../providers/market_providers.dart' show myShopIdProvider;
import '../widgets/products/local_product_card.dart';

const Duration _kHeroAutoPlay = Duration(seconds: 4);
const int _kMaxHeroItems = 10;
const double _kHeroHeight = 210;

class LocalMarketHomePage extends ConsumerStatefulWidget {
  const LocalMarketHomePage({super.key});
  @override
  ConsumerState<LocalMarketHomePage> createState() => _LocalMarketHomePageState();
}

class _LocalMarketHomePageState extends ConsumerState<LocalMarketHomePage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final PageController _heroCtrl = PageController(viewportFraction: 0.92);
  Timer? _heroTimer;
  int _heroIndex = 0;
  bool _heroReady = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    debugPrint('[LocalMarket] 🏠 Local home v2 opened');
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      ref.read(localProductsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  String _t(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  void _startHeroAuto(int count) {
    if (_heroReady || count <= 1) return;
    _heroReady = true;
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(_kHeroAutoPlay, (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % count;
      _heroCtrl.animateToPage(
        _heroIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openSellForm() async {
    HapticFeedback.mediumImpact();

    String? shopId = ref.read(myShopIdProvider).valueOrNull;
    if (shopId == null) {
      try {
        shopId = await ref.read(myShopIdProvider.future);
      } catch (_) {}
    }
    if (shopId == null) shopId = await _fetchMyShopIdDirect();

    if (!mounted) return;
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
              'Créez d\'abord une boutique pour vendre un produit local',
              'Create a shop first to sell a local product')),
          backgroundColor: ThixPolicy.warning,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: _t('Créer', 'Create'),
            textColor: Colors.white,
            onPressed: () => context.push('/market/shop/create'),
          ),
        ),
      );
      return;
    }

    final created = await context.push<bool>('/market/local/create', extra: shopId);
    if (created == true && mounted) invalidateLocalProviders(ref);
  }

  Future<String?> _fetchMyShopIdDirect() async {
    try {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser?.id;
      if (uid == null) return null;
      final res = await db
          .from('shops')
          .select('id,type')
          .eq('owner_id', uid)
          .order('created_at', ascending: true)
          .limit(5)
          .timeout(const Duration(seconds: 10));
      final list = List<Map<String, dynamic>>.from(res as List);
      if (list.isEmpty) return null;
      final pick = list.firstWhere(
        (s) => s['type']?.toString() != 'supermarket',
        orElse: () => list.first,
      );
      return pick['id']?.toString();
    } catch (e) {
      debugPrint('[LocalMarket] ⚠️ direct shop resolve: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final productsAsync = ref.watch(localProductsProvider);
    final filtered = ref.watch(filteredLocalProductsProvider);
    final producersAsync = ref.watch(localProducersProvider);
    final selectedSector = ref.watch(localSectorFilterProvider);
    final hasMore = ref.read(localProductsProvider.notifier).hasMore;
    ref.watch(currencyProvider);

    final newest = (productsAsync.valueOrNull ?? const <Map<String, dynamic>>[])
        .take(_kMaxHeroItems)
        .toList();

    productsAsync.whenData((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startHeroAuto(newest.length);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: RefreshIndicator(
        color: kLocalGreen,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          invalidateLocalProviders(ref);
          await ref.read(localProductsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildHero(newest)),
            SliverToBoxAdapter(child: _buildCategories(lang, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildPromoBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProducers(producersAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProductsHeader(selectedSector, filtered.length, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            _buildProductsGrid(productsAsync, filtered, hasMore),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLocalGreen, kLocalGreenDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            children: [
              Row(
                children: [
                  _headerCircle(Icons.arrow_back_rounded, () => context.pop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('THIX ',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.4)),
                            const Text('LOCAL',
                                style: TextStyle(color: Color(0xFFB9F0C8), fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.4)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_t('100% LOCAL', '100% LOCAL', '100% NDANI'),
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                            ),
                          ],
                        ),
                        Text(
                          _t('L\'espace des produits de chez nous', 'Home-grown products space', 'Eneo la bidhaa za ndani'),
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  _headerCircle(Icons.add_rounded, _openSellForm,
                      tooltip: _t('Publier un produit local', 'Publish a local product')),
                  const SizedBox(width: 8),
                  _headerCircle(Icons.shopping_cart_rounded, () => context.push('/market/cart')),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded, color: kLocalGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 13.5, color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: _t('Rechercher un produit, un producteur...', 'Search product, producer...', 'Tafuta bidhaa...'),
                          hintStyle: TextStyle(color: ThixPolicy.textMuted.withOpacity(0.7), fontSize: 12.5),
                        ),
                        onChanged: (v) => ref.read(localSearchQueryProvider.notifier).state = v,
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: ThixPolicy.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(localSearchQueryProvider.notifier).state = '';
                        },
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

  Widget _headerCircle(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return Semantics(
      button: true,
      label: tooltip ?? 'action',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildHero(List<Map<String, dynamic>> newest) {
    if (newest.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          height: _kHeroHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kLocalGreen, kLocalGreenDeep]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.agriculture_rounded, color: Colors.white.withOpacity(0.7), size: 44),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _t('Les nouveautés locales apparaîtront ici', 'Local novelties will appear here', 'Bidhaa mpya zitaonekana hapa'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: _kHeroHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                _heroTimer?.cancel();
                _heroReady = false;
              } else if (n is ScrollEndNotification) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _startHeroAuto(newest.length);
                });
              }
              return false;
            },
            child: PageView.builder(
              controller: _heroCtrl,
              itemCount: newest.length,
              onPageChanged: (i) => setState(() => _heroIndex = i),
              itemBuilder: (_, i) => _heroItem(newest[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(newest.length, (i) {
            final active = i == _heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 20 : 6,
              decoration: BoxDecoration(
                color: active ? kLocalGreen : kLocalGreen.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _heroItem(Map<String, dynamic> p) {
    final lang = Localizations.localeOf(context).languageCode;
    final id = p['id']?.toString() ?? '';
    final title = (p['title'] ?? '').toString();
    final sector = localSectorById(p['local_sector']?.toString());
    final producer = (p['producer_name'] ?? '').toString();

    String? img;
    final u = p['image_url']?.toString();
    if (u != null && u.startsWith('http')) {
      img = u;
    } else if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      final f = (p['images'] as List).first.toString();
      if (f.startsWith('http')) img = f;
    }

    final displayCur = ref.watch(currencyProvider);
    final sellerCur = (p['currency'] ?? 'CDF').toString().toUpperCase();
    final svc = CurrencyService.instance;
    final orig = (p['price'] as num?)?.toDouble() ?? 0;
    final disc = (p['discount_price'] as num?)?.toDouble();
    final base = (disc != null && disc > 0 && disc < orig) ? disc : orig;
    final priceLabel = svc.formatPrice(
      svc.convert(base, from: sellerCur, to: displayCur),
      currencyCode: displayCur,
      lang: lang,
    );
    final unit = p['unit']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (id.isNotEmpty) context.push('/market/product/$id');
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: kLocalGreenSoft,
              boxShadow: [BoxShadow(color: kLocalGreen.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null)
                  CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.10), Colors.black.withOpacity(0.62)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: (sector?.color ?? kLocalGreen).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sector?.icon ?? Icons.eco_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(sector?.label(lang) ?? _t('Local', 'Local'),
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_t('NOUVEAU', 'NEW', 'MPYA'),
                        style: const TextStyle(color: Color(0xFF78350F), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.15),
                      ),
                      if (producer.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.handshake_rounded, size: 10, color: Color(0xFFB9F0C8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(producer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(priceLabel,
                                    style: const TextStyle(color: kLocalGreenDeep, fontSize: 12.5, fontWeight: FontWeight.w900)),
                                if (unit.isNotEmpty)
                                  Text(' / ${kLocalUnitLabel(unit)}',
                                      style: TextStyle(color: kLocalGreenDeep.withOpacity(0.7), fontSize: 9.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_rounded, size: 13, color: kLocalGreenDeep),
                          ),
                        ],
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

  Widget _buildCategories(String lang, String? selected) {
    final counts = ref.watch(localSectorCountsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Catégories', 'Categories', 'Kategoria'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ThixPolicy.textMain, letterSpacing: -0.4),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: () => ref.read(localSectorFilterProvider.notifier).state = null,
                  child: Text(_t('Tout voir', 'See all', 'Ona zote'),
                      style: const TextStyle(color: kLocalGreen, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: kLocalSectors.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _categoryTile(
                  label: _t('Tout', 'All', 'Zote'),
                  icon: Icons.grid_view_rounded,
                  color: ThixPolicy.primaryDeep,
                  selected: selected == null,
                  count: counts.values.fold<int>(0, (a, b) => a + b),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(localSectorFilterProvider.notifier).state = null;
                  },
                );
              }
              final s = kLocalSectors[i - 1];
              return _categoryTile(
                label: s.label(lang),
                icon: s.icon,
                color: s.color,
                selected: selected == s.id,
                count: counts[s.id] ?? 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(localSectorFilterProvider.notifier).state = (selected == s.id) ? null : s.id;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryTile({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required int count,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label, $count',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: selected ? color : color.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : color.withOpacity(0.25),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Icon(icon, color: selected ? Colors.white : color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? color : ThixPolicy.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [kLocalGreenDeep, kLocalGreen],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: kLocalGreen.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08))),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(6)),
                        child: Text(_t('Circuit court', 'Short supply chain', 'Biashara moja kwa moja'),
                            style: const TextStyle(color: Color(0xFF78350F), fontSize: 8.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t('100% Local\n& Authentique', '100% Local\n& Authentic', '100% Ndani\n& Halisi'),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t('Directement des producteurs & coopératives', 'Directly from producers & cooperatives', 'Moja kwa moja kutoka wakulima'),
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducers(AsyncValue<List<Map<String, dynamic>>> async) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Producteurs & coopératives', 'Producers & cooperatives', 'Wakulima na ushirika'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ThixPolicy.textMain, letterSpacing: -0.4),
              ),
              GestureDetector(
                onTap: () => context.push('/market/shops'),
                child: Text(_t('Voir tout', 'See all', 'Ona zote'),
                    style: const TextStyle(color: kLocalGreen, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const SizedBox(height: 60, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLocalGreen)))),
            error: (_, __) => const SizedBox.shrink(),
            data: (producers) {
              if (producers.isEmpty) {
                return Text(
                  _t('Aucun producteur pour le moment. Soyez le premier !', 'No producer yet. Be the first!', 'Hakuna mkulima bado!'),
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: producers.length > 3 ? 3 : producers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = producers[i];
                  final id = p['id']?.toString() ?? '';
                  final logo = p['logo_url']?.toString();
                  final name = (p['name'] ?? '').toString();
                  final city = AfricanCountries.locationLine(city: (p['city'] ?? '').toString(), code: p['country']?.toString());
                  final count = p['local_count'] ?? 0;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (id.isNotEmpty) context.push('/market/shop/$id');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kLocalGreenSoft,
                              image: (logo != null && logo.startsWith('http'))
                                  ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (logo == null || !logo.startsWith('http'))
                                ? const Icon(Icons.agriculture_rounded, color: kLocalGreen, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
                                const SizedBox(height: 2),
                                Text(city, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary)),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    _tag(_t('Vérifié', 'Verified', 'Imethibitishwa'), kLocalGreen),
                                    const SizedBox(width: 6),
                                    _tag('$count ${_t('locaux', 'local', 'ndani')}', ThixPolicy.primaryDeep),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildProductsHeader(String? sector, int count, String lang) {
    final s = localSectorById(sector);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (s != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(s.icon, size: 15, color: s.color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              s != null ? s.label(lang) : _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ThixPolicy.textMain, letterSpacing: -0.4),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: kLocalGreen.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kLocalGreenDeep)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(
    AsyncValue<List<Map<String, dynamic>>> async,
    List<Map<String, dynamic>> filtered,
    bool hasMore,
  ) {
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kLocalGreen))),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_t('Erreur de chargement', 'Loading error'), textAlign: TextAlign.center,
              style: const TextStyle(color: ThixPolicy.danger, fontSize: 12.5)),
        ),
      ),
      data: (_) {
        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.agriculture_rounded, size: 52, color: kLocalGreen.withOpacity(0.30)),
                  const SizedBox(height: 12),
                  Text(
                    _t('Aucun produit local dans cette sélection', 'No local product in this selection', 'Hakuna bidhaa hapa'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez pour actualiser', 'Pull to refresh', 'Vuta kuburudisha'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 268,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i >= filtered.length) {
                  return const Center(child: CircularProgressIndicator(color: kLocalGreen, strokeWidth: 2));
                }
                final p = filtered[i];
                return LocalProductCard(key: ValueKey('local_${p['id']}'), product: p);
              },
              childCount: filtered.length + (hasMore ? 1 : 0),
            ),
          ),
        );
      },
    );
  }
}
