// lib/presentation/thix_weeding/services/provider_service.dart
// ============================================================================
// THIX WEDDING PROVIDER SERVICE (PRODUCTION v4 — MULTI-ACTIVITÉS)
// ✅ LOGIQUE IDENTIQUE À WeddingService (mariages)
// ✅ Code unique THIX-P-XXXYY généré par Trigger SQL (pas en Dart)
// ✅ owner_id = user.id (comme owner_id des mariages)
// ✅ 1 compte = N activités/métiers (traiteur, salle, DJ…)
//    → getByOwner() retourne l'activité principale (rétro-compat)
//    → getAllByOwner() retourne TOUTES les activités du compte
//    → createProvider() marque is_primary=true si 1ère activité
// ✅ Méthodes offres/réservations/tâches/stats inchangées (par provider_id)
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_models.dart';

class ProviderService {
  final SupabaseClient _client;

  ProviderService() : _client = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ MULTI-ACTIVITÉS : TOUTES les activités d'un compte
  //    Calqué sur WeddingService.getByOwner (qui retourne une liste)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<List<ThixProviderModel>> getAllByOwner(String ownerId) async {
    try {
      final response = await _client
          .from('thix_weeding_providers')
          .select('*')
          .eq('owner_id', ownerId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((e) => ThixProviderModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des activités: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RÉCUPÉRER PRESTATAIRE PAR OWNER (rétro-compat : retourne la principale)
  //    Les call-sites existants (shell, register, auth) attendent un seul objet.
  //    En multi-activités, on retourne l'activité marquée is_primary
  //    ou la plus récente si aucune n'est marquée.
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel?> getByOwner(String ownerId) async {
    try {
      final response = await _client
          .from('thix_weeding_providers')
          .select('*')
          .eq('owner_id', ownerId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RÉCUPÉRER TOUS LES PRESTATAIRES (PAGINÉ — catalogue public)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<List<ThixProviderModel>> getAllProviders({
    int page = 1,
    int limit = 20,
    ProviderCategory? category,
    TrackingLevel? level,
    String? city,
    bool? isAvailable,
    String? search,
  }) async {
    try {
      var query = _client.from('thix_weeding_providers').select('*');

      if (category != null) query = query.eq('category', category.name);
      if (level != null) query = query.eq('level', level.name);
      if (city != null && city.isNotEmpty) query = query.eq('city', city);
      if (isAvailable != null) query = query.eq('is_available', isAvailable);
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'business_name.ilike.%$search%,description.ilike.%$search%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => ThixProviderModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des prestataires: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RÉCUPÉRER PRESTATAIRE PAR ID
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel?> getProviderById(String id) async {
    try {
      final response = await _client
          .from('thix_weeding_providers')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RÉCUPÉRER PRESTATAIRE PAR CODE UNIQUE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel?> getProviderByCode(String code) async {
    try {
      final response = await _client
          .from('thix_weeding_providers')
          .select('*')
          .eq('unique_code', code.toUpperCase())
          .maybeSingle();

      if (response == null) return null;
      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Code introuvable: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRÉER UN NOUVEAU PRESTATAIRE / ACTIVITÉ
  // ✅ Multi-activités : marque is_primary=true si c'est la 1ère du compte
  // ✅ Code THIX-P-XXXYY généré par Trigger SQL (pas en Dart)
  // ✅ owner_id = user.id (comme owner_id des mariages)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel> createProvider({
    required String ownerId,
    required ProviderCategory category,
    required String businessName,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? city,
    List<String>? galleryUrls,
    List<String>? videoUrls,
    double? minPrice,
    double? maxPrice,
    String? currency,
    Map<String, dynamic>? requirements,
  }) async {
    try {
      final now = DateTime.now();

      // ✅ Vérifier si c'est la 1ère activité du compte → is_primary = true
      final existing = await _client
          .from('thix_weeding_providers')
          .select('id')
          .eq('owner_id', ownerId)
          .limit(1);
      final isFirst = (existing as List).isEmpty;

      final data = <String, dynamic>{
        'owner_id': ownerId,
        'category': category.name,
        'business_name': businessName,
        'level': TrackingLevel.bronze.name,
        'verification_status': ProviderVerificationStatus.pending.name,
        'rating': 0.0,
        'review_count': 0,
        'currency': currency ?? 'USD',
        'is_available': true,
        'is_primary': isFirst, // ✅ Multi-activités
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (description != null) data['description'] = description;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (address != null) data['address'] = address;
      if (city != null) data['city'] = city;
      if (minPrice != null) data['min_price'] = minPrice;
      if (maxPrice != null) data['max_price'] = maxPrice;

      data['gallery_urls'] = galleryUrls ?? [];
      data['video_urls'] = videoUrls ?? [];
      data['requirements'] = requirements ?? {};

      final response = await _client
          .from('thix_weeding_providers')
          .insert(data)
          .select()
          .single();

      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // METTRE À JOUR UN PRESTATAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel> updateProvider(
    String id, {
    String? businessName,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? city,
    List<String>? galleryUrls,
    List<String>? videoUrls,
    TrackingLevel? level,
    ProviderVerificationStatus? verificationStatus,
    double? rating,
    int? reviewCount,
    double? minPrice,
    double? maxPrice,
    String? currency,
    bool? isAvailable,
    Map<String, dynamic>? requirements,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (businessName != null) data['business_name'] = businessName;
      if (description != null) data['description'] = description;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (address != null) data['address'] = address;
      if (city != null) data['city'] = city;
      if (galleryUrls != null) data['gallery_urls'] = galleryUrls;
      if (videoUrls != null) data['video_urls'] = videoUrls;
      if (level != null) data['level'] = level.name;
      if (verificationStatus != null) {
        data['verification_status'] = verificationStatus.name;
      }
      if (rating != null) data['rating'] = rating;
      if (reviewCount != null) data['review_count'] = reviewCount;
      if (minPrice != null) data['min_price'] = minPrice;
      if (maxPrice != null) data['max_price'] = maxPrice;
      if (currency != null) data['currency'] = currency;
      if (isAvailable != null) data['is_available'] = isAvailable;
      if (requirements != null) data['requirements'] = requirements;

      final response = await _client
          .from('thix_weeding_providers')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDER UN PRESTATAIRE (Par le staff)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel> validateProvider(
    String id, {
    required bool approved,
    String? rejectionReason,
    TrackingLevel? newLevel,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'verification_status': approved
            ? ProviderVerificationStatus.verified.name
            : ProviderVerificationStatus.rejected.name,
      };

      if (approved && newLevel != null) data['level'] = newLevel.name;
      if (!approved && rejectionReason != null) {
        data['rejection_reason'] = rejectionReason;
      }

      final response = await _client
          .from('thix_weeding_providers')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return ThixProviderModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la validation du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPPRIMER UN PRESTATAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> deleteProvider(String id) async {
    try {
      await _client.from('thix_weeding_providers').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du prestataire: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFRES / SERVICES / MENUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Offres d'un prestataire (filtrées par provider_id = activité spécifique)
  Future<List<ProviderOfferModel>> getOffersByProvider(
      String providerId) async {
    try {
      final response = await _client
          .from('thix_weeding_provider_offers')
          .select('*')
          .eq('provider_id', providerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map((json) => ProviderOfferModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des offres: $e');
    }
  }

  /// Offres actives de TOUS les prestataires (pour le HOME + catalogue)
  Future<List<ProviderOfferModel>> getActiveOffersWithProvider(
      {int limit = 20}) async {
    try {
      final response = await _client
          .from('thix_weeding_provider_offers')
          .select(
              '*, provider:thix_weeding_providers(id, business_name, city, category, verification_status)')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response)
          .map((json) => ProviderOfferModel.fromJson(json))
          .where((o) => o.providerVerificationStatus != 'rejected')
          .toList();
    } catch (e) {
      throw Exception(
          'Erreur lors de la récupération des offres actives: $e');
    }
  }

  /// Créer une offre
  Future<ProviderOfferModel> createOffer({
    required String providerId,
    required String title,
    required OfferType type,
    String? description,
    double? price,
    String? currency,
    String? imageUrl,
    bool isActive = true,
  }) async {
    try {
      final now = DateTime.now();
      final data = <String, dynamic>{
        'provider_id': providerId,
        'title': title,
        'offer_type': type.name,
        'description': description,
        'price': price,
        'currency': currency ?? 'USD',
        'image_url': imageUrl,
        'is_active': isActive,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final response = await _client
          .from('thix_weeding_provider_offers')
          .insert(data)
          .select()
          .single();
      return ProviderOfferModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'offre: $e');
    }
  }

  /// Mettre à jour une offre
  Future<ProviderOfferModel> updateOffer(
    String id, {
    String? title,
    OfferType? type,
    String? description,
    double? price,
    String? imageUrl,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) data['title'] = title;
      if (type != null) data['offer_type'] = type.name;
      if (description != null) data['description'] = description;
      if (price != null) data['price'] = price;
      if (imageUrl != null) data['image_url'] = imageUrl;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _client
          .from('thix_weeding_provider_offers')
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return ProviderOfferModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'offre: $e');
    }
  }

  /// Supprimer une offre
  Future<void> deleteOffer(String id) async {
    try {
      await _client.from('thix_weeding_provider_offers').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'offre: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ ALIAS RÉTROCOMPATIBLE : getProviderByUserId → getByOwner
  // ═══════════════════════════════════════════════════════════════════════════
  Future<ThixProviderModel?> getProviderByUserId(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    return getByOwner(userId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RÉSERVATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<ProviderReservationModel> createReservation({
    required String providerId,
    required String weddingId,
    required String clientName,
    required String clientPhone,
    required DateTime eventDate,
    String? eventType,
    int? guestCount,
    double? totalPrice,
    String? currency,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final data = <String, dynamic>{
        'provider_id': providerId,
        'wedding_id': weddingId,
        'client_name': clientName,
        'client_phone': clientPhone,
        'event_date': eventDate.toIso8601String(),
        'status': ReservationStatus.pending.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (eventType != null) data['event_type'] = eventType;
      if (guestCount != null) data['guest_count'] = guestCount;
      if (totalPrice != null) data['total_price'] = totalPrice;
      if (currency != null) data['currency'] = currency;
      if (notes != null) data['notes'] = notes;

      final response = await _client
          .from('thix_weeding_provider_reservations')
          .insert(data)
          .select()
          .single();

      return ProviderReservationModel.fromJson(
          response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création de la réservation: $e');
    }
  }

  Future<List<ProviderReservationModel>> getProviderReservations(
    String providerId, {
    ReservationStatus? status,
  }) async {
    try {
      var query = _client
          .from('thix_weeding_provider_reservations')
          .select('*')
          .eq('provider_id', providerId);

      if (status != null) query = query.eq('status', status.name);

      final response = await query.order('event_date', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => ProviderReservationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des réservations: $e');
    }
  }

  Future<ProviderReservationModel> updateReservationStatus(
    String reservationId,
    ReservationStatus status,
  ) async {
    try {
      final data = <String, dynamic>{
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('thix_weeding_provider_reservations')
          .update(data)
          .eq('id', reservationId)
          .select()
          .single();

      return ProviderReservationModel.fromJson(
          response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la réservation: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TÂCHES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<ProviderTaskModel> createTask({
    required String providerId,
    required String weddingId,
    required String assignedBy,
    required String title,
    String? description,
    required DateTime dueDateTime,
    int priority = 2,
  }) async {
    try {
      final now = DateTime.now();
      final data = <String, dynamic>{
        'provider_id': providerId,
        'wedding_id': weddingId,
        'assigned_by': assignedBy,
        'title': title,
        'due_datetime': dueDateTime.toIso8601String(),
        'status': TaskStatus.assigned.name,
        'priority': priority,
        'created_at': now.toIso8601String(),
      };

      if (description != null) data['description'] = description;

      final response = await _client
          .from('thix_weeding_provider_tasks')
          .insert(data)
          .select()
          .single();

      return ProviderTaskModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la création de la tâche: $e');
    }
  }

  Future<List<ProviderTaskModel>> getProviderTasks(
    String providerId, {
    TaskStatus? status,
  }) async {
    try {
      var query = _client
          .from('thix_weeding_provider_tasks')
          .select('*')
          .eq('provider_id', providerId);

      if (status != null) query = query.eq('status', status.name);

      final response = await query.order('due_datetime', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => ProviderTaskModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des tâches: $e');
    }
  }

  Future<ProviderTaskModel> updateTaskStatus(
    String taskId,
    TaskStatus status,
  ) async {
    try {
      final data = <String, dynamic>{
        'status': status.name,
      };

      if (status == TaskStatus.completed) {
        data['completed_at'] = DateTime.now().toIso8601String();
      }

      final response = await _client
          .from('thix_weeding_provider_tasks')
          .update(data)
          .eq('id', taskId)
          .select()
          .single();

      return ProviderTaskModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la tâche: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTIQUES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    try {
      final reservations = await _client
          .from('thix_weeding_provider_reservations')
          .select('status, total_price')
          .eq('provider_id', providerId);

      final tasks = await _client
          .from('thix_weeding_provider_tasks')
          .select('status')
          .eq('provider_id', providerId);

      final totalReservations = reservations.length;
      final confirmedReservations = reservations
          .where((r) => r['status'] == ReservationStatus.confirmed.name)
          .length;
      final totalRevenue = reservations.fold<double>(
        0.0,
        (sum, r) => sum + ((r['total_price'] as num?)?.toDouble() ?? 0.0),
      );

      final totalTasks = tasks.length;
      final completedTasks = tasks
          .where((t) => t['status'] == TaskStatus.completed.name)
          .length;

      return {
        'total_reservations': totalReservations,
        'confirmed_reservations': confirmedReservations,
        'total_revenue': totalRevenue,
        'total_tasks': totalTasks,
        'completed_tasks': completedTasks,
        'completion_rate':
            totalTasks > 0 ? (completedTasks / totalTasks) : 0.0,
      };
    } catch (e) {
      throw Exception('Erreur lors de la récupération des statistiques: $e');
    }
  }
}
