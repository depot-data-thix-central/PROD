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

      // ========== TOUS LES AUTRES (Mobile Money + Carte) → SerdiPay ==========
      try {
        final serdipay = SerdiPayService(_supabase);
        final telecom = _toSerdiPayTelecom(paymentMethod);
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

        debugPrint(
            '→ SerdiPay result: success=${result.success}, status=${result.status}');

        if (result.success) {
          return {
            'success': true,
            'payment_status': result.status,
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
    } catch (e) {
      debugPrint('❌ MarketPaymentService.initiatePayment error: $e');
      rethrow;
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

  /// Convertit la méthode de paiement UI vers le code telecom SerdiPay
  SerdipayTelecom _toSerdiPayTelecom(String method) {
    switch (method.toLowerCase()) {
      case 'airtel':
      case 'airtel_money':
        return SerdipayTelecom.airtel; // AM
      case 'orange_money':
      case 'orange':
        return SerdipayTelecom.orange; // OM
      case 'afrimoney':
      case 'afrimomo':
        return SerdipayTelecom.afrimoney; // AF
      case 'card':
      case 'carte':
        // Carte bancaire → on utilise MP comme fallback (SerdiPay gérera)
        return SerdipayTelecom.mpesa;
      case 'mpesa':
      default:
        return SerdipayTelecom.mpesa; // MP
    }
  }
}
