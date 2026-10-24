// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// HOME PRODUITS LOCAUX — design ultra moderne
//  • Header vert premium + recherche flottante
//  • Hero carousel auto-scroll (10 nouveaux produits)
//  • Secteurs en scroll horizontal (cartes modernes)
//  • Producteurs & coopératives
//  • Grille produits locaux
//  • FAB "Vendre local" supprimé
// ============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../core/african_countries.dart';
import '../core/local_sectors.dart';
import '../providers/local_market_providers.dart';
import '../widgets/products/local_product_card.dart';

class LocalMarketHomePage extends ConsumerStatefulWidget {
  const LocalMarketHomePage({super.key});
  @override
  ConsumerState<LocalMarketHomePage> createState() => _LocalMarketHomePageState();
}

class _LocalMarketHomePageState extends ConsumerState<LocalMarketHomePage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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
    super.dispose();
  }

  String _t(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  // ─── Helpers produit (défensifs) ───
  String _productName(Map<String, dynamic> p) =>
      (p['name'] ?? p['title'] ?? _t('Produit local', 'Local product', 'Bidhaa ya ndani')).toString();

  String? _productImage(Map<String, dynamic> p) {
    final candidates = [
      p['image_url'], p['main_image'], p['thumbnail'],
      p['photo_url'], p['cover_url'], p['image'],
    ];
    for (final c in candidates) {
      final s = c?.toString() ?? '';
      if (s.startsWith('http')) return s;
    }
    return null;
  }

  double? _productPrice(Map<String, dynamic> p) {
    final v = p['price'] ?? p['amount'] ?? p['unit_price'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _productCurrency(Map<String, dynamic> p) =>
      (p['currency'] ?? 'XOF').toString();

  String? _shopName(Map<String, dynamic> p) {
    final direct = p['shop_name'];
    if (direct != null && direct.toString().isNotEmpty) return direct.toString();
    final shop = p['shop'];
    if (shop is Map && shop['name'] != null) return shop['name'].toString();
    final shops = p['shops'];
    if (shops is Map && shops['name'] != null) return shops['name'].toString();
    return null;
  }

  String _formatPrice(double? price, String currency) {
    if (price == null) return '';
    final whole = price == price.truncateToDouble();
    final s = whole ? price.toInt().toString() : price.toStringAsFixed(2);
    return '$s $currency';
  }

  List<Map<String, dynamic>> _newestProducts(List<Map<String, dynamic>> products, int count) {
    if (products.isEmpty) return const [];
    final sorted = [...products];
    try {
      sorted.sort((a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });
    } catch (_) {}
    return sorted.take(count).toList();
  }

  void _openProduct(String id) {
    if (id.isEmpty) return;
    HapticFeedback.selectionClick();
    try {
      context.push('/market/product/$id');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final productsAsync = ref.watch(localProductsProvider);
    final filtered = ref.watch(filteredLocalProductsProvider);
    final counts = ref.watch(localSectorCountsProvider);
    final covers = ref.watch(localSectorCoverProvider);
    final producersAsync = ref.watch(localProducersProvider);
    final selectedSector = ref.watch(localSectorFilterProvider);
    final hasMore = ref.read(localProductsProvider.notifier).hasMore;

    final allProducts = productsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final newest = _newestProducts(allProducts, 10);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
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
            SliverToBoxAdapter(child: _buildHeroCarousel(newest)),
            SliverToBoxAdapter(child: _buildSectors(lang, counts, covers, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProducers(producersAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildProductsHeader(selectedSector, filtered.length, lang),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _buildProductsGrid(productsAsync, filtered, hasMore),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ HEADER PREMIUM ═══════════════════
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLocalGreen, kLocalGreenDeep],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: kLocalGreenDeep.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row logo + cart
              Row(
                children: [
                  _circleIcon(Icons.arrow_back_rounded, onTap: () => context.pop()),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Row(
                      children: [
                        Text('THIX ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: -0.5)),
                        Text('LOCAL',
                            style: TextStyle(
                                color: Color(0xFFB9F0C8),
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: -0.5)),
                        SizedBox(width: 8),
                        _HeaderBadge(),
                      ],
                    ),
                  ),
                  _circleIcon(
                    Icons.shopping_bag_rounded,
                    filled: true,
                    onTap: () => context.push('/market/cart'),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Recherche flottante
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded,
                        color: ThixPolicy.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: ThixPolicy.textMain,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: _t('Rechercher un produit local...',
                              'Search local product...', 'Tafuta bidhaa ya ndani...'),
                          hintStyle: TextStyle(
                              color: ThixPolicy.textMuted.withOpacity(0.8),
                              fontSize: 13),
                        ),
                        onChanged: (v) {
                          ref.read(localSearchQueryProvider.notifier).state = v;
                          setState(() {});
                        },
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: ThixPolicy.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(localSearchQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tagline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  _t(
                    'Trouvez vos produits\nlocaux, tous secteurs',
                    'Find your local\nproducts, all sectors',
                    'Pata bidhaa zako\nza ndani, sekta zote',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, {VoidCallback? onTap, bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: filled ? kLocalGreenDeep : Colors.white, size: 18),
      ),
    );
  }

  // ═══════════════════ HERO CAROUSEL ═══════════════════
  Widget _buildHeroCarousel(List<Map<String, dynamic>> newest) {
    if (newest.isEmpty) return const SizedBox.shrink();
    return _HeroCarousel(
      products: newest,
      onTap: _openProduct,
      nameOf: _productName,
      imageOf: _productImage,
      priceOf: (p) => _formatPrice(_productPrice(p), _productCurrency(p)),
      shopOf: _shopName,
      newLabel: _t('NOUVEAU', 'NEW', 'MPYA'),
    );
  }

  // ═══════════════════ SECTEURS (scroll horizontal) ═══════════════════
  Widget _buildSectors(
    String lang,
    Map<String, int> counts,
    Map<String, String> covers,
    String? selected,
  ) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Tous les secteurs', 'All sectors', 'Sekta zote'),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                    letterSpacing: -0.5),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: () => ref
                      .read(localSectorFilterProvider.notifier)
                      .state = null,
                  child: Text(_t('Tout voir', 'See all', 'Ona zote'),
                      style: const TextStyle(
                          color: kLocalGreen,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: kLocalSectors.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _sectorCard(
                  label: _t('Tout', 'All', 'Zote'),
                  icon: Icons.grid_view_rounded,
                  color: ThixPolicy.primaryDeep,
                  cover: null,
                  count: total,
                  selected: selected == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(localSectorFilterProvider.notifier).state = null;
                  },
                );
              }
              final s = kLocalSectors[i - 1];
              return _sectorCard(
                label: s.label(lang),
                icon: s.icon,
                color: s.color,
                cover: covers[s.id],
                count: counts[s.id] ?? 0,
                selected: selected == s.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(localSectorFilterProvider.notifier).state =
                      (selected == s.id) ? null : s.id;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectorCard({
    required String label,
    required IconData icon,
    required Color color,
    required String? cover,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label, $count',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 88,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.14) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4)),
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(13),
                  image: (cover != null && cover.startsWith('http'))
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(cover),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (cover == null || !cover.startsWith('http'))
                    ? Icon(icon, color: color, size: 24)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : ThixPolicy.textMain,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ThixPolicy.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════ PRODUCTEURS ═══════════════════
  Widget _buildProducers(AsyncValue<List<Map<String, dynamic>>> async) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Producteurs & coopératives', 'Producers & cooperatives',
                    'Wakulima na ushirika'),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                    letterSpacing: -0.5),
              ),
              GestureDetector(
                onTap: () => context.push('/market/shops'),
                child: Text(_t('Voir tout', 'Show all', 'Ona zote'),
                    style: const TextStyle(
                        color: ThixPolicy.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(
                height: 70,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kLocalGreen)))),
            error: (_, __) => const SizedBox.shrink(),
            data: (producers) {
              if (producers.isEmpty) {
                return Text(
                  _t('Aucun producteur pour le moment. Soyez le premier !',
                      'No producer yet. Be the first!',
                      'Hakuna mkulima bado. Kuwa wa kwanza!'),
                  style: const TextStyle(
                      color: ThixPolicy.textSecondary, fontSize: 12),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: producers.length > 3 ? 3 : producers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = producers[i];
                  final id = p['id']?.toString() ?? '';
                  final logo = p['logo_url']?.toString();
                  final name = (p['name'] ?? '').toString();
                  final city = AfricanCountries.locationLine(
                    city: (p['city'] ?? '').toString(),
                    code: p['country']?.toString(),
                  );
                  final count = p['local_count'] ?? 0;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (id.isNotEmpty) context.push('/market/shop/$id');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kLocalGreenSoft,
                              image: (logo != null && logo.startsWith('http'))
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(logo),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (logo == null || !logo.startsWith('http'))
                                ? const Icon(Icons.agriculture_rounded,
                                    color: kLocalGreen, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: ThixPolicy.textMain)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 10,
                                        color: ThixPolicy.textMuted),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(city,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color:
                                                  ThixPolicy.textSecondary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _tag(
                                        _t('Vérifié', 'Verified',
                                            'Imethibitishwa'),
                                        kLocalGreen),
                                    const SizedBox(width: 6),
                                    _tag(
                                        '$count ${_t('produits locaux', 'local products', 'bidhaa za ndani')}',
                                        ThixPolicy.primaryDeep),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: ThixPolicy.textMuted, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ═══════════════════ HEADER PRODUITS ═══════════════════
  Widget _buildProductsHeader(String? sector, int count, String lang) {
    final s = localSectorById(sector);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (s != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: s.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(s.icon, size: 16, color: s.color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              s != null
                  ? s.label(lang)
                  : _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: ThixPolicy.textMain,
                  letterSpacing: -0.5),
            ),
          ),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  // ═══════════════════ GRILLE PRODUITS ═══════════════════
  Widget _buildProductsGrid(
    AsyncValue<List<Map<String, dynamic>>> async,
    List<Map<String, dynamic>> filtered,
    bool hasMore,
  ) {
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: kLocalGreen)),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                    _t('Erreur de chargement des produits locaux',
                        'Failed to load local products', 'Hitilafu ya kupakua'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: ThixPolicy.danger, fontSize: 12.5)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.read(localProductsProvider.notifier).refresh(),
                  child: Text(_t('Réessayer', 'Retry', 'Jaribu tena')),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (_) {
        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.agriculture_rounded,
                      size: 52, color: kLocalGreen.withOpacity(0.35)),
                  const SizedBox(height: 12),
                  Text(
                    _t('Aucun produit local dans cette sélection',
                        'No local product in this selection',
                        'Hakuna bidhaa ya ndani hapa'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez pour actualiser.',
                        'Pull to refresh.', 'Vuta kuburudisha.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: ThixPolicy.textSecondary),
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
                  return const Center(
                      child: CircularProgressIndicator(
                          color: kLocalGreen, strokeWidth: 2));
                }
                final p = filtered[i];
                return LocalProductCard(
                    key: ValueKey('local_${p['id']}'), product: p);
              },
              childCount: filtered.length + (hasMore ? 1 : 0),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER BADGE
// ═══════════════════════════════════════════════════════════════════════════
class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('100% LOCAL',
          style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO CAROUSEL — auto-scroll 10 nouveaux produits
// ═══════════════════════════════════════════════════════════════════════════
class _HeroCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final void Function(String id) onTap;
  final String Function(Map<String, dynamic> p) nameOf;
  final String? Function(Map<String, dynamic> p) imageOf;
  final String Function(Map<String, dynamic> p) priceOf;
  final String? Function(Map<String, dynamic> p) shopOf;
  final String newLabel;

  const _HeroCarousel({
    required this.products,
    required this.onTap,
    required this.nameOf,
    required this.imageOf,
    required this.priceOf,
    required this.shopOf,
    required this.newLabel,
  });

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _pc;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.92);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (widget.products.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients) return;
      final next = (_current + 1) % widget.products.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length != widget.products.length) {
      _current = 0;
      if (_pc.hasClients) _pc.jumpToPage(0);
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _timer?.cancel();
                } else if (n is ScrollEndNotification) {
                  _start();
                }
                return false;
              },
              child: PageView.builder(
                controller: _pc,
                itemCount: widget.products.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) {
                  final p = widget.products[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _HeroSlide(
                      product: p,
                      onTap: () =>
                          widget.onTap(p['id']?.toString() ?? ''),
                      nameOf: widget.nameOf,
                      imageOf: widget.imageOf,
                      priceOf: widget.priceOf,
                      shopOf: widget.shopOf,
                      newLabel: widget.newLabel,
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.products.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.products.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? kLocalGreen : kLocalGreen.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO SLIDE
// ═══════════════════════════════════════════════════════════════════════════
class _HeroSlide extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final String Function(Map<String, dynamic> p) nameOf;
  final String? Function(Map<String, dynamic> p) imageOf;
  final String Function(Map<String, dynamic> p) priceOf;
  final String? Function(Map<String, dynamic> p) shopOf;
  final String newLabel;

  const _HeroSlide({
    required this.product,
    required this.onTap,
    required this.nameOf,
    required this.imageOf,
    required this.priceOf,
    required this.shopOf,
    required this.newLabel,
  });

  @override
  Widget build(BuildContext context) {
    final img = imageOf(product);
    final name = nameOf(product);
    final price = priceOf(product);
    final shop = shopOf(product);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kLocalGreenDeep.withOpacity(0.20),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (img != null)
                CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: kLocalGreenSoft),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              else
                _placeholder(),
              // Gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.4, 0.62, 1.0],
                  ),
                ),
              ),
              // Badge NOUVEAU
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 10, color: ThixPolicy.inkDeep),
                      const SizedBox(width: 4),
                      Text(
                        newLabel,
                        style: const TextStyle(
                            color: ThixPolicy.inkDeep,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
              // Contenu bas
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (price.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    price,
                                    style: const TextStyle(
                                        color: kLocalGreenDeep,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (shop != null && shop.isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.storefront_rounded,
                                          size: 11,
                                          color:
                                              Colors.white.withOpacity(0.85)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          shop,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
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

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLocalGreen, kLocalGreenDeep],
        ),
      ),
      child: const Center(
        child: Icon(Icons.agriculture_rounded, size: 60, color: Colors.white54),
      ),
    );
  }
}
