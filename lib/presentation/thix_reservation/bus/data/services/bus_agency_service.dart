// lib/presentation/thix_reservation/bus/data/services/bus_agency_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agency_model.dart';
import '../models/bus_trip_model.dart';
import '../models/booking_model.dart';

class BusAgencyService {
  final SupabaseClient _db = Supabase.instance.client;

  static const String table = 'agencies';

  String get _uid {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }
    return user.id;
  }

  Future<AgencyModel?> getMyAgency() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;

    final byOwner = await _db
        .from(table)
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();
    if (byOwner != null) return AgencyModel.fromJson(byOwner);

    try {
      final byUser = await _db
          .from(table)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (byUser != null) return AgencyModel.fromJson(byUser);
    } catch (_) {}

    return null;
  }

  Future<AgencyModel> createAgency({
    required String name,
    required String countryCode,
    String? description,
    bool autoApprove = true,
  }) async {
    final existing = await getMyAgency();
    if (existing != null) return existing;

    final cleanName = name.trim();
    final slug =
        '\( {cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}- \){DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final payload = <String, dynamic>{
      'owner_id': _uid,
      'name': cleanName,
      'slug': slug,
      'country_code': countryCode,
      'description': description?.trim(),
      'status': autoApprove ? 'active' : 'pending',
      'is_verified': autoApprove,
    };

    try {
      final res = await _db.from(table).insert(payload).select().single();
      return AgencyModel.fromJson(res);
    } catch (e) {
      payload['user_id'] = _uid;
      final res = await _db.from(table).insert(payload).select().single();
      return AgencyModel.fromJson(res);
    }
  }

  Future<Map<String, dynamic>> getDashboardStats(String agencyId) async {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day)
        .toIso8601String();

    try {
      final bookingsToday = await _db
          .from('bus_bookings')
          .select()
          .eq('agency_id', agencyId)
          .gte('created_at', start)
          .count(CountOption.exact);

      dynamic revenueRes;
      try {
        revenueRes = await _db.rpc('agency_revenue_today', params: {'p_agency_id': agencyId});
      } catch (_) {
        revenueRes = 0;
      }

      return {
        'bookings_today': bookingsToday.count,
        'revenue_today': revenueRes ?? 0,
      };
    } catch (_) {
      return {'bookings_today': 0, 'revenue_today': 0};
    }
  }

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

  Future<List<BookingModel>> getAgencyBookings(String agencyId) async {
    final res = await _db
        .from('bus_bookings')
        .select('*, bus_trips(*)')
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => BookingModel.fromJson(e)).toList();
  }

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
