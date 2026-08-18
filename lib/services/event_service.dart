import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/event_booking.dart';
import '../models/event_model.dart';

class EventService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();
  EventService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id?? '';

  // ============ HELPERS ============
  Future<Set<String>> _likedIds(List<String> ids) async {
    final uid = currentUserId;
    if (uid.isEmpty || ids.isEmpty) return {};
    try {
      final res = await _supabase.from('event_favorites').select('event_id').eq('user_id', uid).inFilter('event_id', ids);
      return (res as List).map((e) => e['event_id'].toString()).toSet();
    } catch (_) { return {}; }
  }

  Future<T> _retry<T>(Future<T> Function() fn, {int max = 3}) async {
    int attempt = 0;
    while (true) {
      try { return await fn(); } catch (e) {
        attempt++; if (attempt >= max) rethrow;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  // ============ LECTURE SCALABLE ============
  Future<List<Event>> getEvents({
    String? category,
    String dateFilter = 'all',
    String? city,
    int page = 0,
    int limit = 20,
    String? search,
  }) async {
    try {
      final now = DateTime.now();
      var query = _supabase.from('events').select('*').eq('status', 'upcoming').gte('start_date', now.subtract(const Duration(hours: 1)).toIso8601String());

      if (category!= null && category!= 'all' && category!= 'featured') {
        query = query.eq('category', category);
      }
      if (city!= null && city!= 'all') {
        query = query.eq('city', city);
      }

      // date filter server-side
      if (dateFilter == 'today') {
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        query = query.gte('start_date', start.toIso8601String()).lt('start_date', end.toIso8601String());
      } else if (dateFilter == 'week') {
        query = query.lte('start_date', now.add(const Duration(days: 7)).toIso8601String());
      } else if (dateFilter == 'month') {
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        query = query.gte('start_date', start.toIso8601String()).lt('start_date', end.toIso8601String());
      }

      if (search!= null && search.trim().isNotEmpty) {
        final q = search.trim();
        query = query.or('title.ilike.%$q%,description.ilike.%$q%,location.ilike.%$q%');
      }

      final res = await query.order('start_date', ascending: true).range(page * limit, page * limit + limit - 1) as List<dynamic>;

      if (res.isEmpty) return [];
      final ids = res.map((e) => (e['id']?? '').toString()).toList();
      final likedSet = await _likedIds(ids);

      return res.map((e) {
        final map = Map<String, dynamic>.from((e as Map).cast<String, dynamic>());
        final id = map['id'].toString();
        return Event.fromJson({...map, 'is_liked': likedSet.contains(id), 'is_saved': likedSet.contains(id)});
      }).toList();
    } catch (e) {
      debugPrint('getEvents error: $e');
      return [];
    }
  }

  Future<List<Event>> getPopularEvents({int limit = 10}) async {
    try {
      final res = await _supabase.from('events').select('*').eq('status', 'upcoming').gte('start_date', DateTime.now().toIso8601String()).order('views_count', ascending: false).limit(limit) as List<dynamic>;
      final ids = res.map((e) => (e['id']?? '').toString()).toList();
      final liked = await _likedIds(ids);
      return res.map((e) { final m = Map<String, dynamic>.from((e as Map).cast<String, dynamic>()); return Event.fromJson({...m, 'is_liked': liked.contains(m['id'].toString())}); }).toList();
    } catch (_) { return []; }
  }

  Future<List<Event>> getRecentEvents({int limit = 10}) async {
    try {
      final res = await _supabase.from('events').select('*').eq('status', 'upcoming').order('created_at', ascending: false).limit(limit) as List<dynamic>;
      final ids = res.map((e) => (e['id']?? '').toString()).toList();
      final liked = await _likedIds(ids);
      return res.map((e) { final m = Map<String, dynamic>.from((e as Map).cast<String, dynamic>()); return Event.fromJson({...m, 'is_liked': liked.contains(m['id'].toString())}); }).toList();
    } catch (_) { return []; }
  }

  Future<List<Event>> getEventsForModerator({String? status}) async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];
    try {
      var query = _supabase.from('events').select('*');
      if (status!= null && status!= 'all') query = query.eq('status', status);
      final res = await query.order('created_at', ascending: false).limit(100) as List<dynamic>;
      return res.map((e) => Event.fromJson(Map<String, dynamic>.from((e as Map).cast<String, dynamic>()))).toList();
    } catch (_) { return []; }
  }

  Future<Event?> getEventById(String eventId) async {
    try {
      final res = await _supabase.from('events').select('*').eq('id', eventId).maybeSingle();
      if (res == null) return null;
      final liked = await _likedIds([eventId]);
      return Event.fromJson({...Map<String, dynamic>.from((res as Map).cast<String, dynamic>()), 'is_liked': liked.contains(eventId), 'is_saved': liked.contains(eventId)});
    } catch (_) { return null; }
  }

  Future<List<Event>> getFeaturedEvents() async {
    try {
      final res = await _supabase.from('events').select('*').eq('is_featured', true).eq('status', 'upcoming').gte('start_date', DateTime.now().toIso8601String()).order('start_date').limit(10) as List<dynamic>;
      final ids = res.map((e) => (e['id']?? '').toString()).toList();
      final liked = await _likedIds(ids);
      return res.map((e) { final m = Map<String, dynamic>.from((e as Map).cast<String, dynamic>()); return Event.fromJson({...m, 'is_liked': liked.contains(m['id'].toString())}); }).toList();
    } catch (_) { return []; }
  }

  Future<List<Event>> getEventsByCategory(String category) => getEvents(category: category, limit: 20, page: 0);

  Future<List<Event>> searchEvents(String query) {
    if (query.trim().isEmpty) return Future.value([]);
    return getEvents(search: query, limit: 50, page: 0);
  }

  // ============ INTERACTIONS ============
  Future<void> incrementViews(String eventId) async {
    try { await _supabase.rpc('increment_event_views', params: {'event_id': eventId}); } catch (_) {}
  }

  Future<void> likeEvent(String eventId) async {
    final uid = currentUserId; if (uid.isEmpty) return;
    await _supabase.from('event_favorites').upsert({'event_id': eventId, 'user_id': uid}, onConflict: 'event_id,user_id');
    try { await _supabase.rpc('increment_event_likes', params: {'event_id': eventId}); } catch (_) {}
  }

  Future<void> unlikeEvent(String eventId) async {
    final uid = currentUserId; if (uid.isEmpty) return;
    await _supabase.from('event_favorites').delete().eq('event_id', eventId).eq('user_id', uid);
    try { await _supabase.rpc('decrement_event_likes', params: {'event_id': eventId}); } catch (_) {}
  }

  Future<List<Event>> getFavoriteEvents() async {
    final uid = currentUserId; if (uid.isEmpty) return [];
    try {
      final res = await _supabase.from('event_favorites').select('event:event_id(*)').eq('user_id', uid).order('created_at', ascending: false).limit(100) as List<dynamic>;
      return res.where((e) => e['event']!= null).map((e) => Event.fromJson({...Map<String, dynamic>.from((e['event'] as Map).cast<String, dynamic>()), 'is_liked': true})).toList();
    } catch (_) { return []; }
  }

  // ============ RESERVATION ============
  Future<EventBooking?> bookTicket({required String eventId, required int quantity, required double totalPrice, String? paymentMethod}) async {
    final uid = currentUserId; if (uid.isEmpty) throw Exception('Non connecté');
    try {
      final code = 'THIX-${_uuid.v4().substring(0, 12).toUpperCase()}';
      final res = await _retry(() => _supabase.from('event_bookings').insert({
        'event_id': eventId, 'user_id': uid, 'ticket_quantity': quantity, 'total_price': totalPrice,
        'payment_method': paymentMethod, 'payment_status': 'paid', 'ticket_code': code, 'qr_code': code, 'status': 'confirmed', 'booking_date': DateTime.now().toIso8601String(),
      }).select().single());
      try { await _supabase.rpc('decrement_remaining_tickets', params: {'e_id': eventId, 'qty': quantity}); } catch (_) {}
      return EventBooking.fromJson(Map<String, dynamic>.from((res as Map).cast<String, dynamic>()));
    } catch (e) { debugPrint('bookTicket error: $e'); return null; }
  }

  Future<List<EventBooking>> getMyTickets() async {
    final uid = currentUserId; if (uid.isEmpty) return [];
    try {
      final res = await _supabase.from('event_bookings').select('*, events:event_id(title, image_url, start_date, location)').eq('user_id', uid).order('booking_date', ascending: false).limit(100) as List<dynamic>;
      return res.map((e) { final ev = e['events']; return EventBooking.fromJson({...Map<String, dynamic>.from((e as Map).cast<String, dynamic>()), if (ev!= null)...{'event_title': ev['title'], 'event_image_url': ev['image_url'], 'event_date': ev['start_date'], 'event_location': ev['location']}}); }).toList();
    } catch (_) { return []; }
  }

  // ============ ADMIN ============
  Future<Event> createEvent({
    required String title, required String description, required String category, String? subCategory,
    required DateTime startDate, DateTime? endDate, required String location, String? address, double price = 0,
    String priceCurrency = 'FC', bool isFree = false, int? capacity, String? imageUrl, String? bannerUrl, String? city,
    bool isFeatured = false, String? organizerName, String? contactPhone, String? contactEmail,
  }) async {
    final res = await _supabase.from('events').insert({
      'title': title, 'description': description, 'category': category, if (subCategory!= null) 'sub_category': subCategory,
      'start_date': startDate.toIso8601String(), if (endDate!= null) 'end_date': endDate.toIso8601String(),
      'location': location, 'city': city, if (address!= null) 'address': address, 'price': price, 'price_currency': priceCurrency,
      'is_free': isFree, 'capacity': capacity, 'remaining_tickets': capacity, 'image_url': imageUrl, 'banner_url': bannerUrl,
      'is_featured': isFeatured, 'status': startDate.isAfter(DateTime.now())? 'upcoming' : 'ongoing',
      'organizer_id': currentUserId, 'organizer_name': organizerName, 'contact_phone': contactPhone, 'contact_email': contactEmail,
      'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String(),
    }).select().single();
    return Event.fromJson(Map<String, dynamic>.from((res as Map).cast<String, dynamic>()));
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _supabase.from('events').update({...data, 'updated_at': DateTime.now().toIso8601String()}).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  // ============ UPLOAD ============
  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    if (currentUserId.isEmpty) return null;
    final path = 'events/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_$fileName';
    await _retry(() => _supabase.storage.from('event_images').uploadBinary(path, bytes, fileOptions: const FileOptions(cacheControl: '31536000', upsert: true)));
    return _supabase.storage.from('event_images').getPublicUrl(path);
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final total = await _supabase.from('events').select('id').count(CountOption.exact);
      final upcoming = await _supabase.from('events').select('id').eq('status', 'upcoming').gte('start_date', DateTime.now().toIso8601String()).count(CountOption.exact);
      return {'total_events': total.count, 'upcoming_events': upcoming.count, 'total_views': 0, 'total_likes': 0};
    } catch (_) { return {'total_events': 0, 'upcoming_events': 0, 'total_views': 0, 'total_likes': 0}; }
  }

  Future<bool> checkConnection() async {
    try { await _supabase.from('events').select('id').limit(1); return true; } catch (_) { return false; }
  }
}
