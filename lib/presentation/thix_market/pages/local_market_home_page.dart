// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// HOME PRODUITS LOCAUX — v2 « ultra moderne, vert »
//  • En-tête vert dégradé + recherche + HERO des 10 nouveaux produits (auto-scroll)
//  • Secteurs (liste horizontale) • Bannière circuit court
//  • Producteurs & coopératives (cartes) • Grille produits
//  • Bouton « Vendre local » retiré
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../core/african_countries.dart';
import '../core/local_sectors.dart';
import '../providers/local_market_providers.dart';
import '../widgets/products/local_hero_banner.dart';
import '../widgets/products/local_product_card.dart';

/// Hauteur du hero qui dépasse sous le fond vert.
const double _kHeroOverlap = 74;
const Color _kPageBg = Color(0xFFF5FAF6);
const Color _kMint = Color(0xFFB9F0C8);

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

  /// Les 10 produits les plus récents (par created_at décroissant).
  List<Map<String, dynamic>> _newest(List<Map<String, dynamic>> src) {
    if (src.isEmpty) return const <Map<String, dynamic>>[];
    final list = [...src];
    list.sort((a, b) => '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
    return list.take(10).toList();
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

    final all = productsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final hero = _newest(all);
    final heroLoading = productsAsync.isLoading && all.isEmpty;

    return Scaffold(
      backgroundColor: _kPageBg,
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
            SliverToBoxAdapter(child: _buildTopSection(hero, heroLoading, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildSectors(lang, counts, covers, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(child: _buildPromoBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(child: _buildProducers(producersAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(child: _buildProductsHeader(selectedSector, filtered.length, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _buildProductsGrid(productsAsync, filtered, hasMore),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ EN-TÊTE VERT + RECHERCHE + HERO ═══════════════════
  Widget _buildTopSection(List<Map<String, dynamic>> hero, bool heroLoading, String lang) {
    return Stack(
      children: [
        // Fond vert (s'arrête _kHeroOverlap px au-dessus du bas : le hero déborde)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _kHeroOverlap,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kLocalGreen, kLocalGreenDeep]),
              ),
              child: Stack(children: [
                Positioned(top: -70, right: -50, child: _halo(200, 0.08)),
                Positioned(top: 110, left: -70, child: _halo(160, 0.06)),
                Positioned(bottom: -40, right: 60, child: _halo(120, 0.07)),
              ]),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildTopBar()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  _t('Le meilleur du local,\ntous secteurs', 'The best of local,\nall sectors', 'Bora ya ndani,\nsekta zote'),
                  style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.12, letterSpacing: -0.8),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 18), child: _buildSearch()),
              LocalHeroBanner(products: hero, loading: heroLoading, lang: lang),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _halo(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('THIX ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.4)),
                const Text('LOCAL', style: TextStyle(color: _kMint, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.4)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                  child: Text(_t('100% LOCAL', '100% LOCAL', '100% NDANI'), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ]),
              Text(
                _t('L\'espace des produits de chez nous', 'The home-grown products space', 'Eneo la bidhaa za ndani'),
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/market/cart'),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_rounded, color: kLocalGreenDeep, size: 19),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: kLocalGreen, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13.5, color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('Rechercher un produit local, un producteur...', 'Search local product, producer...', 'Tafuta bidhaa ya ndani...'),
                hintStyle: TextStyle(color: ThixPolicy.textMuted.withOpacity(0.85), fontSize: 12.5),
              ),
              onChanged: (v) => ref.read(localSearchQueryProvider.notifier).state = v,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox(width: 12)
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(localSearchQueryProvider.notifier).state = '';
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ SECTION TITRE ═══════════════════
  Widget _sectionTitle(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: kLocalGreen, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5)),
          ]),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action, style: const TextStyle(color: kLocalGreen, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  // ═══════════════════ SECTEURS (liste horizontale) ═══════════════════
  Widget _buildSectors(String lang, Map<String, int> counts, Map<String, String> covers, String? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          _t('Secteurs', 'Sectors', 'Sekta'),
          action: selected != null ? _t('Tout voir', 'See all', 'Ona zote') : null,
          onAction: () => ref.read(localSectorFilterProvider.notifier).state = null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kLocalSectors.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _sectorTile(
                  label: _t('Tout', 'All', 'Zote'),
                  icon: Icons.grid_view_rounded,
                  color: kLocalGreen,
                  cover: null,
                  count: counts.values.fold<int>(0, (a, b) => a + b),
                  selected: selected == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(localSectorFilterProvider.notifier).state = null;
                  },
                );
              }
              final s = kLocalSectors[i - 1];
              return _sectorTile(
                label: s.label(lang),
                icon: s.icon,
                color: s.color,
                cover: covers[s.id],
                count: counts[s.id] ?? 0,
                selected: selected == s.id,
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

  Widget _sectorTile({
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
      selected: selected,
      label: '$label, $count',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? kLocalGreen : kLocalGreen.withOpacity(0.12), width: selected ? 2.2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: (selected ? kLocalGreen : Colors.black).withOpacity(selected ? 0.22 : 0.05),
                      blurRadius: selected ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null)
                        CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(child: Icon(icon, color: color, size: 26)),
                        )
                      else
                        Container(color: color.withOpacity(0.12), child: Center(child: Icon(icon, color: color, size: 26))),
                      if (cover != null) Container(color: color.withOpacity(0.18)),
                      if (count > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: kLocalGreen, borderRadius: BorderRadius.circular(8)),
                            child: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? kLocalGreenDeep : ThixPolicy.textMain,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════ BANNIÈRE CIRCUIT COURT ═══════════════════
  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [kLocalGreenDeep, kLocalGreen]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: kLocalGreen.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _kMint, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      _t('Circuit court', 'Short supply chain', 'Biashara ya moja kwa moja'),
                      style: const TextStyle(color: kLocalGreenDeep, fontSize: 8.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('100% Local\n& Authentique', '100% Local\n& Authentic', '100% Ndani\n& Halisi'),
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Directement des producteurs & coopératives', 'Directly from producers & cooperatives', 'Moja kwa moja kutoka kwa wakulima'),
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
              child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 34),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ PRODUCTEURS & COOPÉRATIVES ═══════════════════
  Widget _buildProducers(AsyncValue<List<Map<String, dynamic>>> async) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          _t('Producteurs & coopératives', 'Producers & cooperatives', 'Wakulima na ushirika'),
          action: _t('Voir tout', 'Show all', 'Ona zote'),
          onAction: () => context.push('/market/shops'),
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLocalGreen))),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (producers) {
            if (producers.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _t('Aucun producteur pour le moment. Soyez le premier !', 'No producer yet. Be the first!', 'Hakuna mkulima bado. Kuwa wa kwanza!'),
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                ),
              );
            }
            final list = producers.take(8).toList();
            return SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _producerCard(list[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _producerCard(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final logo = p['logo_url']?.toString();
    final name = (p['name'] ?? '').toString();
    final city = AfricanCountries.locationLine(city: (p['city'] ?? '').toString(), code: p['country']?.toString());
    final count = p['local_count'] ?? 0;
    final hasLogo = logo != null && logo.startsWith('http');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (id.isNotEmpty) context.push('/market/shop/$id');
      },
      child: Container(
        width: 262,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLocalGreen.withOpacity(0.10)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kLocalGreenSoft,
                border: Border.all(color: kLocalGreen.withOpacity(0.25), width: 1.5),
                image: hasLogo ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover) : null,
              ),
              child: !hasLogo ? const Icon(Icons.agriculture_rounded, color: kLocalGreen, size: 24) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: ThixPolicy.textMain)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: kLocalGreen),
                    const SizedBox(width: 2),
                    Expanded(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary))),
                  ]),
                  const SizedBox(height: 7),
                  Row(children: [
                    _tag(_t('Vérifié', 'Verified', 'Imethibitishwa'), kLocalGreen, icon: Icons.verified_rounded),
                    const SizedBox(width: 6),
                    Flexible(child: _tag('$count ${_t('produits', 'products', 'bidhaa')}', kLocalGreenDeep)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 9, color: color), const SizedBox(width: 3)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color))),
      ]),
    );
  }

  // ═══════════════════ PRODUITS LOCAUX ═══════════════════
  Widget _buildProductsHeader(String? sector, int count, String lang) {
    final s = localSectorById(sector);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: kLocalGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          if (s != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: s.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(s.icon, size: 16, color: s.color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              s != null ? s.label(lang) : _t('Produits locaux', 'Local products', 'Bidhaa za ndani'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kLocalGreen.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
            child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kLocalGreenDeep)),
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
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                  _t('Erreur de chargement des produits locaux', 'Failed to load local products', 'Hitilafu ya kupakua'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ThixPolicy.danger, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(localProductsProvider.notifier).refresh(),
                  child: Text(_t('Réessayer', 'Retry', 'Jaribu tena'), style: const TextStyle(color: kLocalGreen, fontWeight: FontWeight.w800)),
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
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: kLocalGreen.withOpacity(0.08), shape: BoxShape.circle),
                    child: Icon(Icons.agriculture_rounded, size: 40, color: kLocalGreen.withOpacity(0.55)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Aucun produit local dans cette sélection', 'No local product in this selection', 'Hakuna bidhaa ya ndani hapa'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez pour actualiser ou changez de secteur.', 'Pull to refresh or change sector.', 'Vuta kuburudisha au badilisha sekta.'),
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
