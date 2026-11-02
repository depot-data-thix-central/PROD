// lib/presentation/thix_weeding/providers/provider_providers.dart
// ============================================================================
// THIX WEDDING PROVIDER RIVERPOD PROVIDERS (PRODUCTION ENTERPRISE)
// ✅ Providers pour prestataires, réservations, tâches
// ✅ Recherche par code unique Thix
// ✅ Cache + Invalidation automatique
// ✅ FIX : userId rendu optionnel (String?) dans createProviderProvider
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../services/provider_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════
final providerServiceProvider = Provider<ProviderService>((ref) {
  return ProviderService();
});

// ═══════════════════════════════════════════════════════════════════════════
// LISTE DES PRESTATAIRES
// ═══════════════════════════════════════════════════════════════════════════
final providersListProvider = FutureProvider.autoDispose
    .family<List<ThixProviderModel>, ProviderListParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  return service.getAllProviders(
    page: params.page,
    limit: params.limit,
    category: params.category,
    level: params.level,
    city: params.city,
    isAvailable: params.isAvailable,
    search: params.search,
  );
});

class ProviderListParams {
  final int page;
  final int limit;
  final ProviderCategory? category;
  final TrackingLevel? level;
  final String? city;
  final bool? isAvailable;
  final String? search;

  const ProviderListParams({
    this.page = 1,
    this.limit = 20,
    this.category,
    this.level,
    this.city,
    this.isAvailable,
    this.search,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderListParams &&
          page == other.page &&
          limit == other.limit &&
          category == other.category &&
          level == other.level &&
          city == other.city &&
          isAvailable == other.isAvailable &&
          search == other.search;

  @override
  int get hashCode => Object.hash(page, limit, category, level, city, isAvailable, search);
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE PAR ID
// ═══════════════════════════════════════════════════════════════════════════
final providerByIdProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, id) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderById(id);
});

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE PAR CODE UNIQUE
// ═══════════════════════════════════════════════════════════════════════════
final providerByCodeProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, code) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderByCode(code);
});

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE COURANT (Espace prestataire)
// ✅ FIX : userId nullable
// ═══════════════════════════════════════════════════════════════════════════
final currentProviderProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String?>((ref, userId) async {
  if (userId == null || userId.isEmpty) return null;
  final service = ref.watch(providerServiceProvider);
  return service.getProviderByUserId(userId);
});

// ═══════════════════════════════════════════════════════════════════════════
// RÉSERVATIONS D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerReservationsProvider = FutureProvider.autoDispose
    .family<List<ProviderReservationModel>, ProviderReservationsParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderReservations(params.providerId, status: params.status);
});

class ProviderReservationsParams {
  final String providerId;
  final ReservationStatus? status;

  const ProviderReservationsParams({required this.providerId, this.status});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderReservationsParams &&
          providerId == other.providerId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(providerId, status);
}

// ═══════════════════════════════════════════════════════════════════════════
// TÂCHES D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerTasksProvider = FutureProvider.autoDispose
    .family<List<ProviderTaskModel>, ProviderTasksParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderTasks(params.providerId, status: params.status);
});

class ProviderTasksParams {
  final String providerId;
  final TaskStatus? status;

  const ProviderTasksParams({required this.providerId, this.status});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderTasksParams &&
          providerId == other.providerId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(providerId, status);
}

// ═══════════════════════════════════════════════════════════════════════════
// STATISTIQUES D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, providerId) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderStats(providerId);
});

// ═══════════════════════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Créer un prestataire
/// ✅ FIX : userId rendu optionnel (String?)
final createProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return ({
    String? userId,
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
    final provider = await service.createProvider(
      userId: userId,
      category: category,
      businessName: businessName,
      description: description,
      phone: phone,
      email: email,
      address: address,
      city: city,
      galleryUrls: galleryUrls,
      videoUrls: videoUrls,
      minPrice: minPrice,
      maxPrice: maxPrice,
      currency: currency,
      requirements: requirements,
    );
    
    ref.invalidate(providersListProvider);
    
    return provider;
  };
});

/// Mettre à jour un prestataire
final updateProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return (
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
    final provider = await service.updateProvider(
      id,
      businessName: businessName,
      description: description,
      phone: phone,
      email: email,
      address: address,
      city: city,
      galleryUrls: galleryUrls,
      videoUrls: videoUrls,
      level: level,
      verificationStatus: verificationStatus,
      rating: rating,
      reviewCount: reviewCount,
      minPrice: minPrice,
      maxPrice: maxPrice,
      currency: currency,
      isAvailable: isAvailable,
      requirements: requirements,
    );
    
    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    
    return provider;
  };
});

/// Valider un prestataire (Staff)
final validateProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return (
    String id, {
    required bool approved,
    String? rejectionReason,
    TrackingLevel? newLevel,
  }) async {
    final provider = await service.validateProvider(
      id,
      approved: approved,
      rejectionReason: rejectionReason,
      newLevel: newLevel,
    );
    
    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    
    return provider;
  };
});

/// Créer une réservation
final createReservationProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return ({
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
    final reservation = await service.createReservation(
      providerId: providerId,
      weddingId: weddingId,
      clientName: clientName,
      clientPhone: clientPhone,
      eventDate: eventDate,
      eventType: eventType,
      guestCount: guestCount,
      totalPrice: totalPrice,
      currency: currency,
      notes: notes,
    );
    
    ref.invalidate(providerReservationsProvider);
    
    return reservation;
  };
});

/// Mettre à jour le statut d'une réservation
final updateReservationStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return (String reservationId, ReservationStatus status) async {
    final reservation = await service.updateReservationStatus(reservationId, status);
    ref.invalidate(providerReservationsProvider);
    return reservation;
  };
});

/// Créer une tâche
final createTaskProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return ({
    required String providerId,
    required String weddingId,
    required String assignedBy,
    required String title,
    String? description,
    required DateTime dueDateTime,
    int priority = 2,
  }) async {
    final task = await service.createTask(
      providerId: providerId,
      weddingId: weddingId,
      assignedBy: assignedBy,
      title: title,
      description: description,
      dueDateTime: dueDateTime,
      priority: priority,
    );
    
    ref.invalidate(providerTasksProvider);
    
    return task;
  };
});

/// Mettre à jour le statut d'une tâche
final updateTaskStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return (String taskId, TaskStatus status) async {
    final task = await service.updateTaskStatus(taskId, status);
    ref.invalidate(providerTasksProvider);
    return task;
  };
});
