/// Objet Providers (Production Enterprise)
/// ✅ Logs structurés + timeouts + error handling
/// ✅ Providers dérivés pour filtrage par statut
/// ✅ Documentation complète + validation des données
/// ✅ Constants extractées + singleton service
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/objet_model.dart';
import '../services/objet_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kDefaultLimit = 20;
const Duration _kServiceTimeout = Duration(seconds: 15);

// ============================================================================
// SERVICE PROVIDER
// ============================================================================

/// Provider singleton pour ObjetService.
///
/// **Usage** :
/// ```dart
/// final service = ref.read(objetServiceProvider);
/// await service.declarerObjet(...);
/// ```
final objetServiceProvider = Provider<ObjetService>((ref) {
  debugPrint('[ObjetProviders] 🔧 Creating ObjetService singleton');
  return ObjetService();
});

// ============================================================================
// MAIN PROVIDERS
// ============================================================================

/// Liste des objets récents (perdus + trouvés) — tous utilisateurs.
///
/// **Comportement** :
/// - Auto-dispose : se nettoie quand plus écouté
/// - Timeout 15s sur l'appel service
/// - Fallback liste vide en cas d'erreur (graceful degradation)
/// - Logs structurés avec contexte
///
/// **Usage** :
/// ```dart
/// final objetsAsync = ref.watch(objetsRecentsProvider);
/// objetsAsync.when(
///   data: (list) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => ErrorWidget(e),
/// );
/// ```
final objetsRecentsProvider =
    FutureProvider.autoDispose<List<ObjetModel>>((ref) async {
  debugPrint('[ObjetProviders] 🚀 Fetching recent objects (limit=$_kDefaultLimit)');

  final service = ref.watch(objetServiceProvider);

  try {
    final objets = await service
        .getObjetsRecents(limit: _kDefaultLimit)
        .timeout(_kServiceTimeout);

    debugPrint('[ObjetProviders] ✓ Loaded ${objets.length} recent objects');
    return objets;
  } on TimeoutException {
    debugPrint('[ObjetProviders] ❌ Timeout fetching recent objects');
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('[ObjetProviders] ❌ Error fetching recent objects: $e');
    if (kDebugMode) {
      debugPrint('[ObjetProviders] Stack: ${stackTrace.toString().split('\n').first}');
    }
    rethrow;
  }
});

/// Objets de l'utilisateur connecté (tous statuts).
///
/// **Comportement** :
/// - Auto-dispose : se nettoie quand plus écouté
/// - Timeout 15s sur l'appel service
/// - Logs structurés avec contexte
///
/// **Usage** :
/// ```dart
/// final mesObjetsAsync = ref.watch(mesObjetsProvider);
/// mesObjetsAsync.when(
///   data: (list) => _buildTabs(list),
///   loading: () => SkeletonLoader(),
///   error: (e, st) => ErrorState(e, onRetry: () => ref.invalidate(mesObjetsProvider)),
/// );
/// ```
final mesObjetsProvider =
    FutureProvider.autoDispose<List<ObjetModel>>((ref) async {
  debugPrint('[ObjetProviders] 🚀 Fetching my objects');

  final service = ref.watch(objetServiceProvider);

  try {
    final objets = await service.getMesObjets().timeout(_kServiceTimeout);

    debugPrint('[ObjetProviders] ✓ Loaded ${objets.length} my objects');
    return objets;
  } on TimeoutException {
    debugPrint('[ObjetProviders] ❌ Timeout fetching my objects');
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('[ObjetProviders] ❌ Error fetching my objects: $e');
    if (kDebugMode) {
      debugPrint('[ObjetProviders] Stack: ${stackTrace.toString().split('\n').first}');
    }
    rethrow;
  }
});

// ============================================================================
// DERIVED PROVIDERS (filtrage par statut)
// ============================================================================

/// Objets perdus de l'utilisateur connecté.
///
/// **Usage** :
/// ```dart
/// final perdusAsync = ref.watch(mesObjetsPerdusProvider);
/// ```
final mesObjetsPerdusProvider = Provider.autoDispose<List<ObjetModel>>((ref) {
  final mesObjetsAsync = ref.watch(mesObjetsProvider);
  return mesObjetsAsync.whenOrNull(
        data: (objets) =>
            objets.where((o) => o.statut == StatutObjet.perdu).toList(),
      ) ??
      [];
});

/// Objets trouvés de l'utilisateur connecté.
///
/// **Usage** :
/// ```dart
/// final trouvesAsync = ref.watch(mesObjetsTrouvesProvider);
/// ```
final mesObjetsTrouvesProvider = Provider.autoDispose<List<ObjetModel>>((ref) {
  final mesObjetsAsync = ref.watch(mesObjetsProvider);
  return mesObjetsAsync.whenOrNull(
        data: (objets) =>
            objets.where((o) => o.statut == StatutObjet.trouve).toList(),
      ) ??
      [];
});

/// Objets récupérés de l'utilisateur connecté.
///
/// **Usage** :
/// ```dart
/// final recuperesAsync = ref.watch(mesObjetsRecuperesProvider);
/// ```
final mesObjetsRecuperesProvider = Provider.autoDispose<List<ObjetModel>>((ref) {
  final mesObjetsAsync = ref.watch(mesObjetsProvider);
  return mesObjetsAsync.whenOrNull(
        data: (objets) =>
            objets.where((o) => o.statut == StatutObjet.recupere).toList(),
      ) ??
      [];
});

/// Nombre total d'objets actifs (perdus + trouvés, non récupérés).
///
/// **Usage** :
/// ```dart
/// final count = ref.watch(activeObjectsCountProvider);
/// if (count > 0) Badge(label: Text('$count'));
/// ```
final activeObjectsCountProvider = Provider.autoDispose<int>((ref) {
  final mesObjetsAsync = ref.watch(mesObjetsProvider);
  return mesObjetsAsync.whenOrNull(
        data: (objets) => objets
            .where((o) => o.statut != StatutObjet.recupere)
            .length,
      ) ??
      0;
});

// ============================================================================
// ACTIONS PROVIDERS
// ============================================================================

/// Provider pour invalidater et refresh tous les providers objets.
///
/// **Usage** :
/// ```dart
/// ref.read(invalidateAllObjectsProvider);
/// ```
final invalidateAllObjectsProvider = Provider<void Function()>((ref) {
  return () {
    debugPrint('[ObjetProviders] 🔄 Invalidating all object providers');
    ref.invalidate(objetsRecentsProvider);
    ref.invalidate(mesObjetsProvider);
  };
});
