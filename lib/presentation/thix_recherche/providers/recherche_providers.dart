import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/personne_recherchee_model.dart';
import '../services/recherche_service.dart';

final rechercheServiceProvider = Provider<RechercheService>((ref) {
  return RechercheService();
});

/// Filtre onglet : null = toutes, disparue / recherchee
final rechercheFiltreProvider = StateProvider<TypeAlerte?>((ref) => null);

/// Liste alertes actives (Future)
final alertesActivesProvider =
    FutureProvider.autoDispose<List<PersonneRecherchee>>((ref) async {
  final service = ref.watch(rechercheServiceProvider);
  final filtre = ref.watch(rechercheFiltreProvider);
  return service.getAlertesActives(type: filtre, limit: 50);
});

/// Stream temps réel
final alertesStreamProvider =
    StreamProvider.autoDispose<List<PersonneRecherchee>>((ref) {
  final service = ref.watch(rechercheServiceProvider);
  final filtre = ref.watch(rechercheFiltreProvider);
  return service.watchAlertesActives(type: filtre);
});

final personneDetailProvider =
    FutureProvider.autoDispose.family<PersonneRecherchee?, String>((ref, id) {
  return ref.watch(rechercheServiceProvider).getById(id);
});

final mesAlertesProvider =
    FutureProvider.autoDispose<List<PersonneRecherchee>>((ref) async {
  return ref.watch(rechercheServiceProvider).getMesAlertes();
});
