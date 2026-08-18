// lib/services/market_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketPaymentService {
  final SupabaseClient _supabase;

  MarketPaymentService(this._supabase);

  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? phoneNumber,
  }) async {
    try {
      // ========== CASH ==========
      if (paymentMethod == 'cash') {
        debugPrint('→ Paiement Cash : validation locale');
        return {
          'success': true,
          'payment_status': 'pending_delivery',
          'needs_waiting': false,
        };
      }

      // ========== THIX MONEY ==========
      if (paymentMethod == 'thix_money') {
        final ok = await _processThixMoney(orderId, amount);
        return {
          'success': ok,
          'payment_status': ok ? 'paid' : 'failed',
          'needs_waiting': false,
          if (!ok) 'error': 'Solde THIX Money insuffisant',
        };
      }

      // ========== MOBILE MONEY / CARD ==========
      // Normalisation de la méthode pour l'Edge Function
      final methodForGateway = _normalizePaymentMethod(paymentMethod);

      final response = await _supabase.functions.invoke(
        'process-payment',
        body: {
          'booking_id': orderId,
          'order_id': orderId,
          'amount': amount,
          'currency': currency.toUpperCase() == 'FC' ? 'CDF' : currency.toUpperCase(),
          'payment_method': methodForGateway,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
          'type': 'market',
        },
      );

      debugPrint('→ process-payment response status: ${response.status}');
      debugPrint('→ process-payment data: ${response.data}');

      if (response.status == 200 && response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'payment_status': 'awaiting_payment',
          'needs_waiting': true,
          'data': response.data,
        };
      }

      // Meilleure extraction de l'erreur
      final errorMsg = response.data?['error'] ?? 
                       response.data?['details']?['message'] ?? 
                       'Échec de l\'initiation du paiement';

      throw Exception(errorMsg);
    } catch (e) {
      debugPrint('❌ MarketPaymentService.initiatePayment error: $e');
      rethrow;
    }
  }

  String _normalizePaymentMethod(String method) {
    // On mappe les IDs UI vers ce que l'Edge Function attend
    switch (method) {
      case 'orange_money':
      case 'africell':
      case 'mtn':
      case 'mobile_money':
        return 'mobile_money';
      case 'card':
      case 'carte':
        return 'card';
      default:
        return method;
    }
  }

  Future<bool> _processThixMoney(String orderId, double amount) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final result = await _supabase.rpc('deduct_wallet_balance', params: {
        'user_id': userId,
        'amount': amount,
      });

      return result == true;
    } catch (e) {
      debugPrint('Erreur THIX Money: $e');
      return false;
    }
  }
}
