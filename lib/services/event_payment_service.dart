// lib/services/event_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventPaymentService {
  final SupabaseClient _supabase;
  EventPaymentService(this._supabase);

  Future<bool> processPayment({
    required String bookingId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? phoneNumber,
    Map<String, String>? cardDetails,
  }) async {
    try {
      // Appel de la Supabase Edge Function sécurisée
      final response = await _supabase.functions.invoke(
        'process-payment',
        body: {
          'booking_id': bookingId,
          'amount': amount,
          'currency': currency,
          'payment_method': paymentMethod,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (cardDetails != null) 'card_details': cardDetails,
        },
      );

      if (response.status == 200 && response.data != null && response.data['success'] == true) {
        return true;
      } else {
        final errorMessage = response.data?['error'] ?? 'Erreur inconnue lors du paiement';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Erreur Edge Function Paiement : $e');
      rethrow;
    }
  }
}
