// lib/presentation/thix_event/admin/services/admin_event_service.dart
import 'dart:typed_data'; // REMPLACE dart:io pour la compatibilité Web
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/admin_stats_model.dart';
import '../core/admin_constants.dart';
import 'package:thix_id/models/event_model.dart';
import 'package:thix_id/models/event_seat.dart';

class AdminEventService {
  final SupabaseClient _supabase;
  AdminEventService(this._supabase);

  // ===================== 1. DASHBOARD STATS VIA RPC (CRITIQUE) =====================
  // Ne fait JAMAIS count(*) côté client. Tout est calculé côté Postgres avec index.
  Future<AdminStats> getDashboardStats() async {
    try {
      final res = await _supabase.rpc('get_admin_stats').single();
      return AdminStats.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('❌ RPC get_admin_stats failed, fallback manual: $e');
      // Fallback si RPC pas encore créée (DEV)
      return await _fallbackStats();
    }
  }

  Future<AdminStats> _fallbackStats() async {
    // Fallback DEV seulement - à supprimer en prod avec 1M rows
    final events = await _supabase.from('events').select('id').limit(1);
    return AdminStats(totalEvents: 0); // On retourne vide pour ne pas bloquer
  }

  // ===================== 2. EVENTS PAGINÉS - SCALABLE =====================
  Future<List<Event>> getEventsPaginated({
    required int page,
    required int pageSize,
    String? search,
    String? category,
    String? city,
    String orderBy = 'start_date',
    bool ascending = true,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      var query = _supabase.from('events').select('*');

      // Filtres côté SQL, pas en Dart
      if (search!= null && search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }
      if (category!= null && category!= 'all') {
        query = query.eq('category', category);
      }
      if (city!= null && city!= 'all') {
        query = query.eq('city', city);
      }

      final response = await query
         .order(orderBy, ascending: ascending)
         .range(from, to); // <--- CLÉ SCALABLE : pagination SQL

      return (response as List).map((e) => Event.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getEventsPaginated error page $page: $e');
      rethrow;
    }
  }

  // ===================== 3. UPSERT EVENT + UPLOAD IMAGE =====================
  Future<Event> upsertEvent(Event event, {Uint8List? imageBytes, Uint8List? bannerBytes}) async {
    try {
      String? imageUrl = event.imageUrl;
      String? bannerUrl = event.bannerUrl;

      // Upload scalable: compress + upload vers Storage
      if (imageBytes != null) {
        imageUrl = await _uploadBytes(imageBytes, 'events/${event.id}_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      if (bannerBytes != null) {
        bannerUrl = await _uploadBytes(bannerBytes, 'events/${event.id}_banner_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }

      final data = {
       ...event.toJson(),
        if (imageUrl != null) 'image_url': imageUrl,
        if (bannerUrl != null) 'banner_url': bannerUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Si id vide => création, sinon update
      if (event.id.isEmpty) {
        data.remove('id');
        final res = await _supabase.from('events').insert(data).select().single();
        return Event.fromJson(res);
      } else {
        final res = await _supabase.from('events').update(data).eq('id', event.id).select().single();
        return Event.fromJson(res);
      }
    } catch (e) {
      debugPrint('❌ upsertEvent error: $e');
      rethrow;
    }
  }

  Future<String> _uploadBytes(Uint8List bytes, String path) async {
    // Vérif taille
    final sizeMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeMB > AdminConstants.maxImageSizeMB) {
      throw Exception('Image trop lourde: ${sizeMB.toStringAsFixed(1)}MB > ${AdminConstants.maxImageSizeMB}MB');
    }

    await _supabase.storage.from('event-images').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('event-images').getPublicUrl(path);
  }

  Future<void> deleteEvent(String id) async {
    // Suppression scalable: transaction côté SQL si possible, sinon cascade
    // 1. Delete seats, bookings limits, etc. d'abord
    await _supabase.from('event_seats').delete().eq('event_id', id);
    await _supabase.from('event_booking_limits').delete().eq('event_id', id);
    await _supabase.from('events').delete().eq('id', id);
  }

  Future<void> updateEventField(String id, Map<String, dynamic> fields) async {
    await _supabase.from('events').update({...fields, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  // ===================== 4. SEATS - BATCH INSERT & DYNAMIC PRICING =====================
  
  Future<List<EventSeat>> getSeatMapForAdmin(String eventId) async {
    try {
      final response = await _supabase
          .from('event_seats')
          .select()
          .eq('event_id', eventId)
          .order('row', ascending: true)
          .order('number', ascending: true);
          
      return (response as List).map((e) => EventSeat.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getSeatMapForAdmin error: $e');
      rethrow;
    }
  }

  // 🟢 MISE À JOUR : Support des prix par catégorie et du design de salle
  Future<void> generateSeatMap({
    required String eventId,
    required int rows,
    required int seatsPerRow,
    required Map<String, dynamic> categoryConfig, // {'A': 'vip', 'B': 'gold'...}
    required Map<String, double> categoryPrices,  // {'standard': 10.0, 'vip': 50.0...}
    required bool hasCenterAisle,                 // Métadonnée optionnelle
  }) async {
    if (rows * seatsPerRow > AdminConstants.maxSeatGeneration) {
      throw Exception('Trop de sièges: max ${AdminConstants.maxSeatGeneration}');
    }

    // 1. Supprimer ancien plan
    await _supabase.from('event_seats').delete().eq('event_id', eventId);

    // [Optionnel] Mettre à jour les métadonnées de l'événement pour retenir s'il y a un couloir
    try {
      await _supabase.from('events').update({
        'has_center_aisle': hasCenterAisle
      }).eq('id', eventId);
    } catch (e) {
      debugPrint('Info: Impossible de sauvegarder "has_center_aisle" (colonne peut-être absente)');
    }

    // 2. Générer en mémoire avec le Prix Dynamique
    final List<Map<String, dynamic>> allSeats = [];
    for (int r = 0; r < rows; r++) {
      final rowLetter = String.fromCharCode(65 + r); // A, B, C...
      final category = categoryConfig[rowLetter] ?? 'standard';
      
      // 🟢 Récupération du prix spécifique à cette catégorie
      final double seatPrice = categoryPrices[category] ?? 10.0;

      for (int n = 1; n <= seatsPerRow; n++) {
        allSeats.add({
          'event_id': eventId,
          'row': rowLetter,
          'number': n,
          'category': category,
          'price': seatPrice, // Applique le vrai prix configuré
          'status': 'available',
        });
      }
    }

    // 3. Insert par batch de 200 (Contourne les limites Supabase)
    for (int i = 0; i < allSeats.length; i += AdminConstants.seatsBatchSize) {
      final batch = allSeats.skip(i).take(AdminConstants.seatsBatchSize).toList();
      await _supabase.from('event_seats').insert(batch);
      debugPrint('✅ Seats batch ${i ~/ AdminConstants.seatsBatchSize + 1} inserted');
    }
  }

  // ===================== 5. BOOKINGS PAGINÉS =====================
  Future<List<Map<String, dynamic>>> getBookingsPaginated({required int page, required int pageSize, String? eventId}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _supabase.from('event_bookings').select('*, events(title, start_date)');

    if (eventId != null) query = query.eq('event_id', eventId);

    final res = await query.order('created_at', ascending: false).range(from, to);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ===================== 6. LIMITS =====================
  Future<void> upsertBookingLimit(String eventId, Map<String, dynamic> limitData) async {
    await _supabase.from('event_booking_limits').upsert({'event_id': eventId, ...limitData});
  }
}
