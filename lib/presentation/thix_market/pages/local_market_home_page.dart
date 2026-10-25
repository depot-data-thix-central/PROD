// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// HOME PRODUITS LOCAUX — REDESIGN ULTRA-MODERNE
//  • Header vert immersif (halos décoratifs + recherche glass)
//  • HERO BANNER : carrousel auto-scroll des 10 derniers produits
//  • Grille secteurs épurée • Bannière promo • Producteurs horizontaux
//  • Grille produits — SANS FAB "Vendre local", SANS carte trust badges
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

  // ── Hero carousel ──────────────────────────────────────────────────────────
  final PageController _heroCtrl = PageController(viewportFraction: 0.88);
  Timer? _heroTimer;
  int _heroIndex = 0;
  int _heroCount = 0;

  static const Duration _heroInterval = Duration(seconds: 4);
  static const int kHeroMax = 10;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    debugPrint('[LocalMarket] 🏠 Local home opened (modern design)');
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      ref.read(localProductsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Auto-scroll du hero ────────────────────────────────────────────────────
  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_heroCount < 2) return;
    _heroTimer = Timer.periodic(_heroInterval, (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      if (_heroCtrl.position.isDragging) return; // pause pendant le drag
      final next = (_heroIndex + 1) % _heroCount;
      _heroCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onHeroChanged(int i) {
    if (!mounted) return;
    setState(() => _heroIndex = i);
    _startHeroTimer(); // reset du cycle après swipe manuel
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _t(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  /// Résout l'image d'un produit quel que soit le champ du backend.
  String? _productImage(Map p) {
    final imgs = p['images'];
    if (imgs is List && imgs.isNotEmpty) {
      final u = imgs.first?.toString() ?? '';
      if (u.startsWith('http')) return u;
    }
    for (final k in ['image_url', 'imageUrl', 'photo_url', 'cover_url']) {
      final v = p[k]?.toString();
      if (v != null && v.startsWith('http')) return v;
    }
    return null;
  }

  String _productName(Map p) =>
      (p['name'] ?? p['title'] ?? p['label'] ?? '').toString();

  /// Format "Br 5 665,60" (adapté à ta devise si besoin).
  String _fmtPrice(dynamic v) {
    final num d = (v is num) ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
    final fixed = d.toStringAsFixed(d % 1 == 0 ? 0 : 2);
    final parts = fixed.split('.');
    final grouped = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return 'Br $grouped${parts.length > 1 ? ',${parts[1]}' : ''}';
  }

  List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
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

    // ── Les 10 produits les plus récents (hero) ──
    final newest = (productsAsync.valueOrNull ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (b['created_at'] ?? '').toString().compareTo(
            (a['created_at'] ?? '').toString()));
    final heroItems = newest.take(kHeroMax).toList();
    _heroCount = heroItems.length;
    if (_heroTimer == null && _heroCount > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startHeroTimer());
    }

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
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildHero(heroItems)),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
                child: _buildSectorGrid(lang, counts, covers, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(child: _buildPromoBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(child: _buildProducers(producersAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
              child: _buildProductsHeader(selectedSector, filtered.length, lang),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            _buildProductsGrid(productsAsync, filtered, hasMore),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ HEADER VERT IMMERSIF ═══════════════════
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLocalGreenDeep, kLocalGreen],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Halos décoratifs
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.22)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 19),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('THIX ',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.5)),
                                const Text('LOCAL',
                                    style: TextStyle(
                                        color: Color(0xFFB9F0C8),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.5)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                      _t('100% LOCAL', '100% LOCAL',
                                          '100% NDANI'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4)),
                                ),
                              ],
                            ),
                            Text(
                              _t('L\'espace des produits de chez nous',
                                  'The home-grown products space',
                                  'Eneo la bidhaa za ndani'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/market/cart'),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Icon(Icons.shopping_bag_rounded,
                              color: kLocalGreenDeep, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Recherche glass ──
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search_rounded,
                            color: ThixPolicy.textSecondary, size: 20),
                        const SizedBox(width: 8),
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
                              hintText: _t(
                                  'Rechercher un produit local, un producteur...',
                                  'Search local product, producer...',
                                  'Tafuta bidhaa ya ndani...'),
                              hintStyle: TextStyle(
                                  color: ThixPolicy.textMuted.withOpacity(0.8),
                                  fontSize: 12.5),
                            ),
                            onChanged: (v) => setState(() =>
                                ref.read(localSearchQueryProvider.notifier).state =
                                    v),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: ThixPolicy.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(localSearchQueryProvider.notifier).state =
                                  '';
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Titre hero ──
                  Text(
                    _t('Trouvez vos produits\nlocaux, tous secteurs',
                        'Find your local\nproducts, all sectors',
                        'Pata bidhaa zako\nza ndani, sekta zote'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.6),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.eco_rounded,
                          color: Colors.white.withOpacity(0.85), size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _t('Directement des producteurs & coopératives',
                              'Directly from producers & cooperatives',
                              'Moja kwa moja kutoka kwa wakulima'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ HERO BANNER — AUTO-SCROLL 10 NOUVEAUTÉS ═══════════════════
  Widget _buildHero(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kLocalGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    const Icon(Icons.auto_awesome_rounded, size: 15, color: kLocalGreen),
              ),
              const SizedBox(width: 8),
              Text(
                _t('Nouveautés', 'Fresh arrivals', 'Bidhaa mpya'),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                    letterSpacing: -0.5),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kLocalGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${items.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: kLocalGreen)),
              ),
            ],
          ),
        ),

        // ── Carrousel auto-scroll ──
        SizedBox(
          height: 216,
          child: PageView.builder(
            controller: _heroCtrl,
            onPageChanged: _onHeroChanged,
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: _heroCard(items[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Indicateur à points animés ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == _heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 22 : 6,
              decoration: BoxDecoration(
                color: active
                    ? kLocalGreen
                    : ThixPolicy.textMuted.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _heroCard(Map p) {
    final img = _productImage(p);
    final sector = localSectorById(
        p['sector']?.toString() ?? p['sector_id']?.toString());
    final city = (p['city'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // TODO: adapter si ta route détail produit diffère
        context.push('/market/product/${p['id']}');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: kLocalGreen.withOpacity(0.16),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (img != null)
                CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: kLocalGreenSoft,
                    child: const Icon(Icons.eco_rounded,
                        color: kLocalGreen, size: 42),
                  ),
                )
              else
                Container(
                  color: kLocalGreenSoft,
                  child: const Center(
                      child: Icon(Icons.eco_rounded,
                          color: kLocalGreen, size: 42)),
                ),

              // Dégradé de lisibilité
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.72),
                      Colors.black.withOpacity(0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.38, 0.75],
                  ),
                ),
              ),

              // Badge NOUVEAU
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.gold,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                      _t('NOUVEAU', 'NEW', 'MPYA').toUpperCase(),
                      style: const TextStyle(
                          color: ThixPolicy.inkDeep,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6)),
                ),
              ),

              // Chip prix (glass)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: Text(_fmtPrice(p['price']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900)),
                ),
              ),

              // Infos bas de carte
              Positioned(
                left: 14,
                right: 14,
                bottom: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productName(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (sector != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sector.icon,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(sector.label(
                                    Localizations.localeOf(context).languageCode),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        if (sector != null && city.isNotEmpty)
                          const SizedBox(width: 8),
                        if (city.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white70, size: 11),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
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

  // ═══════════════════ GRILLE SECTEURS ÉPURÉE ═══════════════════
  Widget _buildSectorGrid(
    String lang,
    Map<String, int> counts,
    Map<String, String> covers,
    String? selected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  onTap: () =>
                      ref.read(localSectorFilterProvider.notifier).state = null,
                  child: Text(_t('Tout voir', 'See all', 'Ona zote'),
                      style: const TextStyle(
                          color: kLocalGreen,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              mainAxisExtent: 92,
            ),
            itemCount: kLocalSectors.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _sectorTile(
                  label: _t('Tout', 'All', 'Zote'),
                  icon: Icons.grid_view_rounded,
                  color: ThixPolicy.primaryDeep,
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
                  ref.read(localSectorFilterProvider.notifier).state =
                      (selected == s.id) ? null : s.id;
                },
              );
            },
          ),
        ],
      ),
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
      label: '$label, $count',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: _softShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null)
                        CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        )
                      else
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.13),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                        ),
                      if (cover != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                color.withOpacity(0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      if (count > 0)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected ? color : kLocalGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
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
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: selected ? color : ThixPolicy.textMain,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ BANNIÈRE PROMO PREMIUM ═══════════════════
  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [kLocalGreen, kLocalGreenDeep],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: kLocalGreen.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -50,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withOpacity(0.14), width: 10),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThixPolicy.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            _t('Circuit court', 'Short supply chain',
                                'Biashara ya moja kwa moja'),
                            style: const TextStyle(
                                color: ThixPolicy.inkDeep,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t('100% Local\n& Authentique', '100% Local\n& Authentic',
                            '100% Ndani\n& Halisi'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            letterSpacing: -0.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t('Des produits frais, traçables, près de chez vous',
                            'Fresh, traceable products near you',
                            'Bidhaa safi, karibu nawe'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => context.push('/market/shops'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  _t('Découvrir', 'Discover', 'Gundua'),
                                  style: const TextStyle(
                                      color: kLocalGreenDeep,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(width: 5),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: kLocalGreenDeep, size: 13),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ PRODUCTEURS (cartes horizontales) ═══════════════════
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
                        color: kLocalGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  style: TextStyle(
                      color: ThixPolicy.textSecondary, fontSize: 12),
                );
              }
              return SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: producers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                        width: 218,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kLocalGreenSoft,
                                    border: Border.all(
                                        color:
                                            kLocalGreen.withOpacity(0.35),
                                        width: 2),
                                    image: (logo != null &&
                                            logo.startsWith('http'))
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                                logo),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: (logo == null ||
                                          !logo.startsWith('http'))
                                      ? const Icon(Icons.agriculture_rounded,
                                          color: kLocalGreen, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: ThixPolicy.textMain)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.location_on_outlined,
                                              size: 10,
                                              color: ThixPolicy.textMuted),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: Text(city,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: ThixPolicy
                                                        .textSecondary)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                _tag(_t('Vérifié', 'Verified',
                                    'Imethibitishwa'), kLocalGreen),
                                const SizedBox(width: 6),
                                _tag('$count', ThixPolicy.primaryDeep),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ═══════════════════ GRILLE PRODUITS LOCAUX ═══════════════════
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
                  borderRadius: BorderRadius.circular(9)),
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kLocalGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: kLocalGreen)),
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
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                    _t('Erreur de chargement des produits locaux',
                        'Failed to load local products',
                        'Hitilafu ya kupakua'),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.eco_rounded,
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
                    _t('Tirez pour actualiser ou explorez d\'autres secteurs !',
                        'Pull to refresh or explore other sectors!',
                        'Vuta kuburudisha au tafuta sekta nyingine!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
