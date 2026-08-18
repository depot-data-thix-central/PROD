// lib/presentation/thix_market/pages/search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/market_providers.dart';
import '../widgets/products/product_card.dart';

// ============================================================
// PROVIDERS
// ============================================================
class RecentSearchNotifier extends StateNotifier<List<String>> {
  RecentSearchNotifier() : super([]);

  void add(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    state = [query, ...state.where((e) => e != query)].take(10).toList();
  }

  void remove(String q) => state = state.where((e) => e != q).toList();
  void clear() => state = [];
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchNotifier, List<String>>(
  (ref) => RecentSearchNotifier(),
);

class SearchFilters {
  final double? minPrice;
  final double? maxPrice;
  final String sortBy; // newest | price_asc | price_desc

  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'newest',
  });

  SearchFilters copyWith({
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    bool clearMin = false,
    bool clearMax = false,
  }) {
    return SearchFilters(
      minPrice: clearMin ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMax ? null : (maxPrice ?? this.maxPrice),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class SearchNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  SearchNotifier(this.ref) : super(const AsyncData([]));

  final Ref ref;
  List<Map<String, dynamic>> _all = [];
  bool hasMore = true;
  int totalResults = 0;
  String lastQuery = '';
  SearchFilters filters = const SearchFilters();

  Future<void> search(String query, {bool loadMore = false}) async {
    final q = query.trim();
    if (q.isEmpty) return;

    final db = ref.read(supabaseClientProvider);

    if (!loadMore) {
      _all = [];
      hasMore = true;
      lastQuery = q;
      state = const AsyncLoading();
      ref.read(recentSearchesProvider.notifier).add(q);
    }

    try {
      final offset = _all.length;

      // Use dynamic to seamlessly handle Supabase filter and transform builders
      dynamic queryBuilder = db
          .from('products')
          .select('id, title, price, currency, image_url, brand, created_at, shop:shops(name)')
          .ilike('title', '%$q%');

      // Filtres prix
      if (filters.minPrice != null) {
        queryBuilder = queryBuilder.gte('price', filters.minPrice!);
      }
      if (filters.maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', filters.maxPrice!);
      }

      // Tri
      switch (filters.sortBy) {
        case 'price_asc':
          queryBuilder = queryBuilder.order('price', ascending: true);
          break;
        case 'price_desc':
          queryBuilder = queryBuilder.order('price', ascending: false);
          break;
        default:
          queryBuilder = queryBuilder.order('created_at', ascending: false);
      }

      final res = await queryBuilder.range(offset, offset + 19);
      final list = List<Map<String, dynamic>>.from(res);

      _all = [..._all, ...list];
      totalResults = _all.length;
      hasMore = list.length == 20;
      state = AsyncData(_all);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() {
    _all = [];
    hasMore = true;
    totalResults = 0;
    lastQuery = '';
    filters = const SearchFilters();
    state = const AsyncData([]);
  }

  void applyFilters(SearchFilters f) {
    filters = f;
    if (lastQuery.isNotEmpty) {
      search(lastQuery);
    }
  }
}

final searchResultsProvider = StateNotifierProvider<SearchNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => SearchNotifier(ref),
);

// ============================================================
// COULEURS
// ============================================================
const Color navyDeep = Color(0xFF0A1F44);
const Color navy = Color(0xFF123B7A);
const Color primaryBlue = Color(0xFF2D6CDF);
const Color softBlue = Color(0xFFEFF5FF);
const Color pureWhite = Color(0xFFFFFFFF);
const Color darkText = Color(0xFF10192E);
const Color mutedText = Color(0xFF7386A8);

// ============================================================
// PAGE
// ============================================================
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController searchCtrl = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollCtrl = ScrollController();
  bool showRecent = true;

  @override
  void initState() {
    super.initState();
    scrollCtrl.addListener(() {
      if (scrollCtrl.position.pixels >=
          scrollCtrl.position.maxScrollExtent - 200) {
        final notifier = ref.read(searchResultsProvider.notifier);
        if (notifier.hasMore && searchCtrl.text.trim().isNotEmpty) {
          notifier.search(searchCtrl.text, loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    focusNode.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  void doSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() => showRecent = false);
    ref.read(searchResultsProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSearchesProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final searchNotifier = ref.read(searchResultsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navyDeep, navy, primaryBlue],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher produits...',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: doSearch,
                  onChanged: (v) {
                    if (v.isEmpty) {
                      setState(() => showRecent = true);
                      searchNotifier.reset();
                    }
                  },
                ),
              ),
              if (searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                  onPressed: () {
                    searchCtrl.clear();
                    setState(() => showRecent = true);
                    searchNotifier.reset();
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: resultsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (results) {
          if (showRecent) return _buildRecent(recent);
          if (results.isEmpty && searchCtrl.text.isNotEmpty) {
            return _buildEmpty();
          }
          return _buildResults(results, searchNotifier);
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // RÉCENT + SUGGESTIONS
  // ----------------------------------------------------------
  Widget _buildRecent(List<String> recent) {
    return ListView(
      children: [
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recherches récentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                  child: const Text(
                    'Effacer tout',
                    style: TextStyle(
                      color: Color(0xFFFF5B3D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...recent.map(
            (s) => ListTile(
              leading: const Icon(Icons.history, color: mutedText),
              title: Text(s, style: const TextStyle(fontSize: 14, color: darkText)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18, color: mutedText),
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).remove(s),
              ),
              onTap: () {
                searchCtrl.text = s;
                doSearch(s);
              },
            ),
          ),
          const Divider(height: 1, color: softBlue),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Mode', Icons.checkroom_rounded),
                  _chip('Électronique', Icons.phone_android_rounded),
                  _chip('Maison', Icons.chair_rounded),
                  _chip('Sport', Icons.sports_soccer_rounded),
                  _chip('Beauté', Icons.spa_rounded),
                  _chip('Auto', Icons.directions_car_rounded),
                  _chip('Immobilier', Icons.house_rounded),
                  _chip('Services', Icons.build_rounded),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: primaryBlue),
      onPressed: () {
        searchCtrl.text = label;
        doSearch(label);
      },
      backgroundColor: pureWhite,
      side: BorderSide(color: Colors.grey.shade200),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // ----------------------------------------------------------
  // EMPTY
  // ----------------------------------------------------------
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: mutedText),
          const SizedBox(height: 16),
          const Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Essayez d\'autres mots-clés',
            style: TextStyle(color: mutedText),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              searchCtrl.clear();
              setState(() => showRecent = true);
              ref.read(searchResultsProvider.notifier).reset();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Nouvelle recherche'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryBlue),
              foregroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // RÉSULTATS
  // ----------------------------------------------------------
  Widget _buildResults(
    List<Map<String, dynamic>> results,
    SearchNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${notifier.totalResults} résultat${notifier.totalResults > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showFilters,
                child: const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 16, color: primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      'Filtrer',
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: results.length + (notifier.hasMore ? 1 : 0),
            itemBuilder: (c, i) {
              if (i == results.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: primaryBlue),
                  ),
                );
              }
              final product = results[i];
              return ProductCard(
                product: product,
                onTap: (_) =>
                    context.push('/market/product/${product['id']}'),
              );
            },
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // FILTRES
  // ----------------------------------------------------------
  void _showFilters() {
    final notifier = ref.read(searchResultsProvider.notifier);
    final current = notifier.filters;

    double? minPrice = current.minPrice;
    double? maxPrice = current.maxPrice;
    String sortBy = current.sortBy;

    final minCtrl = TextEditingController(
      text: minPrice?.toInt().toString() ?? '',
    );
    final maxCtrl = TextEditingController(
      text: maxPrice?.toInt().toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filtres',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tri
                  const Text(
                    'Trier par',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sortChip('Plus récents', 'newest', sortBy, (v) {
                        setModalState(() => sortBy = v);
                      }),
                      _sortChip('Prix ↑', 'price_asc', sortBy, (v) {
                        setModalState(() => sortBy = v);
                      }),
                      _sortChip('Prix ↓', 'price_desc', sortBy, (v) {
                        setModalState(() => sortBy = v);
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Prix',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Min',
                            filled: true,
                            fillColor: softBlue,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max',
                            filled: true,
                            fillColor: softBlue,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            notifier.applyFilters(const SearchFilters());
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mutedText,
                            side: BorderSide(color: Colors.grey.shade300),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final min = double.tryParse(minCtrl.text.trim());
                            final max = double.tryParse(maxCtrl.text.trim());
                            notifier.applyFilters(
                              SearchFilters(
                                minPrice: min,
                                maxPrice: max,
                                sortBy: sortBy,
                              ),
                            );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Appliquer',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortChip(
    String label,
    String value,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: primaryBlue.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? primaryBlue : darkText,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? primaryBlue : Colors.grey.shade300,
      ),
    );
  }
}
