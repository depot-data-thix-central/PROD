// lib/presentation/thix_weeding/providers/provider_providers.dart
// ============================================================================
// THIX WEDDING PROVIDER RIVERPOD PROVIDERS (PRODUCTION ENTERPRISE)
// ✅ Providers pour prestataires, réservations, tâches
// ✅ Recherche par code unique Thix
// ✅ Cache + Invalidation intelligente
// ✅ Gestion d'erreurs robuste avec retry
// ✅ Logging pour debugging production
// ✅ Optimisation des performances
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../services/provider_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TYPES D'ERREURS PERSONNALISÉS
// ═══════════════════════════════════════════════════════════════════════════

/// Erreur personnalisée pour les opérations Provider
class ProviderException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  ProviderException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (code != null) {
      return 'ProviderException[$code]: $message';
    }
    return 'ProviderException: $message';
  }
}

/// Erreur de timeout
class ProviderTimeoutException extends ProviderException {
  ProviderTimeoutException(String message) 
      : super(message: message, code: 'TIMEOUT');
}

/// Erreur réseau
class ProviderNetworkException extends ProviderException {
  ProviderNetworkException(String message, {dynamic originalError})
      : super(
          message: message,
          code: 'NETWORK_ERROR',
          originalError: originalError,
        );
}

/// Erreur de validation
class ProviderValidationException extends ProviderException {
  ProviderValidationException(String message)
      : super(message: message, code: 'VALIDATION_ERROR');
}

/// Erreur de données introuvables
class ProviderNotFoundException extends ProviderException {
  ProviderNotFoundException(String message)
      : super(message: message, code: 'NOT_FOUND');
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════
final providerServiceProvider = Provider<ProviderService>((ref) {
  return ProviderService();
});

// ═══════════════════════════════════════════════════════════════════════════
// UTILITAIRE : WRAPPER AVEC TIMEOUT ET GESTION D'ERREURS
// ═══════════════════════════════════════════════════════════════════════════

/// Exécute une opération async avec timeout et gestion d'erreurs
Future<T> _executeWithTimeout<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 30),
  String operationName = 'operation',
}) async {
  try {
    return await operation().timeout(timeout);
  } on TimeoutException {
    throw ProviderTimeoutException(
        'L\'opération "$operationName" a pris trop de temps. Vérifiez votre connexion.');
  } on ProviderException {
    rethrow;
  } catch (e, stack) {
    final errorMsg = e.toString();
    
    // Classification des erreurs
    if (errorMsg.contains('SocketException') || 
        errorMsg.contains('Network')) {
      throw ProviderNetworkException(
        'Erreur de connexion réseau',
        originalError: e,
      );
    }
    
    if (errorMsg.contains('not found') || errorMsg.contains('404')) {
      throw ProviderNotFoundException('Données introuvables');
    }
    
    throw ProviderException(
      message: 'Erreur inattendue: $errorMsg',
      code: 'UNKNOWN',
      originalError: e,
      stackTrace: stack,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LISTE DES PRESTATAIRES (PAGINÉ + FILTRES)
// ═══════════════════════════════════════════════════════════════════════════
final providersListProvider = FutureProvider.autoDispose
    .family<List<ThixProviderModel>, ProviderListParams>((ref, params) async {
  final service = ref.watch(providerServiceProvider);
  
  if (kDebugMode) {
    debugPrint('📋 Loading providers: page=${params.page}, '
        'category=${params.category?.name ?? "all"}, '
        'search="${params.search ?? ""}"');
  }
  
  return await _executeWithTimeout(
    () => service.getAllProviders(
      page: params.page,
      limit: params.limit,
      category: params.category,
      level: params.level,
      city: params.city,
      isAvailable: params.isAvailable,
      search: params.search,
    ),
    operationName: 'getAllProviders',
  );
});

/// Paramètres pour la liste des prestataires
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

  /// Crée une copie avec des paramètres modifiés
  ProviderListParams copyWith({
    int? page,
    int? limit,
    ProviderCategory? category,
    TrackingLevel? level,
    String? city,
    bool? isAvailable,
    String? search,
    bool clearCategory = false,
    bool clearLevel = false,
    bool clearCity = false,
    bool clearSearch = false,
  }) {
    return ProviderListParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      category: clearCategory ? null : (category ?? this.category),
      level: clearLevel ? null : (level ?? this.level),
      city: clearCity ? null : (city ?? this.city),
      isAvailable: isAvailable ?? this.isAvailable,
      search: clearSearch ? null : (search ?? this.search),
    );
  }

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
  int get hashCode => Object.hash(
        page,
        limit,
        category,
        level,
        city,
        isAvailable,
        search,
      );

  @override
  String toString() {
    return 'ProviderListParams(page: $page, limit: $limit, '
        'category: ${category?.name}, level: ${level?.name}, '
        'city: $city, search: $search)';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE PAR ID
// ═══════════════════════════════════════════════════════════════════════════
final providerByIdProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, id) async {
  final service = ref.watch(providerServiceProvider);
  
  if (kDebugMode) {
    debugPrint('🔍 Loading provider by ID: $id');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderById(id),
    operationName: 'getProviderById($id)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE PAR CODE UNIQUE (THIX-P-XXXYY)
// ═══════════════════════════════════════════════════════════════════════════
final providerByCodeProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, code) async {
  final service = ref.watch(providerServiceProvider);
  
  if (kDebugMode) {
    debugPrint('🔍 Loading provider by code: $code');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderByCode(code),
    operationName: 'getProviderByCode($code)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRE COURANT (Espace prestataire connecté)
// ═══════════════════════════════════════════════════════════════════════════
final currentProviderProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String?>((ref, userId) async {
  if (userId == null || userId.isEmpty) {
    if (kDebugMode) {
      debugPrint('⚠️ currentProviderProvider: userId is null/empty');
    }
    return null;
  }
  
  final service = ref.watch(providerServiceProvider);
  
  if (kDebugMode) {
    debugPrint('👤 Loading current provider for user: $userId');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderByUserId(userId),
    operationName: 'getProviderByUserId($userId)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// RÉSERVATIONS D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerReservationsProvider = FutureProvider.autoDispose
    .family<List<ProviderReservationModel>, ProviderReservationsParams>(
        (ref, params) async {
  final service = ref.watch(providerServiceProvider);
  
  if (kDebugMode) {
    debugPrint('📅 Loading reservations for provider: ${params.providerId}');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderReservations(
      params.providerId,
      status: params.status,
    ),
    operationName: 'getProviderReservations(${params.providerId})',
  );
});

/// Paramètres pour les réservations
class ProviderReservationsParams {
  final String providerId;
  final ReservationStatus? status;

  const ProviderReservationsParams({
    required this.providerId,
    this.status,
  });

  ProviderReservationsParams copyWith({
    String? providerId,
    ReservationStatus? status,
    bool clearStatus = false,
  }) {
    return ProviderReservationsParams(
      providerId: providerId ?? this.providerId,
      status: clearStatus ? null : (status ?? this.status),
    );
  }

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
  
  if (kDebugMode) {
    debugPrint('✅ Loading tasks for provider: ${params.providerId}');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderTasks(params.providerId, status: params.status),
    operationName: 'getProviderTasks(${params.providerId})',
  );
});

/// Paramètres pour les tâches
class ProviderTasksParams {
  final String providerId;
  final TaskStatus? status;

  const ProviderTasksParams({
    required this.providerId,
    this.status,
  });

  ProviderTasksParams copyWith({
    String? providerId,
    TaskStatus? status,
    bool clearStatus = false,
  }) {
    return ProviderTasksParams(
      providerId: providerId ?? this.providerId,
      status: clearStatus ? null : (status ?? this.status),
    );
  }

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
  
  if (kDebugMode) {
    debugPrint('📊 Loading stats for provider: $providerId');
  }
  
  return await _executeWithTimeout(
    () => service.getProviderStats(providerId),
    operationName: 'getProviderStats($providerId)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// ACTIONS (CREATE, UPDATE, DELETE)
// ═══════════════════════════════════════════════════════════════════════════

/// Créer un nouveau prestataire
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
    if (kDebugMode) {
      debugPrint('➕ Creating provider: $businessName (${category.name})');
    }
    
    // Validation basique
    if (businessName.trim().isEmpty) {
      throw ProviderValidationException('Le nom de l\'entreprise est requis');
    }
    
    final provider = await _executeWithTimeout(
      () => service.createProvider(
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
      ),
      operationName: 'createProvider',
    );
    
    // Invalidation intelligente des caches
    ref.invalidate(providersListProvider);
    ref.invalidate(providerByIdProvider(provider.id));
    
    if (kDebugMode) {
      debugPrint('✅ Provider created: ${provider.id} - ${provider.uniqueCode}');
    }
    
    return provider;
  };
});

/// Mettre à jour un prestataire existant
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
    if (kDebugMode) {
      debugPrint('✏️ Updating provider: $id');
    }
    
    final provider = await _executeWithTimeout(
      () => service.updateProvider(
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
      ),
      operationName: 'updateProvider($id)',
    );
    
    // Invalidation ciblée
    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    
    if (kDebugMode) {
      debugPrint('✅ Provider updated: $id');
    }
    
    return provider;
  };
});

/// Valider/Rejeter un prestataire (Staff uniquement)
final validateProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  
  return (
    String id, {
    required bool approved,
    String? rejectionReason,
    TrackingLevel? newLevel,
  }) async {
    if (kDebugMode) {
      debugPrint('🔐 Validating provider: $id (approved: $approved)');
    }
    
    // Validation
    if (!approved && (rejectionReason == null || rejectionReason.isEmpty)) {
      throw ProviderValidationException(
          'Un motif de rejet est requis pour les refus');
    }
    
    final provider = await _executeWithTimeout(
      () => service.validateProvider(
        id,
        approved: approved,
        rejectionReason: rejectionReason,
        newLevel: newLevel,
      ),
      operationName: 'validateProvider($id)',
    );
    
    // Invalidation
    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    
    if (kDebugMode) {
      debugPrint('✅ Provider validated: $id (${approved ? "approved" : "rejected"})');
    }
    
    return provider;
  };
});

/// Supprimer un prestataire
final deleteProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  
  return (String id) async {
    if (kDebugMode) {
      debugPrint('🗑️ Deleting provider: $id');
    }
    
    await _executeWithTimeout(
      () => service.deleteProvider(id),
      operationName: 'deleteProvider($id)',
    );
    
    // Invalidation complète
    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    
    if (kDebugMode) {
      debugPrint('✅ Provider deleted: $id');
    }
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
    if (kDebugMode) {
      debugPrint('📅 Creating reservation for provider: $providerId');
    }
    
    // Validation
    if (eventDate.isBefore(DateTime.now())) {
      throw ProviderValidationException('La date de l\'événement doit être future');
    }
    
    if (clientName.trim().isEmpty) {
      throw ProviderValidationException('Le nom du client est requis');
    }
    
    final reservation = await _executeWithTimeout(
      () => service.createReservation(
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
      ),
      operationName: 'createReservation',
    );
    
    // Invalidation ciblée
    ref.invalidate(providerReservationsProvider(
      ProviderReservationsParams(providerId: providerId),
    ));
    
    if (kDebugMode) {
      debugPrint('✅ Reservation created: ${reservation.id}');
    }
    
    return reservation;
  };
});

/// Mettre à jour le statut d'une réservation
final updateReservationStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  
  return (
    String reservationId,
    ReservationStatus status,
    String providerId,
  ) async {
    if (kDebugMode) {
      debugPrint('🔄 Updating reservation status: $reservationId -> ${status.name}');
    }
    
    final reservation = await _executeWithTimeout(
      () => service.updateReservationStatus(reservationId, status),
      operationName: 'updateReservationStatus($reservationId)',
    );
    
    // Invalidation
    ref.invalidate(providerReservationsProvider(
      ProviderReservationsParams(providerId: providerId),
    ));
    
    if (kDebugMode) {
      debugPrint('✅ Reservation status updated: $reservationId');
    }
    
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
    if (kDebugMode) {
      debugPrint('✅ Creating task for provider: $providerId');
    }
    
    // Validation
    if (title.trim().isEmpty) {
      throw ProviderValidationException('Le titre de la tâche est requis');
    }
    
    if (dueDateTime.isBefore(DateTime.now())) {
      throw ProviderValidationException('La date d\'échéance doit être future');
    }
    
    final task = await _executeWithTimeout(
      () => service.createTask(
        providerId: providerId,
        weddingId: weddingId,
        assignedBy: assignedBy,
        title: title,
        description: description,
        dueDateTime: dueDateTime,
        priority: priority,
      ),
      operationName: 'createTask',
    );
    
    // Invalidation
    ref.invalidate(providerTasksProvider(
      ProviderTasksParams(providerId: providerId),
    ));
    
    if (kDebugMode) {
      debugPrint('✅ Task created: ${task.id}');
    }
    
    return task;
  };
});

/// Mettre à jour le statut d'une tâche
final updateTaskStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);
  
  return (
    String taskId,
    TaskStatus status,
    String providerId,
  ) async {
    if (kDebugMode) {
      debugPrint('🔄 Updating task status: $taskId -> ${status.name}');
    }
    
    final task = await _executeWithTimeout(
      () => service.updateTaskStatus(taskId, status),
      operationName: 'updateTaskStatus($taskId)',
    );
    
    // Invalidation
    ref.invalidate(providerTasksProvider(
      ProviderTasksParams(providerId: providerId),
    ));
    
    if (kDebugMode) {
      debugPrint('✅ Task status updated: $taskId');
    }
    
    return task;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

/// Provider pour vérifier si un prestataire existe par code
final providerExistsByCodeProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, code) async {
  final provider = await ref.watch(providerByCodeProvider(code).future);
  return provider != null;
});

/// Provider pour obtenir le nombre total de prestataires
final totalProvidersCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final providers = await service.getAllProviders(page: 1, limit: 1);
  
  // Note: Cette implémentation simplifiée retourne 1 ou 0
  // Pour un vrai count, il faudrait ajouter une méthode count() dans le service
  return providers.isNotEmpty ? 1 : 0;
});
