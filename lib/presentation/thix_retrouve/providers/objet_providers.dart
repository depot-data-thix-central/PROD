import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/objet_model.dart';
import '../services/objet_service.dart';

/// Instance du service
final objetServiceProvider = Provider<ObjetService>((ref) {
  return ObjetService();
});

/// Liste des objets récents (perdus + trouvés)
final objetsRecentsProvider = FutureProvider.autoDispose<List<ObjetModel>>((ref) async {
  final service = ref.watch(objetServiceProvider);
  return service.getObjetsRecents(limit: 20);
});

/// Objets de l'utilisateur connecté
final mesObjetsProvider = FutureProvider.autoDispose<List<ObjetModel>>((ref) async {
  final service = ref.watch(objetServiceProvider);
  return service.getMesObjets();
});

/// Provider pour déclarer un objet
final declarerObjetProvider = Provider<ObjetService>((ref) {
  return ref.watch(objetServiceProvider);
});
