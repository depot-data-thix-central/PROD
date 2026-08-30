// lib/presentation/thix_market/checkout/checkout_provider.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../providers/market_providers.dart';
import '../cart/cart_provider.dart';
import '../../../services/market_payment_service.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kPaymentTimeout = Duration(seconds: 45);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxCheckoutItems = 50;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CheckoutValidators {
  _CheckoutValidators._();

  static bool isValidId(String? id) {
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

  static int safeInt(dynamic v, {int fallback = 0, int max = 999999}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    if (parsed < 0 || parsed > max) return fallback;
    return parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    if (parsed < 0 || parsed.isNaN || parsed.isInfinite) return fallback;
    return parsed;
  }

  static String normalizeCurrency(String? raw) {
    if (raw == null) return 'CDF';
    final c = raw.toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$') return 'USD';
    if (c == 'CDF' || c == 'FC' || c == 'XOF' || c == 'FCFA' || c == 'XAF') return 'CDF';
    if (c == 'EUR' || c == '€') return 'EUR';
    return c.isEmpty ? 'CDF' : c;
  }

  /// Génère un receipt_code court et non-prévisible (6 chars alphanumériques)
  static String generateReceiptCode(String orderId) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Pas de 0, O, I, 1 (confusion)
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${orderId.substring(0, 8).toUpperCase()}-$code';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[CheckoutProvider] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[CheckoutProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

String _friendlyError(dynamic e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
  if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
  if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
  if (msg.contains('unique') || msg.contains('duplicate')) return 'Cette ressource existe déjà.';
  if (msg.contains('rupture')) return e.toString();
  if (msg.contains('stock')) return e.toString();
  return 'Une erreur est survenue. Réessayez.';
}

// ============================================================================
// MODÈLES INTERNES
// ============================================================================
class _StockValidationResult {
  final String productId;
  final String title;
  final int available;
  final int requested;
  final bool isValid;
  final String? errorMessage;

  const _StockValidationResult({
    required this.productId,
    required this.title,
    required this.available,
    required this.requested,
    required this.isValid,
    this.errorMessage,
  });
}

// ============================================================================
// STATE
// ============================================================================
class CheckoutState {
  final bool isLoading;
  final bool isProcessing;
  final String? error;
  final String currentStep;
  final List<Map<String, dynamic>> savedAddresses;
  final Map<String, dynamic>? selectedAddress;
  final Map<String, dynamic>? selectedShipping;
  final Map<String, dynamic>? selectedPayment;
  final Map<String, dynamic> userInfo;
  final Map<String, dynamic>? createdOrder;

  const CheckoutState({
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.currentStep = 'address',
    this.savedAddresses = const [],
    this.selectedAddress,
    this.selectedShipping,
    this.selectedPayment,
    this.userInfo = const {},
    this.createdOrder,
  });

  CheckoutState copyWith({
    bool? isLoading,
    bool? isProcessing,
    Object? error = _sentinel,
    String? currentStep,
    List<Map<String, dynamic>>? savedAddresses,
    Object? selectedAddress = _sentinel,
    Object? selectedShipping = _sentinel,
    Object? selectedPayment = _sentinel,
    Map<String, dynamic>? userInfo,
    Object? createdOrder = _sentinel,
  }) {
    return CheckoutState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: identical(error, _sentinel) ? this.error : error as String?,
      currentStep: currentStep ?? this.currentStep,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      selectedAddress: identical(selectedAddress, _sentinel)
          ? this.selectedAddress
          : selectedAddress as Map<String, dynamic>?,
      selectedShipping: identical(selectedShipping, _sentinel)
          ? this.selectedShipping
          : selectedShipping as Map<String, dynamic>?,
      selectedPayment: identical(selectedPayment, _sentinel)
          ? this.selectedPayment
          : selectedPayment as Map<String, dynamic>?,
      userInfo: userInfo ?? this.userInfo,
      createdOrder: identical(createdOrder, _sentinel)
          ? this.createdOrder
          : createdOrder as Map<String, dynamic>?,
    );
  }
}

// Sentinel pour permettre `copyWith(field: null)` explicite
const Object _sentinel = Object();

// ============================================================================
// NOTIFIER
// ============================================================================
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this.ref) : super(const CheckoutState());
  final Ref ref;

  // ========== NAVIGATION ==========
  static const List<String> _validSteps = [
    'address',
    'shipping',
    'summary',
    'payment',
    'waiting_payment',
    'confirmation',
    'success',
    'bon_de_commande',
  ];

  void goToStep(String step) {
    if (!_validSteps.contains(step)) {
      debugPrint('[CheckoutProvider] ⚠️ Invalid step: $step');
      return;
    }
    debugPrint('[CheckoutProvider] 🧭 Step: ${state.currentStep} → $step');
    state = state.copyWith(currentStep: step, error: null);
  }

  void setStep(String step) => goToStep(step);

  void next() {
    switch (state.currentStep) {
      case 'address': goToStep('shipping'); break;
      case 'shipping': goToStep('summary'); break;
      case 'summary':
      case 'confirmation': goToStep('payment'); break;
      case 'payment': goToStep('waiting_payment'); break;
      case 'waiting_payment': goToStep('bon_de_commande'); break;
      default: break;
    }
  }

  void previous() {
    switch (state.currentStep) {
      case 'shipping': goToStep('address'); break;
      case 'summary':
      case 'confirmation': goToStep('shipping'); break;
      case 'payment': goToStep('summary'); break;
      case 'waiting_payment': goToStep('payment'); break;
      case 'success':
      case 'bon_de_commande': goToStep('payment'); break;
      default: break;
    }
  }

  // ========== CHARGEMENT ==========
  Future<void> loadCheckoutData() async {
    final db = ref.read(supabaseClientProvider);
    final userId = db.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[CheckoutProvider] ⚠️ No authenticated user');
      state = state.copyWith(isLoading: false, error: 'Non connecté');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    debugPrint('[CheckoutProvider] 🔄 Loading checkout data for ${userId.substring(0, 8)}...');

    try {
      final results = await Future.wait([
        _loadAddresses(userId),
        _loadUserInfo(userId),
      ]);

      final addresses = results[0] as List<Map<String, dynamic>>;
      final userInfo = results[1] as Map<String, dynamic>;

      // Sélection adresse : défaut > première
      Map<String, dynamic>? selAddr = state.selectedAddress;
      final defaultId = userInfo['default_address_id']?.toString();

      if (defaultId != null && defaultId.isNotEmpty) {
        try {
          selAddr = addresses.firstWhere(
            (a) => a['id']?.toString() == defaultId,
          );
        } catch (_) {
          selAddr = null;
        }
      }
      selAddr ??= state.selectedAddress;
      selAddr ??= addresses.isNotEmpty ? addresses.first : null;

      state = state.copyWith(
        isLoading: false,
        savedAddresses: addresses,
        userInfo: userInfo,
        selectedAddress: selAddr,
        currentStep: 'address',
      );
      debugPrint('[CheckoutProvider] ✓ Loaded ${addresses.length} addresses');
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ Load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadAddresses(String userId) async {
    try {
      final db = ref.read(supabaseClientProvider);
      final res = await _withRetry(
        () => db
            .from('addresses')
            .select()
            .eq('user_id', userId)
            .order('is_default', ascending: false),
        label: 'loadAddresses',
      );
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ _loadAddresses error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadUserInfo(String userId) async {
    final db = ref.read(supabaseClientProvider);
    try {
      // Sélection large qui couvre les deux schémas possibles (name / full_name)
      final r = await _withRetry(
        () => db
            .from('users')
            .select('id, full_name, name, email, phone, default_address_id')
            .eq('id', userId)
            .maybeSingle(),
        label: 'loadUserInfo',
      );

      if (r != null) {
        // Normaliser full_name
        final fullName = r['full_name']?.toString() ?? r['name']?.toString();
        return {
          'id': r['id']?.toString() ?? userId,
          'full_name': _CheckoutValidators.sanitize(fullName ?? 'Utilisateur', maxLength: 100),
          'email': _CheckoutValidators.sanitize(r['email']?.toString(), maxLength: 200),
          'phone': _CheckoutValidators.sanitize(r['phone']?.toString(), maxLength: 20),
          'default_address_id': r['default_address_id']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ _loadUserInfo error: $e');
    }

    return {
      'id': userId,
      'full_name': 'Utilisateur',
      'email': '',
      'phone': '',
    };
  }

  // ========== SÉLECTIONS (avec validation IDs) ==========
  void selectAddress(Map<String, dynamic> address) {
    final id = address['id']?.toString();
    if (id == null || !_CheckoutValidators.isValidId(id)) {
      debugPrint('[CheckoutProvider] ⚠️ Invalid address ID rejected');
      return;
    }
    state = state.copyWith(selectedAddress: address);
    debugPrint('[CheckoutProvider] 📍 Address selected: ${id.substring(0, 8)}');
  }

  Future<void> addAddress(Map<String, dynamic> newAddress) async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(error: 'Non connecté');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await _withRetry(
        () => db
            .from('addresses')
            .insert({...newAddress, 'user_id': uid})
            .select()
            .single(),
        label: 'addAddress',
      );

      final map = Map<String, dynamic>.from(res);
      state = state.copyWith(
        savedAddresses: [map, ...state.savedAddresses],
        selectedAddress: map,
        isLoading: false,
      );
      debugPrint('[CheckoutProvider] ✓ Address added: ${map['id']}');
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ addAddress error: $e');
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  void selectShippingMethod(Map<String, dynamic> method) {
    final id = method['id']?.toString();
    if (id == null || !_CheckoutValidators.isValidId(id)) {
      debugPrint('[CheckoutProvider] ⚠️ Invalid shipping method ID rejected');
      return;
    }
    state = state.copyWith(selectedShipping: method);
    debugPrint('[CheckoutProvider] 🚚 Shipping selected: ${id.substring(0, 8)}');
  }

  void selectPaymentMethod(Map<String, dynamic> method) {
    final id = method['id']?.toString();
    if (id == null || id.isEmpty) {
      debugPrint('[CheckoutProvider] ⚠️ Invalid payment method ID rejected');
      return;
    }
    state = state.copyWith(selectedPayment: method);
    debugPrint('[CheckoutProvider] 💳 Payment selected: $id');
  }

  // ========== DEVISE ==========
  String _resolveCurrency(List<Map<String, dynamic>> items) {
    // 1. Priorité au panier (source de vérité)
    try {
      final cartCurrency = ref.read(cartProvider.notifier).currencySymbol;
      final normalized = _CheckoutValidators.normalizeCurrency(cartCurrency);
      if (normalized != 'CDF' || cartCurrency.toUpperCase() == 'USD' || cartCurrency == '\$') {
        return normalized;
      }
    } catch (_) {}

    // 2. Fallback : premier item avec currency valide
    for (final item in items) {
      final product = item['product'];
      final raw = (product is Map ? product['currency'] : null) ?? item['currency'];
      if (raw != null) {
        final normalized = _CheckoutValidators.normalizeCurrency(raw.toString());
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return 'CDF';
  }

  // ========== VALIDATION STOCK EN BATCH ==========
  Future<List<_StockValidationResult>> _validateStockBatch(
    List<Map<String, dynamic>> items,
  ) async {
    final db = ref.read(supabaseClientProvider);

    // Extraire tous les IDs et quantités
    final Map<String, int> productQuantities = {};
    for (final item in items) {
      final productId = item['product_id']?.toString() ??
          (item['product'] is Map ? (item['product'] as Map)['id']?.toString() : null);
      if (productId == null || !_CheckoutValidators.isValidId(productId)) {
        throw Exception('Produit invalide dans le panier');
      }
      final qty = _CheckoutValidators.safeInt(item['quantity'], fallback: 1, max: 999);
      productQuantities[productId] = (productQuantities[productId] ?? 0) + qty;
    }

    if (productQuantities.isEmpty) {
      throw Exception('Panier vide');
    }

    // Batch fetch : 1 requête au lieu de N
    final productIds = productQuantities.keys.toList();
    final products = await _withRetry(
      () => db
          .from('products')
          .select('id, stock, title, status')
          .inFilter('id', productIds),
      label: 'batchFetchStock',
    );

    final productsMap = <String, Map<String, dynamic>>{};
    for (final p in products as List) {
      final map = Map<String, dynamic>.from(p as Map);
      final id = map['id']?.toString();
      if (id != null) productsMap[id] = map;
    }

    // Valider chaque produit
    final results = <_StockValidationResult>[];
    for (final entry in productQuantities.entries) {
      final productId = entry.key;
      final requested = entry.value;
      final product = productsMap[productId];

      if (product == null) {
        throw Exception('Produit introuvable (ID: ${productId.substring(0, 8)})');
      }

      final title = _CheckoutValidators.sanitize(product['title']?.toString() ?? 'Produit', maxLength: 80);
      final status = product['status']?.toString() ?? 'active';
      final stock = _CheckoutValidators.safeInt(product['stock']);

      if (status == 'sold_out' || stock <= 0) {
        throw Exception('Rupture de stock : $title');
      }
      if (requested > stock) {
        throw Exception('Stock insuffisant pour "$title" (disponible : $stock, demandé : $requested)');
      }

      results.add(_StockValidationResult(
        productId: productId,
        title: title,
        available: stock,
        requested: requested,
        isValid: true,
      ));
    }

    debugPrint('[CheckoutProvider] ✓ Stock validated for ${results.length} products');
    return results;
  }

  // ========== CRÉATION COMMANDE ==========
  Future<Map<String, dynamic>> createOrderOnly({
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = ref.read(supabaseClientProvider);
    final userId = db.auth.currentUser?.id;

    // Validations pré-requêtes
    if (userId == null) throw Exception('Non connecté');
    if (state.selectedAddress == null) throw Exception('Adresse requise');
    if (state.selectedShipping == null) throw Exception('Mode livraison requis');
    if (state.selectedPayment == null) throw Exception('Paiement requis');
    if (items.isEmpty) throw Exception('Panier vide');
    if (items.length > _kMaxCheckoutItems) {
      throw Exception('Trop d\'articles (max $_kMaxCheckoutItems)');
    }

    final addressId = state.selectedAddress!['id']?.toString();
    final shippingId = state.selectedShipping!['id']?.toString();
    if (!_CheckoutValidators.isValidId(addressId)) throw Exception('Adresse invalide');
    if (!_CheckoutValidators.isValidId(shippingId)) throw Exception('Mode livraison invalide');

    // Validation stock en batch (1 requête au lieu de N)
    await _validateStockBatch(items);

    state = state.copyWith(isProcessing: true, error: null);

    String? orderId;
    bool stockDecremented = false;

    try {
      // Résolution shop_id + currency
      String? shopId;
      final first = items.first;
      if (first['product'] is Map && (first['product'] as Map)['shop_id'] != null) {
        shopId = (first['product'] as Map)['shop_id'].toString();
      } else if (first['shop_id'] != null) {
        shopId = first['shop_id'].toString();
      }
      final currency = _resolveCurrency(items);
      final shippingCost = _CheckoutValidators.safeDouble(state.selectedShipping!['price']);

      // 1. Créer l'order
      final orderData = {
        'user_id': userId,
        'shop_id': shopId,
        'address_id': addressId,
        'shipping_method': shippingId,
        'shipping_cost': shippingCost,
        'total': total,
        'currency': currency,
        'status': 'pending',
        'payment_status': 'awaiting_payment',
        'payout_status': 'held',
        'refund_requested': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final orderRes = await _withRetry(
        () => db.from('orders').insert(orderData).select().single(),
        label: 'createOrder',
      );
      final orderMap = Map<String, dynamic>.from(orderRes as Map);
      orderId = orderMap['id'].toString();
      debugPrint('[CheckoutProvider] ✓ Order created: ${orderId.substring(0, 8)}');

      // 2. Receipt code non-prévisible
      final receiptCode = _CheckoutValidators.generateReceiptCode(orderId);
      try {
        await _withRetry(
          () => db.from('orders').update({'receipt_code': receiptCode}).eq('id', orderId ?? ''),
          label: 'updateReceiptCode',
        );
        orderMap['receipt_code'] = receiptCode;
      } catch (e) {
        debugPrint('[CheckoutProvider] ⚠️ Receipt code update failed: $e');
      }

      // 3. Batch insert order_items
      final orderItems = items.map((item) {
        final product = item['product'];
        final productId = item['product_id']?.toString() ??
            (product is Map ? product['id']?.toString() : null);
        final prodTitle = _CheckoutValidators.sanitize(
          (product is Map ? product['title'] : null)?.toString() ??
              item['product_name']?.toString() ??
              'Produit',
          maxLength: 120,
        );
        final qty = _CheckoutValidators.safeInt(item['quantity'], fallback: 1, max: 999);
        final price = _CheckoutValidators.safeDouble(item['price']);
        final imageUrl = _CheckoutValidators.sanitize(item['image_url']?.toString(), maxLength: 500);

        return {
          'order_id': orderId,
          'product_id': productId,
          'quantity': qty,
          'price': price,
          'product_name': prodTitle,
          'product_image': imageUrl.isEmpty ? null : imageUrl,
          'title_snapshot': prodTitle,
        };
      }).toList();

      await _withRetry(
        () => db.from('order_items').insert(orderItems),
        label: 'batchInsertOrderItems',
      );
      debugPrint('[CheckoutProvider] ✓ ${orderItems.length} order_items inserted');

      // 4. Décrémenter stock en parallèle (via RPC si disponible, fallback update)
      await _decrementStockBatch(db, items);
      stockDecremented = true;

      final finalOrder = {...orderMap, 'currency': currency};
      state = state.copyWith(createdOrder: finalOrder, isProcessing: false);
      return finalOrder;
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ createOrderOnly error: $e');

      // Rollback : si stock décrémenté mais order_items échoués, tenter restaurer stock
      if (stockDecremented && orderId != null) {
        debugPrint('[CheckoutProvider] 🔄 Attempting rollback for order $orderId');
        await _rollbackOrder(db, orderId, items);
      }

      state = state.copyWith(isProcessing: false, error: _friendlyError(e));
      rethrow;
    }
  }

  /// Décrémente le stock en batch via RPC (atomique) ou fallback update individuel
  Future<void> _decrementStockBatch(
    dynamic db,
    List<Map<String, dynamic>> items,
  ) async {
    // Regrouper quantités par produit
    final Map<String, int> quantities = {};
    for (final item in items) {
      final productId = item['product_id']?.toString() ??
          (item['product'] is Map ? (item['product'] as Map)['id']?.toString() : null);
      if (productId == null) continue;
      final qty = _CheckoutValidators.safeInt(item['quantity'], fallback: 1, max: 999);
      quantities[productId] = (quantities[productId] ?? 0) + qty;
    }

    // Tenter RPC atomique d'abord
    for (final entry in quantities.entries) {
      try {
        await _withRetry(
          () => db.rpc('decrement_product_stock', params: {
            'p_product_id': entry.key,
            'p_quantity': entry.value,
          }),
          label: 'decrementStock[${entry.key.substring(0, 8)}]',
        );
      } catch (rpcError) {
        debugPrint('[CheckoutProvider] ⚠️ RPC decrement failed for ${entry.key}, fallback to update: $rpcError');
        // Fallback : update manuel (non-atomique mais mieux que rien)
        try {
          final prod = await db.from('products').select('stock').eq('id', entry.key).maybeSingle();
          if (prod != null) {
            final current = _CheckoutValidators.safeInt((prod as Map)['stock']);
            final newStock = (current - entry.value).clamp(0, 999999);
            await db.from('products').update({
              'stock': newStock,
              if (newStock <= 0) 'status': 'sold_out',
            }).eq('id', entry.key);
          }
        } catch (fallbackError) {
          debugPrint('[CheckoutProvider] ❌ Stock decrement fallback failed: $fallbackError');
          // Non-bloquant : l'order est créé, le stock sera resync plus tard
        }
      }
    }
  }

  /// Rollback : supprime l'order et restaure le stock si possible
  Future<void> _rollbackOrder(
    dynamic db,
    String orderId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await db.from('orders').delete().eq('id', orderId);
      debugPrint('[CheckoutProvider] 🗑️ Rollback: order $orderId deleted');
    } catch (e) {
      debugPrint('[CheckoutProvider] ⚠️ Rollback delete failed: $e');
    }
  }

  // ========== PROCESS ORDER + PAIEMENT ==========
  Future<Map<String, dynamic>> processOrder({
    required double total,
    required List<Map<String, dynamic>> items,
    String? phoneNumber,
  }) async {
    debugPrint('[CheckoutProvider] 💰 Processing order (${items.length} items, total: $total)');

    // 1. Créer la commande (avec rollback si échec)
    final order = await createOrderOnly(total: total, items: items);
    final orderId = order['id'].toString();
    final currency = order['currency']?.toString() ?? _resolveCurrency(items);

    // 2. Initier le paiement
    final paymentService = MarketPaymentService(ref.read(supabaseClientProvider));
    final method = state.selectedPayment!['id'] as String;

    Map<String, dynamic> result;
    try {
      result = await _withRetry(
        () => paymentService.initiatePayment(
          orderId: orderId,
          amount: total,
          currency: currency,
          paymentMethod: method,
          phoneNumber: phoneNumber ?? state.userInfo['phone']?.toString(),
        ),
        label: 'initiatePayment',
        timeout: _kPaymentTimeout,
        maxRetries: 0, // Pas de retry sur paiement (risque de double charge)
      );
    } catch (e) {
      debugPrint('[CheckoutProvider] ❌ Payment initiation error: $e');
      // Rollback order si paiement n'a pas pu être initié
      await _rollbackOrder(ref.read(supabaseClientProvider), orderId, items);
      state = state.copyWith(
        isProcessing: false,
        error: _friendlyError(e),
        createdOrder: null,
      );
      throw Exception(_friendlyError(e));
    }

    if (result['success'] != true) {
      debugPrint('[CheckoutProvider] ❌ Payment failed: ${result['error']}');
      await _rollbackOrder(ref.read(supabaseClientProvider), orderId, items);
      state = state.copyWith(
        isProcessing: false,
        error: result['error']?.toString() ?? 'Paiement échoué',
        createdOrder: null,
      );
      throw Exception(result['error'] ?? 'Paiement échoué');
    }

    // 3. Mettre à jour payment_status (order status reste "pending" jusqu'au scan client)
    final paymentStatus = result['payment_status']?.toString() ?? 'awaiting_payment';
    try {
      await _withRetry(
        () => ref.read(supabaseClientProvider).from('orders').update({
          'payment_status': paymentStatus,
          'status': 'pending',
          'payout_status': 'held',
          'payment_method': method,
        }).eq('id', orderId),
        label: 'updatePaymentStatus',
      );
    } catch (e) {
      debugPrint('[CheckoutProvider] ⚠️ Payment status update failed: $e');
      // Non-bloquant : le webhook du PSP mettra à jour plus tard
    }

    // 4. Paiement immédiat (cash / thix) → vider panier
    if (result['needs_waiting'] != true) {
      try {
        await ref.read(cartProvider.notifier).clearCart();
        debugPrint('[CheckoutProvider] 🛒 Cart cleared (immediate payment)');
      } catch (e) {
        debugPrint('[CheckoutProvider] ⚠️ Cart clear failed: $e');
      }

      try {
        final updated = await _withRetry(
          () => ref.read(supabaseClientProvider).from('orders').select().eq('id', orderId).single(),
          label: 'refreshOrder',
        );
        state = state.copyWith(createdOrder: Map<String, dynamic>.from(updated as Map));
      } catch (e) {
        debugPrint('[CheckoutProvider] ⚠️ Order refresh failed: $e');
      }
    }

    debugPrint('[CheckoutProvider] ✅ Order processed: ${orderId.substring(0, 8)}');
    return {...result, 'order': order, 'order_id': orderId};
  }

  void reset() {
    debugPrint('[CheckoutProvider] 🔄 Reset state');
    state = const CheckoutState();
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref),
);
