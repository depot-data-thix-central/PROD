// lib/presentation/thix_market/data/market_repository.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kDefaultPageSize = 20;
const int _kMaxPageSize = 100;
const int _kMaxSearchLength = 100;
const int _kMaxNameLength = 150;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _RepoValidators {
  _RepoValidators._();

  /// Sanitize une chaîne pour prévenir injection SQL/XSS dans les paramètres
  static String sanitizeParam(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r"'"), "''") // Escape SQL single quote
        .replaceAll(RegExp(r'"'), '""')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static int clampPage(int page) => page < 0 ? 0 : page;
  static int clampLimit(int limit) => limit.clamp(1, _kMaxPageSize);

  /// Validation catégorie : whitelist stricte
  static bool isValidCategory(String? category) {
    if (category == null || category == 'all' || category.isEmpty) return true;
    const allowed = {
      'fashion', 'electronics', 'home', 'services',
      'vehicles', 'realestate', 'beauty', 'food',
      'books', 'sports', 'toys', 'pets', 'health',
    };
    return allowed.contains(category.toLowerCase());
  }
}

// ============================================================================
// HELPERS
// ============================================================================

/// Exécute une Future avec timeout + retry automatique sur TimeoutException
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[MarketRepo] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[MarketRepo] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[MarketRepo] ❌ $label error: $e');
      rethrow;
    }
  }
}

/// Wrapper qui retourne une liste vide en cas d'erreur (non-bloquant)
Future<List<Map<String, dynamic>>> _safeQuery(
  Future<List<Map<String, dynamic>>> Function() fn, {
  required String label,
}) async {
  try {
    return await fn();
  } catch (e) {
    debugPrint('[MarketRepo] ⚠️ $label failed safely: $e');
    return [];
  }
}

// ============================================================================
// REPOSITORY
// ============================================================================
class MarketRepository {
  final SupabaseClient _db;

  MarketRepository(this._db) {
    debugPrint('[MarketRepo] 🏪 Initialized');
  }

  String? get _uid => _db.auth.currentUser?.id;
  bool get _isAuth => _uid != null;

  // ─────────────────────────────────────────────────────────────
  // BANNERS
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBanners() async {
    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] 🎨 Fetching banners');
        final res = await _db
            .from('banners')
            .select('*')
            .eq('is_active', true)
            .order('priority', ascending: true)
            .limit(10);
        final list = List<Map<String, dynamic>>.from(res);
        debugPrint('[MarketRepo] ✓ ${list.length} banners loaded');
        return list;
      }, label: 'fetchBanners'),
      label: 'fetchBanners',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PRODUITS (avec pagination + filtres)
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchProducts({
    int page = 0,
    int limit = _kDefaultPageSize,
    bool flashOnly = false,
    bool featuredOnly = false,
    String? category,
    String? search,
  }) async {
    final safePage = _RepoValidators.clampPage(page);
    final safeLimit = _RepoValidators.clampLimit(limit);
    final safeSearch = search != null
        ? _RepoValidators.sanitizeParam(search, maxLength: _kMaxSearchLength)
        : null;

    if (!_RepoValidators.isValidCategory(category)) {
      debugPrint('[MarketRepo] ⚠️ Invalid category rejected: $category');
      return [];
    }

    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] 📦 Fetching products (page=$safePage, limit=$safeLimit, flash=$flashOnly, featured=$featuredOnly, cat=$category, search="${safeSearch?.substring(0, safeSearch.length > 20 ? 20 : safeSearch.length)}...")');

        var q = _db
            .from('products')
            .select('*, shop:shops(id,name,rating,logo_url,city)')
            .eq('status', 'active');

        if (flashOnly) q = q.eq('is_flash_sale', true);
        if (featuredOnly) q = q.eq('is_featured', true);
        if (category != null && category != 'all' && category.isNotEmpty) {
          q = q.eq('category', category);
        }
        if (safeSearch != null && safeSearch.isNotEmpty) {
          q = q.ilike('title', '%$safeSearch%');
        }

        final res = await q
            .order('created_at', ascending: false)
            .range(safePage * safeLimit, (safePage + 1) * safeLimit - 1);

        final list = List<Map<String, dynamic>>.from(res);
        debugPrint('[MarketRepo] ✓ ${list.length} products loaded');
        return list;
      }, label: 'fetchProducts'),
      label: 'fetchProducts',
    );
  }

  /// Version avec info pagination (total + hasMore)
  Future<({List<Map<String, dynamic>> items, int total, bool hasMore})> fetchProductsWithMeta({
    int page = 0,
    int limit = _kDefaultPageSize,
    bool flashOnly = false,
    bool featuredOnly = false,
    String? category,
    String? search,
  }) async {
    final items = await fetchProducts(
      page: page,
      limit: limit + 1, // +1 pour détecter hasMore
      flashOnly: flashOnly,
      featuredOnly: featuredOnly,
      category: category,
      search: search,
    );

    final hasMore = items.length > limit;
    final trimmed = hasMore ? items.sublist(0, limit) : items;

    return (items: trimmed, total: items.length, hasMore: hasMore);
  }

  // ─────────────────────────────────────────────────────────────
  // SHOPS
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFeaturedShops() async {
    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] 🏪 Fetching featured shops');
        final res = await _db
            .from('shops')
            .select('id,name,logo_url,rating,is_verified,city')
            .eq('is_featured', true)
            .order('rating', ascending: false)
            .limit(10);
        final list = List<Map<String, dynamic>>.from(res);
        debugPrint('[MarketRepo] ✓ ${list.length} featured shops');
        return list;
      }, label: 'fetchFeaturedShops'),
      label: 'fetchFeaturedShops',
    );
  }

  Future<String?> fetchMyShopId() async {
    if (!_isAuth) {
      debugPrint('[MarketRepo] ⚠️ fetchMyShopId: not authenticated');
      return null;
    }

    try {
      return await _withRetry(() async {
        debugPrint('[MarketRepo] 🛍️ Fetching my shop ID');
        final res = await _db
            .from('shops')
            .select('id')
            .eq('owner_id', _uid!)
            .maybeSingle();
        final id = res?['id']?.toString();
        debugPrint('[MarketRepo] ✓ My shop ID: ${id ?? "none"}');
        return id;
      }, label: 'fetchMyShopId');
    } catch (e) {
      debugPrint('[MarketRepo] ⚠️ No shop for user: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────

  Future<int> fetchUnread() async {
    if (!_isAuth) return 0;

    try {
      return await _withRetry(() async {
        final res = await _db
            .from('notifications')
            .select('id')
            .eq('user_id', _uid!)
            .eq('is_read', false)
            .count(CountOption.exact);
        return res.count;
      }, label: 'fetchUnread');
    } catch (e) {
      debugPrint('[MarketRepo] ⚠️ fetchUnread error: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FAVORITES (Legacy — à migrer vers wishlist unifiée)
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFavorites() async {
    if (!_isAuth) return [];

    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] ❤️ Fetching favorites');
        final res = await _db
            .from('favorites')
            .select('*, product:products(*, shop:shops(id,name,logo_url,city))')
            .eq('user_id', _uid!)
            .order('created_at', ascending: false)
            .limit(100);

        final list = List<Map<String, dynamic>>.from(res)
            .map((e) {
              final prod = e['product'] as Map<String, dynamic>?;
              return prod ?? e;
            })
            .toList();

        debugPrint('[MarketRepo] ✓ ${list.length} favorites');
        return list;
      }, label: 'fetchFavorites'),
      label: 'fetchFavorites',
    );
  }

  Future<void> toggleFavorite(String productId) async {
    if (!_isAuth) throw Exception('Non authentifié');
    if (productId.isEmpty) throw Exception('ID produit invalide');

    await _withRetry(() async {
      debugPrint('[MarketRepo] ❤️ Toggling favorite $productId');

      // Vérifier si déjà favori
      final existing = await _db
          .from('favorites')
          .select('id')
          .eq('user_id', _uid!)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        await _db.from('favorites').delete().eq('id', existing['id']);
        debugPrint('[MarketRepo] ✓ Removed from favorites');
      } else {
        await _db.from('favorites').insert({
          'user_id': _uid!,
          'product_id': productId,
        });
        debugPrint('[MarketRepo] ✓ Added to favorites');
      }
    }, label: 'toggleFavorite');
  }

  // ─────────────────────────────────────────────────────────────
  // WISHLIST
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWishlist() async {
    if (!_isAuth) return [];

    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] 📋 Fetching wishlist');
        final res = await _db
            .from('wishlist')
            .select('*, products(*, shop:shops(id,name,logo_url,city))')
            .eq('user_id', _uid!)
            .order('created_at', ascending: false)
            .limit(100);

        final list = List<Map<String, dynamic>>.from(res);
        debugPrint('[MarketRepo] ✓ ${list.length} wishlist items');
        return list;
      }, label: 'fetchWishlist'),
      label: 'fetchWishlist',
    );
  }

  Future<void> removeFromWishlist(String itemId) async {
    if (!_isAuth) throw Exception('Non authentifié');
    if (itemId.isEmpty) throw Exception('ID item invalide');

    await _withRetry(() async {
      debugPrint('[MarketRepo] 🗑️ Removing wishlist item $itemId');
      await _db
          .from('wishlist')
          .delete()
          .eq('id', itemId)
          .eq('user_id', _uid!);
      debugPrint('[MarketRepo] ✓ Removed');
    }, label: 'removeFromWishlist');
  }

  Future<String> createWishlist(
    String name, {
    String? description,
    bool isPublic = true,
  }) async {
    if (!_isAuth) throw Exception('Non authentifié');

    final safeName = _RepoValidators.sanitizeParam(name, maxLength: _kMaxNameLength);
    if (safeName.isEmpty) throw Exception('Nom invalide');

    final safeDesc = description != null
        ? _RepoValidators.sanitizeParam(description, maxLength: 500)
        : null;

    return await _withRetry(() async {
      debugPrint('[MarketRepo] ➕ Creating wishlist "$safeName"');
      final res = await _db
          .from('wishlists')
          .insert({
            'user_id': _uid!,
            'name': safeName,
            'description': safeDesc,
            'is_public': isPublic,
          })
          .select('id')
          .single();

      final id = res['id'].toString();
      debugPrint('[MarketRepo] ✓ Wishlist created: $id');
      return id;
    }, label: 'createWishlist');
  }

  // ─────────────────────────────────────────────────────────────
  // RECHERCHE GLOBALE
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> globalSearch(String query) async {
    final safeQuery = _RepoValidators.sanitizeParam(query, maxLength: _kMaxSearchLength);
    if (safeQuery.isEmpty) {
      return {'products': [], 'shops': [], 'categories': []};
    }

    debugPrint('[MarketRepo] 🔍 Global search: "$safeQuery"');

    // Requêtes parallèles pour performance
    final productsFuture = fetchProducts(search: safeQuery, limit: 10);
    final shopsFuture = _searchShops(safeQuery);

    final results = await Future.wait([productsFuture, shopsFuture]);

    return {
      'products': results[0],
      'shops': results[1],
      'categories': const [],
    };
  }

  Future<List<Map<String, dynamic>>> _searchShops(String query) async {
    return _safeQuery(
      () => _withRetry(() async {
        final res = await _db
            .from('shops')
            .select('id,name,logo_url,city,rating,is_verified')
            .ilike('name', '%$query%')
            .eq('is_active', true)
            .limit(10);
        return List<Map<String, dynamic>>.from(res);
      }, label: 'searchShops'),
      label: 'searchShops',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DÉTAIL PRODUIT
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProductDetail(String productId) async {
    if (productId.isEmpty) return null;

    try {
      return await _withRetry(() async {
        debugPrint('[MarketRepo] 📦 Fetching product detail $productId');
        final res = await _db
            .from('products')
            .select('*, shop:shops(id,name,logo_url,city,rating,is_verified), reviews:product_reviews(user_id,rating,comment,created_at)')
            .eq('id', productId)
            .eq('status', 'active')
            .maybeSingle();

        if (res == null) {
          debugPrint('[MarketRepo] ⚠️ Product not found: $productId');
          return null;
        }

        debugPrint('[MarketRepo] ✓ Product loaded: ${(res['title'] as String?)?.substring(0, (res['title'] as String).length > 30 ? 30 : (res['title'] as String).length)}...');
        return res;
      }, label: 'fetchProductDetail');
    } catch (e) {
      debugPrint('[MarketRepo] ❌ Product detail error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COMMANDES
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    String? notes,
  }) async {
    if (!_isAuth) throw Exception('Non authentifié');
    if (items.isEmpty) throw Exception('Panier vide');

    final safeNotes = notes != null
        ? _RepoValidators.sanitizeParam(notes, maxLength: 500)
        : null;

    return await _withRetry(() async {
      debugPrint('[MarketRepo] 🛒 Creating order (${items.length} items)');

      // Calcul total côté client (devrait être fait côté serveur via RPC)
      num total = 0;
      for (final item in items) {
        final price = (item['price'] as num?) ?? 0;
        final qty = (item['quantity'] as num?) ?? 1;
        total += price * qty;
      }

      final res = await _db
          .from('orders')
          .insert({
            'user_id': _uid!,
            'address_id': addressId,
            'total_amount': total,
            'status': 'pending',
            'notes': safeNotes,
          })
          .select()
          .single();

      final orderId = res['id'].toString();

      // Insérer les items
      final orderItems = items.map((item) => {
            'order_id': orderId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'price': item['price'],
          }).toList();

      await _db.from('order_items').insert(orderItems);

      debugPrint('[MarketRepo] ✓ Order created: $orderId (total: $total)');
      return res;
    }, label: 'createOrder');
  }

  Future<void> cancelOrder(String orderId, {String reason = 'client_request'}) async {
    if (!_isAuth) throw Exception('Non authentifié');

    await _withRetry(() async {
      debugPrint('[MarketRepo] ❌ Cancelling order $orderId');

      // Essayer RPC d'abord (vérifie ownership + restaure stock)
      try {
        await _db.rpc('cancel_order', params: {
          'p_order_id': orderId,
          'p_reason_code': reason,
        });
      } catch (_) {
        // Fallback direct
        await _db
            .from('orders')
            .update({'status': 'cancelled', 'payout_status': 'refunded'})
            .eq('id', orderId)
            .eq('user_id', _uid!);
      }

      debugPrint('[MarketRepo] ✓ Order cancelled');
    }, label: 'cancelOrder');
  }

  // ─────────────────────────────────────────────────────────────
  // COMPARATEUR PRODUITS
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchProductsForComparison(List<String> productIds) async {
    if (productIds.isEmpty) return [];
    if (productIds.length > 5) {
      debugPrint('[MarketRepo] ⚠️ Comparison limited to 5 products');
      productIds = productIds.sublist(0, 5);
    }

    return _safeQuery(
      () => _withRetry(() async {
        debugPrint('[MarketRepo] ⚖️ Fetching ${productIds.length} products for comparison');
        final res = await _db
            .from('products')
            .select('*, shop:shops(id,name,logo_url)')
            .inFilter('id', productIds)
            .eq('status', 'active');
        return List<Map<String, dynamic>>.from(res);
      }, label: 'fetchProductsForComparison'),
      label: 'fetchProductsForComparison',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ALERTES PRIX
  // ─────────────────────────────────────────────────────────────

  Future<void> createPriceAlert({
    required String productId,
    required double targetPrice,
  }) async {
    if (!_isAuth) throw Exception('Non authentifié');
    if (targetPrice <= 0) throw Exception('Prix cible invalide');

    await _withRetry(() async {
      debugPrint('[MarketRepo] 🔔 Creating price alert for $productId @ $targetPrice');
      await _db.from('price_alerts').upsert({
        'user_id': _uid!,
        'product_id': productId,
        'target_price': targetPrice,
        'is_active': true,
      }, onConflict: 'user_id,product_id');
      debugPrint('[MarketRepo] ✓ Alert created');
    }, label: 'createPriceAlert');
  }

  Future<List<Map<String, dynamic>>> fetchPriceAlerts() async {
    if (!_isAuth) return [];

    return _safeQuery(
      () => _withRetry(() async {
        final res = await _db
            .from('price_alerts')
            .select('*, product:products(title,image_url,current_price)')
            .eq('user_id', _uid!)
            .eq('is_active', true)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      }, label: 'fetchPriceAlerts'),
      label: 'fetchPriceAlerts',
    );
  }
}
