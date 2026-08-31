// lib/presentation/thix_market/cart/cart_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kDebounceDelay = Duration(milliseconds: 300);
const int _kMaxRetries = 1;
const int _kMaxQuantity = 999;
const int _kMinQuantity = 1;
const int _kCacheVersion = 1;

// SharedPreferences keys
const String _kPrefCartCache = 'cart_cache_v$_kCacheVersion';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CartValidators {
  _CartValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

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

  static int safeInt(dynamic v, {int fallback = 0, int min = 0, int max = 999999999}) {
    if (v == null) return fallback;
    final parsed = v is num ? v.toInt() : int.tryParse(v.toString()) ?? fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    if (parsed < 0 || parsed.isNaN || parsed.isInfinite) return fallback;
    return parsed;
  }

  static int validateQuantity(int qty, int stock) {
    if (qty < _kMinQuantity) return _kMinQuantity;
    if (qty > _kMaxQuantity) return _kMaxQuantity;
    if (stock > 0 && qty > stock) return stock;
    return qty;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
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
        debugPrint('[CartProvider] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[CartProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[CartProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

String _friendlyError(dynamic e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
  if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
  if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
  if (msg.contains('rupture') || msg.contains('out of stock')) return 'Produit en rupture de stock.';
  if (msg.contains('stock limité')) return e.toString();
  if (msg.contains('introuvable')) return 'Produit introuvable.';
  if (msg.contains('connecter') || msg.contains('login')) return 'Veuillez vous connecter.';
  if (msg.contains('devises') || msg.contains('currency')) return e.toString();
  return 'Une erreur est survenue. Réessayez.';
}

// ============================================================================
// STATE
// ============================================================================
class CartState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isSyncing;
  final String? lastError;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.lastError,
  });

  CartState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? isSyncing,
    Object? lastError = _sentinel,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: identical(lastError, _sentinel) ? this.lastError : lastError as String?,
    );
  }

  /// Serialisation pour cache offline
  String toJson() {
    return jsonEncode({
      'items': items,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static CartState fromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      final items = (data['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      return CartState(items: items);
    } catch (e) {
      debugPrint('[CartProvider] ⚠️ Cache parse error: $e');
      return const CartState();
    }
  }
}

const Object _sentinel = Object();

// ============================================================================
// NOTIFIER
// ============================================================================
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this.ref) : super(const CartState()) {
    _init();
  }

  final Ref ref;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription? _authSub;
  Timer? _debounceTimer;
  bool _isAddingToCart = false;

  // ========== HELPERS PRIX ==========
  double _getRealPrice(Map<String, dynamic> product) {
    final raw = _CartValidators.safeDouble(product['price']);
    final sale = _CartValidators.safeDouble(
      product['sale_price'] ?? product['discount_price'],
    );
    final percent = _CartValidators.safeDouble(product['discount_percent']);
    final original = _CartValidators.safeDouble(
      product['original_price'],
      fallback: raw,
    );

    if (sale > 0 && sale < raw) return sale;
    if (sale > 0 && original > 0 && sale < original) return sale;
    if (percent > 0 && percent < 100) return raw * (1 - percent / 100);
    return raw;
  }

  double _getOldPrice(Map<String, dynamic> product) {
    final raw = _CartValidators.safeDouble(product['price']);
    final original = _CartValidators.safeDouble(product['original_price'], fallback: raw);
    final sale = _CartValidators.safeDouble(product['sale_price']);
    if (sale > 0 && sale < raw) return raw;
    return original;
  }

  /// Normalise toutes les devises vers USD ou FC uniquement
  String _normalizeCurrency(dynamic raw) {
    if (raw == null) return 'FC';
    final c = raw.toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$' || c == 'DOLLAR' || c == 'US' || c == 'US Dollar') {
      return 'USD';
    }
    if (c.isEmpty) return 'FC';
    // CDF, XOF, FCFA, FC, XAF, etc. → FC
    return 'FC';
  }

  Map<String, dynamic> _sanitizeProduct(Map<String, dynamic> product) {
    return {
      ...product,
      'title': _CartValidators.sanitize(product['title']?.toString(), maxLength: 120),
      'name': _CartValidators.sanitize(product['name']?.toString(), maxLength: 120),
      'description': _CartValidators.sanitize(product['description']?.toString(), maxLength: 1000),
      'shop': product['shop'] is Map
          ? {
              ...(product['shop'] as Map).map(
                (k, v) => MapEntry(k.toString(), k == 'name' ? _CartValidators.sanitize(v?.toString(), maxLength: 60) : v),
              ),
            }
          : product['shop'],
    };
  }

  // ========== GETTERS ==========
  List<Map<String, dynamic>> get cartItems => state.items;
  bool get isLoading => state.isLoading;
  bool get isSyncing => state.isSyncing;
  String? get lastError => state.lastError;
  int get itemCount => state.items.length;

  /// Sous-totaux regroupés par devise
  Map<String, double> get subtotalsByCurrency {
    final totals = <String, double>{};
    for (final item in state.items) {
      final product = item['product'] is Map
          ? Map<String, dynamic>.from(item['product'] as Map)
          : <String, dynamic>{};
      final qty = _CartValidators.safeInt(item['quantity'], fallback: 1);
      final curr = currencyForItem(item);
      totals[curr] = (totals[curr] ?? 0.0) + (_getRealPrice(product) * qty);
    }
    return totals;
  }

  int get totalQuantity => state.items.fold<int>(
        0,
        (sum, item) => sum + _CartValidators.safeInt(item['quantity'], fallback: 1),
      );

  String get currency {
    if (state.items.isEmpty) return 'FC';
    final p = state.items.first['product'] as Map?;
    return _normalizeCurrency(p?['currency']);
  }

  String get currencySymbol => currency == 'USD' ? '\$' : 'FC';

  String currencyForItem(Map<String, dynamic> item) {
    final p = item['product'] as Map?;
    return _normalizeCurrency(p?['currency']);
  }

  /// true si plusieurs devises présentes
  bool get hasMixedCurrency {
    if (state.items.length < 2) return false;
    final first = currencyForItem(state.items.first);
    return state.items.any((item) => currencyForItem(item) != first);
  }

  double get subtotal => state.items.fold(0.0, (sum, item) {
        final product = item['product'] is Map
            ? Map<String, dynamic>.from(item['product'] as Map)
            : <String, dynamic>{};
        final qty = _CartValidators.safeInt(item['quantity'], fallback: 1);
        return sum + (_getRealPrice(product) * qty);
      });

  double get originalSubtotal => state.items.fold(0.0, (sum, item) {
        final product = item['product'] is Map
            ? Map<String, dynamic>.from(item['product'] as Map)
            : <String, dynamic>{};
        final qty = _CartValidators.safeInt(item['quantity'], fallback: 1);
        return sum + (_getOldPrice(product) * qty);
      });

  double get totalDiscount {
    final discount = originalSubtotal - subtotal;
    return discount > 0 ? discount : 0.0;
  }

  double get shippingCost => 0.0;
  String get shippingSymbol => currencySymbol;
  double get total => subtotal + shippingCost;

  double getItemRealPrice(Map<String, dynamic> item) {
    final product = item['product'] is Map
        ? Map<String, dynamic>.from(item['product'] as Map)
        : <String, dynamic>{};
    return _getRealPrice(product);
  }

  double getItemOldPrice(Map<String, dynamic> item) {
    final product = item['product'] is Map
        ? Map<String, dynamic>.from(item['product'] as Map)
        : <String, dynamic>{};
    return _getOldPrice(product);
  }

  int getItemDiscountPercent(Map<String, dynamic> item) {
    final oldP = getItemOldPrice(item);
    final real = getItemRealPrice(item);
    if (oldP <= 0 || real >= oldP) return 0;
    return ((1 - real / oldP) * 100).round().clamp(0, 99);
  }

  bool get hasOutOfStockItems {
    for (final item in state.items) {
      final product = item['product'] as Map?;
      if (product == null) return true;
      final stock = _CartValidators.safeInt(product['stock']);
      final qty = _CartValidators.safeInt(item['quantity'], fallback: 1);
      if (stock <= 0 || qty > stock) return true;
    }
    return false;
  }

  // ========== CACHE OFFLINE ==========
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefCartCache, state.toJson());
    } catch (e) {
      debugPrint('[CartProvider] ⚠️ Cache save error: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kPrefCartCache);
      if (cached != null && cached.isNotEmpty) {
        final cachedState = CartState.fromJson(cached);
        if (cachedState.items.isNotEmpty) {
          state = cachedState;
          debugPrint('[CartProvider] 📦 Loaded ${cachedState.items.length} items from cache');
        }
      }
    } catch (e) {
      debugPrint('[CartProvider] ⚠️ Cache load error: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefCartCache);
    } catch (e) {
      debugPrint('[CartProvider] ⚠️ Cache clear error: $e');
    }
  }

  // ========== INIT ==========
  void _init() {
    debugPrint('[CartProvider] 🚀 Initializing');
    _loadFromCache();

    final db = ref.read(supabaseClientProvider);
    _authSub = db.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        debugPrint('[CartProvider] 🔐 User authenticated, loading cart');
        _setupRealtime();
        loadCart();
      } else {
        debugPrint('[CartProvider] 👤 User signed out, clearing cart');
        _sub?.cancel();
        state = const CartState();
        _clearCache();
      }
    });

    if (db.auth.currentUser != null) {
      _setupRealtime();
      loadCart();
    }
  }

  void _setupRealtime() {
    _sub?.cancel();
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (!_CartValidators.isValidUuid(uid)) {
      debugPrint('[CartProvider] ⚠️ Invalid user ID, skipping realtime');
      return;
    }

    final stream = db
        .from('cart')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid!)
        .order('created_at', ascending: false);

    _sub = stream.listen(
      (updated) {
        debugPrint('[CartProvider] 📡 Realtime event: ${updated.length} items');
        _syncCartWithProducts(List<Map<String, dynamic>>.from(updated));
      },
      onError: (error) {
        debugPrint('[CartProvider] ⚠️ Realtime error: $error');
      },
      onDone: () {
        debugPrint('[CartProvider] ℹ️ Realtime stream closed');
      },
    );
  }

  /// Enrichit les lignes panier en batch (évite N+1 queries)
  Future<void> _syncCartWithProducts(
    List<Map<String, dynamic>> cartRecords,
  ) async {
    if (cartRecords.isEmpty) {
      state = state.copyWith(items: [], isSyncing: false, isLoading: false); // CORRECTION ICI
      await _saveToCache();
      return;
    }
    state = state.copyWith(isSyncing: true);

    try {
      final db = ref.read(supabaseClientProvider);

      // Extraire tous les product_ids uniques
      final productIds = cartRecords
          .map((item) => item['product_id']?.toString())
          .where((id) => _CartValidators.isValidUuid(id))
          .toSet()
          .toList();

      // Batch fetch produits : 1 requête au lieu de N
      Map<String, Map<String, dynamic>> productsMap = {};
      if (productIds.isNotEmpty) {
        try {
          final products = await _withRetry(
            () => db
                .from('products')
                .select('*, shop:shops(id, name, logo_url, city)')
                .inFilter('id', productIds),
            label: 'batchFetchProducts[${productIds.length}]',
          );

          for (final p in products as List) {
            final map = Map<String, dynamic>.from(p as Map);
            final id = map['id']?.toString();
            if (id != null) {
              productsMap[id] = _sanitizeProduct(map);
            }
          }
          debugPrint('[CartProvider] ✓ Fetched ${productsMap.length} products in batch');
        } catch (e) {
          debugPrint('[CartProvider] ❌ Batch fetch products error: $e');
          // Fallback : garder items avec données existantes si possible
        }
      }

      // Identifier items à supprimer (produits inexistants)
      final toDelete = <String>[];
      final enriched = <Map<String, dynamic>>[];

      for (var cartItem in cartRecords) {
        final pid = cartItem['product_id']?.toString();
        if (pid == null) continue;

        final product = productsMap[pid];
        if (product != null) {
          enriched.add({...cartItem, 'product': product});
        } else {
          toDelete.add(cartItem['id'].toString());
        }
      }

      // Batch delete des items orphelins
      if (toDelete.isNotEmpty) {
        try {
          await _withRetry(
            () => db.from('cart').delete().inFilter('id', toDelete),
            label: 'batchDeleteOrphans[${toDelete.length}]',
          );
          debugPrint('[CartProvider] 🗑️ Deleted ${toDelete.length} orphan items');
        } catch (e) {
          debugPrint('[CartProvider] ⚠️ Batch delete error: $e');
        }
      }

      // NOTE : Purge automatique multi-devises DÉSACTIVÉE
      // L'utilisateur doit gérer manuellement via l'UI pour éviter
      // la perte involontaire d'items. L'UI affichera l'alerte.

      state = state.copyWith(items: enriched, isSyncing: false, isLoading: false, lastError: null); // CORRECTION ICI
      await _saveToCache();
    } catch (e) {
      debugPrint('[CartProvider] ❌ Sync error: $e');
      state = state.copyWith(
        isSyncing: false,
        isLoading: false, // CORRECTION ICI
        lastError: _friendlyError(e),
      );
    }
  }

  Future<void> loadCart() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (!_CartValidators.isValidUuid(uid)) {
      state = const CartState();
      return;
    }

    state = state.copyWith(isLoading: true, lastError: null);
    debugPrint('[CartProvider] 🔄 Loading cart for ${uid!.substring(0, 8)}...');

    try {
      final res = await _withRetry(
        () => db
            .from('cart')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false),
        label: 'loadCart',
      );
      await _syncCartWithProducts(List<Map<String, dynamic>>.from(res));
      debugPrint('[CartProvider] ✓ Cart loaded: ${state.items.length} items');
    } catch (e) {
      debugPrint('[CartProvider] ❌ Load error: $e');
      state = state.copyWith(
        isLoading: false,
        lastError: _friendlyError(e),
      );
    }
  }

  // ========== ADD TO CART ==========
  Future<void> addToCart({
    required String productId,
    int quantity = 1,
    String? variant,
    String? color,
  }) async {
    // Protection double-tap
    if (_isAddingToCart) {
      debugPrint('[CartProvider] ⚠️ Add to cart already in progress');
      return;
    }

    if (!_CartValidators.isValidUuid(productId)) {
      throw Exception('Identifiant produit invalide');
    }

    final validatedQty = quantity.clamp(_kMinQuantity, _kMaxQuantity);

    _isAddingToCart = true;
    debugPrint('[CartProvider] ➕ Add to cart: ${productId.substring(0, 8)}... (qty=$validatedQty)');

    try {
      final db = ref.read(supabaseClientProvider);
      final uid = db.auth.currentUser?.id;
      if (!_CartValidators.isValidUuid(uid)) {
        throw Exception('Veuillez vous connecter');
      }

      // Fetch produit avec timeout + retry
      final product = await _withRetry(
        () => db
            .from('products')
            .select('id, stock, title, currency, status')
            .eq('id', productId)
            .maybeSingle(),
        label: 'fetchProduct',
      );

      if (product == null) throw Exception('Produit introuvable');

      final stock = _CartValidators.safeInt(product['stock']);
      final status = product['status']?.toString() ?? 'active';

      if (stock <= 0 || status == 'sold_out') {
        throw Exception('Rupture de stock');
      }

      final newCurrency = _normalizeCurrency(product['currency']);

      // Vérification devise
      if (state.items.isNotEmpty) {
        final existingCurrency = currency;
        if (existingCurrency != newCurrency) {
          throw Exception(
            'Impossible d\'ajouter un produit en $newCurrency. '
            'Votre panier est déjà en $existingCurrency. '
            'Videz le panier ou retirez les autres articles.',
          );
        }
      }

      // Recherche item existant (même produit + variant + color)
      final existingIdx = state.items.indexWhere((i) {
        return i['product_id'] == productId &&
            i['variant'] == variant &&
            i['color'] == color;
      });

      if (existingIdx != -1) {
        final existing = state.items[existingIdx];
        final curQty = _CartValidators.safeInt(existing['quantity'], fallback: 1);
        final newQty = _CartValidators.validateQuantity(curQty + validatedQty, stock);

        if (newQty > stock) {
          throw Exception('Stock limité à $stock');
        }

        await updateQuantity(existing['id'].toString(), newQty);
      } else {
        if (validatedQty > stock) {
          throw Exception('Stock limité à $stock');
        }

        await _withRetry(
          () => db.from('cart').insert({
            'user_id': uid,
            'product_id': productId,
            'quantity': validatedQty,
            'variant': variant,
            'color': color,
          }),
          label: 'insertCartItem',
        );
      }

      // NOTE : Pas de loadCart() ici car le realtime prendra le relais
      debugPrint('[CartProvider] ✓ Item added to cart');
    } catch (e) {
      debugPrint('[CartProvider] ❌ Add to cart error: $e');
      state = state.copyWith(lastError: _friendlyError(e));
      rethrow;
    } finally {
      _isAddingToCart = false;
    }
  }

  // ========== UPDATE QUANTITY (avec debounce) ==========
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (!_CartValidators.isValidUuid(cartItemId)) {
      throw Exception('Identifiant item invalide');
    }

    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    debugPrint('[CartProvider] 🔢 Update quantity: ${cartItemId.substring(0, 8)}... → $newQuantity');

    // Update optimiste immédiat dans le state
    final newItems = [...state.items];
    final idx = newItems.indexWhere((i) => i['id']?.toString() == cartItemId);

    if (idx == -1) {
      debugPrint('[CartProvider] ⚠️ Item not found in local state');
      return;
    }

    final product = newItems[idx]['product'] as Map?;
    final stock = _CartValidators.safeInt(product?['stock']);
    final validatedQty = _CartValidators.validateQuantity(newQuantity, stock);

    if (validatedQty > stock && stock > 0) {
      throw Exception('Stock limité à $stock');
    }

    // Update optimiste
    newItems[idx] = {...newItems[idx], 'quantity': validatedQty};
    state = state.copyWith(items: newItems);
    await _saveToCache();

    // Debounce pour éviter spam DB sur clics rapides +/-
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_kDebounceDelay, () async {
      await _persistQuantityUpdate(cartItemId, validatedQty);
    });
  }

  Future<void> _persistQuantityUpdate(String cartItemId, int quantity) async {
    try {
      final db = ref.read(supabaseClientProvider);
      await _withRetry(
        () => db.from('cart').update({'quantity': quantity}).eq('id', cartItemId),
        label: 'updateQuantity',
      );
      debugPrint('[CartProvider] ✓ Quantity persisted: $quantity');
    } catch (e) {
      debugPrint('[CartProvider] ❌ Persist quantity error: $e');
      state = state.copyWith(lastError: _friendlyError(e));
      // Recharger pour resync avec DB
      await loadCart();
    }
  }

  // ========== REMOVE / CLEAR ==========
  Future<void> removeFromCart(String cartItemId) async {
    if (!_CartValidators.isValidUuid(cartItemId)) {
      throw Exception('Identifiant item invalide');
    }

    debugPrint('[CartProvider] 🗑️ Remove item: ${cartItemId.substring(0, 8)}...');

    // Remove optimiste
    final newItems = state.items.where((i) => i['id']?.toString() != cartItemId).toList();
    state = state.copyWith(items: newItems);
    await _saveToCache();

    try {
      final db = ref.read(supabaseClientProvider);
      await _withRetry(
        () => db.from('cart').delete().eq('id', cartItemId),
        label: 'removeFromCart',
      );
      debugPrint('[CartProvider] ✓ Item removed from DB');
    } catch (e) {
      debugPrint('[CartProvider] ❌ Remove error: $e');
      state = state.copyWith(lastError: _friendlyError(e));
      rethrow;
    }
  }

  Future<void> clearCart() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (!_CartValidators.isValidUuid(uid)) return;

    debugPrint('[CartProvider] 🧹 Clearing cart');

    // Clear optimiste
    state = const CartState();
    await _clearCache();

    try {
      await _withRetry(
        () => db.from('cart').delete().eq('user_id', uid!),
        label: 'clearCart',
      );
      debugPrint('[CartProvider] ✓ Cart cleared');
    } catch (e) {
      debugPrint('[CartProvider] ❌ Clear error: $e');
      state = state.copyWith(lastError: _friendlyError(e));
      rethrow;
    }
  }

  void clearError() {
    if (state.lastError != null) {
      state = state.copyWith(lastError: null);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    _debounceTimer?.cancel();
    debugPrint('[CartProvider] 👋 Disposed');
    super.dispose();
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================
final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier(ref));

final cartItemsProvider = Provider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(cartProvider).items,
);

final cartTotalProvider = Provider<double>((ref) {
  return ref.read(cartProvider.notifier).total;
});

final cartCountProvider = Provider<int>((ref) {
  return ref.read(cartProvider.notifier).itemCount;
});

final cartHasErrorProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).lastError != null;
});
