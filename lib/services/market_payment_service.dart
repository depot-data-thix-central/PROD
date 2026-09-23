// lib/services/market_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/serdipay_transaction.dart';
import 'package:thix_id/services/serdipay_service.dart';

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

      // ========== MOBILE MONEY (SerdiPay : M-Pesa, Airtel, Orange, Afrimoney) ==========
      if (_isSerdipayMethod(paymentMethod)) {
        try {
          final serdipay = SerdiPayService(_supabase);
          final telecom = SerdipayTelecom.fromPaymentMethod(paymentMethod);
          final normalizedCurrency =
              currency.toUpperCase() == 'FC' ? 'CDF' : currency.toUpperCase();

          final result = await serdipay.initiate(
            type: SerdipayPaymentType.market,
            referenceId: orderId,
            amount: amount,
            currency: normalizedCurrency,
            telecom: telecom,
            phoneNumber: phoneNumber ?? '',
          );

          debugPrint('→ serdipay-pay result: success=${result.success}, status=${result.status}');

          if (result.success) {
            return {
              'success': true,
              'payment_status': result.status, // 'awaiting_payment' | 'paid'
              'needs_waiting': result.needsWaiting,
              'transaction_id': result.transactionId,
              'serdi_session_id': result.serdiSessionId,
              'data': result.data,
            };
          } else {
            return {
              'success': false,
              'payment_status': 'failed',
              'needs_waiting': false,
              'error': result.error ?? 'Échec de l\'initiation du paiement SerdiPay',
            };
          }
        } catch (e) {
          debugPrint('❌ SerdiPay market error: $e');
          return {
            'success': false,
            'payment_status': 'failed',
            'needs_waiting': false,
            'error': 'Erreur SerdiPay: $e',
          };
        }
      }

      // ========== CARD (WonyaSoft existant) ==========
      // Normalisation pour l'Edge Function WonyaSoft
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

      debugPrint('→ process-payment (WonyaSoft) response status: ${response.status}');
      debugPrint('→ process-payment data: ${response.data}');

      if (response.status == 200 &&
          response.data != null &&
          response.data['success'] == true) {
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

  /// Normalise la méthode de paiement pour WonyaSoft (cartes uniquement)
  String _normalizePaymentMethod(String method) {
    switch (method) {
      case 'card':
      case 'carte':
        return 'card';
      default:
        return method;
    }
  }

  /// Déduction du wallet THIX Money via RPC sécurisée
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

  /// Vérifie si la méthode de paiement est supportée par SerdiPay (Mobile Money RDC)
  /// Télécoms supportés selon la documentation SerdiPay :
  /// - AM : Airtel Money
  /// - OM : Orange Money
  /// - MP : Vodacom M-Pesa
  /// - AF : Afrimoney
  bool _isSerdipayMethod(String method) {
    const serdiMethods = {
      'mpesa',
      'airtel',
      'airtel_money',
      'orange_money',
      'orange',
      'afrimoney',
      'afrimomo',
      'mobile_money', // routé par défaut vers M-Pesa
    };
    return serdiMethods.contains(method.toLowerCase());
  }
}
