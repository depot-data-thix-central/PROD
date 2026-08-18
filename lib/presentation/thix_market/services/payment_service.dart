import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // Stripe - Créer un Payment Intent (via Edge Function)
  // ============================================================
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String orderId,
  }) async {
    try {
      final response = await _supabase.functions.invoke('create-payment-intent', body: {
        'amount': amount,
        'currency': currency,
        'order_id': orderId,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw PaymentException('Failed to create payment intent: $e');
    }
  }

  // ============================================================
  // Stripe - Confirmer un paiement par carte (via Edge Function)
  // ============================================================
  Future<PaymentResult> processCardPayment({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      final response = await _supabase.functions.invoke('confirm-payment', body: {
        'payment_intent_id': paymentIntentId,
        'payment_method_id': paymentMethodId,
      });
      return PaymentResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return PaymentResult.failure('Payment failed: $e');
    }
  }

  // ============================================================
  // Mobile Money (Orange Money / MTN) - via Edge Function
  // ============================================================
  Future<PaymentResult> processMobileMoney({
    required String phoneNumber,
    required double amount,
    required String provider, // 'orange' or 'mtn'
    required String orderId,
  }) async {
    try {
      final response = await _supabase.functions.invoke('mobile-money-payment', body: {
        'phone_number': phoneNumber,
        'amount': amount,
        'provider': provider,
        'order_id': orderId,
      });
      return PaymentResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return PaymentResult.failure('Mobile money payment failed: $e');
    }
  }

  // ============================================================
  // Portefeuille THIX Money (via RPC)
  // ============================================================
  Future<PaymentResult> processThixMoneyPayment({
    required String userId,
    required double amount,
    required String orderId,
  }) async {
    try {
      // Vérifier le solde
      final balance = await getThixMoneyBalance(userId);
      if (balance < amount) {
        return PaymentResult.failure('Insufficient THIX Money balance');
      }

      final response = await _supabase.rpc('process_wallet_payment', params: {
        'user_id': userId,
        'amount': amount,
        'order_id': orderId,
      });
      return PaymentResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return PaymentResult.failure('Wallet payment failed: $e');
    }
  }

  // ============================================================
  // Solde THIX Money
  // ============================================================
  Future<double> getThixMoneyBalance(String userId) async {
    try {
      final response = await _supabase
          .from('wallet')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      return (response?['balance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // Recharger le portefeuille THIX Money (via Edge Function)
  // ============================================================
  Future<PaymentResult> topUpThixMoney({
    required String userId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final response = await _supabase.functions.invoke('top-up-wallet', body: {
        'user_id': userId,
        'amount': amount,
        'payment_method': paymentMethod,
      });
      return PaymentResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return PaymentResult.failure('Top up failed: $e');
    }
  }

  // ============================================================
  // Cartes sauvegardées
  // ============================================================
  Future<List<SavedCard>> getSavedCards(String userId) async {
    try {
      final response = await _supabase
          .from('saved_cards')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false);
      return (response as List)
          .map((c) => SavedCard.fromJson(c))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCard({
    required String userId,
    required String paymentMethodId,
    required String last4,
    required String brand,
  }) async {
    try {
      await _supabase.from('saved_cards').insert({
        'user_id': userId,
        'payment_method_id': paymentMethodId,
        'last4': last4,
        'brand': brand,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> deleteSavedCard(String cardId) async {
    try {
      await _supabase.from('saved_cards').delete().eq('id', cardId);
    } catch (e) {
      // Silently fail
    }
  }

  // ============================================================
  // Historique des transactions
  // ============================================================
  Future<List<Transaction>> getTransactionHistory(String userId, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((t) => Transaction.fromJson(t))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // Remboursement (via Edge Function)
  // ============================================================
  Future<PaymentResult> refundPayment({
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    try {
      final response = await _supabase.functions.invoke('refund-payment', body: {
        'transaction_id': transactionId,
        'amount': amount,
        'reason': reason,
      });
      return PaymentResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return PaymentResult.failure('Refund failed: $e');
    }
  }
}

// ============================================================
// Modèles
// ============================================================

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? status;
  final String? error;

  PaymentResult({required this.success, this.transactionId, this.status, this.error});

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] as bool,
      transactionId: json['transaction_id'] as String?,
      status: json['status'] as String?,
      error: json['error'] as String?,
    );
  }

  factory PaymentResult.failure(String error) {
    return PaymentResult(success: false, error: error);
  }
}

class SavedCard {
  final String id;
  final String last4;
  final String brand;
  final bool isDefault;

  SavedCard({required this.id, required this.last4, required this.brand, this.isDefault = false});

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] as String,
      last4: json['last4'] as String,
      brand: json['brand'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final String status;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
}
