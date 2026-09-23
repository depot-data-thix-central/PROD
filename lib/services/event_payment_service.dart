// lib/services/event_payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/serdipay_transaction.dart';
import 'package:thix_id/services/serdipay_service.dart';

class EventPaymentService {
  final SupabaseClient _supabase;

  EventPaymentService(this._supabase);

  Future<Map<String, dynamic>> processPayment({
    required String bookingId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? phoneNumber,
    Map<String, String>? cardDetails, // ignoré, SerdiPay gère tout
  }) async {
    try {
      // ========== CASH (si supporté) ==========
      if (paymentMethod == 'cash') {
        debugPrint('→ Paiement Cash : validation locale');
        return {
          'success': true,
          'payment_status': 'pending_confirmation',
          'needs_waiting': false,
        };
      }

      // ========== THIX MONEY ==========
      if (paymentMethod == 'thix_money') {
        final ok = await _processThixMoney(bookingId, amount);
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
          type: SerdipayPaymentType.event,
          referenceId: bookingId,
          amount: amount,
          currency: normalizedCurrency,
          telecom: telecom,
          phoneNumber: phoneNumber ?? '',
        );

        debugPrint(
            '→ SerdiPay event result: success=${result.success}, status=${result.status}');

        if (result.success) {
          return {
            'success': true,
            'payment_status': result.status,
            'transaction_id': result.transactionId,
            'needs_waiting': result.needsWaiting,
            'data': result.data,
          };
        } else {
          return {
            'success': false,
            'payment_status': 'failed',
            'error': result.error ?? 'Erreur SerdiPay',
          };
        }
      } catch (e) {
        debugPrint('❌ SerdiPay event error: $e');
        return {
          'success': false,
          'payment_status': 'failed',
          'error': 'Erreur SerdiPay: $e',
        };
      }
    } catch (e) {
      debugPrint('❌ EventPaymentService error: $e');
      rethrow;
    }
  }

  /// Déduction du wallet THIX Money via RPC sécurisée
  Future<bool> _processThixMoney(String bookingId, double amount) async {
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
