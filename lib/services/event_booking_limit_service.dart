// lib/services/event_booking_limit_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/event_booking_limit.dart';

class EventBookingLimitService {
  final SupabaseClient _supabase;

  EventBookingLimitService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  // Récupérer les limites pour un événement
  Future<EventBookingLimit?> getBookingLimit(String eventId) async {
    try {
      final response = await _supabase
          .from('event_booking_limits')
          .select('*')
          .eq('event_id', eventId)
          .maybeSingle();

      if (response == null) return null;
      return EventBookingLimit.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error getBookingLimit: $e');
      return null;
    }
  }

  // Vérifier si l'utilisateur peut réserver
  Future<Map<String, dynamic>> canUserBook(String eventId, int requestedQuantity) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      return {'allowed': false, 'reason': 'Non connecté'};
    }

    try {
      final limit = await getBookingLimit(eventId);
      if (limit == null) {
        return {'allowed': true, 'reason': null};
      }

      // Vérifier le nombre déjà réservé par l'utilisateur
      final userBookings = await _supabase
          .from('event_bookings')
          .select('ticket_quantity')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'confirmed');
      
      int alreadyBooked = 0;
      for (var booking in userBookings as List) {
        alreadyBooked += booking['ticket_quantity'] as int;
      }

      // Vérifier la limite par personne
      if (alreadyBooked + requestedQuantity > limit.maxPerPerson) {
        return {
          'allowed': false,
          'reason': 'Vous avez déjà réservé $alreadyBooked place(s). Maximum ${limit.maxPerPerson} par personne.',
          'remaining': limit.maxPerPerson - alreadyBooked,
        };
      }

      // Vérifier la limite par transaction
      if (requestedQuantity > limit.maxPerTransaction) {
        return {
          'allowed': false,
          'reason': 'Maximum ${limit.maxPerTransaction} places par réservation.',
          'maxPerTransaction': limit.maxPerTransaction,
        };
      }

      return {'allowed': true, 'reason': null};
    } catch (e) {
      debugPrint('❌ Error canUserBook: $e');
      return {'allowed': true, 'reason': null};
    }
  }

  // Enregistrer une tentative de réservation (anti-fraude)
  Future<void> recordBookingAttempt(String eventId, int quantity) async {
    final userId = currentUserId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('event_booking_attempts').insert({
        'event_id': eventId,
        'user_id': userId,
        'quantity': quantity,
        'attempted_at': DateTime.now().toIso8601String(),
        'ip_address': await _getClientIp(),
      });
    } catch (e) {
      debugPrint('❌ Error recordBookingAttempt: $e');
    }
  }

  // ✅ CORRIGÉ : Vérifier les tentatives suspectes (sans utiliser count)
  Future<bool> isSuspiciousActivity(String eventId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return false;

    try {
      // Compter les tentatives dans les dernières minutes
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      
      final response = await _supabase
          .from('event_booking_attempts')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .gte('attempted_at', fiveMinutesAgo.toIso8601String());
      
      // ✅ CORRECTION : Compter manuellement en Dart
      final count = (response as List).length;
      return count > 10;
    } catch (e) {
      debugPrint('❌ Error isSuspiciousActivity: $e');
      return false;
    }
  }

  Future<String> _getClientIp() async {
    // TODO: Implémenter récupération IP
    return 'unknown';
  }
}
