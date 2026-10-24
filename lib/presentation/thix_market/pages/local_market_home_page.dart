// lib/presentation/thix_market/pages/local_market_home_page.dart
// ============================================================================
// HOME PRODUITS LOCAUX — style "grocery" mais TOUS LES SECTEURS
//  • Header vert + recherche in-page + panier
//  • Bandeau secteurs • Grille tuiles (photo/icone + label + count)
//  • Bannière promo locale • Producteurs & coopératives • Grille produits
//  • FAB "Vendre local" → formulaire dédié
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
import '../providers/market_providers.dart' show myShopIdProvider;
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
    debugPrint('[LocalMarket] 🏠 Local home opened');
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

  Future<void> _openSellForm() async {
    HapticFeedback.mediumImpact();
    final shopId = ref.read(myShopIdProvider).valueOrNull;
    if (!mounted) return;
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
              'Créez d\'abord une boutique pour vendre un produit local',
              'Create a shop first to sell a local product',
              'Kwanza fungua duka kuuzia bidhaa za ndani')),
          backgroundColor: ThixPolicy.warning,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: _t('Créer', 'Create', 'Fungua'),
            textColor: Colors.white,
            onPressed: () => context.push('/market/shop/create'),
          ),
        ),
      );
      return;
    }
    final created = await context.push<bool>('/market/local/create', extra: shopId);
    if (created == true && mounted) {
      invalidateLocalProviders(ref);
    }
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

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSellForm,
        backgroundColor: kLocalGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded, size: 20),
        label: Text(_t('Vendre local', 'Sell local', 'Uza ndani'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
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
            SliverToBoxAdapter(child: _buildSectorGrid(lang, counts, covers, selectedSector)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildPromoBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildProducers(producersAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
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

  // ═══════════════════ HEADER VERT (type capture grocery) ═══════════════════
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLocalGreen, kLocalGreenDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
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
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
                            const Text('LOCAL',
                                style: TextStyle(color: Color(0xFFB9F0C8), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(_t('100% LOCAL', '100% LOCAL', '100% NDANI'),
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        Text(
                          _t('L\'espace des produits de chez nous', 'The home-grown products space', 'Eneo la bidhaa za ndani'),
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/market/cart'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart_rounded, color: kLocalGreenDeep, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Recherche in-page
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 13.5, color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: _t('Rechercher un produit local, un producteur...',
                              'Search local product, producer...', 'Tafuta bidhaa ya ndani...'),
                          hintStyle: TextStyle(color: ThixPolicy.textMuted.withOpacity(0.8), fontSize: 12.5),
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
              const SizedBox(height: 16),

              // Titre type "Find Your Daily Grocery"
              Text(
                _t('Trouvez vos produits\nlocaux, tous secteurs', 'Find your local\nproducts, all sectors', 'Pata bidhaa zako\nza ndani, sekta zote'),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5),
              ),
              const SizedBox(height: 14),

              // Bandeau icônes secteurs (comme la bande de légumes)
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: kLocalSectors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final s = kLocalSectors[i];
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Icon(s.icon, color: Colors.white, size: 20),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════ GRILLE SECTEURS (tuiles pastel + photo) ═══════════════════
  Widget _buildSectorGrid(
    String lang,
    Map<String, int> counts,
    Map<String, String> covers,
    String? selected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Tous les secteurs', 'All sectors', 'Sekta zote'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: () => ref.read(localSectorFilterProvider.notifier).state = null,
                  child: Text(_t('Tout voir', 'See all', 'Ona zote'),
                      style: const TextStyle(color: kLocalGreen, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
              // Tuile "Tout"
              if (i == 0) {
                final isSel = selected == null;
                return _sectorTile(
                  label: _t('Tout', 'All', 'Zote'),
                  icon: Icons.grid_view_rounded,
                  color: ThixPolicy.primaryDeep,
                  cover: null,
                  count: counts.values.fold<int>(0, (a, b) => a + b),
                  selected: isSel,
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
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: color.withOpacity(selected ? 0.28 : 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? color : color.withOpacity(0.25),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null)
                        CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      if (cover == null)
                        Center(child: Icon(icon, color: color, size: 26)),
                      if (cover != null)
                        Container(color: color.withOpacity(0.25)),
                      if (count > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ BANNIÈRE PROMO LOCALE ═══════════════════
  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [kLocalGreenDeep, kLocalGreen],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_t('Circuit court', 'Short supply chain', 'Biashara ya moja kwa moja'),
                        style: const TextStyle(color: ThixPolicy.inkDeep, fontSize: 8.5, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('100% Local\n& Authentique', '100% Local\n& Authentic', '100% Ndani\n& Halisi'),
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Directement des producteurs & coopératives',
                        'Directly from producers & cooperatives', 'Moja kwa moja kutoka kwa wakulima'),
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 34),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ PRODUCTEURS & COOPÉRATIVES ═══════════════════
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
                _t('Producteurs & coopératives', 'Producers & cooperatives', 'Wakulima na ushirika'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.5),
              ),
              GestureDetector(
                onTap: () => context.push('/market/shops'),
                child: Text(_t('Voir tout', 'Show all', 'Ona zote'),
                    style: const TextStyle(color: ThixPolicy.primary, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(height: 70, child: Center(
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kLocalGreen)))),
            error: (_, __) => const SizedBox.shrink(),
            data: (producers) {
              if (producers.isEmpty) {
                return Text(
                  _t('Aucun producteur pour le moment. Soyez le premier !',
                      'No producer yet. Be the first!', 'Hakuna mkulima bado. Kuwa wa kwanza!'),
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
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
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.9)),
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
                                  ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (logo == null || !logo.startsWith('http'))
                                ? const Icon(Icons.agriculture_rounded, color: kLocalGreen, size: 20)
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
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 10, color: ThixPolicy.textMuted),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(city,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _tag(_t('Vérifié', 'Verified', 'Imethibitishwa'), kLocalGreen),
                                    const SizedBox(width: 6),
                                    _tag('$count ${_t('produits locaux', 'local products', 'bidhaa za ndani')}', ThixPolicy.primaryDeep),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
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
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary)),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(_t('Erreur de chargement des produits locaux', 'Failed to load local products', 'Hitilafu ya kupakua'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ThixPolicy.danger, fontSize: 12.5)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(localProductsProvider.notifier).refresh(),
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
                  Icon(Icons.agriculture_rounded, size: 52, color: kLocalGreen.withOpacity(0.35)),
                  const SizedBox(height: 12),
                  Text(
                    _t('Aucun produit local dans cette sélection',
                        'No local product in this selection', 'Hakuna bidhaa ya ndani hapa'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('Tirez pour actualiser ou vendez le premier produit local !',
                        'Pull to refresh or sell the first local product!', 'Vuta kuburudisha au uza bidhaa ya kwanza!'),
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
