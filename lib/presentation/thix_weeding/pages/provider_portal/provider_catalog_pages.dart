// lib/presentation/thix_weeding/pages/provider_portal/provider_catalog_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER CATALOG (PRODUCTION v6 — OFFRES + FILTRE SERVEUR)
// ✅ Hero banner animé avec auto-scroll + zoom parallax
// ✅ Section "Offres & Services" filtrée PAR CATÉGORIE (côté serveur)
// ✅ Section "Promotions" (offres avec prix réduit)
// ✅ Section "Les plus réservés" (basée sur reviewCount + rating)
// ✅ Section "Nouveaux prestataires" (10 derniers inscrits)
// ✅ Multi-photos : carrousel PageView dans toutes les cartes
// ✅ Filtre verified assoupli : pending accepté, rejected exclu
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
import 'provider_offers_page.dart' show offerTypeColor, offerTypeIcon;

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE
// ═══════════════════════════════════════════════════════════════════════════
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
  static const Color purple = Color(0xFF8B5CF6);
  static const Color gold = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS POUR FILTRES ET TRI
// ═══════════════════════════════════════════════════════════════════════════
final _catalogSortProvider = StateProvider<CatalogSort>((ref) => CatalogSort.popular);
final _catalogPriceRangeProvider = StateProvider<PriceRange>((ref) => PriceRange.all);
final _catalogRatingFilterProvider = StateProvider<double?>((ref) => null);
final _catalogCityFilterProvider = StateProvider<String?>((ref) => null);
final _favoritesProvider = StateProvider<Set<String>>((ref) => <String>{});

// ✅ NOUVEAU : offres actives FILTRÉES PAR CATÉGORIE côté serveur
final _activeOffersCatalogProvider = FutureProvider.autoDispose
    .family<List<ProviderOfferModel>, ProviderCategory?>((ref, category) async {
  final service = ref.watch(providerServiceProvider);
  return await service.getActiveOffersWithProvider(limit: 100, category: category);
});

final _topProvidersProvider = FutureProvider<List<ThixProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final all = await service.getAllProviders(limit: 50);
  final usable = all.where((p) => p.verificationStatus != ProviderVerificationStatus.rejected).toList();
  usable.sort((a, b) {
    final scoreA = a.reviewCount * 10 + (a.rating * 100).toInt();
    final scoreB = b.reviewCount * 10 + (b.rating * 100).toInt();
    return scoreB.compareTo(scoreA);
  });
  return usable.take(10).toList();
});

final _newProvidersProvider = FutureProvider<List<ThixProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final all = await service.getAllProviders(limit: 50);
  final usable = all.where((p) => p.verificationStatus != ProviderVerificationStatus.rejected).toList();
  usable.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return usable.take(10).toList();
});

final _promoProvidersProvider = FutureProvider<List<ThixProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final all = await service.getAllProviders(limit: 50);
  final withPrice = all
      .where((p) => p.verificationStatus != ProviderVerificationStatus.rejected
          && p.minPrice != null && p.minPrice! < 1000)
      .toList();
  withPrice.sort((a, b) => (a.minPrice ?? 9999).compareTo(b.minPrice ?? 9999));
  return withPrice.take(8).toList();
});

enum CatalogSort { popular, rating, priceLow, priceHigh, recent }
enum PriceRange { all, low, medium, high }

// ═══════════════════════════════════════════════════════════════════════════
// CATALOGUE - PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderCatalogPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const ProviderCatalogPage({super.key, this.initialCategory});

  @override
  ConsumerState<ProviderCatalogPage> createState() => _ProviderCatalogPageState();
}

class _ProviderCatalogPageState extends ConsumerState<ProviderCatalogPage>
    with SingleTickerProviderStateMixin {
  ProviderCategory? _category;
  String _search = '';
  Timer? _debounce;
  late ProviderListParams _params;
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 1;
  List<ThixProviderModel> _allProviders = [];
  bool _hasMore = true;

  late final PageController _heroPageController;
  int _heroCurrentPage = 0;
  Timer? _heroAutoScrollTimer;
  // CORRIGÉ : Initialisation immédiate avec liste vide
  List<ThixProviderModel> _heroProviders = [];

  @override
  void initState() {
    super.initState();
    _category = _parseCategory(widget.initialCategory);
    _params = ProviderListParams(limit: 20, page: 1, category: _category);
    _scrollController.addListener(_onScroll);
    _loadFavorites();

    _heroPageController = PageController(viewportFraction: 0.92);
    _loadHeroProviders();
  }
}
  Future<void> _loadHeroProviders() async {
    final service = ref.read(providerServiceProvider);
    final all = await service.getAllProviders(limit: 10);
    final usable = all.where((p) => p.verificationStatus != ProviderVerificationStatus.rejected).toList();
    usable.sort((a, b) => b.rating.compareTo(a.rating));
    if (mounted) {
      setState(() {
        _heroProviders = usable.take(5).toList();
      });
      _startHeroAutoScroll();
    }
  }

  void _startHeroAutoScroll() {
    _heroAutoScrollTimer?.cancel();
    _heroAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_heroProviders.isNotEmpty && _heroPageController.hasClients) {
        _heroCurrentPage = (_heroCurrentPage + 1) % _heroProviders.length;
        _heroPageController.animateToPage(
          _heroCurrentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _heroPageController.dispose();
    _heroAutoScrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('thix_favorite_providers') ?? [];
    ref.read(_favoritesProvider.notifier).state = favs.toSet();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      final newProviders = await ref.read(providerServiceProvider).getAllProviders(
        page: _currentPage,
        limit: 20,
        category: _category,
        search: _search.isEmpty ? null : _search,
      );

      if (newProviders.isEmpty) {
        _hasMore = false;
      } else {
        setState(() {
          _allProviders.addAll(newProviders);
        });
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
    setState(() {
      _category = cat;
      _currentPage = 1;
      _hasMore = true;
      _allProviders = [];
      _params = ProviderListParams(
        limit: 20,
        page: 1,
        category: cat,
        search: _search.isEmpty ? null : _search,
      );
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _currentPage = 1;
        _hasMore = true;
        _allProviders = [];
        _params = ProviderListParams(
          limit: 20,
          page: 1,
          category: _category,
          search: _search.isEmpty ? null : _search,
        );
      });
    });
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _allProviders = [];
    });
  }

  bool _isUsable(ThixProviderModel p) =>
      p.verificationStatus != ProviderVerificationStatus.rejected;

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(providersListProvider(_params));
    // ✅ Passe la catégorie au provider → filtre côté serveur
    final offersAsync = ref.watch(_activeOffersCatalogProvider(_category));
    final sort = ref.watch(_catalogSortProvider);
    final favorites = ref.watch(_favoritesProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════ HERO BANNER ═══════════════
          if (_heroProviders.isNotEmpty)
            _HeroBannerSection(
              providers: _heroProviders,
              pageController: _heroPageController,
              currentPage: _heroCurrentPage,
              onPageChanged: (i) => setState(() => _heroCurrentPage = i),
            ),

          // ═══════════════ HEADER ═══════════════
          SliverToBoxAdapter(
            child: _CatalogHeader(
              search: _search,
              onSearch: _onSearchChanged,
              onFilterTap: () => _showFilterSheet(context),
              onSortTap: () => _showSortSheet(context),
            ),
          ),

          // ═══════════════ CHIPS CATÉGORIES ═══════════════
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
                    icon: _getCategoryIcon(cat),
                    isSelected: _category == cat,
                    onTap: () => _setCategory(cat),
                  );
                },
              ),
            ),
          ),

          // ═══════════════ OFFRES & SERVICES (filtrées serveur) ═══════════════
          offersAsync.when(
            data: (allOffers) {
              // ✅ Filtrage client uniquement sur : statut provider + recherche texte
              //    (la catégorie est déjà filtrée côté serveur)
              final filtered = allOffers.where((o) {
                if (o.providerVerificationStatus == 'rejected') return false;
                if (_search.isEmpty) return true;
                final s = _search.toLowerCase();
                return o.title.toLowerCase().contains(s) ||
                    (o.providerBusinessName ?? '').toLowerCase().contains(s);
              }).toList();

              return SliverToBoxAdapter(
                child: _CatalogOffersSection(
                  offers: filtered,
                  category: _category,
                  totalActiveOffers: allOffers.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ═══════════════ LES PLUS RÉSERVÉS ═══════════════
          SliverToBoxAdapter(
            child: _TopProvidersSection(topProvidersAsync: ref.watch(_topProvidersProvider)),
          ),

          // ═══════════════ PROMOTIONS ═══════════════
          SliverToBoxAdapter(
            child: _PromoSection(promoProvidersAsync: ref.watch(_promoProvidersProvider)),
          ),

          // ═══════════════ NOUVEAUX PRESTATAIRES ═══════════════
          SliverToBoxAdapter(
            child: _NewProvidersSection(newProvidersAsync: ref.watch(_newProvidersProvider)),
          ),

          // ═══════════════ BARRE D'INFOS ═══════════════
          providersAsync.when(
            data: (providers) {
              final visible = providers.where(_isUsable).toList();
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        '${visible.length} prestataire${visible.length > 1 ? 's' : ''} trouvé${visible.length > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.inkSoft),
                      ),
                      const Spacer(),
                      if (sort != CatalogSort.popular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _P.rose.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getSortLabel(sort),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.rose),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ═══════════════ GRILLE DES PRESTATAIRES ═══════════════
          providersAsync.when(
            data: (providers) {
              var visible = providers.where(_isUsable).toList();
              visible = _sortProviders(visible, sort);

              final offersData = offersAsync.valueOrNull ?? const <ProviderOfferModel>[];
              final visibleOffers = offersData
                  .where((o) => o.providerVerificationStatus != 'rejected')
                  .toList();

              if (visible.isEmpty && visibleOffers.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.store_outlined,
                    title: 'Aucun résultat',
                    subtitle: 'Essayez une autre catégorie ou modifiez vos filtres',
                    actionLabel: 'Réinitialiser les filtres',
                    onAction: () {
                      _setCategory(null);
                      _onSearchChanged('');
                    },
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i < visible.length) {
                        return _CatalogCard(
                          provider: visible[i],
                          isFavorite: favorites.contains(visible[i].id),
                          onFavoriteToggle: () => _toggleFavorite(visible[i].id),
                        );
                      } else if (_isLoadingMore) {
                        return const _LoadingCard();
                      }
                      return null;
                    },
                    childCount: visible.length + (_isLoadingMore ? 2 : 0),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3, color: _P.rose),
                      ),
                      SizedBox(height: 16),
                      Text('Chargement du catalogue...', style: TextStyle(color: _P.inkSoft, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(providersListProvider(_params)),
              ),
            ),
          ),

          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: _P.rose)),
              ),
            ),

          if (!_hasMore && _allProviders.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Vous avez vu tous les prestataires',
                    style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  List<ThixProviderModel> _sortProviders(List<ThixProviderModel> providers, CatalogSort sort) {
    final sorted = List<ThixProviderModel>.from(providers);
    switch (sort) {
      case CatalogSort.popular:
        sorted.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case CatalogSort.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case CatalogSort.priceLow:
        sorted.sort((a, b) => (a.minPrice ?? 999999).compareTo(b.minPrice ?? 999999));
        break;
      case CatalogSort.priceHigh:
        sorted.sort((a, b) => (b.minPrice ?? 0).compareTo(a.minPrice ?? 0));
        break;
      case CatalogSort.recent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  IconData _getCategoryIcon(ProviderCategory cat) {
    return switch (cat) {
      ProviderCategory.salle => Icons.meeting_room_rounded,
      ProviderCategory.traiteur => Icons.restaurant_rounded,
      ProviderCategory.photographe => Icons.camera_alt_rounded,
      ProviderCategory.videaste => Icons.videocam_rounded,
      ProviderCategory.decorateur => Icons.palette_rounded,
      ProviderCategory.dj => Icons.music_note_rounded,
      ProviderCategory.mc => Icons.mic_rounded,
      ProviderCategory.maquilleur => Icons.face_rounded,
      ProviderCategory.patissier => Icons.cake_rounded,
      ProviderCategory.fleuriste => Icons.local_florist_rounded,
    };
  }

  String _getSortLabel(CatalogSort sort) {
    return switch (sort) {
      CatalogSort.popular => 'Populaire',
      CatalogSort.rating => 'Mieux notés',
      CatalogSort.priceLow => 'Prix ↑',
      CatalogSort.priceHigh => 'Prix ↓',
      CatalogSort.recent => 'Récents',
    };
  }

  Future<void> _toggleFavorite(String providerId) async {
    HapticFeedback.mediumImpact();
    final favorites = ref.read(_favoritesProvider.notifier);
    final current = ref.read(_favoritesProvider);

    final newSet = Set<String>.from(current);
    if (newSet.contains(providerId)) {
      newSet.remove(providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Retiré des favoris', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _P.inkSoft,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } else {
      newSet.add(providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ajouté aux favoris ❤️', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    }

    favorites.state = newSet;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('thix_favorite_providers', newSet.toList());
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(onApply: _applyFilters),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION OFFRES & SERVICES
// ═══════════════════════════════════════════════════════════════════════════
class _CatalogOffersSection extends StatelessWidget {
  final List<ProviderOfferModel> offers;
  final ProviderCategory? category;
  final int totalActiveOffers;

  const _CatalogOffersSection({
    required this.offers,
    required this.category,
    required this.totalActiveOffers,
  });

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category == null
                            ? 'Offres & Services'
                            : 'Offres — ${category!.displayName}',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
                      ),
                      Text(
                        '${offers.length} offre${offers.length > 1 ? 's' : ''} disponible${offers.length > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _CatalogOfferCard(offer: offers[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE OFFRE DU CATALOGUE (multi-photos PageView)
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
        context.push('/thix-weeding/provider/detail/${offer.providerId}');
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
                      child: Text(
                        offer.type.displayName.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                  if (allImages.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${allImages.length}',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
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
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
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
// HERO BANNER ANIMÉ
// ═══════════════════════════════════════════════════════════════════════════
class _HeroBannerSection extends StatelessWidget {
  final List<ThixProviderModel> providers;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _HeroBannerSection({
    required this.providers,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 320,
        margin: const EdgeInsets.only(bottom: 16),
        child: PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final provider = providers[index];
            return AnimatedBuilder(
              animation: pageController,
              builder: (context, child) {
                double value = 1.0;
                if (pageController.position.haveDimensions) {
                  value = (pageController.page ?? 0) - index;
                  value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                }
                return Center(
                  child: SizedBox(
                    height: Curves.easeOut.transform(value) * 300,
                    child: child,
                  ),
                );
              },
              child: _HeroCard(provider: provider),
            );
          },
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _HeroCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cover = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls.first
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80';

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
            Image.network(
              cover,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _P.roseSoft,
                child: const Icon(Icons.broken_image_outlined, size: 64, color: _P.inkSoft),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
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
                    boxShadow: [BoxShadow(color: _P.gold.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('PREMIUM',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                child: const Icon(Icons.verified_rounded, size: 18, color: _P.green),
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
// SECTION : LES PLUS RÉSERVÉS
// ═══════════════════════════════════════════════════════════════════════════
class _TopProvidersSection extends StatelessWidget {
  final AsyncValue<List<ThixProviderModel>> topProvidersAsync;
  const _TopProvidersSection({required this.topProvidersAsync});

  @override
  Widget build(BuildContext context) {
    return topProvidersAsync.when(
      data: (providers) {
        if (providers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Les plus réservés',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: providers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _TopProviderCard(provider: providers[i]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TopProviderCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _TopProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cover = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls.first
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80';

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
                  Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.roseSoft)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('#${provider.reviewCount}',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
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
                        Text(
                          provider.minPrice != null ? '${provider.minPrice!.toStringAsFixed(0)}\$' : 'Devis',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _P.rose),
                        ),
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
// SECTION : PROMOTIONS
// ═══════════════════════════════════════════════════════════════════════════
class _PromoSection extends StatelessWidget {
  final AsyncValue<List<ThixProviderModel>> promoProvidersAsync;
  const _PromoSection({required this.promoProvidersAsync});

  @override
  Widget build(BuildContext context) {
    return promoProvidersAsync.when(
      data: (providers) {
        if (providers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P.red, Color(0xFFFF6B6B)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Promotions',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _P.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('HOT',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _P.red)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: providers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PromoCard(provider: providers[i]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _PromoCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cover = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls.first
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_P.red.withOpacity(0.1), _P.roseSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.red.withOpacity(0.3), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.roseSoft)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _P.red, borderRadius: BorderRadius.circular(8)),
                child: Text('PROMO',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${provider.minPrice!.toStringAsFixed(0)}\$',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
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
// SECTION : NOUVEAUX PRESTATAIRES
// ═══════════════════════════════════════════════════════════════════════════
class _NewProvidersSection extends StatelessWidget {
  final AsyncValue<List<ThixProviderModel>> newProvidersAsync;
  const _NewProvidersSection({required this.newProvidersAsync});

  @override
  Widget build(BuildContext context) {
    return newProvidersAsync.when(
      data: (providers) {
        if (providers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P.blue, Color(0xFF60A5FA)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fiber_new_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Nouveaux prestataires',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: providers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _NewProviderCard(provider: providers[i]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _NewProviderCard extends StatelessWidget {
  final ThixProviderModel provider;
  const _NewProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cover = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls.first
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80';

    final daysSinceCreation = DateTime.now().difference(provider.createdAt).inDays;

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
                  Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.roseSoft)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _P.blue, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        daysSinceCreation == 0 ? 'Aujourd\'hui' : 'Il y a ${daysSinceCreation}j',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
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

// ═══════════════════════════════════════════════════════════════════════════
// HEADER DU CATALOGUE
// ═══════════════════════════════════════════════════════════════════════════
class _CatalogHeader extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;

  const _CatalogHeader({
    required this.search,
    required this.onSearch,
    required this.onFilterTap,
    required this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_P.rose, _P.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
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
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: _P.inkSoft),
                        onPressed: () => onSearch(''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHIP DE CATÉGORIE
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

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
          boxShadow: isSelected
              ? [BoxShadow(color: _P.rose.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
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
// CARTE DE PRESTATAIRE (multi-photos PageView)
// ═══════════════════════════════════════════════════════════════════════════
class _CatalogCard extends StatelessWidget {
  final ThixProviderModel provider;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _CatalogCard({
    required this.provider,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final images = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls
        : ['https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80'];

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
                  PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (_, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _P.roseSoft,
                        child: const Icon(Icons.broken_image_outlined, size: 32, color: _P.inkSoft),
                      ),
                    ),
                  ),

                  if (provider.level == TrackingLevel.platinum)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: _P.gold.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('PREMIUM',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Icon(
                        provider.verificationStatus == ProviderVerificationStatus.verified
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        size: 14,
                        color: provider.verificationStatus == ProviderVerificationStatus.verified ? _P.green : _P.amber,
                      ),
                    ),
                  ),

                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${images.length}',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onFavoriteToggle();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: isFavorite ? _P.rose : _P.inkSoft,
                        ),
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
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: _P.gold),
                            const SizedBox(width: 3),
                            Text(provider.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink)),
                            Text(' (${provider.reviewCount})', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft)),
                          ],
                        ),
                        Text(
                          provider.minPrice != null
                              ? 'Dès ${provider.minPrice!.toStringAsFixed(0)}\$'
                              : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: _P.rose),
                        ),
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
// SHEET DE FILTRES
// ═══════════════════════════════════════════════════════════════════════════
class _FilterSheet extends ConsumerStatefulWidget {
  final VoidCallback onApply;
  const _FilterSheet({required this.onApply});

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late PriceRange _priceRange;
  late double? _minRating;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _priceRange = ref.read(_catalogPriceRangeProvider);
    _minRating = ref.read(_catalogRatingFilterProvider);
    _selectedCity = ref.read(_catalogCityFilterProvider);
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
          Text('Filtres avancés', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
          const SizedBox(height: 24),
          Text('Gamme de prix', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'Tous', isSelected: _priceRange == PriceRange.all, onTap: () => setState(() => _priceRange = PriceRange.all)),
              _FilterChip(label: '< 500\$', isSelected: _priceRange == PriceRange.low, onTap: () => setState(() => _priceRange = PriceRange.low)),
              _FilterChip(label: '500-2000\$', isSelected: _priceRange == PriceRange.medium, onTap: () => setState(() => _priceRange = PriceRange.medium)),
              _FilterChip(label: '> 2000\$', isSelected: _priceRange == PriceRange.high, onTap: () => setState(() => _priceRange = PriceRange.high)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Note minimale', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'Toutes', isSelected: _minRating == null, onTap: () => setState(() => _minRating = null)),
              _FilterChip(label: '3+ ⭐', isSelected: _minRating == 3.0, onTap: () => setState(() => _minRating == 3.0)),
              _FilterChip(label: '4+ ⭐', isSelected: _minRating == 4.0, onTap: () => setState(() => _minRating == 4.0)),
              _FilterChip(label: '4.5+ ⭐', isSelected: _minRating == 4.5, onTap: () => setState(() => _minRating == 4.5)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = PriceRange.all;
                      _minRating = null;
                      _selectedCity = null;
                    });
                  },
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
                    ref.read(_catalogCityFilterProvider.notifier).state = _selectedCity;
                    widget.onApply();
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
            ],
          ),
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
// SHEET DE TRI
// ═══════════════════════════════════════════════════════════════════════════
class _SortSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(_catalogSortProvider);
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
          _SortOption(icon: Icons.trending_up_rounded, label: 'Plus populaires', selected: currentSort == CatalogSort.popular,
              onTap: () { ref.read(_catalogSortProvider.notifier).state = CatalogSort.popular; Navigator.pop(context); }),
          _SortOption(icon: Icons.star_rounded, label: 'Mieux notés', selected: currentSort == CatalogSort.rating,
              onTap: () { ref.read(_catalogSortProvider.notifier).state = CatalogSort.rating; Navigator.pop(context); }),
          _SortOption(icon: Icons.attach_money_rounded, label: 'Prix croissant', selected: currentSort == CatalogSort.priceLow,
              onTap: () { ref.read(_catalogSortProvider.notifier).state = CatalogSort.priceLow; Navigator.pop(context); }),
          _SortOption(icon: Icons.attach_money_rounded, label: 'Prix décroissant', selected: currentSort == CatalogSort.priceHigh,
              onTap: () { ref.read(_catalogSortProvider.notifier).state = CatalogSort.priceHigh; Navigator.pop(context); }),
          _SortOption(icon: Icons.new_releases_rounded, label: 'Plus récents', selected: currentSort == CatalogSort.recent,
              onTap: () { ref.read(_catalogSortProvider.notifier).state = CatalogSort.recent; Navigator.pop(context); }),
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
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _P.rose : _P.inkSoft),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? _P.rose : _P.ink)),
            const Spacer(),
            if (selected) const Icon(Icons.check_rounded, size: 20, color: _P.rose),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE & ERROR STATE
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 64, color: _P.inkSoft),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft, height: 1.4)),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _P.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 64, color: _P.red),
            ),
            const SizedBox(height: 20),
            Text('Une erreur est survenue',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: _P.line)),
      child: const Center(child: CircularProgressIndicator(color: _P.rose)),
    );
  }
}
