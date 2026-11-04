// lib/presentation/thix_weeding/pages/provider_portal/provider_catalog_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER CATALOG (PRODUCTION v7 — TRI PAR CATÉGORIE)
// ✅ Toutes les sections suivent la catégorie choisie (offres, promos, top, nouveaux)
// ✅ « Tous » = groupé par catégorie (offres + prestataires de chaque catégorie)
// ✅ Filtres prix / note réellement appliqués (bug des chips corrigé)
// ✅ Promotions = vraies offres de type promo (plus de faux prix < 1000$)
// ✅ Prestataire sans photo = visuel de catégorie (plus de fausse photo de salle)
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_cover.dart';
import 'provider_offers_page.dart' show offerTypeColor, offerTypeIcon;

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color gold = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _catalogSortProvider = StateProvider<CatalogSort>((ref) => CatalogSort.popular);
final _catalogPriceRangeProvider = StateProvider<PriceRange>((ref) => PriceRange.all);
final _catalogRatingFilterProvider = StateProvider<double?>((ref) => null);
final _favoritesProvider = StateProvider<Set<String>>((ref) => <String>{});

final _allProvidersCatalogProvider = FutureProvider.autoDispose<List<ThixProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final all = await service.getAllProviders(limit: 200);
  return all.where((p) => p.verificationStatus != ProviderVerificationStatus.rejected).toList();
});

final _allOffersCatalogProvider = FutureProvider.autoDispose<List<ProviderOfferModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final all = await service.getActiveOffersWithProvider(limit: 200, category: null);
  return all.where((o) => o.providerVerificationStatus != 'rejected').toList();
});

enum CatalogSort { popular, rating, priceLow, priceHigh, recent }

enum PriceRange { all, low, medium, high }

// ═══════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderCatalogPage extends ConsumerStatefulWidget {
  final String? initialCategory;
  const ProviderCatalogPage({super.key, this.initialCategory});

  @override
  ConsumerState<ProviderCatalogPage> createState() => _ProviderCatalogPageState();
}

class _ProviderCatalogPageState extends ConsumerState<ProviderCatalogPage> {
  ProviderCategory? _category;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _category = _parseCategory(widget.initialCategory);
    _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('thix_favorite_providers') ?? [];
    if (mounted) ref.read(_favoritesProvider.notifier).state = favs.toSet();
  }

  ProviderCategory? _parseCategory(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final c in ProviderCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  void _setCategory(ProviderCategory? cat) {
    HapticFeedback.selectionClick();
    setState(() => _category = cat);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  // ── FILTRES ──
  bool _priceOk(double? price, PriceRange r) {
    if (r == PriceRange.all) return true;
    if (price == null) return false;
    return switch (r) {
      PriceRange.low => price < 500,
      PriceRange.medium => price >= 500 && price <= 2000,
      PriceRange.high => price > 2000,
      PriceRange.all => true,
    };
  }

  List<ThixProviderModel> _filterProviders(List<ThixProviderModel> all, PriceRange pr, double? minRating) {
    final q = _search.toLowerCase();
    return all.where((p) {
      if (_category != null && p.category != _category) return false;
      if (minRating != null && p.rating < minRating) return false;
      if (!_priceOk(p.minPrice, pr)) return false;
      if (q.isEmpty) return true;
      return p.businessName.toLowerCase().contains(q) ||
          (p.city ?? '').toLowerCase().contains(q) ||
          p.category.displayName.toLowerCase().contains(q);
    }).toList();
  }

  List<ProviderOfferModel> _filterOffers(List<ProviderOfferModel> all, PriceRange pr) {
    final q = _search.toLowerCase();
    return all.where((o) {
      if (_category != null && !o.isInCategory(_category!)) return false;
      if (!_priceOk(o.price, pr)) return false;
      if (q.isEmpty) return true;
      return o.title.toLowerCase().contains(q) || (o.providerBusinessName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<ThixProviderModel> _sort(List<ThixProviderModel> providers, CatalogSort sort) {
    final s = List<ThixProviderModel>.from(providers);
    switch (sort) {
      case CatalogSort.popular:
        s.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case CatalogSort.rating:
        s.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case CatalogSort.priceLow:
        s.sort((a, b) => (a.minPrice ?? 999999).compareTo(b.minPrice ?? 999999));
        break;
      case CatalogSort.priceHigh:
        s.sort((a, b) => (b.minPrice ?? 0).compareTo(a.minPrice ?? 0));
        break;
      case CatalogSort.recent:
        s.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return s;
  }

  Future<void> _toggleFavorite(String id) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(_favoritesProvider.notifier);
    final set = Set<String>.from(ref.read(_favoritesProvider));
    final added = !set.contains(id);
    added ? set.add(id) : set.remove(id);
    notifier.state = set;
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(added ? 'Ajouté aux favoris ❤️' : 'Retiré des favoris',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: added ? _P.rose : _P.inkSoft,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('thix_favorite_providers', set.toList());
  }

  IconData _catIcon(ProviderCategory c) => providerCategoryIcon(c);

  String _sortLabel(CatalogSort s) => switch (s) {
        CatalogSort.popular => 'Populaire',
        CatalogSort.rating => 'Mieux notés',
        CatalogSort.priceLow => 'Prix ↑',
        CatalogSort.priceHigh => 'Prix ↓',
        CatalogSort.recent => 'Récents',
      };

  // ── SECTIONS ──
  Widget _sectionTitle(IconData icon, List<Color> grad, String title, {String? sub, VoidCallback? onAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: LinearGradient(colors: grad), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _P.ink)),
                if (sub != null)
                  Text(sub, style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (onAll != null)
            GestureDetector(
              onTap: onAll,
              child: Row(children: [
                Text('Voir tout', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: _P.rose)),
                const Icon(Icons.chevron_right_rounded, size: 16, color: _P.rose),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _offersRow(List<ProviderOfferModel> offers) => SizedBox(
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _CatalogOfferCard(offer: offers[i]),
        ),
      );

  Widget _providersRow(List<ThixProviderModel> list, Set<String> favs) => SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: 172,
            child: _CatalogCard(
              provider: list[i],
              isFavorite: favs.contains(list[i].id),
              onFavoriteToggle: () => _toggleFavorite(list[i].id),
            ),
          ),
        ),
      );

  List<Widget> _content(List<ThixProviderModel> providers, List<ProviderOfferModel> offers, CatalogSort sort,
      Set<String> favs) {
    final w = <Widget>[];

    // PROMOTIONS (vraies offres promo)
    final promos = offers.where((o) => o.type == OfferType.promo).toList();
    if (promos.isNotEmpty) {
      w.add(_sectionTitle(Icons.local_fire_department_rounded, [_P.red, const Color(0xFFFF6B6B)], 'Promotions',
          sub: '${promos.length} offre${promos.length > 1 ? 's' : ''} en promo'));
      w.add(_offersRow(promos));
      w.add(const SizedBox(height: 24));
    }

    // LES PLUS RÉSERVÉS (uniquement ceux qui ont des avis)
    final top = providers.where((p) => p.reviewCount > 0).toList()
      ..sort((a, b) => (b.reviewCount * 10 + b.rating * 100).compareTo(a.reviewCount * 10 + a.rating * 100));
    if (top.isNotEmpty) {
      w.add(_sectionTitle(Icons.emoji_events_rounded, [_P.gold, const Color(0xFFFFA500)], 'Les plus réservés'));
      w.add(SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: top.take(10).length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _TopProviderCard(provider: top[i]),
        ),
      ));
      w.add(const SizedBox(height: 24));
    }

    // NOUVEAUX PRESTATAIRES
    final fresh = [...providers]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (fresh.isNotEmpty) {
      w.add(_sectionTitle(Icons.fiber_new_rounded, [_P.blue, const Color(0xFF60A5FA)], 'Nouveaux prestataires'));
      w.add(SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: fresh.take(10).length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _NewProviderCard(provider: fresh[i]),
        ),
      ));
      w.add(const SizedBox(height: 24));
    }

    if (providers.isEmpty && offers.isEmpty) {
      w.add(_EmptyState(
        icon: Icons.store_outlined,
        title: 'Aucun résultat',
        subtitle: 'Essayez une autre catégorie ou modifiez vos filtres',
        actionLabel: 'Réinitialiser',
        onAction: () {
          ref.read(_catalogPriceRangeProvider.notifier).state = PriceRange.all;
          ref.read(_catalogRatingFilterProvider.notifier).state = null;
          setState(() {
            _category = null;
            _search = '';
          });
        },
      ));
      return w;
    }

    if (_category == null) {
      // TOUS : groupé par catégorie
      for (final cat in ProviderCategory.values) {
        final o = offers.where((x) => x.isInCategory(cat)).take(12).toList();
        final p = _sort(providers.where((x) => x.category == cat).toList(), sort).take(12).toList();
        if (o.isEmpty && p.isEmpty) continue;
        w.add(_sectionTitle(_catIcon(cat), [_P.rose, _P.roseLight], cat.displayName,
            sub: '${o.length} offre${o.length > 1 ? 's' : ''} · ${p.length} prestataire${p.length > 1 ? 's' : ''}',
            onAll: () => _setCategory(cat)));
        if (o.isNotEmpty) {
          w.add(_offersRow(o));
          w.add(const SizedBox(height: 12));
        }
        if (p.isNotEmpty) w.add(_providersRow(p, favs));
        w.add(const SizedBox(height: 26));
      }
    } else {
      // CATÉGORIE CHOISIE
      if (offers.isNotEmpty) {
        w.add(_sectionTitle(Icons.local_offer_rounded, [_P.rose, _P.roseLight], 'Offres — ${_category!.displayName}',
            sub: '${offers.length} offre${offers.length > 1 ? 's' : ''} disponible${offers.length > 1 ? 's' : ''}'));
        w.add(_offersRow(offers));
        w.add(const SizedBox(height: 24));
      }
      final sorted = _sort(providers, sort);
      if (sorted.isNotEmpty) {
        w.add(_sectionTitle(_catIcon(_category!), [_P.rose, _P.roseLight], 'Prestataires — ${_category!.displayName}',
            sub: '${sorted.length} trouvé${sorted.length > 1 ? 's' : ''}'));
        w.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.68),
            itemBuilder: (_, i) => _CatalogCard(
              provider: sorted[i],
              isFavorite: favs.contains(sorted[i].id),
              onFavoriteToggle: () => _toggleFavorite(sorted[i].id),
            ),
          ),
        ));
      }
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(_allProvidersCatalogProvider);
    final offersAsync = ref.watch(_allOffersCatalogProvider);
    final sort = ref.watch(_catalogSortProvider);
    final priceRange = ref.watch(_catalogPriceRangeProvider);
    final minRating = ref.watch(_catalogRatingFilterProvider);
    final favorites = ref.watch(_favoritesProvider);

    final providers = _filterProviders(providersAsync.valueOrNull ?? const [], priceRange, minRating);
    final offers = _filterOffers(offersAsync.valueOrNull ?? const [], priceRange);
    final loading = providersAsync.isLoading && !providersAsync.hasValue;

    final heroList = ([...providers]..sort((a, b) => b.rating.compareTo(a.rating))).take(5).toList();

    return Scaffold(
      backgroundColor: _P.bg,
      body: RefreshIndicator(
        color: _P.rose,
        onRefresh: () async {
          ref.invalidate(_allProvidersCatalogProvider);
          ref.invalidate(_allOffersCatalogProvider);
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            if (heroList.isNotEmpty)
              SliverToBoxAdapter(child: _HeroBannerSection(key: ValueKey(_category), providers: heroList)),

            SliverToBoxAdapter(
              child: _CatalogHeader(
                search: _search,
                onSearch: _onSearchChanged,
                onFilterTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _FilterSheet(),
                ),
                onSortTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _SortSheet(),
                ),
              ),
            ),

            // CHIPS CATÉGORIES
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: ProviderCategory.values.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _CategoryChip(
                        label: 'Tous',
                        icon: Icons.grid_view_rounded,
                        isSelected: _category == null,
                        onTap: () => _setCategory(null),
                      );
                    }
                    final cat = ProviderCategory.values[i - 1];
                    return _CategoryChip(
                      label: cat.displayName,
                      icon: _catIcon(cat),
                      isSelected: _category == cat,
                      onTap: () => _setCategory(cat),
                    );
                  },
                ),
              ),
            ),

            // BARRE D'INFOS
            if (!loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    children: [
                      Text(
                        '${providers.length} prestataire${providers.length > 1 ? 's' : ''} · ${offers.length} offre${offers.length > 1 ? 's' : ''}'
                        '${_category != null ? ' · ${_category!.displayName}' : ''}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.inkSoft),
                      ),
                      const Spacer(),
                      if (sort != CatalogSort.popular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration:
                              BoxDecoration(color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(_sortLabel(sort),
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.rose)),
                        ),
                    ],
                  ),
                ),
              ),

            // CONTENU
            if (loading)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: _P.rose)),
                ),
              )
            else if (providersAsync.hasError && !providersAsync.hasValue)
              SliverToBoxAdapter(
                child: _ErrorState(
                  message: '${providersAsync.error}',
                  onRetry: () => ref.invalidate(_allProvidersCatalogProvider),
                ),
              )
            else
              SliverList(delegate: SliverChildListDelegate(_content(providers, offers, sort, favorites))),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE OFFRE
// ═══════════════════════════════════════════════════════════════════════════
class _CatalogOfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  const _CatalogOfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    final allImages = offer.allImages;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${offer.providerId}?offer=${offer.id}');
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (allImages.isNotEmpty)
                    PageView.builder(
                      itemCount: allImages.length,
                      itemBuilder: (_, i) => Image.network(
                        allImages[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withOpacity(0.15),
                          child: Icon(offerTypeIcon(offer.type), size: 40, color: color),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: color.withOpacity(0.15),
                      child: Icon(offerTypeIcon(offer.type), size: 40, color: color),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.type.displayName.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                  if (allImages.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration:
                            BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${allImages.length}',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(offer.providerBusinessName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text(
                      offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _P.rose),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO BANNER
// ═══════════════════════════════════════════════════════════════════════════
class _HeroBannerSection extends StatefulWidget {
  final List<ThixProviderModel> providers;
  const _HeroBannerSection({super.key, required this.providers});

  @override
  State<_HeroBannerSection> createState() => _HeroBannerSectionState();
}

class _HeroBannerSectionState extends State<_HeroBannerSection> {
  late final PageController _ctrl = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients || widget.providers.length <= 1) return;
      _page = (_page + 1) % widget.providers.length;
      _ctrl.animateToPage(_page, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
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
    return Container(
      height: 320,
      margin: const EdgeInsets.only(bottom: 16),
      child: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => _page = i,
        itemCount: widget.providers.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              var value = 1.0;
              if (_ctrl.hasClients && _ctrl.position.haveDimensions) {
                value = ((_ctrl.page ?? 0) - index).abs();
                value = (1 - value * 0.3).clamp(0.0, 1.0);
              }
              return Center(child: SizedBox(height: Curves.easeOut.transform(value) * 300, child: child));
            },
            child: _HeroCard(provider: widget.providers[index]),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _HeroCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProviderPhotos(provider: provider),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            if (provider.level == TrackingLevel.platinum)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('PREMIUM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('${provider.category.displayName} · ${provider.city ?? 'RDC'}',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: _P.gold),
                      const SizedBox(width: 4),
                      Text(provider.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(' (${provider.reviewCount} avis)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                      const Spacer(),
                      Text(
                        provider.minPrice != null ? 'Dès ${provider.minPrice!.toStringAsFixed(0)}\$' : 'Sur devis',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// CARTES PRESTATAIRES
// ═══════════════════════════════════════════════════════════════════════════
class _TopProviderCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _TopProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProviderPhotos(provider: provider),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text('${provider.reviewCount} avis',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(provider.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: _P.gold),
                        const SizedBox(width: 2),
                        Text(provider.rating.toStringAsFixed(1),
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink)),
                        const Spacer(),
                        Text(provider.minPrice != null ? '${provider.minPrice!.toStringAsFixed(0)}\$' : 'Devis',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _P.rose)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewProviderCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _NewProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(provider.createdAt).inDays;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProviderPhotos(provider: provider),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _P.blue, borderRadius: BorderRadius.circular(8)),
                      child: Text(days == 0 ? 'Aujourd\'hui' : 'Il y a ${days}j',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(provider.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
                    Text(provider.category.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final ThixProviderModel provider;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _CatalogCard({required this.provider, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    final photoCount = providerRealPhotos(provider).length;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProviderPhotos(provider: provider),
                  if (provider.level == TrackingLevel.platinum)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('PREMIUM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ]),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), shape: BoxShape.circle),
                      child: Icon(
                        provider.verificationStatus == ProviderVerificationStatus.verified
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        size: 14,
                        color: provider.verificationStatus == ProviderVerificationStatus.verified ? _P.green : _P.amber,
                      ),
                    ),
                  ),
                  if (photoCount > 1)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration:
                            BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('$photoCount',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ]),
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), shape: BoxShape.circle),
                        child: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18, color: isFavorite ? _P.rose : _P.inkSoft),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.3)),
                        const SizedBox(height: 2),
                        Text('${provider.category.displayName} · ${provider.city ?? 'RDC'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 13, color: _P.gold),
                          const SizedBox(width: 3),
                          Text(provider.rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink)),
                          Text(' (${provider.reviewCount})', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft)),
                        ]),
                        Text(provider.minPrice != null ? 'Dès ${provider.minPrice!.toStringAsFixed(0)}\$' : 'Sur devis',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: _P.rose)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER + CHIPS
// ═══════════════════════════════════════════════════════════════════════════
class _CatalogHeader extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;

  const _CatalogHeader(
      {required this.search, required this.onSearch, required this.onFilterTap, required this.onSortTap});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_P.rose, _P.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/thix-weeding'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catalogue',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
                    Text('Trouvez le prestataire idéal',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSortTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.sort_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _P.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
                hintText: 'Rechercher un prestataire ou une offre...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _P.rose),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _P.rose : _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _P.rose : _P.line),
          boxShadow: isSelected ? [BoxShadow(color: _P.rose.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _P.inkSoft),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _P.ink)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTRES (bug corrigé : les chips note n'enregistraient rien)
// ═══════════════════════════════════════════════════════════════════════════
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late PriceRange _priceRange;
  late double? _minRating;

  @override
  void initState() {
    super.initState();
    _priceRange = ref.read(_catalogPriceRangeProvider);
    _minRating = ref.read(_catalogRatingFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Filtres', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
          const SizedBox(height: 24),
          Text('Gamme de prix', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FilterChip(label: 'Tous', isSelected: _priceRange == PriceRange.all, onTap: () => setState(() => _priceRange = PriceRange.all)),
            _FilterChip(label: '< 500\$', isSelected: _priceRange == PriceRange.low, onTap: () => setState(() => _priceRange = PriceRange.low)),
            _FilterChip(label: '500-2000\$', isSelected: _priceRange == PriceRange.medium, onTap: () => setState(() => _priceRange = PriceRange.medium)),
            _FilterChip(label: '> 2000\$', isSelected: _priceRange == PriceRange.high, onTap: () => setState(() => _priceRange = PriceRange.high)),
          ]),
          const SizedBox(height: 24),
          Text('Note minimale', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FilterChip(label: 'Toutes', isSelected: _minRating == null, onTap: () => setState(() => _minRating = null)),
            _FilterChip(label: '3+ ⭐', isSelected: _minRating == 3.0, onTap: () => setState(() => _minRating = 3.0)),
            _FilterChip(label: '4+ ⭐', isSelected: _minRating == 4.0, onTap: () => setState(() => _minRating = 4.0)),
            _FilterChip(label: '4.5+ ⭐', isSelected: _minRating == 4.5, onTap: () => setState(() => _minRating = 4.5)),
          ]),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _priceRange = PriceRange.all;
                  _minRating = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _P.inkSoft,
                  side: const BorderSide(color: _P.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Réinitialiser', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(_catalogPriceRangeProvider.notifier).state = _priceRange;
                  ref.read(_catalogRatingFilterProvider.notifier).state = _minRating;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Appliquer', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _P.rose : _P.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _P.rose : _P.line),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _P.ink)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRI
// ═══════════════════════════════════════════════════════════════════════════
class _SortSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_catalogSortProvider);
    Widget opt(IconData i, String l, CatalogSort s) => _SortOption(
          icon: i,
          label: l,
          selected: current == s,
          onTap: () {
            ref.read(_catalogSortProvider.notifier).state = s;
            Navigator.pop(context);
          },
        );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Trier par', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
          const SizedBox(height: 16),
          opt(Icons.trending_up_rounded, 'Plus populaires', CatalogSort.popular),
          opt(Icons.star_rounded, 'Mieux notés', CatalogSort.rating),
          opt(Icons.attach_money_rounded, 'Prix croissant', CatalogSort.priceLow),
          opt(Icons.attach_money_rounded, 'Prix décroissant', CatalogSort.priceHigh),
          opt(Icons.new_releases_rounded, 'Plus récents', CatalogSort.recent),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortOption({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _P.rose.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _P.rose : _P.line),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: selected ? _P.rose : _P.inkSoft),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? _P.rose : _P.ink)),
          const Spacer(),
          if (selected) const Icon(Icons.check_rounded, size: 20, color: _P.rose),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTATS
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: _P.inkSoft),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft, height: 1.4)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _P.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: _P.red),
            ),
            const SizedBox(height: 20),
            Text('Une erreur est survenue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
