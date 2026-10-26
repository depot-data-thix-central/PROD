// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// DRC PRODUCTS PORTAL — v4.2 « Produits de la semaine = LocalProductCard »
//  • ✅ Les 4 piliers fixes → CARTES AUTO-DÉFILENTES gérées par modérateur/admin
//  • ✅ Produits de la semaine : EXACTEMENT la carte LocalProductCard
//  • ✅ Producteurs & coopératives = COOPÉRATIVES UNIQUEMENT
//  • ✅ Nos Partenaires (DrcPartnersBand) avec logique complète conservée
//  • ✅ Cartes portail réduites (84px) + Slogan compact (46px)
//  • ✅ Design RDC strictement conservé
// ============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/african_countries.dart';
import '../core/drc_portal_theme.dart';
import '../core/local_sectors.dart';
import '../providers/drc_portal_media_providers.dart';
import '../providers/local_market_providers.dart';
import '../providers/local_moderation_providers.dart';
import '../widgets/products/drc_portal_widgets.dart';
import '../widgets/products/local_hero_banner.dart';
import '../widgets/products/local_product_card.dart';

/// Hauteur du hero qui dépasse sous le fond bleu.
const double _kHeroOverlap = 120;

/// Dimensions de la carte « Produit de la semaine » (même carte que la grille).
const double _kWeeklyCardWidth = 180;
const double _kWeeklyCardHeight = 268;
const int _kWeeklyMax = 10;

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
    final cooperativesAsync = ref.watch(localCooperativesProvider);
    final highlightsAsync = ref.watch(drcPortalHighlightsProvider);
    final weeklyAsync = ref.watch(weeklyProductsProvider);
    final selectedSector = ref.watch(localSectorFilterProvider);
    final hasMore = ref.read(localProductsProvider.notifier).hasMore;

    final all = productsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final hero = _newest(all);
    final heroLoading = productsAsync.isLoading && all.isEmpty;

    return Scaffold(
      backgroundColor: kDrcBg,
      body: RefreshIndicator(
        color: kDrcBlue,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          invalidateLocalProviders(ref);
          ref.invalidate(drcPortalMediaProvider(kDrcKindLogo));
          ref.invalidate(drcPortalMediaProvider(kDrcKindPartner));
          ref.invalidate(drcPortalEditorProvider);
          ref.invalidate(drcPortalHighlightsProvider);
          ref.invalidate(weeklyProductsProvider);
          ref.invalidate(localCooperativesProvider);
          await ref.read(localProductsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildTopSection(hero, heroLoading, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildSectors(lang, counts, covers, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ✅ NOS PARTENAIRES — Logique complète (widget externe DrcPartnersBand)
            SliverToBoxAdapter(child: DrcPartnersBand(lang: lang)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // ✅ CARTES AUTO-DÉFILENTES (remplacent les 4 piliers fixes)
            SliverToBoxAdapter(child: _buildHighlights(highlightsAsync, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // ✅ SLOGAN COMPACT
            SliverToBoxAdapter(child: _buildSlogan()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // ✅ PRODUITS DE LA SEMAINE — carte LocalProductCard exacte
            SliverToBoxAdapter(child: _buildWeekly(weeklyAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProducers(cooperativesAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProductsHeader(selectedSector, filtered.length, lang)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _buildProductsGrid(productsAsync, filtered, hasMore),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ EN-TÊTE OFFICIEL + LOGO + RECHERCHE + HERO ═══════════════════
  Widget _buildTopSection(List<Map<String, dynamic>> hero, bool heroLoading, String lang) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _kHeroOverlap,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kDrcNavy, kDrcBlueDeep, kDrcBlue],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(children: [
                Positioned(top: -70, right: -50, child: _halo(200, 0.07, Colors.white)),
                Positioned(top: 130, left: -70, child: _halo(160, 0.06, Colors.white)),
                Positioned(bottom: -40, right: 50, child: _halo(130, 0.10, kDrcYellow)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: kDrcYellow, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            _t('PORTAIL OFFICIEL', 'OFFICIAL PORTAL', 'PORTALI RASMI'),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _t('Les produits\n', 'The products\n', 'Bidhaa za\n'),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const TextSpan(text: 'Made in DRC', style: TextStyle(color: kDrcYellow)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('Nos richesses, notre fierté !', 'Our riches, our pride!', 'Utajiri wetu, fahari yetu!'),
                      style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const DrcTricolorStripe(width: 64, height: 4),
                  ],
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

  Widget _halo(double size, double opacity, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)),
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
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: DrcPortalLogo())),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.push('/market/cart'),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_rounded, color: kDrcBlueDeep, size: 19),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: kDrcBlue, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              cursorColor: kDrcBlue,
              style: const TextStyle(fontSize: 13.5, color: kDrcInk, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('Rechercher un produit congolais, un producteur...', 'Search a Congolese product, producer...', 'Tafuta bidhaa ya Kongo...'),
                hintStyle: TextStyle(color: kDrcMuted.withOpacity(0.95), fontSize: 12.5),
              ),
              onChanged: (v) => ref.read(localSearchQueryProvider.notifier).state = v,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox(width: 12)
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: kDrcSub),
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
          Flexible(
            child: Row(children: [
              const DrcTricolorBar(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kDrcInk, letterSpacing: -0.5),
                ),
              ),
            ]),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action, style: const TextStyle(color: kDrcBlue, fontSize: 12.5, fontWeight: FontWeight.w800)),
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
                  color: kDrcBlue,
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
                  border: Border.all(color: selected ? kDrcBlue : kDrcLine, width: selected ? 2.2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: (selected ? kDrcBlue : Colors.black).withOpacity(selected ? 0.22 : 0.05),
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
                            decoration: BoxDecoration(color: kDrcRed, borderRadius: BorderRadius.circular(8)),
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
                  color: selected ? kDrcBlueDeep : kDrcInk,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════ ✅ CARTES AUTO-DÉFILENTES (modérées) — HAUTEUR RÉDUITE ═══════════════════
  Widget _buildHighlights(AsyncValue<List<PortalHighlight>> async, String lang) {
    return async.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _HighlightsCarousel(items: items, lang: lang);
      },
    );
  }

  // ═══════════════════ ✅ PRODUITS DE LA SEMAINE — LocalProductCard EXACTE ═══════════════════
  Widget _buildWeekly(AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        final displayed = products.take(_kWeeklyMax).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const DrcTricolorBar(),
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded, color: kDrcYellow, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _t('Produits de la semaine', 'Products of the week', 'Bidhaa za wiki'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kDrcInk, letterSpacing: -0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _kWeeklyCardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = displayed[i];
                  return SizedBox(
                    width: _kWeeklyCardWidth,
                    child: LocalProductCard(
                      key: ValueKey('weekly_${p['id']}'),
                      product: p,
                      width: _kWeeklyCardWidth,
                      height: _kWeeklyCardHeight,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════ ✅ SLOGAN COMPACT (hauteur réduite) ═══════════════════
  Widget _buildSlogan() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [kDrcBlueDeep, kDrcBlue]),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 5,
                height: 46,
                child: Column(
                  children: [
                    Expanded(child: ColoredBox(color: kDrcYellow, child: SizedBox.expand())),
                    Expanded(child: ColoredBox(color: kDrcRed, child: SizedBox.expand())),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _t('Consommons congolais, valorisons notre pays !', 'Let us consume Congolese, let us value our country!',
                        'Tutumie bidhaa za Kongo, tuthamini nchi yetu!'),
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, height: 1.2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.favorite_rounded, color: kDrcYellow, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════ ✅ PRODUCTEURS = COOPÉRATIVES UNIQUEMENT ═══════════════════
  Widget _buildProducers(AsyncValue<List<Map<String, dynamic>>> async) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          _t('Producteurs & coopératives', 'Producers & cooperatives', 'Wakulima na ushirika'),
          action: _t('Voir tout', 'Show all', 'Ona zote'),
          onAction: () => context.push('/market/local/producers'),
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (producers) {
            if (producers.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _t('Aucune coopérative pour le moment. Soyez le premier !', 'No cooperative yet. Be the first!', 'Hakuna ushirika bado. Kuwa wa kwanza!'),
                  style: const TextStyle(color: kDrcSub, fontSize: 12),
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
          border: Border.all(color: kDrcLine),
          boxShadow: [BoxShadow(color: kDrcBlueDeep.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kDrcSoft,
                border: Border.all(color: kDrcBlue.withOpacity(0.25), width: 1.5),
                image: hasLogo ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover) : null,
              ),
              child: !hasLogo ? const Icon(Icons.agriculture_rounded, color: kDrcBlue, size: 24) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: kDrcInk)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: kDrcRed),
                    const SizedBox(width: 2),
                    Expanded(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: kDrcSub))),
                  ]),
                  const SizedBox(height: 7),
                  Row(children: [
                    _tag(_t('Coopérative', 'Cooperative', 'Ushirika'), kDrcBlue, icon: Icons.verified_rounded),
                    const SizedBox(width: 6),
                    Flexible(child: _tag('$count ${_t('produits', 'products', 'bidhaa')}', kDrcBlueDeep)),
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

  // ═══════════════════ PRODUITS ═══════════════════
  Widget _buildProductsHeader(String? sector, int count, String lang) {
    final s = localSectorById(sector);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const DrcTricolorBar(),
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
              s != null ? s.label(lang) : _t('Produits Made in Congo', 'Made in Congo products', 'Bidhaa za Kongo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kDrcInk, letterSpacing: -0.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kDrcSoft, borderRadius: BorderRadius.circular(20)),
            child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kDrcBlueDeep)),
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
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kDrcBlue))),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kDrcRed.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kDrcRed.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                  _t('Erreur de chargement des produits', 'Failed to load products', 'Hitilafu ya kupakua'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kDrcRed, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(localProductsProvider.notifier).refresh(),
                  child: Text(_t('Réessayer', 'Retry', 'Jaribu tena'), style: const TextStyle(color: kDrcBlue, fontWeight: FontWeight.w800)),
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
                    decoration: const BoxDecoration(color: kDrcSoft, shape: BoxShape.circle),
                    child: Icon(Icons.public_rounded, size: 40, color: kDrcBlue.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Aucun produit dans cette sélection', 'No product in this selection', 'Hakuna bidhaa hapa'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kDrcInk),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez pour actualiser ou changez de secteur.', 'Pull to refresh or change sector.', 'Vuta kuburudisha au badilisha sekta.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: kDrcSub),
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
                  return const Center(child: CircularProgressIndicator(color: kDrcBlue, strokeWidth: 2));
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

// ============================================================================
// ✅ CARROUSEL AUTO-DÉFILENT DES CARTES DU PORTAIL — HAUTEUR RÉDUITE (84px)
// ============================================================================
class _HighlightsCarousel extends StatefulWidget {
  final List<PortalHighlight> items;
  final String lang;
  const _HighlightsCarousel({required this.items, required this.lang});

  @override
  State<_HighlightsCarousel> createState() => _HighlightsCarouselState();
}

class _HighlightsCarouselState extends State<_HighlightsCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.88);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final page = _ctrl.page?.round() ?? 0;
      if (page >= widget.items.length - 1) {
        _ctrl.animateToPage(0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
      } else {
        _ctrl.nextPage(duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
      }
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
      height: 84,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: widget.items.length,
        itemBuilder: (_, i) {
          final h = widget.items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kDrcLine),
                boxShadow: [BoxShadow(color: kDrcBlueDeep.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [h.color.withOpacity(0.85), h.color]),
                    ),
                    child: Icon(portalHighlightIcon(h.icon), size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title(widget.lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kDrcInk, height: 1.15),
                        ),
                        if (h.subtitle(widget.lang).isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            h.subtitle(widget.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: kDrcSub, height: 1.1),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
