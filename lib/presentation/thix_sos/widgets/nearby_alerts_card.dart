import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thix_id/presentation/thix_sos/providers/sos_providers.dart';

import 'package:thix_id/presentation/thix_recherche/models/personne_recherchee_model.dart';
import 'package:thix_id/presentation/thix_recherche/providers/recherche_providers.dart';

class NearbyAlertsCard extends ConsumerWidget {
  const NearbyAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(sosUserPositionProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ALERTES À PROXIMITÉ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // carte plein écran ou go RECHERCHE
                  // context.push('/thix-recherche');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF60A5FA),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Voir sur la carte',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          posAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFEF4444)),
              ),
            ),
            error: (e, _) => const _InfoBox('Position indisponible'),
            data: (pos) {
              if (pos == null) {
                return const _InfoBox('Active la localisation pour voir les alertes proches');
              }
              final nearbyAsync = ref.watch(
                nearbyAlertesProvider(
                  NearbyParams(lat: pos.lat, lng: pos.lng),
                ),
              );
              return nearbyAsync.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFEF4444)),
                  ),
                ),
                error: (e, _) => _InfoBox('Erreur: $e'),
                data: (list) => _MapBlock(
                  lat: pos.lat,
                  lng: pos.lng,
                  alertes: list,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.lat,
    required this.lng,
    required this.alertes,
  });

  final double lat;
  final double lng;
  final List<PersonneRecherchee> alertes;

  @override
  Widget build(BuildContext context) {
    final disparues =
        alertes.where((a) => a.typeAlerte == TypeAlerte.disparue).length;
    final officiels =
        alertes.where((a) => a.typeAlerte == TypeAlerte.recherchee).length;

    // Je laisse la logique des marqueurs au cas où, 
    // mais elle n'est pas utilisée pour le moment.
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      for (final a in alertes)
        if (a.latitude != null && a.longitude != null)
          Marker(
            markerId: MarkerId(a.id),
            position: LatLng(a.latitude!, a.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              a.typeAlerte == TypeAlerte.disparue
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(title: a.nomComplet, snippet: a.badgeLabel),
          ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            child: Stack(
              children: [
                // ---------------------------------------------------------
                // MAP DÉSACTIVÉE TEMPORAIREMENT POUR ÉVITER LE CRASH
                // ---------------------------------------------------------
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: const Color(0xFF1E1E26), // Couleur de fond neutre
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.white24, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Carte désactivée\n(En attente de clé API)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // ---------------------------------------------------------
                
                // Overlay contenant les statistiques
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alertes.length} alertes actives',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF87171),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$disparues disparues · $officiels officiels',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const _Legend(color: Color(0xFFEF4444), label: 'Disparue'),
            const SizedBox(width: 12),
            const _Legend(color: Color(0xFF3B82F6), label: 'Avis officiel'),
            const SizedBox(width: 12),
            const _Legend(color: Color(0xFFF59E0B), label: 'Signalement'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
      ),
    );
  }
}
