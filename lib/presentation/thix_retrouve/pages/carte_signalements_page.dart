import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/objet_model.dart';
import '../providers/objet_providers.dart';
import 'object_detail_page.dart';

class CarteSignalementsPage extends ConsumerStatefulWidget {
  const CarteSignalementsPage({super.key});

  @override
  ConsumerState<CarteSignalementsPage> createState() => _CarteSignalementsPageState();
}

class _CarteSignalementsPageState extends ConsumerState<CarteSignalementsPage> {
  GoogleMapController? _mapController;
  bool _showPerdus = true;
  bool _showTrouves = true;
  ObjetModel? _selected;

  // Position par défaut (Kinshasa / ajuste selon ta zone)
  static const LatLng _defaultCenter = LatLng(-4.325, 15.322);

  @override
  Widget build(BuildContext context) {
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Carte des signalements',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
            onPressed: () => ref.invalidate(objetsRecentsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Légende ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _legendItem(Colors.red, 'Perdus', _showPerdus, () {
                  setState(() => _showPerdus = !_showPerdus);
                }),
                const SizedBox(width: 16),
                _legendItem(Colors.green, 'Trouvés', _showTrouves, () {
                  setState(() => _showTrouves = !_showTrouves);
                }),
                const Spacer(),
                _legendItem(const Color(0xFF2563EB), 'Vous', true, null),
              ],
            ),
          ),

          // ── Carte ─────────────────────────────────────────────
          Expanded(
            child: objetsAsync.when(
              data: (objets) {
                final filtered = objets.where((o) {
                  if (o.statut == StatutObjet.perdu && !_showPerdus) return false;
                  if (o.statut == StatutObjet.trouve && !_showTrouves) return false;
                  if (o.statut == StatutObjet.recupere) return false;
                  return true;
                }).toList();

                final markers = _buildMarkers(filtered);

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _defaultCenter,
                        zoom: 13,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      markers: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onTap: (_) => setState(() => _selected = null),
                    ),

                    // Carte flottante objet sélectionné
                    if (_selected != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: _buildSelectedCard(_selected!),
                      ),

                    // Liste horizontale en bas
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomList(filtered),
                    ),

                    // Bouton ma position
                    Positioned(
                      bottom: 190,
                      right: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.white,
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_defaultCenter, 14),
                          );
                        },
                        child: const Icon(Icons.my_location, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 8),
                    Text('Erreur carte', style: GoogleFonts.inter(color: Colors.red)),
                    TextButton(
                      onPressed: () => ref.invalidate(objetsRecentsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Markers Google Maps ───────────────────────────────────────
  Set<Marker> _buildMarkers(List<ObjetModel> objets) {
    final markers = <Marker>{};

    // Positions de secours si pas de lat/lng (réparties autour du centre)
    final fallbacks = [
      const LatLng(-4.320, 15.310),
      const LatLng(-4.330, 15.335),
      const LatLng(-4.315, 15.325),
      const LatLng(-4.340, 15.315),
      const LatLng(-4.325, 15.340),
      const LatLng(-4.310, 15.300),
      const LatLng(-4.335, 15.350),
      const LatLng(-4.345, 15.305),
    ];

    for (var i = 0; i < objets.length; i++) {
      final obj = objets[i];
      final isLost = obj.statut == StatutObjet.perdu;

      LatLng position;
      if (obj.latitude != null && obj.longitude != null) {
        position = LatLng(obj.latitude!, obj.longitude!);
      } else {
        position = fallbacks[i % fallbacks.length];
      }

      markers.add(
        Marker(
          markerId: MarkerId(obj.id),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isLost ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: obj.titre,
            snippet: '${obj.statutLabel} • ${obj.lieu}',
          ),
          onTap: () {
            setState(() => _selected = obj);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(position, 15),
            );
          },
        ),
      );
    }

    return markers;
  }

  // ── Carte objet sélectionné ───────────────────────────────────
  Widget _buildSelectedCard(ObjetModel obj) {
    final isLost = obj.statut == StatutObjet.perdu;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ObjectDetailPage(
                title: obj.titre,
                status: obj.statutLabel,
                location: obj.lieu,
                time: _formatDate(obj.date),
                description: obj.description,
                reward: obj.recompense ?? '',
                imageUrl: obj.imageUrl,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isLost ? Colors.red : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obj.titre,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${obj.statutLabel} • ${_formatDate(obj.date)} • ${obj.lieu}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste horizontale ─────────────────────────────────────────
  Widget _buildBottomList(List<ObjetModel> objets) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              // CORRECTION 1 ICI : Utilisation des double-guillemets (" ") et des symboles $ corrects
              "${objets.length} objet${objets.length > 1 ? 's' : ''} autour de vous",
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: objets.isEmpty
                ? Center(
                    child: Text(
                      'Aucun objet pour le moment',
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: objets.length,
                    itemBuilder: (context, index) {
                      final obj = objets[index];
                      final isLost = obj.statut == StatutObjet.perdu;
                      final isSelected = _selected?.id == obj.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selected = obj);
                          if (obj.latitude != null && obj.longitude != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(obj.latitude!, obj.longitude!),
                                15,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 10, bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isLost ? Colors.red : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    obj.statutLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isLost ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                obj.titre,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                obj.lieu,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: active ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: active ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    // CORRECTION 2 ICI : Remplacement des \( \) par des $
    final timeStr = '${date.hour}h${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) return 'Aujourd\'hui, $timeStr';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Hier, $timeStr';
    // CORRECTION 3 ICI AUSSI
    return '${date.day}/${date.month}/${date.year}';
  }
}
