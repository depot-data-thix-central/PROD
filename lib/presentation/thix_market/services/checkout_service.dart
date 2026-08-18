import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Vérifier le stock avant commande (RPC atomique)
  Future<StockValidationResult> validateStock(List<CartItem> items) async {
    try {
      final List<Map<String, dynamic>> productIds = items
          .map((e) => {'id': e.productId, 'quantity': e.quantity})
          .toList();

      final response = await _supabase.rpc('validate_stock', params: {
        'items': productIds,
      });

      return StockValidationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      // Fallback local si la RPC n'existe pas encore
      return await _validateStockLocally(items);
    }
  }

  // Fallback : vérification locale du stock
  Future<StockValidationResult> _validateStockLocally(
      List<CartItem> items) async {
    final List<String> errors = [];

    for (final item in items) {
      try {
        final product = await _supabase
            .from('products')
            .select('stock, title')
            .eq('id', item.productId)
            .maybeSingle();

        if (product == null) {
          errors.add('Produit introuvable (${item.productId})');
          continue;
        }

        final stock = (product['stock'] as num?)?.toInt() ?? 0;
        final title = product['title']?.toString() ?? item.productName;

        if (stock <= 0) {
          errors.add('Rupture de stock : $title');
        } else if (item.quantity > stock) {
          errors.add('Stock insuffisant pour $title (dispo: $stock)');
        }
      } catch (e) {
        errors.add('Erreur stock pour ${item.productName}');
      }
    }

    return StockValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  // Créer une commande (avec validation stock obligatoire)
  Future<OrderResult> createOrder({
    required String userId,
    required String addressId,
    required String shippingMethodId,
    required double shippingCost,
    required double total,
    required List<CartItem> items,
    required String paymentMethodId,
  }) async {
    try {
      // 1. VALIDATION STOCK OBLIGATOIRE
      final stockCheck = await validateStock(items);
      if (!stockCheck.isValid) {
        return OrderResult(
          success: false,
          error: stockCheck.errors.join('\n'),
        );
      }

      // 2. Créer la commande
      final orderData = {
        'user_id': userId,
        'address_id': addressId,
        'shipping_method_id': shippingMethodId,
        'shipping_cost': shippingCost,
        'total': total,
        'payment_method': paymentMethodId,
        'status': 'pending',
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final orderResponse = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'];

      // 3. Ajouter les articles + décrémenter le stock
      for (var item in items) {
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'price': item.price,
          'product_name': item.productName,
          'product_image': item.imageUrl,
          'variant': item.variant,
          'color': item.color,
        });

        // Déduire le stock (atomique)
        try {
          final ok = await _supabase.rpc('decrement_product_stock', params: {
            'p_product_id': item.productId,
            'p_quantity': item.quantity,
          });

          if (ok != true) {
            // Rollback partiel : on annule la commande
            await _supabase.from('orders').delete().eq('id', orderId);
            return OrderResult(
              success: false,
              error: 'Stock insuffisant pour ${item.productName}',
            );
          }
        } catch (_) {
          // Fallback manuel si RPC absente
          await _supabase.rpc('exec', params: {}).catchError((_) => null);
          await _supabase
              .from('products')
              .update({
                'stock': item.quantity, // sera corrigé par une vraie RPC
              })
              .eq('id', item.productId)
              .gte('stock', item.quantity);
        }
      }

      // 4. Vider le panier
      await _supabase.from('cart').delete().eq('user_id', userId);

      return OrderResult(
        success: true,
        orderId: orderId,
        orderData: orderResponse,
      );
    } catch (e) {
      return OrderResult(
        success: false,
        error: 'Erreur lors de la création: ${e.toString()}',
      );
    }
  }

  // Traiter le paiement selon méthode choisie
  Future<PaymentResult> processPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      switch (paymentMethod) {
        case 'card':
          return await _processCardPayment(orderId, amount, paymentDetails);
        case 'mobile_money':
        case 'orange_money':
        case 'africell':
          return await _processMobileMoney(orderId, amount, paymentDetails);
        case 'thix_money':
          return await _processThixMoney(orderId, amount);
        case 'cash':
          await _updateOrderPayment(orderId, 'pending_delivery', null);
          return PaymentResult.success(status: 'pending_delivery');
        default:
          return PaymentResult.failure('Méthode de paiement inconnue');
      }
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  Future<PaymentResult> _processCardPayment(
    String orderId,
    double amount,
    Map<String, dynamic>? details,
  ) async {
    try {
      final response =
          await _supabase.functions.invoke('process-card-payment', body: {
        'order_id': orderId,
        'amount': amount,
        'currency': 'XOF',
        'payment_method_id': details?['payment_method_id'],
      });

      if (response.data['success'] == true) {
        await _updateOrderPayment(
            orderId, 'paid', response.data['transaction_id']);
        return PaymentResult.success(
          transactionId: response.data['transaction_id'],
          status: 'paid',
        );
      } else {
        return PaymentResult.failure(
            response.data['error'] ?? 'Paiement échoué');
      }
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  Future<PaymentResult> _processMobileMoney(
    String orderId,
    double amount,
    Map<String, dynamic>? details,
  ) async {
    try {
      final response =
          await _supabase.functions.invoke('process-payment', body: {
        'order_id': orderId,
        'amount': amount,
        'phone_number': details?['phone'],
        'payment_method': 'mobile_money',
        'type': 'market',
        'currency': 'CDF',
      });

      if (response.data['success'] == true) {
        await _updateOrderPayment(
            orderId, 'awaiting_payment', response.data['ref_transa']);
        return PaymentResult.pending(
          transactionId: response.data['ref_transa'],
          status: 'awaiting_payment',
        );
      } else {
        return PaymentResult.failure(
            response.data['error'] ?? 'Paiement échoué');
      }
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  Future<PaymentResult> _processThixMoney(String orderId, double amount) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return PaymentResult.failure('Utilisateur non connecté');
    }

    try {
      final balanceResponse = await _supabase
          .from('wallet')
          .select('balance')
          .eq('user_id', userId)
          .single();
      final balance = (balanceResponse['balance'] as num).toDouble();

      if (balance < amount) {
        return PaymentResult.failure('Solde THIX Money insuffisant');
      }

      await _supabase.rpc('deduct_wallet_balance', params: {
        'user_id': userId,
        'amount': amount,
      });

      await _updateOrderPayment(orderId, 'paid', null);
      return PaymentResult.success(
        transactionId: 'THIX_${DateTime.now().millisecondsSinceEpoch}',
        status: 'paid',
      );
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  Future<void> _updateOrderPayment(
      String orderId, String status, String? transactionId) async {
    await _supabase.from('orders').update({
      'payment_status': status,
      'transaction_id': transactionId,
      'paid_at': status == 'paid' ? DateTime.now().toIso8601String() : null,
    }).eq('id', orderId);
  }

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            address:addresses(*),
            items:order_items(*),
            user:users(name, email, phone)
          ''')
          .eq('id', orderId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      final order = await _supabase
          .from('orders')
          .select('payment_status, status')
          .eq('id', orderId)
          .single();

      if (order['payment_status'] == 'paid') return false;

      await _supabase.from('orders').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toISOString(),
      }).eq('id', orderId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<OrderTracking> trackOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('order_tracking')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      final history = List<Map<String, dynamic>>.from(response);
      final currentStatus =
          history.isNotEmpty ? history.last['status'] : 'pending';

      return OrderTracking(
        orderId: orderId,
        currentStatus: currentStatus,
        history: history,
      );
    } catch (e) {
      return OrderTracking(
        orderId: orderId,
        currentStatus: 'unknown',
        history: [],
        error: e.toString(),
      );
    }
  }
}

// ==================== MODÈLES ====================

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

  StockValidationResult({
    required this.isValid,
    this.errors = const [],
    this.updatedStock,
  });

  factory StockValidationResult.fromJson(Map<String, dynamic> json) {
    return StockValidationResult(
      isValid: json['valid'] as bool? ?? false,
      errors: List<String>.from(json['errors'] ?? []),
      updatedStock: json['updated_stock'] != null
          ? Map<String, int>.from(json['updated_stock'])
          : null,
    );
  }
}

class OrderResult {
  final bool success;
  final String? orderId;
  final Map<String, dynamic>? orderData;
  final String? error;

  OrderResult({
    required this.success,
    this.orderId,
    this.orderData,
    this.error,
  });
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

  factory PaymentResult.success({String? transactionId, String? status}) {
    return PaymentResult(
      success: true,
      isPending: false,
      transactionId: transactionId,
      status: status,
    );
  }

  factory PaymentResult.pending({
    String? transactionId,
    String? paymentUrl,
    String? status,
  }) {
    return PaymentResult(
      success: true,
      isPending: true,
      transactionId: transactionId,
      paymentUrl: paymentUrl,
      status: status,
    );
  }

  factory PaymentResult.failure(String error) {
    return PaymentResult(
      success: false,
      isPending: false,
      error: error,
    );
  }
}

class OrderTracking {
  final String orderId;
  final String currentStatus;
  final List<Map<String, dynamic>> history;
  final String? error;

  OrderTracking({
    required this.orderId,
    required this.currentStatus,
    required this.history,
    this.error,
  });
}
