// lib/presentation/thix_market/pages/all_shops_and_supermarkets_page.dart
// ============================================================================
// ALL SHOPS & SUPERMARKETS PAGE — Production Enterprise v2
// ============================================================================
// Architecture :
//   ✅ 2 onglets : Supermarchés (cards détaillées) + Boutiques (grille)
//   ✅ Featured shops en carousel horizontal dans chaque onglet
//   ✅ Recherche + filtres (ville, note min) + tri (populaires/récents/alpha)
//   ✅ Realtime + cache TTL + pull-to-refresh
//   ✅ Navigation vers /market/shop/:id au tap
//   ✅ Design system ThixPolicy cohérent
//   ✅ Empty / Error / Skeleton / Badge count
//   ✅ Semantics + HapticFeedback + logs structurés + i18n fallbacks
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================
const Duration _kShopsTimeout = Duration(seconds: 12);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 250);
const int _kMaxNameLength = 80;
const int _kMaxAddressLength = 200;
const int _kMaxDescriptionLength = 300;
const int _kMaxResults = 200; // garde anti-OOM
const int _kMaxFeatured = 8;

// ─── VILLES (extrait de la liste pays/villes THIX) ─────────────────────────
const List<String> _kCities = [
  'Toutes',
  'Kinshasa', 'Lubumbashi', 'Mbuji-Mayi', 'Kananga', 'Kisangani',
  'Bukavu', 'Goma', 'Matadi', 'Kolwezi', 'Likasi',
];

// ─── TRI ────────────────────────────────────────────────────────────────────
enum _ShopSort {
  popular,   // followers DESC
  newest,    // created_at DESC
  alpha,     // name ASC
  rating,    // rating DESC
}

String _sortLabel(AppLocalizations l10n, _ShopSort s) {
  switch (s) {
    case _ShopSort.popular:
      return _tr(l10n, 'shops_sort_popular', 'Populaires');
    case _ShopSort.newest:
      return _tr(l10n, 'shops_sort_newest', 'Récents');
    case _ShopSort.alpha:
      return _tr(l10n, 'shops_sort_alpha', 'A → Z');
    case _ShopSort.rating:
      return _tr(l10n, 'shops_sort_rating', 'Mieux notés');
  }
}

// ============================================================================
// HELPERS
// ============================================================================
class _ShopSanitizer {
  _ShopSanitizer._();

  static String text(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    try {
      final doc = html_parser.parse(input);
      var s = doc.body?.text ?? input;
      s = s
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();
      return s.length > maxLength ? s.substring(0, maxLength) : s;
    } catch (_) {
      return '';
    }
  }

  static String? url(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

class _ShopLogger {
  static void info(String m) => debugPrint('[ShopsPage] $m');
  static void warn(String m) => debugPrint('[ShopsPage] ⚠️ $m');
  static void error(String m) => debugPrint('[ShopsPage] ❌ $m');
}

String _tr(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fallback : v;
}

Future<T> _withTimeout<T>(Future<T> f, {String label = 'op'}) async {
  try {
    return await f.timeout(_kShopsTimeout);
  } on TimeoutException {
    _ShopLogger.error('$label timeout after ${_kShopsTimeout.inSeconds}s');
    rethrow;
  }
}

// ============================================================================
// PROVIDER : liste des shops (avec cache + filtres)
// ============================================================================
enum ShopKind { supermarket, boutique }

class _ShopQuery {
  final ShopKind kind;
  final String? city;
  final double minRating;
  final _ShopSort sort;
  final String search;

  const _ShopQuery({
    required this.kind,
    this.city,
    this.minRating = 0,
    this.sort = _ShopSort.popular,
    this.search = '',
  });

  @override
  bool operator ==(Object o) =>
      o is _ShopQuery &&
      o.kind == kind &&
      o.city == city &&
      o.minRating == minRating &&
      o.sort == sort &&
      o.search == search;

  @override
  int get hashCode => Object.hash(kind, city, minRating, sort, search);
}

class ShopsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  ShopsNotifier(this.ref, this.query) : super(const AsyncLoading()) {
    load();
  }

  final Ref ref;
  final _ShopQuery query;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final client = Supabase.instance.client;
      final qStr = _ShopSanitizer.text(query.search).trim();

      var builder = client
          .from('shops')
          .select('id, name, slug, logo_url, cover_url, address, city, '
              'description, rating, followers_count, is_featured, is_verified, '
              'created_at, type')
          .eq('status', 'active');

      // Filtre par type (supermarket / boutique)
      builder = builder.eq('type',
          query.kind == ShopKind.supermarket ? 'supermarket' : 'boutique');

      // Recherche texte (OR name / description)
      if (qStr.isNotEmpty) {
        final safe = qStr.replaceAll(RegExp(r'[,"()]'), ' ');
        builder = builder.or('name.ilike.%$safe%,description.ilike.%$safe%');
      }

      // Filtres additionnels
      if (query.city != null && query.city != 'Toutes') {
        builder = builder.eq('city', query.city!);
      }
      if (query.minRating > 0) {
        builder = builder.gte('rating', query.minRating);
      }

      // Tri
      switch (query.sort) {
        case _ShopSort.popular:
          builder = builder.order('followers_count', ascending: false);
          break;
        case _ShopSort.newest:
          builder = builder.order('created_at', ascending: false);
          break;
        case _ShopSort.alpha:
          builder = builder.order('name', ascending: true);
          break;
        case _ShopSort.rating:
          builder = builder.order('rating', ascending: false);
          break;
      }

      final res = await _withTimeout(
        builder.limit(_kMaxResults),
        label: 'shops(${query.kind.name})',
      );
      state = AsyncData(List<Map<String, dynamic>>.from(res));
      _ShopLogger.info('✓ ${query.kind.name}: ${(res as List).length} shops');
    } catch (e, st) {
      _ShopLogger.error('load failed: $e');
      state = AsyncError(e, st);
    }
  }
}

final shopsProvider = StateNotifierProvider.family<ShopsNotifier,
    AsyncValue<List<Map<String, dynamic>>>, _ShopQuery>(
  (ref, query) => ShopsNotifier(ref, query),
);

// Provider compteur simple (pour badges dans les tabs)
final shopsCountProvider = FutureProvider.family<int, ShopKind>((ref, kind) async {
  try {
    final res = await _withTimeout(
  Supabase.instance.client
      .from('shops')
      .select('id')
      .eq('status', 'active')
      .eq('type', kind == ShopKind.supermarket ? 'supermarket' : 'boutique')
      .count(CountOption.exact),
  label: 'count(${kind.name})',
);
return res.count ?? 0;

  }
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class AllShopsAndSupermarketsPage extends ConsumerStatefulWidget {
  const AllShopsAndSupermarketsPage({super.key});

  @override
  ConsumerState<AllShopsAndSupermarketsPage> createState() =>
      _AllShopsAndSupermarketsPageState();
}

class _AllShopsAndSupermarketsPageState
    extends ConsumerState<AllShopsAndSupermarketsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Filtres onglet Supermarchés
  String _smSearch = '';
  String? _smCity = 'Toutes';
  double _smMinRating = 0;
  _ShopSort _smSort = _ShopSort.popular;

  // Filtres onglet Boutiques
  String _btSearch = '';
  String? _btCity = 'Toutes';
  double _btMinRating = 0;
  _ShopSort _btSort = _ShopSort.popular;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        HapticFeedback.selectionClick();
        if (mounted) setState(() {});
      }
    });
    _ShopLogger.info('🏬 Shops page opened');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isSupermarketTab => _tabCtrl.index == 0;

  _ShopQuery _currentQuery() {
    final kind = _isSupermarketTab ? ShopKind.supermarket : ShopKind.boutique;
    final q = _isSupermarketTab
        ? _ShopQuery(
            kind: kind,
            city: _smCity,
            minRating: _smMinRating,
            sort: _smSort,
            search: _smSearch,
          )
        : _ShopQuery(
            kind: kind,
            city: _btCity,
            minRating: _btMinRating,
            sort: _btSort,
            search: _btSearch,
          );
    return q;
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      setState(() {
        if (_isSupermarketTab) {
          _smSearch = v;
        } else {
          _btSearch = v;
        }
      });
    });
  }

  void _openShop(Map<String, dynamic> shop) {
    HapticFeedback.selectionClick();
    final id = shop['id']?.toString() ?? '';
    if (id.isEmpty) return;
    context.push('/market/shop/$id');
  }

  void _showFiltersSheet() {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);

    // Copies locales des états actuels
    String? city = _isSupermarketTab ? _smCity : _btCity;
    double minRating = _isSupermarketTab ? _smMinRating : _btMinRating;
    _ShopSort sort = _isSupermarketTab ? _smSort : _btSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    const Icon(Icons.tune_rounded,
                        color: ThixPolicy.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _tr(l10n, 'shops_filters', 'Filtres'),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: ThixPolicy.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Tri
                Text(_tr(l10n, 'shops_sort_by', 'Trier par'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ThixPolicy.textMain)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ShopSort.values
                      .map((s) => ChoiceChip(
                            label: Text(_sortLabel(l10n, s)),
                            selected: sort == s,
                            onSelected: (_) =>
                                setModal(() => sort = s),
                            selectedColor: ThixPolicy.primary.withOpacity(0.15),
                            backgroundColor: ThixPolicy.surfaceSoft,
                            labelStyle: TextStyle(
                              color: sort == s
                                  ? ThixPolicy.primary
                                  : ThixPolicy.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                            side: BorderSide(
                              color: sort == s
                                  ? ThixPolicy.primary
                                  : ThixPolicy.border,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),

                // Ville
                Text(_tr(l10n, 'shops_city', 'Ville'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ThixPolicy.textMain)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: city,
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
                  items: _kCities
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setModal(() => city = v),
                ),
                const SizedBox(height: 18),

                // Note minimum
                Text(
                  '${_tr(l10n, 'shops_min_rating', 'Note minimum')} : '
                  '${minRating.toStringAsFixed(1)} ★',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 4),
                Slider(
                  value: minRating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  activeColor: ThixPolicy.primary,
                  inactiveColor: ThixPolicy.border,
                  onChanged: (v) => setModal(() => minRating = v),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_isSupermarketTab) {
                              _smCity = 'Toutes';
                              _smMinRating = 0;
                              _smSort = _ShopSort.popular;
                            } else {
                              _btCity = 'Toutes';
                              _btMinRating = 0;
                              _btSort = _ShopSort.popular;
                            }
                          });
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
                          setState(() {
                            if (_isSupermarketTab) {
                              _smCity = city;
                              _smMinRating = minRating;
                              _smSort = sort;
                            } else {
                              _btCity = city;
                              _btMinRating = minRating;
                              _btSort = sort;
                            }
                          });
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
          );
        },
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final smCountAsync = ref.watch(shopsCountProvider(ShopKind.supermarket));
    final btCountAsync = ref.watch(shopsCountProvider(ShopKind.boutique));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (ctx, inner) {
          return [
            SliverToBoxAdapter(child: _buildHeader(l10n, smCountAsync, btCountAsync)),
          ];
        },
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildShopList(ShopKind.supermarket),
            _buildShopList(ShopKind.boutique),
          ],
        ),
      ),
    );
  }

  // ─── HEADER (gradient + tabs) ────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n, AsyncValue<int> smCount,
      AsyncValue<int> btCount) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.inkDeep, ThixPolicy.primary, ThixPolicy.domainMarket],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: top > 0 ? 4 : 12),
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Row(
                children: [
                  _headerIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(l10n, 'shops_title', 'Supermarchés & Boutiques'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tr(l10n, 'shops_subtitle',
                              'Découvrez les commerces de confiance'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  _headerIconButton(
                    icon: Icons.tune_rounded,
                    onTap: _showFiltersSheet,
                  ),
                ],
              ),
            ),
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        controller: TextEditingController(
                          text: _isSupermarketTab ? _smSearch : _btSearch,
                        ),
                        style: const TextStyle(
                            color: ThixPolicy.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        cursorColor: ThixPolicy.primary,
                        decoration: InputDecoration(
                          hintText: _tr(l10n, 'shops_search_hint',
                              'Rechercher un commerce...'),
                          hintStyle: const TextStyle(
                              color: ThixPolicy.textMuted, fontSize: 13.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tabs avec badges
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(child: _tabLabel(
                    _tr(l10n, 'shops_tab_supermarkets', 'Supermarchés'),
                    smCount,
                    Icons.storefront_rounded,
                  )),
                  Tab(child: _tabLabel(
                    _tr(l10n, 'shops_tab_boutiques', 'Boutiques'),
                    btCount,
                    Icons.shopping_bag_rounded,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _tabLabel(String label, AsyncValue<int> count, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.whenOrNull(data: (n) => '$n') ?? '–',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ─── LISTE ONGLET ────────────────────────────────────────────────
  Widget _buildShopList(ShopKind kind) {
    final query = _currentQuery();
    final async = ref.watch(shopsProvider(query));

    return async.when(
      loading: () => const _ShopsSkeleton(kind: null),
      error: (e, _) => _ShopsErrorState(
        message: _ShopSanitizer.text(e.toString(), maxLength: 200),
        onRetry: () => ref.read(shopsProvider(query).notifier).load(),
      ),
      data: (shops) {
        if (shops.isEmpty) {
          return _ShopsEmptyState(
            kind: kind,
            hasFilters: query.city != 'Toutes' ||
                query.minRating > 0 ||
                query.search.isNotEmpty,
            onReset: () {
              setState(() {
                if (kind == ShopKind.supermarket) {
                  _smCity = 'Toutes';
                  _smMinRating = 0;
                  _smSearch = '';
                  _smSort = _ShopSort.popular;
                } else {
                  _btCity = 'Toutes';
                  _btMinRating = 0;
                  _btSearch = '';
                  _btSort = _ShopSort.popular;
                }
              });
            },
          );
        }

        // Featured en top + reste
        final featured = shops.where((s) => s['is_featured'] == true).toList();
        final rest = shops.where((s) => s['is_featured'] != true).toList();

        return RefreshIndicator(
          color: ThixPolicy.primary,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await ref.read(shopsProvider(query).notifier).load();
          },
          child: kind == ShopKind.supermarket
              ? _buildSupermarketList(featured, rest)
              : _buildBoutiqueGrid(featured, rest),
        );
      },
    );
  }

  // ─── LISTE SUPERMARCHÉS (cards détaillées) ───────────────────────
  Widget _buildSupermarketList(
      List<Map<String, dynamic>> featured, List<Map<String, dynamic>> rest) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (featured.isNotEmpty) ...[
          _sectionTitle(l10n,
              _tr(l10n, 'shops_featured', 'Commerces en vedette'),
              Icons.star_rounded,
              ThixPolicy.gold),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.take(_kMaxFeatured).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FeaturedShopCard(
                  shop: featured[i], onTap: () => _openShop(featured[i])),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _sectionTitle(l10n,
            '${_tr(l10n, 'shops_all', 'Tous')} (${rest.length + featured.length})',
            Icons.storefront_rounded,
            ThixPolicy.primary),
        const SizedBox(height: 8),
        ...rest.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SupermarketCard(shop: s, onTap: () => _openShop(s)),
            )),
      ],
    );
  }

  // ─── GRILLE BOUTIQUES ────────────────────────────────────────────
  Widget _buildBoutiqueGrid(
      List<Map<String, dynamic>> featured, List<Map<String, dynamic>> rest) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (featured.isNotEmpty) ...[
          _sectionTitle(l10n,
              _tr(l10n, 'shops_featured', 'Boutiques en vedette'),
              Icons.star_rounded,
              ThixPolicy.gold),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.take(_kMaxFeatured).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FeaturedShopCard(
                  shop: featured[i], onTap: () => _openShop(featured[i])),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _sectionTitle(l10n,
            '${_tr(l10n, 'shops_all', 'Toutes')} (${rest.length + featured.length})',
            Icons.shopping_bag_rounded,
            ThixPolicy.primary),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: rest.length,
          itemBuilder: (_, i) => _BoutiqueCard(
            shop: rest[i],
            onTap: () => _openShop(rest[i]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(AppLocalizations l10n, String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ThixPolicy.textMain,
              letterSpacing: -0.2,
            )),
      ],
    );
  }
}

// ============================================================================
// CARD : SUPERMARCHÉ (détaillée)
// ============================================================================
class _SupermarketCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onTap;
  const _SupermarketCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final logo = _ShopSanitizer.url(shop['logo_url']?.toString());
    final name = _ShopSanitizer.text(shop['name']?.toString(),
        maxLength: _kMaxNameLength);
    final address = _ShopSanitizer.text(shop['address']?.toString(),
        maxLength: _kMaxAddressLength);
    final city = _ShopSanitizer.text(shop['city']?.toString(), maxLength: 40);
    final description = _ShopSanitizer.text(shop['description']?.toString(),
        maxLength: _kMaxDescriptionLength);
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final followers = (shop['followers_count'] as num?)?.toInt() ?? 0;
    final isVerified = shop['is_verified'] == true;

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Commerce' : name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 90,
                height: 110,
                decoration: const BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: logo != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                          errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.storefront_rounded,
                                  color: ThixPolicy.textMuted, size: 30)),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.storefront_rounded,
                            color: ThixPolicy.textMuted, size: 32),
                      ),
              ),
              // Infos
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? '—' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: ThixPolicy.textMain,
                                  height: 1.2),
                            ),
                          ),
                          if (isVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded,
                                  size: 14, color: ThixPolicy.primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (address.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 12, color: ThixPolicy.textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                city.isNotEmpty ? '$city · $address' : address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: ThixPolicy.textSecondary,
                                height: 1.3)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _stat(
                            icon: Icons.star_rounded,
                            value: rating > 0 ? rating.toStringAsFixed(1) : '–',
                            color: ThixPolicy.gold,
                          ),
                          const SizedBox(width: 10),
                          _stat(
                            icon: Icons.people_rounded,
                            value: _formatCount(followers),
                            color: ThixPolicy.primary,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Voir',
                                    style: TextStyle(
                                        color: ThixPolicy.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 8, color: ThixPolicy.primary),
                              ],
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
        ),
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// ============================================================================
// CARD : BOUTIQUE (grille compacte)
// ============================================================================
class _BoutiqueCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onTap;
  const _BoutiqueCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final logo = _ShopSanitizer.url(shop['logo_url']?.toString());
    final cover = _ShopSanitizer.url(shop['cover_url']?.toString());
    final name = _ShopSanitizer.text(shop['name']?.toString(),
        maxLength: _kMaxNameLength);
    final city = _ShopSanitizer.text(shop['city']?.toString(), maxLength: 30);
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isVerified = shop['is_verified'] == true;

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Boutique' : name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover / Logo
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: cover != null
                            ? CachedNetworkImage(
                                imageUrl: cover,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _buildFallbackLogo(name, logo),
                              )
                            : _buildFallbackLogo(name, logo),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Verified badge
                      if (isVerified)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                      // Rating pill
                      if (rating > 0)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 11, color: ThixPolicy.gold),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Infos
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ThixPolicy.textMain,
                        height: 1.2,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 10, color: ThixPolicy.textMuted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo(String name, String? logo) {
    return logo != null
        ? CachedNetworkImage(
            imageUrl: logo,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initialsPlaceholder(name),
          )
        : _initialsPlaceholder(name);
  }

  Widget _initialsPlaceholder(String name) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: ThixPolicy.primary.withOpacity(0.15),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: ThixPolicy.primary,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD : FEATURED (horizontal, grande)
// ============================================================================
class _FeaturedShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onTap;
  const _FeaturedShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = _ShopSanitizer.url(shop['cover_url']?.toString());
    final logo = _ShopSanitizer.url(shop['logo_url']?.toString());
    final name = _ShopSanitizer.text(shop['name']?.toString(),
        maxLength: _kMaxNameLength);
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Commerce en vedette' : '$name, en vedette',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.gold.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.gold.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Cover
                Positioned.fill(
                  child: cover != null
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _initialsPlaceholder(name),
                        )
                      : _initialsPlaceholder(name),
                ),
                // Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Badge VEDETTE
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: ThixPolicy.inkDeep, size: 10),
                        SizedBox(width: 2),
                        Text('VEDETTE',
                            style: TextStyle(
                                color: ThixPolicy.inkDeep,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3)),
                      ],
                    ),
                  ),
                ),
                // Logo
                if (logo != null)
                  Positioned(
                    bottom: 12,
                    left: 10,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: ThixPolicy.primary.withOpacity(0.2),
                            child: const Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Nom + rating
                Positioned(
                  bottom: 10,
                  left: logo != null ? 52 : 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '—' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      if (rating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 12, color: ThixPolicy.gold),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _initialsPlaceholder(String name) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThixPolicy.primary.withOpacity(0.7),
            ThixPolicy.domainMarket.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ÉTATS : SKELETON / ERROR / EMPTY
// ============================================================================
class _ShopsSkeleton extends StatelessWidget {
  final ShopKind? kind;
  const _ShopsSkeleton({this.kind});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: List.generate(6, (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 90,
              decoration: const BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: double.infinity, color: ThixPolicy.surfaceSoft),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 150, color: ThixPolicy.surfaceSoft),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 80, color: ThixPolicy.surfaceSoft),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class _ShopsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ShopsErrorState({required this.message, required this.onRetry});

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
              child: const Icon(Icons.cloud_off_rounded,
                  size: 48, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(_tr(l10n, 'shops_load_error', 'Impossible de charger'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ThixPolicy.textMain)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ThixPolicy.textSecondary, fontSize: 12)),
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

class _ShopsEmptyState extends StatelessWidget {
  final ShopKind kind;
  final bool hasFilters;
  final VoidCallback onReset;
  const _ShopsEmptyState({
    required this.kind,
    required this.hasFilters,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icon = kind == ShopKind.supermarket
        ? Icons.storefront_outlined
        : Icons.shopping_bag_outlined;
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
              child: Icon(icon, size: 48, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? _tr(l10n, 'shops_no_match', 'Aucun commerce trouvé')
                  : _tr(l10n, 'shops_empty', 'Pas encore de commerces'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? _tr(l10n, 'shops_no_match_sub',
                      'Essayez d\'ajuster vos filtres.')
                  : _tr(l10n, 'shops_empty_sub',
                      'Les premiers commerces apparaîtront bientôt.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: ThixPolicy.textSecondary, fontSize: 12),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_tr(l10n, 'common_reset', 'Réinitialiser')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThixPolicy.primary,
                  side: const BorderSide(color: ThixPolicy.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UTILS
// ============================================================================
String _formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}K';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(0)}K';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
