// lib/presentation/thix_weeding/providers/provider_providers.dart
// ============================================================================
// THIX WEDDING PROVIDER RIVERPOD PROVIDERS (PRODUCTION v7 — MULTI-CATÉGORIES OFFRES)
// ✅ 1 compte (owner_id) = PLUSIEURS activités/métiers (traiteur, salle, DJ…)
// ✅ myProviderProvider(ownerId) = activité sélectionnée (fallback principale)
// ✅ selectedActivityIdProvider = sélecteur global (barre du shell)
// ✅ myActivitiesProvider / activityDetailProvider / CRUD activités
// ✅ createProvider / update / delete / validate / offres / réservations / tâches
// ✅ OFFRES : galleryUrls (multi-photos) + categories[] (1 à 3 catégories d'offre)
// ✅ ZÉRO doublon — chaque provider déclaré une seule fois
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/provider_models.dart';
import '../services/provider_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TYPES D'ERREURS PERSONNALISÉS
// ═══════════════════════════════════════════════════════════════════════════

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
    if (code != null) return 'ProviderException[$code]: $message';
    return 'ProviderException: $message';
  }
}

class ProviderTimeoutException extends ProviderException {
  ProviderTimeoutException(String message)
      : super(message: message, code: 'TIMEOUT');
}

class ProviderNetworkException extends ProviderException {
  ProviderNetworkException(String message, {dynamic originalError})
      : super(
            message: message,
            code: 'NETWORK_ERROR',
            originalError: originalError);
}

class ProviderValidationException extends ProviderException {
  ProviderValidationException(String message)
      : super(message: message, code: 'VALIDATION_ERROR');
}

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
// WRAPPER TIMEOUT
// ═══════════════════════════════════════════════════════════════════════════
Future<T> _executeWithTimeout<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 30),
  String operationName = 'operation',
}) async {
  try {
    return await operation().timeout(timeout);
  } on TimeoutException {
    throw ProviderTimeoutException('Opération "$operationName" trop longue');
  } on ProviderException {
    rethrow;
  } catch (e, stack) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Network')) {
      throw ProviderNetworkException('Erreur réseau', originalError: e);
    }
    if (msg.contains('not found') || msg.contains('404')) {
      throw ProviderNotFoundException('Données introuvables');
    }
    throw ProviderException(
      message: 'Erreur inattendue: $msg',
      code: 'UNKNOWN',
      originalError: e,
      stackTrace: stack,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : SÉLECTEUR GLOBAL
// ═══════════════════════════════════════════════════════════════════════════
/// ID de l'activité actuellement ouverte dans le shell prestataire.
/// null => on retombe sur la principale / 1ère (rétro-compat mono-activité)
final selectedActivityIdProvider = StateProvider<String?>((ref) => null);

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : LISTE DES ACTIVITÉS D'UN COMPTE
// ═══════════════════════════════════════════════════════════════════════════
final myActivitiesProvider = FutureProvider.autoDispose
    .family<List<ThixProviderModel>, String>((ref, ownerId) async {
  if (kDebugMode) {
    debugPrint('🧩 [myActivitiesProvider] Loading activities for owner: $ownerId');
  }

  return await _executeWithTimeout(
    () async {
      final res = await Supabase.instance.client
          .from('thix_weeding_providers')
          .select()
          .eq('owner_id', ownerId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res)
          .map((e) => ThixProviderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    },
    operationName: 'getAllByOwner($ownerId)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : DÉTAIL D'UNE ACTIVITÉ
// ═══════════════════════════════════════════════════════════════════════════
final activityDetailProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, activityId) async {
  if (kDebugMode) {
    debugPrint('🔎 [activityDetailProvider] Loading activity: $activityId');
  }

  return await _executeWithTimeout(
    () async {
      final res = await Supabase.instance.client
          .from('thix_weeding_providers')
          .select()
          .eq('id', activityId)
          .maybeSingle();
      if (res == null) return null;
      return ThixProviderModel.fromJson(Map<String, dynamic>.from(res));
    },
    operationName: 'getActivityById($activityId)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 👤 ACTIVITÉ COURANTE (shell + formulaires)
//    Renvoie l'activité sélectionnée, sinon la principale/1ère.
//    MÊME signature <ThixProviderModel?, String> => AUCUN call-site cassé.
// ═══════════════════════════════════════════════════════════════════════════
final myProviderProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, ownerId) async {
  if (kDebugMode) {
    debugPrint('👤 [myProviderProvider] Resolving active activity for owner: $ownerId');
  }

  final activities = await ref.watch(myActivitiesProvider(ownerId).future);
  if (activities.isEmpty) return null;

  final sel = ref.watch(selectedActivityIdProvider);
  if (sel != null) {
    final match = activities.where((a) => a.id == sel);
    if (match.isNotEmpty) return match.first;
  }
  return activities.first;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📋 LISTE PUBLIQUE DES PRESTATAIRES (catalogue)
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
  int get hashCode =>
      Object.hash(page, limit, category, level, city, isAvailable, search);
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔍 PRESTATAIRE PAR ID (page détail catalogue)
// ═══════════════════════════════════════════════════════════════════════════
final providerByIdProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, id) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) debugPrint('🔍 Loading provider by ID: $id');
  return await _executeWithTimeout(
    () => service.getProviderById(id),
    operationName: 'getProviderById($id)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 🔍 PRESTATAIRE PAR CODE UNIQUE (THIX-P-XXXYY)
// ═══════════════════════════════════════════════════════════════════════════
final providerByCodeProvider = FutureProvider.autoDispose
    .family<ThixProviderModel?, String>((ref, code) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) debugPrint('🔍 Loading provider by code: $code');
  return await _executeWithTimeout(
    () => service.getProviderByCode(code),
    operationName: 'getProviderByCode($code)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 📅 RÉSERVATIONS D'UN PRESTATAIRE (activité spécifique)
// ═══════════════════════════════════════════════════════════════════════════
final providerReservationsProvider = FutureProvider.autoDispose
    .family<List<ProviderReservationModel>, ProviderReservationsParams>(
        (ref, params) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) {
    debugPrint('📅 Loading reservations for provider: ${params.providerId}');
  }
  return await _executeWithTimeout(
    () => service.getProviderReservations(params.providerId,
        status: params.status),
    operationName: 'getProviderReservations(${params.providerId})',
  );
});

class ProviderReservationsParams {
  final String providerId;
  final ReservationStatus? status;
  const ProviderReservationsParams({required this.providerId, this.status});

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
// ✅ TÂCHES D'UN PRESTATAIRE
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

class ProviderTasksParams {
  final String providerId;
  final TaskStatus? status;
  const ProviderTasksParams({required this.providerId, this.status});

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
// 📊 STATISTIQUES D'UN PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final providerStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, providerId) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) debugPrint('📊 Loading stats for provider: $providerId');
  return await _executeWithTimeout(
    () => service.getProviderStats(providerId),
    operationName: 'getProviderStats($providerId)',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 🎁 OFFRES / SERVICES (avec jointure provider)
// ═══════════════════════════════════════════════════════════════════════════
final providerOffersProvider = FutureProvider.autoDispose
    .family<List<ProviderOfferModel>, String>((ref, providerId) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) debugPrint('🎁 Loading offers for provider: $providerId');
  return await _executeWithTimeout(
    () => service.getOffersByProvider(providerId),
    operationName: 'getOffersByProvider($providerId)',
  );
});

// ✅ OFFRES ACTIVES (home + catalogue) — filtre catégorie optionnel
//    null = toutes catégories, sinon filtre côté serveur
final activeOffersProvider =
    FutureProvider.autoDispose.family<List<ProviderOfferModel>, ProviderCategory?>((ref, category) async {
  final service = ref.watch(providerServiceProvider);
  if (kDebugMode) {
    debugPrint('🌟 Loading active offers (home/catalog) category=${category?.name ?? "all"}');
  }
  return await _executeWithTimeout(
    () => service.getActiveOffersWithProvider(limit: 100, category: category),
    operationName: 'getActiveOffersWithProvider',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// ➕ CRÉATION PRESTATAIRE "HISTORIQUE" (1 fiche, enum category)
// ═══════════════════════════════════════════════════════════════════════════
final createProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return ({
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
    if (kDebugMode) {
      debugPrint('➕ Creating provider: $businessName (owner: $ownerId)');
    }
    if (businessName.trim().isEmpty) {
      throw ProviderValidationException('Le nom de l\'entreprise est requis');
    }

    final provider = await _executeWithTimeout(
      () => service.createProvider(
        ownerId: ownerId,
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

    ref.invalidate(myProviderProvider(ownerId));
    ref.invalidate(myActivitiesProvider(ownerId));
    ref.invalidate(providersListProvider);
    ref.invalidate(providerByIdProvider(provider.id));

    if (kDebugMode) {
      debugPrint('✅ Provider created: ${provider.id} - ${provider.uniqueCode}');
    }
    return provider;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : CRÉER UNE NOUVELLE ACTIVITÉ (category = String)
//    1ère activité du compte => is_primary = true automatiquement
// ═══════════════════════════════════════════════════════════════════════════
final createActivityProvider = Provider((ref) {
  return ({
    required String ownerId,
    required String businessName,
    required String category,
    String? description,
    String? phone,
    String? email,
    String? city,
  }) async {
    if (businessName.trim().isEmpty) {
      throw ProviderValidationException('Le nom commercial est requis');
    }
    if (category.trim().isEmpty) {
      throw ProviderValidationException('Choisissez un métier (catégorie)');
    }

    final c = Supabase.instance.client;

    final existing = await c
        .from('thix_weeding_providers')
        .select('id')
        .eq('owner_id', ownerId)
        .limit(1);
    final isFirst = (existing as List).isEmpty;

    final res = await c
        .from('thix_weeding_providers')
        .insert({
          'owner_id': ownerId,
          'business_name': businessName.trim(),
          'category': category.trim().toLowerCase(),
          'description':
              (description ?? '').trim().isEmpty ? null : description!.trim(),
          'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
          'email': (email ?? '').trim().isEmpty ? null : email!.trim(),
          'city': (city ?? '').trim().isEmpty ? null : city!.trim(),
          'is_primary': isFirst,
          'verification_status': 'pending',
        })
        .select()
        .single();

    final model =
        ThixProviderModel.fromJson(Map<String, dynamic>.from(res));

    ref.invalidate(myActivitiesProvider(ownerId));
    ref.invalidate(myProviderProvider(ownerId));
    ref.invalidate(providersListProvider);

    if (kDebugMode) {
      debugPrint('🧩 Activity created: ${model.id} (${model.category})');
    }
    return model;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : METTRE À JOUR UNE ACTIVITÉ
// ═══════════════════════════════════════════════════════════════════════════
final updateActivityProvider = Provider((ref) {
  return (
    String activityId, {
    String? ownerId,
    String? businessName,
    String? category,
    String? description,
    String? phone,
    String? email,
    String? city,
  }) async {
    final patch = <String, dynamic>{};
    if (businessName != null) patch['business_name'] = businessName.trim();
    if (category != null) patch['category'] = category.trim().toLowerCase();
    if (description != null) {
      patch['description'] =
          description.trim().isEmpty ? null : description.trim();
    }
    if (phone != null) {
      patch['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (email != null) {
      patch['email'] = email.trim().isEmpty ? null : email.trim();
    }
    if (city != null) {
      patch['city'] = city.trim().isEmpty ? null : city.trim();
    }

    if (patch.isEmpty) return null;

    final res = await Supabase.instance.client
        .from('thix_weeding_providers')
        .update(patch)
        .eq('id', activityId)
        .select()
        .single();
    final model =
        ThixProviderModel.fromJson(Map<String, dynamic>.from(res));

    ref.invalidate(activityDetailProvider(activityId));
    ref.invalidate(providerByIdProvider(activityId));
    ref.invalidate(providersListProvider);
    if (ownerId != null) {
      ref.invalidate(myActivitiesProvider(ownerId));
      ref.invalidate(myProviderProvider(ownerId));
    }
    return model;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : SUPPRIMER UNE ACTIVITÉ
// ═══════════════════════════════════════════════════════════════════════════
final deleteActivityProvider = Provider((ref) {
  return (String activityId, {String? ownerId}) async {
    await Supabase.instance.client
        .from('thix_weeding_providers')
        .delete()
        .eq('id', activityId);

    if (ref.read(selectedActivityIdProvider) == activityId) {
      ref.read(selectedActivityIdProvider.notifier).state = null;
    }

    ref.invalidate(activityDetailProvider(activityId));
    ref.invalidate(providerByIdProvider(activityId));
    ref.invalidate(providersListProvider);
    if (ownerId != null) {
      ref.invalidate(myActivitiesProvider(ownerId));
      ref.invalidate(myProviderProvider(ownerId));
    }
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 MULTI-ACTIVITÉS : DÉFINIR ACTIVITÉ PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
final setPrimaryActivityProvider = Provider((ref) {
  return (String activityId, {String? ownerId}) async {
    final c = Supabase.instance.client;
    final row = await c
        .from('thix_weeding_providers')
        .select('owner_id')
        .eq('id', activityId)
        .single();
    final oid = ownerId ?? (row['owner_id'] as String);

    await c
        .from('thix_weeding_providers')
        .update({'is_primary': false})
        .eq('owner_id', oid);
    await c
        .from('thix_weeding_providers')
        .update({'is_primary': true})
        .eq('id', activityId);

    ref.invalidate(myActivitiesProvider(oid));
    ref.invalidate(myProviderProvider(oid));
    ref.invalidate(activityDetailProvider(activityId));
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// ✏️ MISE À JOUR PRESTATAIRE HISTORIQUE
// ═══════════════════════════════════════════════════════════════════════════
final updateProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (
    String id, {
    String? ownerId,
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
    if (kDebugMode) debugPrint('✏️ Updating provider: $id');

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

    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    if (ownerId != null) {
      ref.invalidate(myProviderProvider(ownerId));
      ref.invalidate(myActivitiesProvider(ownerId));
    }
    return provider;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🔐 VALIDATION PAR LE STAFF
// ═══════════════════════════════════════════════════════════════════════════
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
    if (!approved && (rejectionReason == null || rejectionReason.isEmpty)) {
      throw ProviderValidationException('Un motif de rejet est requis');
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

    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    return provider;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🗑️ SUPPRESSION PRESTATAIRE
// ═══════════════════════════════════════════════════════════════════════════
final deleteProviderProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (String id, {String? ownerId}) async {
    if (kDebugMode) debugPrint('🗑️ Deleting provider: $id');

    await _executeWithTimeout(
      () => service.deleteProvider(id),
      operationName: 'deleteProvider($id)',
    );

    ref.invalidate(providerByIdProvider(id));
    ref.invalidate(providersListProvider);
    if (ownerId != null) {
      ref.invalidate(myProviderProvider(ownerId));
      ref.invalidate(myActivitiesProvider(ownerId));
    }
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🎁 ACTIONS OFFRES (v7 : galleryUrls + categories[] multi-catégories)
// ═══════════════════════════════════════════════════════════════════════════
final createOfferProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return ({
    required String providerId,
    required String title,
    required OfferType type,
    String? description,
    double? price,
    String? currency,
    String? imageUrl,
    List<String>? galleryUrls,
    ProviderCategory? category,
    List<ProviderCategory>? categories,  // ✅ MULTI-CATÉGORIES
    bool isActive = true,
  }) async {
    if (kDebugMode) {
      debugPrint('🎁 Creating offer: $title (categories: ${categories?.map((c) => c.name).toList() ?? category?.name})');
    }

    final offer = await _executeWithTimeout(
      () => service.createOffer(
        providerId: providerId,
        title: title,
        type: type,
        description: description,
        price: price,
        currency: currency,
        imageUrl: imageUrl,
        galleryUrls: galleryUrls,
        category: category,
        categories: categories,  // ✅ transmis au service
        isActive: isActive,
      ),
      operationName: 'createOffer',
    );

    ref.invalidate(providerOffersProvider(providerId));
    ref.invalidate(activeOffersProvider(null));  // ✅ family provider
    return offer;
  };
});

final updateOfferProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (
    String offerId,
    String providerId, {
    String? title,
    OfferType? type,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? galleryUrls,
    ProviderCategory? category,
    List<ProviderCategory>? categories,  // ✅ MULTI-CATÉGORIES
    bool? isActive,
  }) async {
    if (kDebugMode) {
      debugPrint('✏️ Updating offer: $offerId (categories: ${categories?.map((c) => c.name).toList() ?? category?.name})');
    }

    final offer = await _executeWithTimeout(
      () => service.updateOffer(
        offerId,
        title: title,
        type: type,
        description: description,
        price: price,
        imageUrl: imageUrl,
        galleryUrls: galleryUrls,
        category: category,
        categories: categories,  // ✅ transmis au service
        isActive: isActive,
      ),
      operationName: 'updateOffer($offerId)',
    );

    ref.invalidate(providerOffersProvider(providerId));
    ref.invalidate(activeOffersProvider(null));  // ✅ family provider
    return offer;
  };
});

final deleteOfferProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (String offerId, String providerId) async {
    if (kDebugMode) debugPrint('🗑️ Deleting offer: $offerId');

    await _executeWithTimeout(
      () => service.deleteOffer(offerId),
      operationName: 'deleteOffer($offerId)',
    );

    ref.invalidate(providerOffersProvider(providerId));
    ref.invalidate(activeOffersProvider(null));  // ✅ family provider
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 📅 ACTIONS RÉSERVATIONS
// ═══════════════════════════════════════════════════════════════════════════
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
    if (eventDate.isBefore(DateTime.now())) {
      throw ProviderValidationException('La date doit être future');
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

    ref.invalidate(providerReservationsProvider(
      ProviderReservationsParams(providerId: providerId),
    ));
    return reservation;
  };
});

final updateReservationStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (
    String reservationId,
    ReservationStatus status,
    String providerId,
  ) async {
    if (kDebugMode) {
      debugPrint('🔄 Updating reservation: $reservationId -> ${status.name}');
    }

    final reservation = await _executeWithTimeout(
      () => service.updateReservationStatus(reservationId, status),
      operationName: 'updateReservationStatus($reservationId)',
    );

    ref.invalidate(providerReservationsProvider(
      ProviderReservationsParams(providerId: providerId),
    ));
    return reservation;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// ✅ ACTIONS TÂCHES
// ═══════════════════════════════════════════════════════════════════════════
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
    if (title.trim().isEmpty) {
      throw ProviderValidationException('Le titre est requis');
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

    ref.invalidate(providerTasksProvider(
      ProviderTasksParams(providerId: providerId),
    ));
    return task;
  };
});

final updateTaskStatusProvider = Provider((ref) {
  final service = ref.read(providerServiceProvider);

  return (String taskId, TaskStatus status, String providerId) async {
    if (kDebugMode) {
      debugPrint('🔄 Updating task: $taskId -> ${status.name}');
    }

    final task = await _executeWithTimeout(
      () => service.updateTaskStatus(taskId, status),
      operationName: 'updateTaskStatus($taskId)',
    );

    ref.invalidate(providerTasksProvider(
      ProviderTasksParams(providerId: providerId),
    ));
    return task;
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════
final providerExistsByCodeProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, code) async {
  final provider = await ref.watch(providerByCodeProvider(code).future);
  return provider != null;
});

final totalProvidersCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(providerServiceProvider);
  final providers = await service.getAllProviders(page: 1, limit: 1);
  return providers.isNotEmpty ? 1 : 0;
});
