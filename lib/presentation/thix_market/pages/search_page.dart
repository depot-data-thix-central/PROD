// lib/presentation/thix_market/pages/search_page.dart
// ============================================================================
// SEARCH PAGE — Production Enterprise v2
// ============================================================================
// Fonctionnalités :
//   ✅ Champ de saisie lisible (fond blanc opaque + texte sombre)
//   ✅ Filtres avancés : tri, devise, pays (54 pays africains), catégorie, prix
//   ✅ Symbole de devise dynamique (plus de "FCFA" codé en dur)
//   ✅ Chips de filtres actifs dismissibles
//   ✅ Debounce 300ms + garde anti-race-condition (seq)
//   ✅ Pagination + dedup + retry + timeout
//   ✅ Recherches récentes persistées (SharedPreferences)
//   ✅ i18n avec fallbacks FR + Semantics + Haptics + logs structurés
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../providers/market_providers.dart';
import '../widgets/products/product_card.dart';

// ============================================================================
// CONFIGURATION CENTRALISÉE
// ============================================================================

/// Colonnes de la table `products` utilisées par la recherche.
/// ⚠️ Ajuste [_kCountryColumn] si ta colonne pays s'appelle autrement.
const String _kCountryColumn = 'country';
const String _kSelectColumns =
    'id, title, description, price, discount_price, currency, image_url, images, '
    'brand, category, $_kCountryColumn, city, stock, is_flash_sale, expires_at, '
    'created_at, shop:shops(name)';

const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 300);
const int _kPageSize = 20;
const int _kMaxRecentSearches = 10;
const int _kMaxQueryLength = 100;
const String _kRecentSearchesKey = 'market_recent_searches';

// ─── DEVISES ────────────────────────────────────────────────────────────────
class CurrencyInfo {
  final String code;
  final String symbol;
  final String label;
  const CurrencyInfo(this.code, this.symbol, this.label);
}

/// Devises proposées dans le filtre (couvre l'Afrique + international).
const List<CurrencyInfo> _kCurrencies = [
  CurrencyInfo('USD', r'$', 'Dollar US'),
  CurrencyInfo('CDF', 'FC', 'Franc congolais'),
  CurrencyInfo('XOF', 'FCFA', 'Franc CFA (UEMOA)'),
  CurrencyInfo('XAF', 'FCFA', 'Franc CFA (CEMAC)'),
  CurrencyInfo('NGN', '₦', 'Naira'),
  CurrencyInfo('KES', 'KSh', 'Shilling kenyan'),
  CurrencyInfo('ZAR', 'R', 'Rand'),
  CurrencyInfo('GHS', '₵', 'Cedi'),
  CurrencyInfo('MAD', 'DH', 'Dirham'),
  CurrencyInfo('DZD', 'DA', 'Dinar algérien'),
  CurrencyInfo('EGP', 'E£', 'Livre égyptienne'),
  CurrencyInfo('ETB', 'Br', 'Birr'),
  CurrencyInfo('TZS', 'TSh', 'Shilling tanzanien'),
  CurrencyInfo('UGX', 'USh', 'Shilling ougandais'),
  CurrencyInfo('RWF', 'FRw', 'Franc rwandais'),
];

String currencySymbol(String? code) {
  if (code == null) return '';
  for (final c in _kCurrencies) {
    if (c.code == code) return c.symbol;
  }
  return code;
}

// ─── PAYS AFRICAINS (54) ────────────────────────────────────────────────────
class AfricanCountry {
  final String code;
  final String name;
  const AfricanCountry(this.code, this.name);
}

const List<AfricanCountry> _kAfricanCountries = [
  AfricanCountry('DZ', 'Algérie'), AfricanCountry('AO', 'Angola'),
  AfricanCountry('BJ', 'Bénin'), AfricanCountry('BW', 'Botswana'),
  AfricanCountry('BF', 'Burkina Faso'), AfricanCountry('BI', 'Burundi'),
  AfricanCountry('CM', 'Cameroun'), AfricanCountry('CV', 'Cap-Vert'),
  AfricanCountry('CF', 'Centrafrique'), AfricanCountry('KM', 'Comores'),
  AfricanCountry('CG', 'Congo'), AfricanCountry('CD', 'RD Congo'),
  AfricanCountry('CI', "Côte d'Ivoire"), AfricanCountry('DJ', 'Djibouti'),
  AfricanCountry('EG', 'Égypte'), AfricanCountry('ER', 'Érythrée'),
  AfricanCountry('SZ', 'Eswatini'), AfricanCountry('ET', 'Éthiopie'),
  AfricanCountry('GA', 'Gabon'), AfricanCountry('GM', 'Gambie'),
  AfricanCountry('GH', 'Ghana'), AfricanCountry('GN', 'Guinée'),
  AfricanCountry('GW', 'Guinée-Bissau'), AfricanCountry('GQ', 'Guinée équ.'),
  AfricanCountry('KE', 'Kenya'), AfricanCountry('LS', 'Lesotho'),
  AfricanCountry('LR', 'Libéria'), AfricanCountry('LY', 'Libye'),
  AfricanCountry('MG', 'Madagascar'), AfricanCountry('MW', 'Malawi'),
  AfricanCountry('ML', 'Mali'), AfricanCountry('MA', 'Maroc'),
  AfricanCountry('MR', 'Mauritanie'), AfricanCountry('MU', 'Maurice'),
  AfricanCountry('MZ', 'Mozambique'), AfricanCountry('NA', 'Namibie'),
  AfricanCountry('NE', 'Niger'), AfricanCountry('NG', 'Nigeria'),
  AfricanCountry('RW', 'Rwanda'), AfricanCountry('ST', 'Sao Tomé'),
  AfricanCountry('SN', 'Sénégal'), AfricanCountry('SC', 'Seychelles'),
  AfricanCountry('SL', 'Sierra Leone'), AfricanCountry('SO', 'Somalie'),
  AfricanCountry('SD', 'Soudan'), AfricanCountry('SS', 'Soudan du Sud'),
  AfricanCountry('ZA', 'Afrique du Sud'), AfricanCountry('TZ', 'Tanzanie'),
  AfricanCountry('TD', 'Tchad'), AfricanCountry('TG', 'Togo'),
  AfricanCountry('TN', 'Tunisie'), AfricanCountry('UG', 'Ouganda'),
  AfricanCountry('ZM', 'Zambie'), AfricanCountry('ZW', 'Zimbabwe'),
];

// ─── CATÉGORIES ─────────────────────────────────────────────────────────────
const Map<String, String> _kCategoryLabels = {
  'fashion': 'Mode',
  'electronics': 'Électronique',
  'home': 'Maison',
  'services': 'Services',
  'vehicles': 'Véhicules',
  'realestate': 'Immobilier',
  'food': 'Alimentation',
  'beauty': 'Beauté',
  'sports': 'Sport',
};

// ============================================================================
// VALIDATEURS & HELPERS
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

  /// Nettoie une valeur pour une clause PostgREST `.or(...)` (virgules/parens interdites).
  static String orSafe(String q) => q.replaceAll(RegExp(r'[,"()]'), ' ').trim();

  static bool isValidId(String? id) =>
      id != null && id.isNotEmpty && RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);

  static double? parsePrice(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    final val = double.tryParse(cleaned);
    if (val == null || val < 0 || val > 999999999) return null;
    return val;
  }

  static String truncateQuery(String q) =>
      q.length > _kMaxQueryLength ? q.substring(0, _kMaxQueryLength) : q;
}

class _SearchLogger {
  static void info(String m) => debugPrint('[SearchPage] $m');
  static void warn(String m) => debugPrint('[SearchPage] ⚠️ $m');
  static void error(String m) => debugPrint('[SearchPage] ❌ $m');
}

String _tr(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fallback : v;
}

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
        _SearchLogger.error('$label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      _SearchLogger.warn('$label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      _SearchLogger.error('$label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// RECHERCHES RÉCENTES (persistance)
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
    } catch (e) {
      _SearchLogger.warn('Load recent searches error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, state);
    } catch (e) {
      _SearchLogger.warn('Save recent searches error: $e');
    }
  }

  void add(String q) {
    final query = _SearchValidators.sanitize(q.trim(), maxLength: _kMaxQueryLength);
    if (query.isEmpty) return;
    state = [query, ...state.where((e) => e.toLowerCase() != query.toLowerCase())]
        .take(_kMaxRecentSearches)
        .toList();
    _save();
  }

  void remove(String q) {
    state = state.where((e) => e != q).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchNotifier, List<String>>(
  (ref) => RecentSearchNotifier(),
);

// ============================================================================
// FILTRES DE RECHERCHE
// ============================================================================
class SearchFilters {
  final double? minPrice;
  final double? maxPrice;
  final String sortBy; // newest | price_asc | price_desc
  final String? currency; // code ISO (null = toutes)
  final String? countryCode; // code ISO pays (null = tous)
  final String? category; // id catégorie (null = toutes)

  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'newest',
    this.currency,
    this.countryCode,
    this.category,
  });

  bool get hasActiveFilters =>
      minPrice != null ||
      maxPrice != null ||
      sortBy != 'newest' ||
      currency != null ||
      countryCode != null ||
      category != null;

  int get activeCount {
    int c = 0;
    if (minPrice != null) c++;
    if (maxPrice != null) c++;
    if (sortBy != 'newest') c++;
    if (currency != null) c++;
    if (countryCode != null) c++;
    if (category != null) c++;
    return c;
  }

  SearchFilters copyWith({
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String? currency,
    String? countryCode,
    String? category,
    bool clearMin = false,
    bool clearMax = false,
    bool clearCurrency = false,
    bool clearCountry = false,
    bool clearCategory = false,
  }) {
    return SearchFilters(
      minPrice: clearMin ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMax ? null : (maxPrice ?? this.maxPrice),
      sortBy: sortBy ?? this.sortBy,
      currency: clearCurrency ? null : (currency ?? this.currency),
      countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

// ============================================================================
// SEARCH NOTIFIER (avec garde anti-race-condition)
// ============================================================================
class SearchNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  SearchNotifier(this.ref) : super(const AsyncData([]));

  final Ref ref;
  List<Map<String, dynamic>> _all = [];
  bool _isLoadingMore = false;
  int _seq = 0; // ✅ garde anti-race-condition
  bool hasMore = true;
  String lastQuery = '';
  SearchFilters filters = const SearchFilters();

  Future<void> search(String query, {bool loadMore = false}) async {
    final q = _SearchValidators.truncateQuery(query.trim());
    if (q.isEmpty) return;
    if (loadMore && (_isLoadingMore || !hasMore)) return;

    final seq = ++_seq;
    final db = ref.read(supabaseClientProvider);

    if (!loadMore) {
      _all = [];
      hasMore = true;
      lastQuery = q;
      state = const AsyncLoading();
      ref.read(recentSearchesProvider.notifier).add(q);
      _SearchLogger.info('🔍 Searching: "$q" (filters: ${filters.activeCount})');
    } else {
      _isLoadingMore = true;
    }

    try {
      final offset = _all.length;
      final orValue = _SearchValidators.orSafe(q);

      var builder = db
          .from('products')
          .select(_kSelectColumns)
          .or('title.ilike.%$orValue%,brand.ilike.%$orValue%,description.ilike.%$orValue%');

      // ── Filtres ──
      if (filters.currency != null) {
        builder = builder.eq('currency', filters.currency!);
      }
      if (filters.countryCode != null) {
        builder = builder.eq(_kCountryColumn, filters.countryCode!);
      }
      if (filters.category != null) {
        builder = builder.eq('category', filters.category!);
      }
      if (filters.minPrice != null) {
        builder = builder.gte('price', filters.minPrice!);
      }
      if (filters.maxPrice != null) {
        builder = builder.lte('price', filters.maxPrice!);
      }

      // ── Tri ─
      switch (filters.sortBy) {
        case 'price_asc':
          builder = builder.order('price', ascending: true);
          break;
        case 'price_desc':
          builder = builder.order('price', ascending: false);
          break;
        default:
          builder = builder.order('created_at', ascending: false);
      }

      final res = await _withRetry(
        () => builder.range(offset, offset + _kPageSize - 1),
        label: loadMore ? 'loadMore[$offset]' : 'search["$q"]',
      );

      // ✅ Ignore les réponses obsolètes (l'utilisateur a re-tapé entre-temps)
      if (seq != _seq || !mounted) return;

      final list = List<Map<String, dynamic>>.from(res);
      final seenIds = _all.map((p) => p['id']?.toString()).toSet();
      final unique = list.where((p) {
        final id = p['id']?.toString();
        return id != null && seenIds.add(id);
      }).toList();

      _all = [..._all, ...unique];
      hasMore = list.length == _kPageSize;
      state = AsyncData(_all);

      _SearchLogger.info('✓ +${unique.length} results (total ${_all.length}, hasMore=$hasMore)');
    } catch (e, st) {
      if (seq != _seq || !mounted) return;
      _SearchLogger.error('Search error: $e');
      if (loadMore) {
        state = AsyncData(_all); // préserve les résultats déjà chargés
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  void reset() {
    _seq++;
    _all = [];
    _isLoadingMore = false;
    hasMore = true;
    lastQuery = '';
    filters = const SearchFilters();
    state = const AsyncData([]);
  }

  void applyFilters(SearchFilters f) {
    filters = f;
    _SearchLogger.info(
        '🎛️ Filters applied: sort=${f.sortBy} cur=${f.currency} cty=${f.countryCode} cat=${f.category} min=${f.minPrice} max=${f.maxPrice}');
    if (lastQuery.isNotEmpty) {
      search(lastQuery);
    }
  }

  /// Retire un filtre unitaire depuis les chips actifs.
  void clearFilter(String key) {
    switch (key) {
      case 'min':
        applyFilters(filters.copyWith(clearMin: true));
        break;
      case 'max':
        applyFilters(filters.copyWith(clearMax: true));
        break;
      case 'sort':
        applyFilters(filters.copyWith(sortBy: 'newest'));
        break;
      case 'currency':
        applyFilters(filters.copyWith(clearCurrency: true));
        break;
      case 'country':
        applyFilters(filters.copyWith(clearCountry: true));
        break;
      case 'category':
        applyFilters(filters.copyWith(clearCategory: true));
        break;
    }
  }
}

final searchResultsProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<List<Map<String, dynamic>>>>(
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
    searchCtrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
    _SearchLogger.info('🔍 Page opened');
  }

  void _onTextChanged() {
    if (mounted) setState(() {}); // refresh bouton clear + empty state
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
    searchCtrl.removeListener(_onTextChanged);
    searchCtrl.dispose();
    focusNode.dispose();
    scrollCtrl.dispose();
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
      if (!mounted) return;
      if (v.trim().length >= 3) {
        setState(() => showRecent = false);
        ref.read(searchResultsProvider.notifier).search(v);
      }
    });
  }

  void _clearQuery() {
    HapticFeedback.selectionClick();
    searchCtrl.clear();
    setState(() => showRecent = true);
    ref.read(searchResultsProvider.notifier).reset();
    focusNode.requestFocus();
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recent = ref.watch(recentSearchesProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final notifier = ref.read(searchResultsProvider.notifier);
    final activeFilters = notifier.filters.activeCount;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Column(
        children: [
          _buildHeader(l10n, activeFilters),
          Expanded(
            child: resultsAsync.when(
              loading: () => const _SearchSkeleton(),
              error: (e, _) => _ErrorState(
                message: _SearchValidators.sanitize(e.toString(), maxLength: 200),
                onRetry: () {
                  final q = searchCtrl.text.trim();
                  if (q.isNotEmpty) doSearch(q);
                },
              ),
              data: (results) {
                if (showRecent) return _buildRecent(l10n, recent);
                if (results.isEmpty && searchCtrl.text.trim().isNotEmpty) {
                  return _buildEmpty(l10n);
                }
                return _buildResults(l10n, results, notifier);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER (champ blanc opaque = lisibilité garantie) ───────────
  Widget _buildHeader(AppLocalizations l10n, int activeFilters) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.inkDeep, ThixPolicy.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, top > 0 ? 4 : 12, 12, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.pop();
                },
              ),
              const SizedBox(width: 4),
              // ✅ Champ BLANC opaque + texte SOMBRE : contraste garanti
              Expanded(
                child: Semantics(
                  label: _tr(l10n, 'market_search_hint', 'Rechercher'),
                  textField: true,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search_rounded,
                            color: ThixPolicy.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            focusNode: focusNode,
                            style: const TextStyle(
                              color: ThixPolicy.textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: ThixPolicy.primary,
                            decoration: InputDecoration(
                              hintText: _tr(l10n, 'market_search_hint',
                                  'Rechercher produits, marques...'),
                              hintStyle: const TextStyle(
                                color: ThixPolicy.textMuted,
                                fontSize: 13.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: doSearch,
                            onChanged: _onQueryChanged,
                          ),
                        ),
                        if (searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: ThixPolicy.textSecondary, size: 18),
                            tooltip: _tr(l10n, 'common_clear', 'Effacer'),
                            onPressed: _clearQuery,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton filtres + badge compteur
              Semantics(
                button: true,
                label: _tr(l10n, 'market_filters', 'Filtres'),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 20),
                        onPressed: _showFilters,
                      ),
                    ),
                    if (activeFilters > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: ThixPolicy.danger,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$activeFilters',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
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

  // ─── RÉCENT + SUGGESTIONS ────────────────────────────────────────
  Widget _buildRecent(AppLocalizations l10n, List<String> recent) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tr(l10n, 'search_recent', 'Recherches récentes'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.textMain),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(recentSearchesProvider.notifier).clear();
                  },
                  child: Text(
                    _tr(l10n, 'search_clear_all', 'Effacer tout'),
                    style: const TextStyle(
                        color: ThixPolicy.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          ...recent.map(
            (s) => ListTile(
              dense: true,
              leading:
                  const Icon(Icons.history_rounded, color: ThixPolicy.textMuted, size: 20),
              title: Text(
                _SearchValidators.sanitize(s, maxLength: _kMaxQueryLength),
                style: const TextStyle(
                    color: ThixPolicy.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: ThixPolicy.textMuted),
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).remove(s),
              ),
              onTap: () {
                searchCtrl.text = s;
                doSearch(s);
              },
            ),
          ),
          const Divider(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            _tr(l10n, 'search_suggestions', 'Suggestions'),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ThixPolicy.textMain),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kCategoryLabels.entries
                .map((e) => ActionChip(
                      label: Text(e.value,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ThixPolicy.textMain)),
                      onPressed: () {
                        searchCtrl.text = e.value;
                        doSearch(e.value);
                      },
                      backgroundColor: ThixPolicy.card,
                      side: const BorderSide(color: ThixPolicy.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ─── EMPTY ──────────────────────────────────────────────────────
  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.textMuted.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 56, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              _tr(l10n, 'search_no_results', 'Aucun résultat trouvé'),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(l10n, 'search_no_results_sub',
                  'Essayez d\'autres mots-clés ou ajustez vos filtres.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(searchResultsProvider.notifier).applyFilters(const SearchFilters());
                _clearQuery();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_tr(l10n, 'search_new', 'Nouvelle recherche')),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.primary,
                side: const BorderSide(color: ThixPolicy.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RÉSULTATS ───────────────────────────────────────────────────
  Widget _buildResults(
    AppLocalizations l10n,
    List<Map<String, dynamic>> results,
    SearchNotifier notifier,
  ) {
    return Column(
      children: [
        // Ligne compteur + filtres actifs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${results.length}${notifier.hasMore ? '+' : ''} '
                '${_tr(l10n, 'search_results', 'résultats')}',
                style: const TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showFilters,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded,
                        size: 15, color: ThixPolicy.primary),
                    const SizedBox(width: 4),
                    Text(
                      _tr(l10n, 'market_filters', 'Filtrer'),
                      style: const TextStyle(
                          color: ThixPolicy.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (notifier.filters.hasActiveFilters)
          _ActiveFilterChips(l10n: l10n, filters: notifier.filters),
        Expanded(
          child: RefreshIndicator(
            color: ThixPolicy.primary,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              final q = searchCtrl.text.trim();
              if (q.isNotEmpty) {
                await ref.read(searchResultsProvider.notifier).search(q);
              }
            },
            child: GridView.builder(
              controller: scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ThixPolicy.primary),
                      ),
                    ),
                  );
                }
                final product = results[i];
                final id = product['id']?.toString() ?? '';
                if (!_SearchValidators.isValidId(id)) {
                  return const SizedBox.shrink();
                }
                return ProductCard(
                  product: product,
                  onTap: (_) {
                    HapticFeedback.selectionClick();
                    context.push('/market/product/$id');
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── SHEET FILTRES AVANCÉ ────────────────────────────────────────
  void _showFilters() {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(searchResultsProvider.notifier);
    final current = notifier.filters;

    double? minPrice = current.minPrice;
    double? maxPrice = current.maxPrice;
    String sortBy = current.sortBy;
    String? currency = current.currency;
    String? countryCode = current.countryCode;
    String? category = current.category;

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
          builder: (ctx, setModal) {
            final symbol = currencySymbol(currency);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
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
                        const Icon(Icons.tune_rounded,
                            color: ThixPolicy.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _tr(l10n, 'market_filters', 'Filtres'),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: ThixPolicy.textMain),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── TRI ──
                    _sheetTitle(l10n.t('search_sort_by', fallback: 'Trier par')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sortChip(l10n, 'newest',
                            _tr(l10n, 'sort_newest', 'Plus récents'), sortBy, setModal, (v) => sortBy = v),
                        _sortChip(l10n, 'price_asc',
                            _tr(l10n, 'sort_price_asc', 'Prix ↑'), sortBy, setModal, (v) => sortBy = v),
                        _sortChip(l10n, 'price_desc',
                            _tr(l10n, 'sort_price_desc', 'Prix ↓'), sortBy, setModal, (v) => sortBy = v),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── DEVISE ──
                    _sheetTitle(_tr(l10n, 'search_currency', 'Devise')),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _kCurrencies.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final isAll = i == 0;
                          final cur = isAll ? null : _kCurrencies[i - 1];
                          final selected = currency == cur?.code;
                          final label = isAll
                              ? _tr(l10n, 'common_all', 'Toutes')
                              : '${cur!.code} ${cur.symbol}';
                          return _pill(label, selected, () {
                            setModal(() => currency = cur?.code);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── PRIX (symbole dynamique) ──
                    _sheetTitle(
                        '${_tr(l10n, 'search_price', 'Prix')}${symbol.isNotEmpty ? ' ($symbol)' : ''}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _tr(l10n, 'search_min', 'Min'),
                              filled: true,
                              fillColor: ThixPolicy.surfaceSoft,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: ThixPolicy.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: ThixPolicy.primary, width: 1.5),
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
                              labelText: _tr(l10n, 'search_max', 'Max'),
                              filled: true,
                              fillColor: ThixPolicy.surfaceSoft,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: ThixPolicy.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: ThixPolicy.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── PAYS ──
                    _sheetTitle(_tr(l10n, 'search_country', 'Pays')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: countryCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ThixPolicy.surfaceSoft,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ThixPolicy.border),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(_tr(l10n, 'search_all_countries', 'Tous les pays')),
                        ),
                        ..._kAfricanCountries.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.code,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => countryCode = v),
                    ),
                    const SizedBox(height: 18),

                    // ── CATÉGORIE ──
                    _sheetTitle(_tr(l10n, 'search_category', 'Catégorie')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(_tr(l10n, 'common_all', 'Toutes'), category == null,
                            () => setModal(() => category = null)),
                        ..._kCategoryLabels.entries.map(
                          (e) => _pill(e.value, category == e.key,
                              () => setModal(() => category = e.key)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── ACTIONS ──
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
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(_tr(l10n, 'common_reset', 'Réinitialiser')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              final min =
                                  _SearchValidators.parsePrice(minCtrl.text);
                              final max =
                                  _SearchValidators.parsePrice(maxCtrl.text);
                              if (min != null && max != null && min > max) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(_tr(l10n, 'search_price_order',
                                        'Le prix min doit être inférieur au max')),
                                    backgroundColor: ThixPolicy.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              notifier.applyFilters(SearchFilters(
                                minPrice: min,
                                maxPrice: max,
                                sortBy: sortBy,
                                currency: currency,
                                countryCode: countryCode,
                                category: category,
                              ));
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThixPolicy.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              _tr(l10n, 'common_apply', 'Appliquer'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  Widget _sheetTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.textMain),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ThixPolicy.primary : ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? ThixPolicy.primary : ThixPolicy.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ThixPolicy.textMain,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sortChip(
    AppLocalizations l10n,
    String value,
    String label,
    String selected,
    StateSetter setModal,
    ValueChanged<String> onPick,
  ) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setModal(() => onPick(value));
      },
      selectedColor: ThixPolicy.primary.withOpacity(0.15),
      backgroundColor: ThixPolicy.surfaceSoft,
      labelStyle: TextStyle(
        color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      side: BorderSide(
          color: isSelected ? ThixPolicy.primary : ThixPolicy.border),
    );
  }
}

// ============================================================================
// CHIPS DE FILTRES ACTIFS (dismissibles)
// ============================================================================
class _ActiveFilterChips extends StatelessWidget {
  final AppLocalizations l10n;
  final SearchFilters filters;
  const _ActiveFilterChips({required this.l10n, required this.filters});

  @override
  Widget build(BuildContext context) {
    final notifier = context.read(searchResultsProvider.notifier);
    final chips = <Widget>[];

    if (filters.sortBy != 'newest') {
      chips.add(_chip(
        filters.sortBy == 'price_asc'
            ? _tr(l10n, 'sort_price_asc', 'Prix ↑')
            : _tr(l10n, 'sort_price_desc', 'Prix ↓'),
        () => notifier.clearFilter('sort'),
      ));
    }
    if (filters.currency != null) {
      chips.add(_chip(filters.currency!, () => notifier.clearFilter('currency')));
    }
    if (filters.countryCode != null) {
      final c = _kAfricanCountries
          .where((e) => e.code == filters.countryCode)
          .firstOrNull;
      chips.add(_chip(c?.name ?? filters.countryCode!,
          () => notifier.clearFilter('country')));
    }
    if (filters.category != null) {
      chips.add(_chip(_kCategoryLabels[filters.category] ?? filters.category!,
          () => notifier.clearFilter('category')));
    }
    if (filters.minPrice != null) {
      chips.add(_chip(
          '≥ ${filters.minPrice!.toInt()} ${currencySymbol(filters.currency)}',
          () => notifier.clearFilter('min')));
    }
    if (filters.maxPrice != null) {
      chips.add(_chip(
          '≤ ${filters.maxPrice!.toInt()} ${currencySymbol(filters.currency)}',
          () => notifier.clearFilter('max')));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.primary)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: () {
        HapticFeedback.selectionClick();
        onRemove();
      },
      backgroundColor: ThixPolicy.primary.withOpacity(0.08),
      side: BorderSide(color: ThixPolicy.primary.withOpacity(0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================================
// SKELETON & ERROR
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
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 12, width: double.infinity, color: Colors.grey.shade200),
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 48, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(
              _tr(l10n, 'search_error', 'Erreur de recherche'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                  color: ThixPolicy.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_tr(l10n, 'common_retry', 'Réessayer')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
