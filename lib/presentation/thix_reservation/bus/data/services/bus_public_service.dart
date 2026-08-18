// lib/presentation/thix_reservation/bus/data/services/bus_public_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_trip_model.dart';
import '../models/city_model.dart';
import '../models/seat_model.dart';
import '../models/booking_model.dart';

class BusPublicService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------- Villes pour autocomplete ----------
  Future<List<CityModel>> getCities() async {
    final res = await _db
        .from('cities')
        .select()
        .eq('is_active', true)
        .order('name');
    return (res as List).map((e) => CityModel.fromJson(e)).toList();
  }

  // ---------- Recherche SaaS : cherche dans TOUTES les agences ----------
  Future<List<BusTripModel>> searchTrips({
    required String from,
    required String to,
    required DateTime date,
    int passengers = 1,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final res = await _db
        .from('bus_trips')
        .select('*, agencies!inner(*)')
        .eq('departure_city', from)
        .eq('arrival_city', to)
        .eq('status', 'scheduled')
        .gte('departure_time', start.toIso8601String())
        .lt('departure_time', end.toIso8601String())
        .gte('available_seats', passengers)
        .eq('agencies.status', 'active') // SaaS: seulement agences actives
        .order('departure_time', ascending: true);

    return (res as List).map((e) => BusTripModel.fromJson(e)).toList();
  }

  // ---------- Routes populaires : prix le moins cher par route ----------
  Future<List<Map<String, dynamic>>> getPopularRoutes() async {
    // Vue SQL à créer côté Supabase: popular_routes_view
    final res = await _db.from('popular_routes_view').select().limit(8);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ---------- Sièges en temps réel ----------
  Future<List<SeatModel>> getSeatsForTrip(String tripId) async {
    final res = await _db
        .from('bus_seats')
        .select()
        .eq('trip_id', tripId)
        .order('seat_number');
    return (res as List).map((e) => SeatModel.fromJson(e)).toList();
  }

  // Stream Realtime pour le plan de sièges
  Stream<List<SeatModel>> watchSeats(String tripId) {
    return _db
        .from('bus_seats')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('seat_number')
        .map((data) => data.map((e) => SeatModel.fromJson(e)).toList());
  }

  // ---------- Lock siège 10 min (lié au THIX ID) ----------
  Future<void> lockSeats({
    required String tripId,
    required List<String> seatNumbers,
  }) async {
    final userId = _db.auth.currentUser!.id;
    final until = DateTime.now().add(const Duration(minutes: 10)).toIso8601String();

    for (final seatNum in seatNumbers) {
      await _db.from('bus_seats').update({
        'status': 'locked',
        'locked_by': userId,
        'locked_until': until,
      }).match({
        'trip_id': tripId,
        'seat_number': seatNum,
        'status': 'available',
      });
    }
  }

  Future<void> unlockSeats({
    required String tripId,
    required List<String> seatNumbers,
  }) async {
    final userId = _db.auth.currentUser!.id;
    await _db
        .from('bus_seats')
        .update({'status': 'available', 'locked_by': null, 'locked_until': null})
        .eq('trip_id', tripId)
        .inFilter('seat_number', seatNumbers)
        .eq('locked_by', userId);
  }

  // ---------- Création Réservation ----------
  Future<BookingModel> createBooking({
    required String agencyId,
    required String tripId,
    required List<String> seats,
    required int totalPrice,
  }) async {
    final userId = _db.auth.currentUser!.id;
    final qr = 'THX-${agencyId.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final res = await _db
        .from('bus_bookings')
        .insert({
          'user_id': userId,
          'agency_id': agencyId,
          'trip_id': tripId,
          'seats': seats,
          'total_price_fcfa': totalPrice,
          'status': 'pending_payment',
          'qr_code': qr,
        })
        .select('*, bus_trips(*, agencies(*))')
        .single();

    return BookingModel.fromJson(res);
  }

  // ---------- Mes réservations (client lié à son THIX ID) ----------
  Future<List<BookingModel>> getMyBookings() async {
    final userId = _db.auth.currentUser!.id;
    final res = await _db
        .from('bus_bookings')
        .select('*, bus_trips(*, agencies(*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => BookingModel.fromJson(e)).toList();
  }
}
