// lib/services/checkout_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kPaymentTimeout = Duration(seconds: 45);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxOrderItems = 50;
const int _kMaxProductNameLength = 120;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CheckoutServiceValidators {
  _CheckoutServiceValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static int safeInt(dynamic v, {int fallback = 0, int max = 999999}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    if (parsed < 0) return fallback;
    return parsed > max ? max : parsed;
  }

  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(cleaned);
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('duplicate')) return 'Cette commande existe déjà.';
    if (msg.contains('insufficient') || msg.contains('balance')) return 'Solde insuffisant.';
    if (msg.contains('stock')) return e.toString();
    return 'Une erreur est survenue. Réessayez.';
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
        debugPrint('[CheckoutService] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[CheckoutService] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[CheckoutService] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// SERVICE PRINCIPAL
// ============================================================================
class CheckoutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================================
  // VALIDATION STOCK
  // ================================================================
  Future<StockValidationResult> validateStock(List<CartItem> items) async {
    if (items.isEmpty) {
      return StockValidationResult(isValid: false, errors: ['Panier vide']);
    }
    if (items.length > _kMaxOrderItems) {
      return StockValidationResult(
        isValid: false,
        errors: ['Trop d\'articles (max $_kMaxOrderItems)'],
      );
    }

    for (final item in items) {
      if (!_CheckoutServiceValidators.isValidId(item.productId)) {
        return StockValidationResult(isValid: false, errors: ['Identifiant produit invalide']);
      }
      if (item.quantity < 1 || item.quantity > 999) {
        return StockValidationResult(isValid: false, errors: ['Quantité invalide pour ${item.productName}']);
      }
    }

    try {
      final productIds = items.map((e) => {'id': e.productId, 'quantity': e.quantity}).toList();

      final response = await _withRetry(
        () => _supabase.rpc('validate_stock', params: {'items': productIds}),
        label: 'validateStock[RPC]',
      );

      return StockValidationResult.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('[CheckoutService] ⚠️ RPC validate_stock failed, fallback: $e');
      return await _validateStockLocally(items);
    }
  }

  Future<StockValidationResult> _validateStockLocally(List<CartItem> items) async {
    final errors = <String>[];

    try {
      // Agrégation quantités par produit
      final aggregated = <String, int>{};
      for (final item in items) {
        aggregated[item.productId] = (aggregated[item.productId] ?? 0) + item.quantity;
      }

      final productIds = aggregated.keys.toList();

      // BATCH fetch (1 requête au lieu de N)
      final products = await _withRetry(
        () => _supabase.from('products').select('id, stock, title, status').inFilter('id', productIds),
        label: 'batchFetchStock[${productIds.length}]',
      );

      final productsMap = <String, Map<String, dynamic>>{};
      for (final p in products as List) {
        final map = Map<String, dynamic>.from(p as Map);
        final id = map['id']?.toString();
        if (id != null) productsMap[id] = map;
      }

      for (final entry in aggregated.entries) {
        final productId = entry.key;
        final requested = entry.value;
        final product = productsMap[productId];
        final item = items.firstWhere((i) => i.productId == productId);
        final title = product != null
            ? _CheckoutServiceValidators.sanitize(product['title']?.toString() ?? item.productName, maxLength: 60)
            : item.productName;

        if (product == null) {
          errors.add('Produit introuvable : $title');
          continue;
        }

        final stock = _CheckoutServiceValidators.safeInt(product['stock']);
        final status = product['status']?.toString() ?? 'active';

        if (status == 'sold_out' || stock <= 0) {
          errors.add('Rupture de stock : $title');
        } else if (requested > stock) {
          errors.add('Stock insuffisant pour $title (dispo: $stock, demandé: $requested)');
        }
      }
    } catch (e) {
      debugPrint('[CheckoutService] ❌ Local stock validation error: $e');
      errors.add('Erreur lors de la vérification du stock');
    }

    return StockValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  // ================================================================
  // CRÉATION COMMANDE
  // ================================================================
  Future<OrderResult> createOrder({
    required String userId,
    required String addressId,
    required String shippingMethodId,
    required double shippingCost,
    required double total,
    required List<CartItem> items,
    required String paymentMethodId,
  }) async {
    // ========== VALIDATIONS PRÉ-REQUÊTES ==========
    if (!_CheckoutServiceValidators.isValidId(userId)) {
      return OrderResult(success: false, error: 'Utilisateur non authentifié');
    }
    if (!_CheckoutServiceValidators.isValidId(addressId)) {
      return OrderResult(success: false, error: 'Adresse de livraison invalide');
    }
    if (!_CheckoutServiceValidators.isValidId(shippingMethodId)) {
      return OrderResult(success: false, error: 'Mode de livraison invalide');
    }
    if (items.isEmpty) return OrderResult(success: false, error: 'Panier vide');
    if (items.length > _kMaxOrderItems) return OrderResult(success: false, error: 'Trop d\'articles');
    if (total < 0 || total.isNaN || total.isInfinite) return OrderResult(success: false, error: 'Total invalide');
    if (shippingCost < 0 || shippingCost.isNaN || shippingCost.isInfinite) {
      return OrderResult(success: false, error: 'Frais de livraison invalides');
    }

    debugPrint('[CheckoutService] 🛒 Creating order for user ${userId.substring(0, 8)}... (${items.length} items)');

    final stockCheck = await validateStock(items);
    if (!stockCheck.isValid) {
      debugPrint('[CheckoutService] ❌ Stock validation failed: ${stockCheck.errors}');
      return OrderResult(success: false, error: stockCheck.errors.join('\n'));
    }

    String? orderId;
    final decrementedProducts = <String, int>{}; // Tracking pour rollback complet

    try {
      // 1. Créer la commande
      final orderData = {
        'user_id': userId,
        'address_id': addressId,
        'shipping_method_id': shippingMethodId,
        'shipping_cost': shippingCost,
        'total': total,
        'payment_method': _CheckoutServiceValidators.sanitize(paymentMethodId, maxLength: 30),
        'status': 'pending',
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final orderResponse = await _withRetry(
        () => _supabase.from('orders').insert(orderData).select().single(),
        label: 'createOrder',
      );

      final orderMap = Map<String, dynamic>.from(orderResponse as Map);
      orderId = orderMap['id']?.toString();
      if (orderId == null) throw Exception('Order ID null after insert');
      debugPrint('[CheckoutService] ✓ Order created: ${orderId.substring(0, 8)}...');

      // 2. BATCH insert order_items
      final orderItems = items.map((item) {
        return {
          'order_id': orderId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'price': item.price,
          'product_name': _CheckoutServiceValidators.sanitize(item.productName, maxLength: _kMaxProductNameLength),
          'product_image': _CheckoutServiceValidators.sanitizeUrl(item.imageUrl),
          'variant': _CheckoutServiceValidators.sanitize(item.variant, maxLength: 60),
          'color': _CheckoutServiceValidators.sanitize(item.color, maxLength: 30),
        };
      }).toList();

      await _withRetry(
        () => _supabase.from('order_items').insert(orderItems),
        label: 'batchInsertOrderItems[${orderItems.length}]',
      );

      // 3. Décrémenter stock (avec tracking rollback)
      for (final item in items) {
        try {
          final ok = await _withRetry(
            () => _supabase.rpc('decrement_product_stock', params: {
              'p_product_id': item.productId,
              'p_quantity': item.quantity,
            }),
            label: 'decrementStock[${item.productId.substring(0, 8)}]',
          );

          if (ok != true) throw Exception('RPC returned false for ${item.productId}');
          decrementedProducts[item.productId] = item.quantity;
        } catch (e) {
          debugPrint('[CheckoutService] ⚠️ RPC decrement failed: $e');
          throw Exception('Stock insuffisant pour ${item.productName}');
        }
      }

      // 4. Vider panier (non-bloquant)
      try {
        await _withRetry(() => _supabase.from('cart').delete().eq('user_id', userId), label: 'clearCart');
      } catch (e) {
        debugPrint('[CheckoutService] ⚠️ Cart clear failed (non-blocking): $e');
      }

      return OrderResult(success: true, orderId: orderId, orderData: orderMap);
    } catch (e) {
      debugPrint('[CheckoutService] ❌ Create order error: $e');

      // ROLLBACK COMPLET
      if (decrementedProducts.isNotEmpty) {
        await _rollbackStock(decrementedProducts);
      }
      if (orderId != null) {
        try {
          await _supabase.from('orders').delete().eq('id', orderId);
        } catch (err) {
          debugPrint('[CheckoutService] ⚠️ Order rollback failed: $err');
        }
      }

      return OrderResult(success: false, error: _CheckoutServiceValidators.friendlyError(e));
    }
  }

  Future<void> _rollbackStock(Map<String, int> decrementedProducts) async {
    for (final entry in decrementedProducts.entries) {
      try {
        await _supabase.rpc('increment_product_stock', params: {
          'p_product_id': entry.key,
          'p_quantity': entry.value,
        });
      } catch (e) {
        debugPrint('[CheckoutService] ⚠️ Stock rollback failed for ${entry.key}: $e');
      }
    }
  }

  // ================================================================
  // PAIEMENT
  // ================================================================
  Future<PaymentResult> processPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    if (!_CheckoutServiceValidators.isValidId(orderId)) {
      return PaymentResult.failure('Identifiant de commande invalide');
    }
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return PaymentResult.failure('Montant invalide');
    }

    try {
      switch (paymentMethod) {
        case 'card':
          return await _processCardPayment(orderId, amount, paymentDetails);
        case 'mobile_money':
        case 'orange_money':
        case 'airtel':
        case 'vodacom':
        case 'africell':
          return await _processMobileMoney(orderId, amount, paymentMethod, paymentDetails);
        case 'thix_money':
          return await _processThixMoney(orderId, amount);
        case 'cash':
          await _updateOrderPayment(orderId, 'pending_delivery', null);
          return PaymentResult.success(status: 'pending_delivery');
        default:
          return PaymentResult.failure('Méthode de paiement inconnue');
      }
    } catch (e) {
      return PaymentResult.failure(_CheckoutServiceValidators.friendlyError(e));
    }
  }

  Future<PaymentResult> _processCardPayment(String orderId, double amount, Map<String, dynamic>? details) async {
    final paymentMethodId = details?['payment_method_id']?.toString();
    try {
      final response = await _withRetry(
        () => _supabase.functions.invoke('process-card-payment', body: {
          'order_id': orderId,
          'amount': amount,
          'currency': 'XOF',
          'payment_method_id': paymentMethodId,
        }),
        label: 'processCardPayment',
        timeout: _kPaymentTimeout,
        maxRetries: 0,
      );

      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};

      if (data['success'] == true) {
        final transactionId = data['transaction_id']?.toString();
        await _updateOrderPayment(orderId, 'paid', transactionId);
        return PaymentResult.success(transactionId: transactionId, status: 'paid');
      }
      return PaymentResult.failure(_CheckoutServiceValidators.sanitize(data['error']?.toString() ?? 'Paiement échoué', maxLength: 200));
    } catch (e) {
      return PaymentResult.failure(_CheckoutServiceValidators.friendlyError(e));
    }
  }

  Future<PaymentResult> _processMobileMoney(
    String orderId, double amount, String paymentMethod, Map<String, dynamic>? details,
  ) async {
    final phone = details?['phone']?.toString();
    if (phone == null || !_CheckoutServiceValidators.isValidPhone(phone)) {
      return PaymentResult.failure('Numéro de téléphone invalide');
    }
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    try {
      final response = await _withRetry(
        () => _supabase.functions.invoke('process-payment', body: {
          'order_id': orderId,
          'amount': amount,
          'phone_number': normalizedPhone,
          'payment_method': paymentMethod,
          'type': 'market',
          'currency': 'CDF',
        }),
        label: 'processMobileMoney[$paymentMethod]',
        timeout: _kPaymentTimeout,
        maxRetries: 0,
      );

      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};

      if (data['success'] == true) {
        final transactionId = data['ref_transa']?.toString();
        await _updateOrderPayment(orderId, 'awaiting_payment', transactionId);
        return PaymentResult.pending(transactionId: transactionId, status: 'awaiting_payment');
      }
      return PaymentResult.failure(_CheckoutServiceValidators.sanitize(data['error']?.toString() ?? 'Paiement échoué', maxLength: 200));
    } catch (e) {
      return PaymentResult.failure(_CheckoutServiceValidators.friendlyError(e));
    }
  }

  Future<PaymentResult> _processThixMoney(String orderId, double amount) async {
    final userId = _supabase.auth.currentUser?.id;
    if (!_CheckoutServiceValidators.isValidId(userId)) {
      return PaymentResult.failure('Utilisateur non connecté');
    }

    try {
      // RPC atomique : vérif balance + débit en 1 transaction
      try {
        final result = await _withRetry(
          () => _supabase.rpc('pay_with_wallet', params: {
            'p_user_id': userId,
            'p_order_id': orderId,
            'p_amount': amount,
          }),
          label: 'payWithWallet[atomic]',
          maxRetries: 0,
        );

        final resultData = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};

        if (resultData['success'] == true) {
          final transactionId = resultData['transaction_id']?.toString() ??
              'THIX_${DateTime.now().millisecondsSinceEpoch}';
          return PaymentResult.success(transactionId: transactionId, status: 'paid');
        }
        return PaymentResult.failure(_CheckoutServiceValidators.sanitize(resultData['error']?.toString() ?? 'Solde insuffisant', maxLength: 200));
      } catch (rpcError) {
        debugPrint('[CheckoutService] ⚠️ Atomic wallet RPC failed, fallback: $rpcError');

        final balanceResponse = await _withRetry(
          () => _supabase.from('wallets').select('balance').eq('user_id', userId!).maybeSingle(),
          label: 'fetchWalletBalance',
        );
        if (balanceResponse == null) return PaymentResult.failure('Portefeuille THIX introuvable');

        final balance = _CheckoutServiceValidators.safeDouble((balanceResponse as Map)['balance']);
        if (balance < amount) return PaymentResult.failure('Solde THIX Money insuffisant (dispo: ${balance.toInt()})');

        await _withRetry(
          () => _supabase.rpc('deduct_wallet_balance', params: {'user_id': userId, 'amount': amount}),
          label: 'deductWalletBalance',
          maxRetries: 0,
        );

        final transactionId = 'THIX_${DateTime.now().millisecondsSinceEpoch}';
        await _updateOrderPayment(orderId, 'paid', transactionId);
        return PaymentResult.success(transactionId: transactionId, status: 'paid');
      }
    } catch (e) {
      return PaymentResult.failure(_CheckoutServiceValidators.friendlyError(e));
    }
  }

  Future<void> _updateOrderPayment(String orderId, String status, String? transactionId) async {
    try {
      await _withRetry(
        () => _supabase.from('orders').update({
          'payment_status': status,
          'transaction_id': transactionId,
          'paid_at': status == 'paid' ? DateTime.now().toIso8601String() : null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId),
        label: 'updateOrderPayment',
      );
    } catch (e) {
      debugPrint('[CheckoutService] ⚠️ Update order payment failed: $e');
    }
  }

  // ================================================================
  // ORDER DETAILS (avec ownership check)
  // ================================================================
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    if (!_CheckoutServiceValidators.isValidId(orderId)) return null;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (!_CheckoutServiceValidators.isValidId(currentUserId)) return null;

    try {
      final response = await _withRetry(
        () => _supabase
            .from('orders')
            .select('*, address:addresses(*), items:order_items(*), user:users(id, name, email, phone)')
            .eq('id', orderId)
            .maybeSingle(),
        label: 'getOrderDetails',
      );

      if (response == null) return null;
      final orderMap = Map<String, dynamic>.from(response as Map);

      // Ownership check : user OU owner du shop
      final orderUserId = orderMap['user_id']?.toString();
      final shopId = orderMap['shop_id']?.toString();

      bool isOwner = orderUserId == currentUserId;
      if (!isOwner && shopId != null && _CheckoutServiceValidators.isValidId(shopId)) {
        try {
          final shop = await _supabase.from('shops').select('owner_id').eq('id', shopId).maybeSingle();
          if (shop != null && (shop as Map)['owner_id']?.toString() == currentUserId) isOwner = true;
        } catch (_) {}
      }

      if (!isOwner) {
        debugPrint('[CheckoutService] ⚠️ Unauthorized access to order $orderId');
        return null;
      }

      return orderMap;
    } catch (e) {
      debugPrint('[CheckoutService] ❌ getOrderDetails error: $e');
      return null;
    }
  }

  // ================================================================
  // CANCEL ORDER (avec ownership + rollback stock)
  // ================================================================
  Future<bool> cancelOrder(String orderId) async {
    if (!_CheckoutServiceValidators.isValidId(orderId)) return false;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (!_CheckoutServiceValidators.isValidId(currentUserId)) return false;

    try {
      final order = await _withRetry(
        () => _supabase.from('orders').select('payment_status, status, user_id').eq('id', orderId).single(),
        label: 'fetchOrderForCancel',
      );
      final orderMap = Map<String, dynamic>.from(order as Map);

      if (orderMap['user_id']?.toString() != currentUserId) return false;
      if (orderMap['payment_status']?.toString() == 'paid') return false;
      if (orderMap['status']?.toString() == 'cancelled') return true;

      await _withRetry(
        () => _supabase.from('orders').update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId),
        label: 'updateOrderCancelled',
      );

      // Restaurer stock
      try {
        final items = await _supabase.from('order_items').select('product_id, quantity').eq('order_id', orderId);
        final rollbackMap = <String, int>{};
        for (final item in items as List) {
          final map = Map<String, dynamic>.from(item as Map);
          final pid = map['product_id']?.toString();
          final qty = _CheckoutServiceValidators.safeInt(map['quantity']);
          if (pid != null && qty > 0) rollbackMap[pid] = (rollbackMap[pid] ?? 0) + qty;
        }
        if (rollbackMap.isNotEmpty) await _rollbackStock(rollbackMap);
      } catch (e) {
        debugPrint('[CheckoutService] ⚠️ Stock restoration failed: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[CheckoutService] ❌ Cancel order error: $e');
      return false;
    }
  }

  // ================================================================
  // ORDER TRACKING
  // ================================================================
  Future<OrderTracking> trackOrder(String orderId) async {
    if (!_CheckoutServiceValidators.isValidId(orderId)) {
      return OrderTracking(orderId: orderId, currentStatus: 'unknown', history: const [], error: 'Identifiant invalide');
    }

    try {
      final response = await _withRetry(
        () => _supabase.from('order_tracking').select().eq('order_id', orderId).order('created_at', ascending: true),
        label: 'trackOrder',
      );

      final history = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final currentStatus = history.isNotEmpty
          ? _CheckoutServiceValidators.sanitize(history.last['status']?.toString(), maxLength: 30)
          : 'pending';

      return OrderTracking(
        orderId: orderId,
        currentStatus: currentStatus.isEmpty ? 'pending' : currentStatus,
        history: history,
      );
    } catch (e) {
      return OrderTracking(
        orderId: orderId,
        currentStatus: 'unknown',
        history: const [],
        error: _CheckoutServiceValidators.friendlyError(e),
      );
    }
  }
}

// ============================================================================
// MODÈLES
// ============================================================================
class CartItem {
  final String productId;
  final int quantity;
  final double price;
  final String productName;
  final String? imageUrl;
  final String? variant;
  final String? color;

  CartItem({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.productName,
    this.imageUrl,
    this.variant,
    this.color,
  });
}

class StockValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, int>? updatedStock;

  StockValidationResult({required this.isValid, this.errors = const [], this.updatedStock});

  factory StockValidationResult.fromJson(Map<String, dynamic> json) {
    return StockValidationResult(
      isValid: json['valid'] as bool? ?? false,
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
      updatedStock: json['updated_stock'] != null
          ? Map<String, int>.from((json['updated_stock'] as Map).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)))
          : null,
    );
  }
}

class OrderResult {
  final bool success;
  final String? orderId;
  final Map<String, dynamic>? orderData;
  final String? error;
  OrderResult({required this.success, this.orderId, this.orderData, this.error});
}

class PaymentResult {
  final bool success;
  final bool isPending;
  final String? transactionId;
  final String? paymentUrl;
  final String? status;
  final String? error;

  PaymentResult({
    required this.success,
    this.isPending = false,
    this.transactionId,
    this.paymentUrl,
    this.status,
    this.error,
  });

  factory PaymentResult.success({String? transactionId, String? status}) =>
      PaymentResult(success: true, isPending: false, transactionId: transactionId, status: status);

  factory PaymentResult.pending({String? transactionId, String? paymentUrl, String? status}) =>
      PaymentResult(success: true, isPending: true, transactionId: transactionId, paymentUrl: paymentUrl, status: status);

  factory PaymentResult.failure(String error) => PaymentResult(success: false, isPending: false, error: error);
}

class OrderTracking {
  final String orderId;
  final String currentStatus;
  final List<Map<String, dynamic>> history;
  final String? error;
  OrderTracking({required this.orderId, required this.currentStatus, required this.history, this.error});
}
