// lib/presentation/thix_market/providers/market_providers.dart
// ============================================================================
// MARKET PROVIDERS — Production Enterprise v3
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/market_repository.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const Duration _kUnreadPollingInterval = Duration(seconds: 30);
const int _kMaxProductsInMemory = 500;
const int _kDefaultPageSize = 20;
const int _kMaxRetries = 1;

// ============================================================================
// PROVIDERS DE BASE
// ============================================================================
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.watch(supabaseClientProvider));
});

// ============================================================================
// HELPERS INTERNES
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  String label = 'operation',
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[MarketProvider] ❌ $label: timeout after $attempt attempts');
        rethrow;
      }
      debugPrint('[MarketProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[MarketProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

List<Map<String, dynamic>> _dedupProducts(List<Map<String, dynamic>> items) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) continue;
    if (seen.add(id)) {
      result.add(item);
    }
  }
  return result;
}

List<Map<String, dynamic>> _trimToMax(List<Map<String, dynamic>> items, int max) {
  if (items.length <= max) return items;
  return items.sublist(items.length - max);
}

// ============================================================================
// PROVIDERS SIMPLES
// ============================================================================
final bannersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final repo = ref.watch(marketRepositoryProvider);
    final result = await _withRetry(() => repo.fetchBanners(), label: 'fetchBanners');
    debugPrint('[MarketProvider] ✓ Loaded ${result.length} banners');
    return result;
  } catch (e) {
    debugPrint('[MarketProvider] ❌ Banners error: $e');
    rethrow;
  }
});

final flashSalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final repo = ref.watch(marketRepositoryProvider);
    final result = await _withRetry(
      () => repo.fetchProducts(page: 0, limit: 8, flashOnly: true),
      label: 'fetchFlashSales',
    );
    final dedup = _dedupProducts(result);
    debugPrint('[MarketProvider] ✓ Loaded ${dedup.length} flash sales');
    return dedup;
  } catch (e) {
    debugPrint('[MarketProvider] ❌ Flash sales error: $e');
    rethrow;
  }
});

final featuredShopsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final repo = ref.watch(marketRepositoryProvider);
    final result = await _withRetry(
      () => repo.fetchFeaturedShops(),
      label: 'fetchFeaturedShops',
    );
    debugPrint('[MarketProvider] ✓ Loaded ${result.length} featured shops');
    return result;
  } catch (e) {
    debugPrint('[MarketProvider] ❌ Featured shops error: $e');
    rethrow;
  }
});

final myShopIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final repo = ref.watch(marketRepositoryProvider);
    final result = await _withRetry(() => repo.fetchMyShopId(), label: 'fetchMyShopId');
    debugPrint('[MarketProvider] ✓ My shop ID: ${result ?? "none"}');
    return result;
  } catch (e) {
    debugPrint('[MarketProvider] ⚠️ No shop for current user: $e');
    return null;
  }
});

final unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() => timer?.cancel());
  ref.onResume(() {
    timer?.cancel();
    timer = Timer.periodic(_kUnreadPollingInterval, (_) {
      ref.invalidateSelf();
    });
  });

  try {
    final repo = ref.watch(marketRepositoryProvider);
    final count = await _withRetry(() => repo.fetchUnread(), label: 'fetchUnread');
    debugPrint('[MarketProvider] ✓ Unread count: $count');
    return count;
  } catch (e) {
    debugPrint('[MarketProvider] ❌ Unread error: $e');
    return 0;
  }
});

// ============================================================================
// PROVIDER "POUR VOUS"
// ============================================================================
class ForYouNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final db = ref.read(supabaseClientProvider);
    final res = await db
        .from('products')
        .select('*')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .range(page * _kDefaultPageSize, (page + 1) * _kDefaultPageSize - 1);

    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<List<Map<String, dynamic>>> build() async {
    debugPrint('[MarketProvider] 🛒 Building ForYou feed (page 0)');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;

    try {
      final first = await _fetchPage(0);
      final dedup = _dedupProducts(first);
      _page = 1;
      _hasMore = first.length >= _kDefaultPageSize;
      debugPrint('[MarketProvider] ✓ Loaded ${dedup.length} products (hasMore=$_hasMore)');
      return dedup;
    } catch (e, st) {
      debugPrint('[MarketProvider] ❌ ForYou build error: $e\n$st');
      rethrow;
    }
  }

  /// ✅ FIX : ne passe plus l'état en AsyncLoading (ça remplaçait le grid par le skeleton)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final cur = state.valueOrNull;
    if (cur == null || cur.isEmpty) return;
    if (cur.length >= _kMaxProductsInMemory) {
      _hasMore = false;
      return;
    }

    _isLoadingMore = true;
    try {
      final more = await _fetchPage(_page);
      final combined = _dedupProducts([...cur, ...more]);
      final trimmed = _trimToMax(combined, _kMaxProductsInMemory);
      if (more.length < _kDefaultPageSize) _hasMore = false;
      _page++;
      state = AsyncData(trimmed);
      debugPrint('[MarketProvider] ✓ Page $_page total=${trimmed.length}');
    } catch (e) {
      debugPrint('[MarketProvider] ❌ loadMore error: $e');
      // On garde la liste actuelle intacte
      state = AsyncData(cur);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    debugPrint('[MarketProvider] 🔄 Refreshing ForYou');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    ref.invalidateSelf();
    await future;
  }

  Future<void> reset() async {
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final forYouProvider =
    AsyncNotifierProvider<ForYouNotifier, List<Map<String, dynamic>>>(
  ForYouNotifier.new,
);

// ============================================================================
// PROVIDER AGRÉGÉ (flash + forYou, dedup)
// ============================================================================
final allMarketProductsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final flash = ref.watch(flashSalesProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final forYou = ref.watch(forYouProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final featured = ref.watch(featuredProductsProvider).valueOrNull ?? const <Map<String, dynamic>>[];

  final combined = _dedupProducts([...flash, ...featured, ...forYou]);
  return _trimToMax(combined, _kMaxProductsInMemory);
});

// ============================================================================
// PROVIDER FEATURED PRODUCTS
// ============================================================================
final featuredProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final repo = ref.watch(marketRepositoryProvider);
    final result = await _withRetry(
      () => repo.fetchProducts(page: 0, limit: 6, featuredOnly: true),
      label: 'fetchFeatured',
    );
    final dedup = _dedupProducts(result);
    debugPrint('[MarketProvider] ✓ Loaded ${dedup.length} featured products');
    return dedup;
  } catch (e) {
    debugPrint('[MarketProvider] ⚠️ Featured fallback to forYou top 6: $e');
    final forYou = ref.watch(forYouProvider).valueOrNull ?? const <Map<String, dynamic>>[];
    return forYou.take(6).toList();
  }
});

// ============================================================================
// HELPERS EXPORTÉS
// ============================================================================
void invalidateAllMarketProviders(WidgetRef ref) {
  debugPrint('[MarketProvider] 🧹 Invalidating ALL market providers');
  ref.invalidate(featuredProductsProvider);
  ref.invalidate(flashSalesProvider);
  ref.invalidate(featuredShopsProvider);
  ref.invalidate(forYouProvider);
  ref.invalidate(bannersProvider);
}

List<Map<String, dynamic>> stableSortProducts(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return items;

  final list = List<Map<String, dynamic>>.from(items);
  final now = DateTime.now();

  int score(Map<String, dynamic> p) {
    final isFlash = p['is_flash_sale'] == true;
    final expiresAt = DateTime.tryParse(p['expires_at']?.toString() ?? '');
    final flashActive = isFlash && expiresAt != null && expiresAt.isAfter(now);
    final isFeatured = p['is_featured'] == true;

    if (flashActive) return 0;
    if (isFeatured) return 1;
    return 2;
  }

  list.sort((a, b) {
    final sa = score(a);
    final sb = score(b);
    if (sa != sb) return sa.compareTo(sb);

    final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
    final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
    return bDate.compareTo(aDate);
  });

  return list;
}
