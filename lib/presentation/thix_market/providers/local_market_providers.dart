// lib/presentation/thix_market/providers/local_market_providers.dart
// ============================================================================
// PROVIDERS PRODUITS LOCAUX — espace dédié, isolé du fil principal
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'market_providers.dart' show supabaseClientProvider;

const int _kLocalPageSize = 20;
const int _kMaxLocalInMemory = 300;
const Duration _kLocalTimeout = Duration(seconds: 15);

// ============================================================================
// FEED LOCAL (paginé) — UNIQUEMENT is_local = true
// ============================================================================
class LocalProductsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final db = ref.read(supabaseClientProvider);
    final res = await db
        .from('products')
        .select('*, shop:shops!inner(id, name, logo_url, city, type)')
        .eq('status', 'active')
        .eq('is_local', true) // ✅ espace dédié uniquement
        .order('created_at', ascending: false)
        .range(page * _kLocalPageSize, (page + 1) * _kLocalPageSize - 1)
        .timeout(_kLocalTimeout);
    return List<Map<String, dynamic>>.from(res as List);
  }

  List<Map<String, dynamic>> _dedup(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    return items.where((p) => seen.add(p['id']?.toString() ?? '')).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> build() async {
    debugPrint('[LocalMarket] 🌱 Building local feed (page 0)');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    final first = _dedup(await _fetchPage(0));
    _page = 1;
    _hasMore = first.length >= _kLocalPageSize;
    debugPrint('[LocalMarket] ✓ ${first.length} produits locaux (hasMore=$_hasMore)');
    return first;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final cur = state.valueOrNull;
    if (cur == null || cur.isEmpty) return;
    if (cur.length >= _kMaxLocalInMemory) {
      _hasMore = false;
      return;
    }
    _isLoadingMore = true;
    try {
      final more = _dedup(await _fetchPage(_page));
      final combined = _dedup([...cur, ...more]);
      if (more.length < _kLocalPageSize) _hasMore = false;
      _page++;
      state = AsyncData(combined);
      debugPrint('[LocalMarket] ✓ page $_page total=${combined.length}');
    } catch (e) {
      debugPrint('[LocalMarket] ❌ loadMore: $e');
      state = AsyncData(cur);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    ref.invalidateSelf();
    await future;
  }
}

final localProductsProvider =
    AsyncNotifierProvider<LocalProductsNotifier, List<Map<String, dynamic>>>(
  LocalProductsNotifier.new,
);

// ============================================================================
// FILTRES UI (secteur + recherche in-page)
// ============================================================================
final localSectorFilterProvider = StateProvider<String?>((ref) => null);
final localSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredLocalProductsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final all = ref.watch(localProductsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final sector = ref.watch(localSectorFilterProvider);
  final q = ref.watch(localSearchQueryProvider).trim().toLowerCase();

  var list = all;
  if (sector != null) {
    list = list.where((p) => (p['local_sector'] ?? '').toString() == sector).toList();
  }
  if (q.isNotEmpty) {
    list = list.where((p) {
      final hay = '${p['title'] ?? ''} ${p['producer_name'] ?? ''} ${p['terroir'] ?? ''} '
              '${p['description'] ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }
  return list;
});

/// Compteurs par secteur (pour les tuiles type "grocery")
final localSectorCountsProvider = Provider<Map<String, int>>((ref) {
  final all = ref.watch(localProductsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final counts = <String, int>{};
  for (final p in all) {
    final s = (p['local_sector'] ?? '').toString();
    if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
});

/// Image de couverture par secteur (1ère photo trouvée) pour les tuiles
final localSectorCoverProvider = Provider<Map<String, String>>((ref) {
  final all = ref.watch(localProductsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final covers = <String, String>{};
  for (final p in all) {
    final s = (p['local_sector'] ?? '').toString();
    if (s.isEmpty || covers.containsKey(s)) continue;
    final url = p['image_url']?.toString();
    if (url != null && url.startsWith('http')) {
      covers[s] = url;
    } else if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      final u = (p['images'] as List).first.toString();
      if (u.startsWith('http')) covers[s] = u;
    }
  }
  return covers;
});

// ============================================================================
// PRODUCTEURS & COOPÉRATIVES (section "stores" de la home locale)
// ============================================================================
final localProducersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final all = ref.watch(localProductsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  if (all.isEmpty) return const [];

  final perShop = <String, int>{};
  for (final p in all) {
    final sid = p['shop_id']?.toString() ?? '';
    if (sid.isNotEmpty) perShop[sid] = (perShop[sid] ?? 0) + 1;
  }
  if (perShop.isEmpty) return const [];

  try {
    final db = ref.read(supabaseClientProvider);
    final res = await db
        .from('shops')
        .select('id, name, logo_url, city, country')
        .inFilter('id', perShop.keys.toList())
        .limit(20)
        .timeout(_kLocalTimeout);
    final shops = List<Map<String, dynamic>>.from(res as List);
    for (final s in shops) {
      s['local_count'] = perShop[s['id']?.toString()] ?? 0;
    }
    shops.sort((a, b) =>
        (b['local_count'] as int).compareTo(a['local_count'] as int));
    return shops;
  } catch (e) {
    debugPrint('[LocalMarket] ❌ producers: $e');
    return const [];
  }
});

// ============================================================================
// INVALIDATION
// ============================================================================
void invalidateLocalProviders(WidgetRef ref) {
  debugPrint('[LocalMarket] 🧹 Invalidating local providers');
  ref.invalidate(localProductsProvider);
  ref.invalidate(localProducersProvider);
}
