
// lib/services/event_seat_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/event_seat.dart';

class EventSeatService {
  final SupabaseClient _supabase;

  EventSeatService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  Future<List<EventSeat>> getSeatMap(String eventId) async {
    try {
      final response = await _supabase
          .from('event_seats')
          .select('*')
          .eq('event_id', eventId)
          .order('row', ascending: true)
          .order('number', ascending: true);

      final seats = <EventSeat>[];
      for (var e in response as List) {
        seats.add(EventSeat.fromJson(e));
      }
      return seats;
    } catch (e) {
      debugPrint('❌ Error getSeatMap: $e');
      return [];
    }
  }

  Future<bool> reserveSeats(String eventId, List<String> seatIds) async {
    final userId = currentUserId;
    if (userId.isEmpty) return false;

    try {
      final reservedUntil = DateTime.now().add(const Duration(minutes: 15));
      
      await _supabase
          .from('event_seats')
          .update({
            'status': 'reserved',
            'reserved_by': userId,
            'reserved_until': reservedUntil.toIso8601String(),
          })
          .inFilter('id', seatIds);

      Timer(const Duration(minutes: 15), () async {
        await _releaseExpiredReservations(eventId);
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error reserveSeats: $e');
      return false;
    }
  }

  Future<bool> releaseSeats(String eventId, List<String> seatIds) async {
    try {
      await _supabase
          .from('event_seats')
          .update({
            'status': 'available',
            'reserved_by': null,
            'reserved_until': null,
          })
          .inFilter('id', seatIds);
      return true;
    } catch (e) {
      debugPrint('❌ Error releaseSeats: $e');
      return false;
    }
  }

  Future<bool> confirmSeats(String eventId, List<String> seatIds, int bookingId) async {
    try {
      await _supabase
          .from('event_seats')
          .update({
            'status': 'sold',
            'booking_id': bookingId,
            'reserved_by': null,
            'reserved_until': null,
          })
          .inFilter('id', seatIds);
      return true;
    } catch (e) {
      debugPrint('❌ Error confirmSeats: $e');
      return false;
    }
  }

  Future<void> _releaseExpiredReservations(String eventId) async {
    try {
      await _supabase
          .from('event_seats')
          .update({
            'status': 'available',
            'reserved_by': null,
            'reserved_until': null,
          })
          .eq('event_id', eventId)
          .eq('status', 'reserved')
          .lt('reserved_until', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Error releaseExpiredReservations: $e');
    }
  }

  // ✅ CORRIGÉ: getAvailableSeatsCount sans utiliser count
  Future<int> getAvailableSeatsCount(String eventId) async {
    try {
      final response = await _supabase
          .from('event_seats')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'available');
      
      // Compter manuellement le nombre d'éléments
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getAvailableSeatsCount: $e');
      return 0;
    }
  }

  Future<List<EventSeat>> getSeatsByIds(List<String> seatIds) async {
    try {
      if (seatIds.isEmpty) return [];
      
      final response = await _supabase
          .from('event_seats')
          .select('*')
          .inFilter('id', seatIds);
      
      final seats = <EventSeat>[];
      for (var e in response as List) {
        seats.add(EventSeat.fromJson(e));
      }
      return seats;
    } catch (e) {
      debugPrint('❌ Error getSeatsByIds: $e');
      return [];
    }
  }

  Future<bool> areSeatsAvailable(String eventId, List<String> seatIds) async {
    try {
      final response = await _supabase
          .from('event_seats')
          .select('id, status')
          .eq('event_id', eventId)
          .inFilter('id', seatIds);
      
      for (var seat in response as List) {
        if (seat['status'] != 'available') {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error areSeatsAvailable: $e');
      return false;
    }
  }

  Future<double> getTotalPriceForSeats(List<String> seatIds) async {
    try {
      double total = 0;
      final seats = await getSeatsByIds(seatIds);
      for (var seat in seats) {
        total += seat.price ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('❌ Error getTotalPriceForSeats: $e');
      return 0;
    }
  }

  Future<void> createSeatMap(String eventId, int rows, int seatsPerRow, double basePrice) async {
    try {
      final seats = <Map<String, dynamic>>[];
      final rowsLetters = List.generate(rows, (i) => String.fromCharCode(65 + i));
      
      for (var row in rowsLetters) {
        for (var i = 1; i <= seatsPerRow; i++) {
          seats.add({
            'event_id': eventId,
            'row': row,
            'number': i,
            'category': _getCategory(row, i),
            'price': basePrice,
            'status': 'available',
          });
        }
      }
      
      await _supabase.from('event_seats').insert(seats);
    } catch (e) {
      debugPrint('❌ Error createSeatMap: $e');
    }
  }

  Future<void> updateSeatPrices(String eventId, Map<String, double> pricesByCategory) async {
    try {
      for (var entry in pricesByCategory.entries) {
        await _supabase
            .from('event_seats')
            .update({'price': entry.value})
            .eq('event_id', eventId)
            .eq('category', entry.key);
      }
    } catch (e) {
      debugPrint('❌ Error updateSeatPrices: $e');
    }
  }

  String _getCategory(String row, int number) {
    final rowCode = row.codeUnitAt(0);
    
    if (rowCode >= 65 && rowCode <= 67) return 'vip';      // A, B, C
    if (rowCode >= 68 && rowCode <= 70) return 'gold';     // D, E, F
    if (rowCode >= 71 && rowCode <= 74) return 'family';   // G, H, I, J
    return 'standard';
  }
}
