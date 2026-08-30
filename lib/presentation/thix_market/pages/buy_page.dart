// lib/presentation/market/buy_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../widgets/products/product_card.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kTimeout = Duration(seconds: 15);
const Duration _kScrollDebounce = Duration(milliseconds: 300);
const int _kMaxProductsMemory = 500;

class _BuyValidators {
  _BuyValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t;
  }
}

// ============================================================================
// PROVIDERS (à créer si manquants)
// ============================================================================

/// Provider unifié qui gère explore + favorites + wishlist en un seul endroit
final buyPageStateProvider = StateNotifierProvider<BuyPageNotifier, BuyPageState>((ref) {
  return BuyPageNotifier(ref);
});

class BuyPageState {
  final String selectedCategory;
  final String selectedTab; // 'explore', 'favorites', 'wishlist'
  final AsyncValue<List<Map<String, dynamic>>> exploreProducts;
  final AsyncValue<List<Map<String, dynamic>>> favorites;
  final AsyncValue<List<Map<String, dynamic>>> wishlist;
  final Map<String, dynamic> filters;

  const BuyPageState({
    this.selectedCategory = 'all',
    this.selectedTab = 'explore',
    this.exploreProducts = const AsyncLoading(),
    this.favorites = const AsyncLoading(),
    this.wishlist = const AsyncLoading(),
    this.filters = const {},
  });

  BuyPageState copyWith({
    String? selectedCategory,
    String? selectedTab,
    AsyncValue<List<Map<String, dynamic>>>? exploreProducts,
    AsyncValue<List<Map<String, dynamic>>>? favorites,
    AsyncValue<List<Map<String, dynamic>>>? wishlist,
    Map<String, dynamic>? filters,
  }) {
    return BuyPageState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedTab: selectedTab ?? this.selectedTab,
      exploreProducts: exploreProducts ?? this.exploreProducts,
      favorites: favorites ?? this.favorites,
      wishlist: wishlist ?? this.wishlist,
      filters: filters ?? this.filters,
    );
  }
}

class BuyPageNotifier extends StateNotifier<BuyPageState> {
  final Ref ref;
  Timer? _scrollDebounceTimer;

  BuyPageNotifier(this.ref) : super(const BuyPageState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    debugPrint('[BuyPage] 🔄 Loading all data');
    await Future.wait([
      _loadExplore(),
      _loadFavorites(),
      _loadWishlist(),
    ]);
  }

  Future<void> _loadExplore() async {
    state = state.copyWith(exploreProducts: const AsyncLoading());
    try {
      final repo = ref.read(marketRepositoryProvider);
      final products = await repo.fetchProducts(
        category: state.selectedCategory,
        limit: 20,
      ).timeout(_kTimeout);
      state = state.copyWith(exploreProducts: AsyncData(products));
      debugPrint('[BuyPage] ✓ Loaded ${products.length} explore products');
    } catch (e) {
      state = state.copyWith(exploreProducts: AsyncError(e, StackTrace.current));
      debugPrint('[BuyPage] ❌ Explore error: $e');
    }
  }

  Future<void> _loadFavorites() async {
    state = state.copyWith(favorites: const AsyncLoading());
    try {
      final repo = ref.read(marketRepositoryProvider);
      final favorites = await repo.fetchFavorites().timeout(_kTimeout);
      state = state.copyWith(favorites: AsyncData(favorites));
      debugPrint('[BuyPage] ✓ Loaded ${favorites.length} favorites');
    } catch (e) {
      state = state.copyWith(favorites: AsyncError(e, StackTrace.current));
      debugPrint('[BuyPage] ❌ Favorites error: $e');
    }
  }

  Future<void> _loadWishlist() async {
    state = state.copyWith(wishlist: const AsyncLoading());
    try {
      final repo = ref.read(marketRepositoryProvider);
      final wishlist = await repo.fetchWishlist().timeout(_kTimeout);
      state = state.copyWith(wishlist: AsyncData(wishlist));
      debugPrint('[BuyPage] ✓ Loaded ${wishlist.length} wishlist items');
    } catch (e) {
      state = state.copyWith(wishlist: AsyncError(e, StackTrace.current));
      debugPrint('[BuyPage] ❌ Wishlist error: $e');
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    _loadExplore();
  }

  void setTab(String tab) {
    HapticFeedback.selectionClick();
    state = state.copyWith(selectedTab: tab);
  }

  void updateFilters(Map<String, dynamic> newFilters) {
    state = state.copyWith(filters: {...state.filters, ...newFilters});
    _loadExplore();
  }

  Future<void> toggleFavorite(String productId) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(marketRepositoryProvider);
    try {
      await repo.toggleFavorite(productId).timeout(_kTimeout);
      await _loadFavorites();
      debugPrint('[BuyPage] ✓ Toggled favorite $productId');
    } catch (e) {
      debugPrint('[BuyPage] ❌ Toggle favorite error: $e');
    }
  }

  Future<void> removeFromWishlist(String itemId) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(marketRepositoryProvider);
    try {
      await repo.removeFromWishlist(itemId).timeout(_kTimeout);
      await _loadWishlist();
      debugPrint('[BuyPage] ✓ Removed from wishlist $itemId');
    } catch (e) {
      debugPrint('[BuyPage] ❌ Remove wishlist error: $e');
    }
  }

  Future<void> createWishlist(String name, {String? description, bool isPublic = true}) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(marketRepositoryProvider);
    try {
      await repo.createWishlist(name, description: description, isPublic: isPublic).timeout(_kTimeout);
      await _loadWishlist();
      debugPrint('[BuyPage] ✓ Created wishlist "$name"');
    } catch (e) {
      debugPrint('[BuyPage] ❌ Create wishlist error: $e');
      rethrow;
    }
  }

  void onScroll(ScrollController controller) {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_kScrollDebounce, () {
      if (controller.position.pixels > controller.position.maxScrollExtent - 600) {
        debugPrint('[BuyPage] 📜 Load more triggered');
        // TODO: implémenter pagination
      }
    });
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class BuyPage extends ConsumerStatefulWidget {
  const BuyPage({super.key});
  @override
  ConsumerState<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends ConsumerState<BuyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> categories = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.apps_rounded},
    {'id': 'fashion', 'name': 'Mode', 'icon': Icons.checkroom_rounded},
    {'id': 'electronics', 'name': 'Électronique', 'icon': Icons.phone_android_rounded},
    {'id': 'home', 'name': 'Maison', 'icon': Icons.chair_rounded},
    {'id': 'services', 'name': 'Services', 'icon': Icons.build_rounded},
    {'id': 'vehicles', 'name': 'Véhicules', 'icon': Icons.directions_car_rounded},
    {'id': 'realestate', 'name': 'Immobilier', 'icon': Icons.house_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(() => ref.read(buyPageStateProvider.notifier).onScroll(_scrollController));
    _tabController.addListener(() {
      final tabs = ['explore', 'favorites', 'wishlist'];
      ref.read(buyPageStateProvider.notifier).setTab(tabs[_tabController.index]);
    });
    debugPrint('[BuyPage] 🛍️ Page opened');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    debugPrint('[BuyPage] 👋 Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buyPageStateProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildAppBar(state)],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExploreTab(state),
            _buildFavoritesTab(state),
            _buildWishlistTab(state),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuyPageState state) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: ThixPolicy.inkDeep,
      surfaceTintColor: ThixPolicy.inkDeep,
      toolbarHeight: 60,
      expandedHeight: 60,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ThixPolicy.inkDeep, ThixPolicy.primary],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ThixPolicy.gold.withOpacity(0.5)),
            ),
            child: const Icon(Icons.shopping_bag_rounded, size: 16, color: ThixPolicy.gold),
          ),
          const SizedBox(width: 10),
          Text('Acheter', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
        ],
      ),
      actions: [
        _appBarIconButton(Icons.compare_arrows_rounded, 'Comparer', () => context.push('/market/compare')),
        _appBarIconButton(Icons.notifications_active_rounded, 'Alertes', () => context.push('/market/price-alerts')),
        _appBarIconButton(Icons.refresh_rounded, 'Rafraîchir', () => ref.read(buyPageStateProvider.notifier).loadAll()),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Explorer'),
              Tab(text: 'Favoris'),
              Tab(text: 'Wishlist'),
            ],
            indicator: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(12)),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: ThixPolicy.inkDeep,
            unselectedLabelColor: Colors.white70,
            labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 12.5),
            unselectedLabelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
            dividerColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _appBarIconButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExploreTab(BuyPageState state) {
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: categories.length,
            itemBuilder: (_, index) {
              final category = categories[index];
              final isSelected = state.selectedCategory == category['id'];
              return Semantics(
                button: true,
                label: 'Catégorie ${category['name']}',
                selected: isSelected,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(buyPageStateProvider.notifier).setCategory(category['id']);
                  },
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.border,
                              width: isSelected ? 0 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? ThixPolicy.inkDeep.withOpacity(0.25) : ThixPolicy.inkDeep.withOpacity(0.04),
                                blurRadius: isSelected ? 14 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            color: isSelected ? ThixPolicy.gold : ThixPolicy.textMuted,
                            size: 21,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _BuyValidators.sanitize(category['name'], maxLength: 20),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildQuickFilterChip('Prix', Icons.attach_money_rounded, () => _showPriceFilter()),
              const SizedBox(width: 8),
              _buildQuickFilterChip('Distance', Icons.location_on_rounded, () => _showDistanceFilter()),
              const SizedBox(width: 8),
              _buildQuickFilterChip('Note', Icons.star_rounded, () => _showRatingFilter()),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Filtres avancés',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showAdvancedFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [ThixPolicy.inkDeep, ThixPolicy.primary]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune_rounded, size: 13, color: ThixPolicy.gold),
                        const SizedBox(width: 5),
                        Text(
                          'Filtres',
                          style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: state.exploreProducts.when(
            loading: () => const _SkeletonGrid(),
            error: (e, _) => _ErrorState(message: _BuyValidators.sanitize(e.toString()), onRetry: () => ref.read(buyPageStateProvider.notifier).loadAll()),
            data: (products) {
              if (products.isEmpty) return _EmptyState(message: 'Aucun produit trouvé', icon: Icons.shopping_bag_outlined);
              return RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: () => ref.read(buyPageStateProvider.notifier).loadAll(),
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final product = products[index];
                    final id = product['id']?.toString();
                    if (id == null || id.isEmpty) return const SizedBox.shrink();
                    return ProductCard(
                      product: product,
                      onTap: (_) {
                        HapticFeedback.selectionClick();
                        context.push('/market/product/$id');
                      },
                      onFavoriteTap: (id) => ref.read(buyPageStateProvider.notifier).toggleFavorite(id),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, IconData icon, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: 'Filtrer par $label',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: ThixPolicy.primary),
              const SizedBox(width: 5),
              Text(
                _BuyValidators.sanitize(label, maxLength: 20),
                style: ThixPolicy.labelStyle.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesTab(BuyPageState state) {
    return state.favorites.when(
      loading: () => const _SkeletonGrid(),
      error: (e, _) => _ErrorState(message: _BuyValidators.sanitize(e.toString()), onRetry: () => ref.read(buyPageStateProvider.notifier).loadAll()),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyStateWithAction(
            title: 'Aucun favori',
            subtitle: 'Ajoutez des produits à vos favoris',
            icon: Icons.favorite_border_rounded,
            onAction: () => _tabController.animateTo(0),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final product = list[i];
            final id = product['id']?.toString();
            if (id == null || id.isEmpty) return const SizedBox.shrink();
            return ProductCard(
              product: product,
              isFavorite: true,
              onTap: (_) {
                HapticFeedback.selectionClick();
                context.push('/market/product/$id');
              },
              onFavoriteTap: (id) => ref.read(buyPageStateProvider.notifier).toggleFavorite(id),
            );
          },
        );
      },
    );
  }

  Widget _buildWishlistTab(BuyPageState state) {
    return state.wishlist.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (e, _) => _ErrorState(message: _BuyValidators.sanitize(e.toString()), onRetry: () => ref.read(buyPageStateProvider.notifier).loadAll()),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyStateWithAction(
            title: 'Wishlist vide',
            subtitle: 'Créez une liste de souhaits partageable',
            icon: Icons.share_rounded,
            onAction: _createWishlist,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, index) {
            final item = list[index];
            final prod = item['products'] as Map<String, dynamic>?;
            final img = _BuyValidators.sanitizeUrl(prod?['image_url']?.toString() ?? item['image_url']?.toString());
            final itemId = item['id']?.toString();
            if (itemId == null || itemId.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img == null
                      ? Container(
                          width: 52,
                          height: 52,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.image_rounded, size: 22, color: ThixPolicy.textMuted),
                        )
                      : CachedNetworkImage(
                          imageUrl: img,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: ThixPolicy.surfaceSoft,
                            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
                          ),
                        ),
                ),
                title: Text(
                  _BuyValidators.sanitize(prod?['title']?.toString() ?? item['name']?.toString() ?? 'Produit', maxLength: 80),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5, color: ThixPolicy.textMain),
                ),
                subtitle: Text(
                  '${((prod?['price'] as num?)?.toInt() ?? (item['price'] as num?)?.toInt() ?? 0)} FCFA',
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
                trailing: Semantics(
                  button: true,
                  label: 'Retirer de la wishlist',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => ref.read(buyPageStateProvider.notifier).removeFromWishlist(itemId),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 17, color: ThixPolicy.danger),
                    ),
                  ),
                ),
                onTap: () {
                  final productId = item['product_id']?.toString() ?? prod?['id']?.toString();
                  if (productId != null && productId.isNotEmpty) {
                    HapticFeedback.selectionClick();
                    context.push('/market/product/$productId');
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showPriceFilter() {
    debugPrint('[BuyPage] 🏷️ Price filter clicked');
    // TODO: implémenter
  }

  void _showDistanceFilter() {
    debugPrint('[BuyPage] 📍 Distance filter clicked');
    // TODO: implémenter
  }

  void _showRatingFilter() {
    debugPrint('[BuyPage] ⭐ Rating filter clicked');
    // TODO: implémenter
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdvancedFiltersSheet(),
    );
  }

  void _createWishlist() {
    showDialog(
      context: context,
      builder: (_) => const _CreateWishlistDialog(),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, style: ThixPolicy.bodySmallStyle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(message, style: ThixPolicy.labelStyle.copyWith(fontSize: 15, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyStateWithAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onAction;
  const _EmptyStateWithAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: ThixPolicy.inkDeep.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold.withOpacity(0.4), width: 1.4),
              ),
              child: Icon(icon, size: 38, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(subtitle, style: ThixPolicy.bodySmallStyle, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              ),
              child: Text(title == 'Wishlist vide' ? 'Créer ma wishlist' : 'Explorer', style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHEETS & DIALOGS
// ============================================================================

class _AdvancedFiltersSheet extends ConsumerStatefulWidget {
  const _AdvancedFiltersSheet();
  @override
  ConsumerState<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends ConsumerState<_AdvancedFiltersSheet> {
  RangeValues _priceRange = const RangeValues(0, 1000000);
  final Set<String> _selectedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded, size: 17, color: ThixPolicy.primary),
              ),
              const SizedBox(width: 10),
              Text('Filtres avancés', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 17, color: ThixPolicy.textMain)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Prix (FCFA)', style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: ThixPolicy.primary,
              inactiveTrackColor: ThixPolicy.border,
              thumbColor: ThixPolicy.gold,
              overlayColor: ThixPolicy.gold.withOpacity(0.15),
            ),
            child: RangeSlider(
              values: _priceRange,
              min: 0,
              max: 1000000,
              divisions: 10,
              labels: RangeLabels(
                '${_priceRange.start.toInt()}',
                '${_priceRange.end.toInt()}',
              ),
              onChanged: (values) => setState(() => _priceRange = values),
            ),
          ),
          const SizedBox(height: 14),
          Text('Catégories', style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Mode', 'Électronique', 'Maison', 'Services', 'Véhicules'].map((cat) {
              final selected = _selectedCategories.contains(cat);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedCategories.remove(cat);
                    } else {
                      _selectedCategories.add(cat);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? ThixPolicy.primary : ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? ThixPolicy.primary : ThixPolicy.border),
                  ),
                  child: Text(
                    cat,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : ThixPolicy.textMain,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ThixPolicy.primary, width: 1.6),
                    foregroundColor: ThixPolicy.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Réinitialiser', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(buyPageStateProvider.notifier).updateFilters({
                      'priceMin': _priceRange.start,
                      'priceMax': _priceRange.end,
                      'categories': _selectedCategories.toList(),
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateWishlistDialog extends ConsumerStatefulWidget {
  const _CreateWishlistDialog();
  @override
  ConsumerState<_CreateWishlistDialog> createState() => _CreateWishlistDialogState();
}

class _CreateWishlistDialogState extends ConsumerState<_CreateWishlistDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.favorite_rounded, size: 16, color: ThixPolicy.gold),
                ),
                const SizedBox(width: 10),
                Text('Créer une wishlist', style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.textMain)),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nom de la liste',
                hintText: 'Ex: Cadeaux Noël',
                labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optionnel)',
                labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Liste publique', style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5, color: ThixPolicy.textMain)),
              value: _isPublic,
              activeColor: ThixPolicy.primary,
              activeTrackColor: ThixPolicy.gold.withOpacity(0.4),
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading || _nameCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          try {
                            await ref.read(buyPageStateProvider.notifier).createWishlist(
                                  _nameCtrl.text.trim(),
                                  description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                                  isPublic: _isPublic,
                                );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Wishlist créée avec succès'), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Créer', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
