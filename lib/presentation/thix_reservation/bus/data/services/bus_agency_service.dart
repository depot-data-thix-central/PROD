// lib/presentation/thix_reservation/bus/data/services/bus_agency_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agency_model.dart';
import '../models/bus_trip_model.dart';
import '../models/booking_model.dart';

class BusAgencyService {
  final SupabaseClient _db = Supabase.instance.client;

  static const String table = 'bus_agencies';

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

    final row = await _db
        .from(table)
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return AgencyModel.fromJson(row);
  }

  String _makeSlug(String name) {
    final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = stamp.length > 8 ? stamp.substring(stamp.length - 8) : stamp;
    return '$cleaned-$tail';
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
    final payload = <String, dynamic>{
      'owner_id': _uid,
      'name': cleanName,
      'description': description?.trim(),
      'status': autoApprove ? 'approved' : 'pending',
      'country': countryCode == 'CD' ? 'RDC' : countryCode,
    };

    try {
      payload['slug'] = _makeSlug(cleanName);
      payload['country_code'] = countryCode;
    } catch (_) {}

    final res = await _db.from(table).insert(payload).select().single();
    return AgencyModel.fromJson(res);
  }

  Future<Map<String, dynamic>> getDashboardStats(String agencyId) async {
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day).toIso8601String();
      final bookingsToday = await _db
          .from('bus_bookings')
          .select()
          .eq('agency_id', agencyId)
          .gte('created_at', start)
          .count(CountOption.exact);
      return {
        'bookings_today': bookingsToday.count,
        'revenue_today': 0,
      };
    } catch (_) {
      return {'bookings_today': 0, 'revenue_today': 0};
    }
  }

  Future<List<BusTripModel>> getMyTrips(String agencyId) async {
    try {
      final res = await _db
          .from('bus_trips')
          .select()
          .eq('agency_id', agencyId)
          .order('departure_time', ascending: false);
      return (res as List).map((e) => BusTripModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
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
        .select()
        .single();
    return BusTripModel.fromJson(res);
  }

  Future<List<BookingModel>> getAgencyBookings(String agencyId) async {
    try {
      final res = await _db
          .from('bus_bookings')
          .select('*, bus_trips(*)')
          .eq('agency_id', agencyId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => BookingModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
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
