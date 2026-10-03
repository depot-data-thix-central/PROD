// lib/presentation/thix_market/providers/market_providers.dart
// ============================================================================
// MARKET PROVIDERS — Production Enterprise v2
// ============================================================================
// Architecture :
//   - Providers atomiques (banners, flash, featured, shops, unread)
//   - ForYouNotifier : pagination mémoire-safe avec anti-OOM
//   - allMarketProductsProvider : agrégation flash + forYou (dedup)
//   - Helpers : invalidateAllMarketProviders + stableSortProducts
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
const Duration _kStaticDataTTL = Duration(minutes: 5);
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

/// Exécute une Future avec timeout + retry automatique sur TimeoutException.
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

/// Déduplique une liste de produits par ID.
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

/// Limite la taille d'une liste en gardant les plus récents.
List<Map<String, dynamic>> _trimToMax(List<Map<String, dynamic>> items, int max) {
  if (items.length <= max) return items;
  return items.sublist(items.length - max);
}

// ============================================================================
// PROVIDERS SIMPLES (avec retry + TTL + logs)
// ============================================================================

final bannersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  debugPrint('[MarketProvider] 🎨 Loading banners');
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
  debugPrint('[MarketProvider] ⚡ Loading flash sales');
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
  debugPrint('[MarketProvider] 🏪 Loading featured shops');
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
  debugPrint('[MarketProvider] 🛍️ Loading my shop ID');
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

/// Provider qui se rafraîchit automatiquement toutes les 30 secondes.
final unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  debugPrint('[MarketProvider] 🔔 Loading unread count');

  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() => timer?.cancel());
  ref.onResume(() {
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
// PROVIDER "POUR VOUS" (pagination mémoire-safe)
// ============================================================================

class ForYouNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    debugPrint('[MarketProvider] 🛒 Building ForYou feed (page 0)');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;

    try {
      final repo = ref.read(marketRepositoryProvider);
      final first = await _withRetry(
        () => repo.fetchProducts(page: 0, limit: _kDefaultPageSize),
        label: 'forYou.build',
      );

      final dedup = _dedupProducts(first);
      _page = 1;
      _hasMore = first.length >= _kDefaultPageSize;

      debugPrint('[MarketProvider] ✓ Loaded ${dedup.length} products (hasMore=$_hasMore)');
      return dedup;
    } catch (e) {
      debugPrint('[MarketProvider] ❌ ForYou build error: $e');
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    final cur = state.valueOrNull;
    if (cur == null || cur.isEmpty) return;

    if (cur.length >= _kMaxProductsInMemory) {
      debugPrint('[MarketProvider] ⚠️ Memory limit reached ($_kMaxProductsInMemory) — stop loading');
      _hasMore = false;
      return;
    }

    _isLoadingMore = true;
    state = const AsyncLoading<List<Map<String, dynamic>>>().copyWithPrevious(state);

    try {
      final repo = ref.read(marketRepositoryProvider);
      final more = await _withRetry(
        () => repo.fetchProducts(page: _page, limit: _kDefaultPageSize),
        label: 'forYou.loadMore[$_page]',
      );

      final combined = _dedupProducts([...cur, ...more]);
      final trimmed = _trimToMax(combined, _kMaxProductsInMemory);

      if (more.length < _kDefaultPageSize) {
        _hasMore = false;
      }
      if (combined.length > _kMaxProductsInMemory) {
        _hasMore = false;
        debugPrint('[MarketProvider] ⚠️ Memory cap reached — hasMore=false');
      }

      _page++;
      state = AsyncData(trimmed);

      debugPrint('[MarketProvider] ✓ Page $_page loaded (total: ${trimmed.length}, hasMore=$_hasMore)');
    } catch (e, st) {
      debugPrint('[MarketProvider] ❌ loadMore error: $e');
      state = AsyncValue<List<Map<String, dynamic>>>.error(e, st).copyWithPrevious(
        AsyncData(cur),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    debugPrint('[MarketProvider] 🔄 Refreshing ForYou feed');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    ref.invalidateSelf();
    await future;
  }

  Future<void> reset() async {
    debugPrint('[MarketProvider] 🔁 Resetting ForYou feed');
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final forYouProvider = AsyncNotifierProvider<ForYouNotifier, List<Map<String, dynamic>>>(
  ForYouNotifier.new,
);

// ============================================================================
// PROVIDER AGRÉGÉ (flash + forYou, dedup, mémoire-safe)
// ============================================================================

final allMarketProductsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final flash = ref.watch(flashSalesProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final forYou = ref.watch(forYouProvider).valueOrNull ?? const <Map<String, dynamic>>[];

  final combined = _dedupProducts([...flash, ...forYou]);
  return _trimToMax(combined, _kMaxProductsInMemory);
});

// ============================================================================
// PROVIDER FEATURED PRODUCTS
// ============================================================================

final featuredProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  debugPrint('[MarketProvider] ⭐ Loading featured products');
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
    final forYou = ref.watch(forYouProvider).valueOrNull ?? const [];
    return forYou.take(6).toList();
  }
});

// ============================================================================
// ✅ HELPERS EXPORTÉS — À UTILISER DEPUIS TOUTE L'APP
// ============================================================================

/// Invalide TOUS les providers market en une seule ligne.
/// À appeler après toute création/édition/suppression de produit
/// pour garantir la cohérence de la home.
///
/// Usage :
///   invalidateAllMarketProviders(ref);
void invalidateAllMarketProviders(Ref ref) {
  debugPrint('[MarketProvider] 🧹 Invalidating ALL market providers');
  ref.invalidate(allMarketProductsProvider);
  ref.invalidate(featuredProductsProvider);
  ref.invalidate(flashSalesProvider);
  ref.invalidate(featuredShopsProvider);
  ref.invalidate(forYouProvider);
  ref.invalidate(bannersProvider);
  // unreadProvider volontairement non invalidé (polling auto)
  // myShopIdProvider volontairement non invalidé (rarement modifié)
}

/// Tri STABLE et prévisible d'une liste de produits.
/// Ordre de priorité :
///   1. Flash sales actifs (is_flash_sale=true ET expires_at futur)
///   2. Featured (is_featured=true)
///   3. Produits normaux, triés par created_at DESC (récent d'abord)
///
/// Usage :
///   final sorted = stableSortProducts(items);
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

    // Tri secondaire : plus récent d'abord
    final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
    final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
    return bDate.compareTo(aDate);
  });

  return list;
}
