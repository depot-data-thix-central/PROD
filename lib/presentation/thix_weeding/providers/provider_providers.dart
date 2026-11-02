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
    .family<List<ThixProviderModel>, _ProviderListParams>((ref, params) async {
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

class _ProviderListParams {
  final int page;
  final int limit;
  final ProviderCategory? category;
  final TrackingLevel? level;
  final String? city;
  final bool? isAvailable;
  final String? search;

  const _ProviderListParams({
    this.page = 1,
    this.limit = 20,
    this.category,
    this.level,
    this.city,
    this.isAvailable,
    this.search,
  });
}

ProviderListParams providerListParams({
  int page = 1,
  int limit = 20,
  ProviderCategory? category,
  TrackingLevel? level,
  String? city,
  bool? isAvailable,
  String? search,
}) {
  return ProviderListParams(
    page: page,
    limit: limit,
    category: category,
    level: level,
    city: city,
    isAvailable: isAvailable,
    search: search,
  );
}

class ProviderListParams extends _ProviderListParams {
  const ProviderListParams({
    super.page,
    super.limit,
    super.category,
    super.level,
    super.city,
    super.isAvailable,
    super.search,
  });
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
// PRESTATAIRE PAR CODE UNIQUE (Pour le staff)
// ═══════════════════════════════════════════════════════════════════════════
final providerByCodeProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, code) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderByCode(code);
});

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE COURANT (Espace prestataire)
// ══════════════════════════════════════════════════════════════════════════
final currentProviderProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, userId) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderByUserId(userId);
});

// ═══════════════════════════════════════════════════════════════════════════
// RÉSERVATIONS D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerReservationsProvider = FutureProvider.autoDispose
    .family<List<ProviderReservationModel>, _ReservationParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderReservations(
    params.providerId,
    status: params.status,
  );
});

class _ReservationParams {
  final String providerId;
  final ReservationStatus? status;

  const _ReservationParams({required this.providerId, this.status});
}

ProviderReservationsParams providerReservationsParams({
  required String providerId,
  ReservationStatus? status,
}) {
  return ProviderReservationsParams(providerId: providerId, status: status);
}

class ProviderReservationsParams extends _ReservationParams {
  const ProviderReservationsParams({required super.providerId, super.status});
}

// ═══════════════════════════════════════════════════════════════════════════
// TÂCHES D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerTasksProvider = FutureProvider.autoDispose
    .family<List<ProviderTaskModel>, _TaskParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderTasks(
    params.providerId,
    status: params.status,
  );
});

class _TaskParams {
  final String providerId;
  final TaskStatus? status;

  const _TaskParams({required this.providerId, this.status});
}

ProviderTasksParams providerTasksParams({
  required String providerId,
  TaskStatus? status,
}) {
  return ProviderTasksParams(providerId: providerId, status: status);
}

class ProviderTasksParams extends _TaskParams {
  const ProviderTasksParams({required super.providerId, super.status});
}

// ══════════════════════════════════════════════════════════════════════════
// STATISTIQUES D'UN PRESTATAIRE
// ══════════════════════════════════════════════════════════════════════════
final providerStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, providerId) async {
  final service = ref.watch(providerServiceProvider);
  return service.getProviderStats(providerId);
});

// ═══════════════════════════════════════════════════════════════════════════
// ACTIONS (Avec invalidation automatique)
// ═══════════════════════════════════════════════════════════════════════════

/// Créer un prestataire
/// ✅ FIX : userId rendu optionnel (String?)
final createProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  return ({
    String? userId, // ✅ RENDU OPTIONNEL
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
    
    // Invalider la liste pour rafraîchir
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
    
    // Invalider les providers concernés
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
    final reservation = await service.updateReservationStatus(
      reservationId,
      status,
    );
    
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
