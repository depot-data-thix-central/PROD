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

// ─────────────────────────────────────────────────────────
// --- NOUVEAU : AJOUTS POUR LA RECHERCHE À PROXIMITÉ ---
// ─────────────────────────────────────────────────────────

class NearbyParams {
  final double lat;
  final double lng;
  final double radiusKm;

  const NearbyParams({
    required this.lat,
    required this.lng,
    this.radiusKm = 25.0, // Rayon par défaut
  });

  // Requis par Riverpod "family" pour identifier des paramètres identiques
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NearbyParams &&
          other.lat == lat &&
          other.lng == lng &&
          other.radiusKm == radiusKm);

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm);
}

/// Provider pour récupérer les alertes autour d'une position GPS
final nearbyAlertesProvider = FutureProvider.autoDispose
    .family<List<PersonneRecherchee>, NearbyParams>((ref, params) async {
  
  final service = ref.watch(rechercheServiceProvider); // Utilise ton service existant
  
  return service.getAlertesProximite(
    lat: params.lat,
    lng: params.lng,
    radiusKm: params.radiusKm,
  );
});
