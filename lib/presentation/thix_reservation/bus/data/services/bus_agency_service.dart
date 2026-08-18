// lib/presentation/thix_reservation/bus/data/services/bus_agency_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agency_model.dart';
import '../models/bus_trip_model.dart';
import '../models/booking_model.dart';

class BusAgencyService {
  final SupabaseClient _db = Supabase.instance.client;

  String get _uid => _db.auth.currentUser!.id;

  // ---------- Mon Agence (via owner_id = THIX ID) ----------
  Future<AgencyModel?> getMyAgency() async {
    final res = await _db.from('agencies').select().eq('owner_id', _uid).maybeSingle();
    if (res == null) return null;
    return AgencyModel.fromJson(res);
  }

  Future<AgencyModel> createAgency({
    required String name,
    required String countryCode,
    String? description,
  }) async {
    final slug = '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
    final res = await _db
        .from('agencies')
        .insert({
          'owner_id': _uid,
          'name': name,
          'slug': slug,
          'country_code': countryCode,
          'description': description,
          'status': 'pending', // En attente validation Super Admin
        })
        .select()
        .single();
    return AgencyModel.fromJson(res);
  }

  // ---------- Dashboard Stats isolées ----------
  Future<Map<String, dynamic>> getDashboardStats(String agencyId) async {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day).toIso8601String();

    final bookingsToday = await _db
        .from('bus_bookings')
        .select()
        .eq('agency_id', agencyId)
        .gte('created_at', start)
        .count(CountOption.exact);

    final revenueRes = await _db.rpc('agency_revenue_today', params: {'p_agency_id': agencyId});

    return {
      'bookings_today': bookingsToday.count,
      'revenue_today': revenueRes ?? 0,
    };
  }

  // ---------- Mes trajets (seulement mon agence) ----------
  Future<List<BusTripModel>> getMyTrips(String agencyId) async {
    final res = await _db
        .from('bus_trips')
        .select('*, agencies(*)')
        .eq('agency_id', agencyId)
        .order('departure_time', ascending: false);
    return (res as List).map((e) => BusTripModel.fromJson(e)).toList();
  }

  Future<BusTripModel> createTrip({
    required String agencyId,
    required String from,
    required String to,
    required String departureStation,
    required String arrivalStation,
    required DateTime departureTime,
    required DateTime arrivalTime,
    required int price,
    required int totalSeats,
    required String busType,
  }) async {
    final res = await _db
        .from('bus_trips')
        .insert({
          'agency_id': agencyId,
          'departure_city': from,
          'arrival_city': to,
          'departure_station': departureStation,
          'arrival_station': arrivalStation,
          'departure_time': departureTime.toIso8601String(),
          'arrival_time': arrivalTime.toIso8601String(),
          'price_fcfa': price,
          'total_seats': totalSeats,
          'available_seats': totalSeats,
          'bus_type': busType,
          'status': 'scheduled',
        })
        .select('*, agencies(*)')
        .single();
    return BusTripModel.fromJson(res);
  }

  // ---------- Réservations de mon agence uniquement ----------
  Future<List<BookingModel>> getAgencyBookings(String agencyId) async {
    final res = await _db
        .from('bus_bookings')
        .select('*, bus_trips(*)')
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  // ---------- Scan QR / Check-in ----------
  Future<BookingModel> validateTicketByQr(String agencyId, String qrCode) async {
    final res = await _db
        .from('bus_bookings')
        .select('*, bus_trips(*)')
        .eq('agency_id', agencyId)
        .eq('qr_code', qrCode)
        .single();

    final booking = BookingModel.fromJson(res);
    if (booking.status == 'confirmed') {
      await _db.from('bus_bookings').update({'status': 'completed'}).eq('id', booking.id);
    }
    return booking;
  }
}
