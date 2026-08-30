// lib/presentation/thix_market/pages/search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../widgets/products/product_card.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 300);
const int _kPageSize = 20;
const int _kMaxRecentSearches = 10;
const int _kMaxQueryLength = 100;
const String _kRecentSearchesKey = 'market_recent_searches';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SearchValidators {
  _SearchValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }

  static double? parsePrice(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    final val = double.tryParse(cleaned);
    if (val == null || val < 0 || val > 999999999) return null;
    return val;
  }

  static String truncateQuery(String q) {
    return q.length > _kMaxQueryLength ? q.substring(0, _kMaxQueryLength) : q;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SearchPage] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[SearchPage] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[SearchPage] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// RECENT SEARCHES (avec persistance SharedPreferences)
// ============================================================================
class RecentSearchNotifier extends StateNotifier<List<String>> {
  RecentSearchNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kRecentSearchesKey) ?? [];
      state = list.where((e) => e.trim().isNotEmpty).take(_kMaxRecentSearches).toList();
      debugPrint('[SearchPage] 📋 Loaded ${state.length} recent searches');
    } catch (e) {
      debugPrint('[SearchPage] ⚠️ Load recent searches error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, state);
    } catch (e) {
      debugPrint('[SearchPage] ⚠️ Save recent searches error: $e');
    }
  }

  void add(String q) {
    final query = _SearchValidators.sanitize(q.trim(), maxLength: _kMaxQueryLength);
    if (query.isEmpty) return;
    state = [query, ...state.where((e) => e.toLowerCase() != query.toLowerCase())]
        .take(_kMaxRecentSearches)
        .toList();
    _save();
    debugPrint('[SearchPage] ➕ Added recent: "$query"');
  }

  void remove(String q) {
    state = state.where((e) => e != q).toList();
    _save();
    debugPrint('[SearchPage] ➖ Removed recent: "$q"');
  }

  void clear() {
    state = [];
    _save();
    debugPrint('[SearchPage] 🗑️ Cleared all recent searches');
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchNotifier, List<String>>(
  (ref) => RecentSearchNotifier(),
);

// ============================================================================
// SEARCH FILTERS
// ============================================================================
class SearchFilters {
  final double? minPrice;
  final double? maxPrice;
  final String sortBy; // newest | price_asc | price_desc

  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'newest',
  });

  bool get hasActiveFilters =>
      minPrice != null || maxPrice != null || sortBy != 'newest';

  int get activeCount {
    int c = 0;
    if (minPrice != null) c++;
    if (maxPrice != null) c++;
    if (sortBy != 'newest') c++;
    return c;
  }

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

// ============================================================================
// SEARCH NOTIFIER
// ============================================================================
class SearchNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  SearchNotifier(this.ref) : super(const AsyncData([]));

  final Ref ref;
  List<Map<String, dynamic>> _all = [];
  bool _isLoadingMore = false;
  bool hasMore = true;
  int totalResults = 0;
  String lastQuery = '';
  SearchFilters filters = const SearchFilters();

  Future<void> search(String query, {bool loadMore = false}) async {
    final q = _SearchValidators.truncateQuery(query.trim());
    if (q.isEmpty) return;

    // Protection double-tap
    if (loadMore && _isLoadingMore) return;

    final db = ref.read(supabaseClientProvider);

    if (!loadMore) {
      _all = [];
      hasMore = true;
      lastQuery = q;
      state = const AsyncLoading();
      ref.read(recentSearchesProvider.notifier).add(q);
      debugPrint('[SearchPage] 🔍 Searching: "$q"');
    } else {
      _isLoadingMore = true;
    }

    try {
      final offset = _all.length;

      // Construction typée de la requête (au lieu de dynamic)
      var qBuilder = db
          .from('products')
          .select('id, title, price, currency, image_url, brand, created_at, shop:shops(name)')
          .ilike('title', '%$q%');

      // Filtres prix
      if (filters.minPrice != null) {
        qBuilder = qBuilder.gte('price', filters.minPrice!);
      }
      if (filters.maxPrice != null) {
        qBuilder = qBuilder.lte('price', filters.maxPrice!);
      }

      // Tri
      switch (filters.sortBy) {
        case 'price_asc':
          qBuilder = qBuilder.order('price', ascending: true);
          break;
        case 'price_desc':
          qBuilder = qBuilder.order('price', ascending: false);
          break;
        default:
          qBuilder = qBuilder.order('created_at', ascending: false);
      }

      final res = await _withRetry(
        () => qBuilder.range(offset, offset + _kPageSize - 1),
        label: loadMore ? 'searchLoadMore[$_all.length]' : 'search["$q"]',
      );

      final list = List<Map<String, dynamic>>.from(res);

      // Dedup par ID
      final seenIds = _all.map((p) => p['id']?.toString()).toSet();
      final unique = list.where((p) {
        final id = p['id']?.toString();
        return id != null && seenIds.add(id);
      }).toList();

      _all = [..._all, ...unique];
      totalResults = _all.length;
      hasMore = list.length == _kPageSize;
      state = AsyncData(_all);

      debugPrint('[SearchPage] ✓ Got ${unique.length} results (total: ${_all.length}, hasMore: $hasMore)');
    } catch (e, st) {
      debugPrint('[SearchPage] ❌ Search error: $e');
      if (loadMore) {
        // Conserver l'état précédent sur erreur de pagination
        state = AsyncData(_all);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  void reset() {
    _all = [];
    _isLoadingMore = false;
    hasMore = true;
    totalResults = 0;
    lastQuery = '';
    filters = const SearchFilters();
    state = const AsyncData([]);
    debugPrint('[SearchPage] 🔄 Reset');
  }

  void applyFilters(SearchFilters f) {
    filters = f;
    debugPrint('[SearchPage] 🎛️ Applied filters: min=${f.minPrice}, max=${f.maxPrice}, sort=${f.sortBy}');
    if (lastQuery.isNotEmpty) {
      search(lastQuery);
    }
  }
}

final searchResultsProvider = StateNotifierProvider<SearchNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => SearchNotifier(ref),
);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController searchCtrl = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollCtrl = ScrollController();
  Timer? _debounceTimer;
  bool showRecent = true;

  @override
  void initState() {
    super.initState();
    scrollCtrl.addListener(_onScroll);
    focusNode.requestFocus();
    debugPrint('[SearchPage] 🔍 Page opened');
  }

  void _onScroll() {
    if (scrollCtrl.position.pixels >= scrollCtrl.position.maxScrollExtent - 200) {
      final notifier = ref.read(searchResultsProvider.notifier);
      if (notifier.hasMore && searchCtrl.text.trim().isNotEmpty) {
        notifier.search(searchCtrl.text, loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    scrollCtrl.removeListener(_onScroll);
    searchCtrl.dispose();
    focusNode.dispose();
    scrollCtrl.dispose();
    debugPrint('[SearchPage] 👋 Page disposed');
    super.dispose();
  }

  void doSearch(String q) {
    final query = _SearchValidators.sanitize(q.trim(), maxLength: _kMaxQueryLength);
    if (query.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => showRecent = false);
    ref.read(searchResultsProvider.notifier).search(query);
    FocusScope.of(context).unfocus();
  }

  void _onQueryChanged(String v) {
    _debounceTimer?.cancel();
    if (v.trim().isEmpty) {
      setState(() => showRecent = true);
      ref.read(searchResultsProvider.notifier).reset();
      return;
    }
    _debounceTimer = Timer(_kSearchDebounce, () {
      // Auto-search seulement si query >= 3 caractères
      if (v.trim().length >= 3) {
        setState(() => showRecent = false);
        ref.read(searchResultsProvider.notifier).search(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSearchesProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final searchNotifier = ref.read(searchResultsProvider.notifier);
    final activeFilters = searchNotifier.filters.activeCount;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ThixPolicy.inkDeep, ThixPolicy.primary, ThixPolicy.primary.withOpacity(0.9)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Semantics(
          label: 'Champ de recherche',
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    focusNode: focusNode,
                    style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher produits...',
                      hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white60),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: doSearch,
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                    tooltip: 'Effacer',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      searchCtrl.clear();
                      setState(() => showRecent = true);
                      searchNotifier.reset();
                    },
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Filtres${activeFilters > 0 ? " ($activeFilters actifs)" : ""}',
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  tooltip: 'Filtres',
                  onPressed: _showFilters,
                ),
                if (activeFilters > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$activeFilters',
                        style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: resultsAsync.when(
        loading: () => const _SearchSkeleton(),
        error: (e, _) => _ErrorState(
          message: _SearchValidators.sanitize(e.toString(), maxLength: 200),
          onRetry: () {
            final q = searchCtrl.text.trim();
            if (q.isNotEmpty) doSearch(q);
          },
        ),
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
                Text(
                  'Recherches récentes',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontSize: 16,
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Effacer tout l\'historique',
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(recentSearchesProvider.notifier).clear();
                    },
                    child: Text(
                      'Effacer tout',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.danger,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...recent.map(
            (s) => Semantics(
              button: true,
              label: 'Rechercher $s',
              child: ListTile(
                leading: const Icon(Icons.history_rounded, color: ThixPolicy.textMuted),
                title: Text(
                  _SearchValidators.sanitize(s, maxLength: _kMaxQueryLength),
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textMuted),
                  tooltip: 'Supprimer',
                  onPressed: () => ref.read(recentSearchesProvider.notifier).remove(s),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  searchCtrl.text = s;
                  doSearch(s);
                },
              ),
            ),
          ),
          Divider(height: 1, color: ThixPolicy.border.withOpacity(0.3)),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggestions',
                style: ThixPolicy.titleStyle.copyWith(
                  fontSize: 16,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
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
    return Semantics(
      button: true,
      label: 'Rechercher $label',
      child: ActionChip(
        label: Text(label, style: ThixPolicy.labelStyle.copyWith(fontSize: 13, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
        avatar: Icon(icon, size: 16, color: ThixPolicy.primary),
        onPressed: () {
          HapticFeedback.selectionClick();
          searchCtrl.text = label;
          doSearch(label);
        },
        backgroundColor: ThixPolicy.card,
        side: BorderSide(color: ThixPolicy.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThixPolicy.textMuted.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 64, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé',
            style: ThixPolicy.h3Style.copyWith(
              fontSize: 18,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'autres mots-clés',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Nouvelle recherche',
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                searchCtrl.clear();
                setState(() => showRecent = true);
                ref.read(searchResultsProvider.notifier).reset();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nouvelle recherche', style: TextStyle(fontWeight: ThixPolicy.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ThixPolicy.primary),
                foregroundColor: ThixPolicy.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontSize: 14,
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Ouvrir les filtres',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showFilters();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: ThixPolicy.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Filtrer',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: ThixPolicy.primary,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: ThixPolicy.primary,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              if (searchCtrl.text.trim().isNotEmpty) {
                await ref.read(searchResultsProvider.notifier).search(searchCtrl.text);
              }
            },
            child: GridView.builder(
              controller: scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
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
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                      ),
                    ),
                  );
                }
                final product = results[i];
                final id = product['id']?.toString() ?? '';
                if (!_SearchValidators.isValidId(id)) return const SizedBox.shrink();
                return ProductCard(
                  product: product,
                  onTap: (_) {
                    HapticFeedback.selectionClick();
                    context.push('/market/product/$id');
                    debugPrint('[SearchPage] 🛍️ Tap product $id');
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // FILTRES
  // ----------------------------------------------------------
  void _showFilters() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(searchResultsProvider.notifier);
    final current = notifier.filters;

    double? minPrice = current.minPrice;
    double? maxPrice = current.maxPrice;
    String sortBy = current.sortBy;

    final minCtrl = TextEditingController(text: minPrice?.toInt().toString() ?? '');
    final maxCtrl = TextEditingController(text: maxPrice?.toInt().toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThixPolicy.card,
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
                        color: ThixPolicy.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: ThixPolicy.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Filtres',
                        style: ThixPolicy.h2Style.copyWith(
                          fontSize: 18,
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tri
                  Text(
                    'Trier par',
                    style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sortChip('Plus récents', 'newest', sortBy, (v) => setModalState(() => sortBy = v)),
                      _sortChip('Prix ↑', 'price_asc', sortBy, (v) => setModalState(() => sortBy = v)),
                      _sortChip('Prix ↓', 'price_desc', sortBy, (v) => setModalState(() => sortBy = v)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Prix (FCFA)',
                    style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain),
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
                            fillColor: ThixPolicy.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ThixPolicy.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ThixPolicy.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
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
                            fillColor: ThixPolicy.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ThixPolicy.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ThixPolicy.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
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
                            HapticFeedback.selectionClick();
                            notifier.applyFilters(const SearchFilters());
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThixPolicy.textSecondary,
                            side: BorderSide(color: ThixPolicy.border),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final min = _SearchValidators.parsePrice(minCtrl.text);
                            final max = _SearchValidators.parsePrice(maxCtrl.text);

                            // Validation logique min <= max
                            if (min != null && max != null && min > max) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: const Text('Le prix min doit être inférieur au max'),
                                  backgroundColor: ThixPolicy.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            notifier.applyFilters(SearchFilters(minPrice: min, maxPrice: max, sortBy: sortBy));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThixPolicy.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Appliquer', style: TextStyle(fontWeight: ThixPolicy.bold)),
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
    ).then((_) {
      minCtrl.dispose();
      maxCtrl.dispose();
    });
  }

  Widget _sortChip(String label, String value, String selected, ValueChanged<String> onSelect) {
    final isSelected = selected == value;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        selectedColor: ThixPolicy.primary.withOpacity(0.15),
        backgroundColor: ThixPolicy.surfaceSoft,
        labelStyle: TextStyle(
          color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
          fontWeight: ThixPolicy.semiBold,
          fontSize: 13,
        ),
        side: BorderSide(color: isSelected ? ThixPolicy.primary : ThixPolicy.border),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 80, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
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
            Text(
              'Erreur de recherche',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
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
