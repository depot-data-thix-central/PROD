import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'delivery_provider.dart';

class PickupPointsPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onPointSelected;

  const PickupPointsPage({super.key, this.onPointSelected});

  @override
  State<PickupPointsPage> createState() => _PickupPointsPageState();
}

class _PickupPointsPageState extends State<PickupPointsPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;

  // ─── Couleurs de la marque THIX ───
  static const Color thixOrange = Color(0xFFE5592F);
  static const Color darkText = Color(0xFF10192E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      provider.loadNearbyPickupPoints();
      
      if (provider.currentPosition != null) {
        setState(() {
          _userLocation = LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude);
        });
      }
    });
  }

  void _onMapCreated(GoogleMapController controller, DeliveryProvider provider) {
    _mapController = controller;
    if (_userLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 13));
    }
  }

  // ─── GÉNÉRATION DYNAMIQUE DES MARQUEURS ───
  Set<Marker> _buildMarkers(DeliveryProvider provider) {
    final Set<Marker> markers = {};

    // Marqueur du client
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Votre position'),
        ),
      );
    }

    // Marqueurs des points relais
    for (var point in provider.pickupPoints) {
      final lat = point['latitude'] as double;
      final lng = point['longitude'] as double;
      markers.add(
        Marker(
          markerId: MarkerId(point['id'].toString()),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), // Couleur THIX
          infoWindow: InfoWindow(title: point['name'], snippet: point['address']),
          onTap: () => _showPointDetails(point),
        ),
      );
    }
    return markers;
  }

  // ─── POP-UP DÉTAILS DU POINT RELAIS ───
  void _showPointDetails(Map<String, dynamic> point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: thixOrange.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_rounded, color: thixOrange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText)),
                      const SizedBox(height: 4),
                      Text('${(point['distance_km'] as num?)?.toStringAsFixed(1)} km de vous', style: const TextStyle(color: thixOrange, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: Text(point['address'], style: const TextStyle(fontSize: 14, height: 1.4, color: darkText))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Text(point['opening_hours'] ?? '08h00 - 18h00', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkText)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                widget.onPointSelected?.call(point);
                Navigator.pop(context); // Ferme la modal
                Navigator.pop(context); // Retourne au processus d'achat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: thixOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Livrer à ce point relais', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // La carte passe sous l'AppBar
      appBar: AppBar(
        title: const Text('Points relais THIX', style: TextStyle(fontWeight: FontWeight.w800, color: darkText)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkText),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) => _onMapCreated(controller, provider),
                initialCameraPosition: CameraPosition(
                  target: _userLocation ?? const LatLng(-4.322447, 15.307045), // Centre sur Kinshasa
                  zoom: 13,
                ),
                markers: _buildMarkers(provider),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false, // Épure l'interface
              ),
              
              if (provider.isLoadingPickupPoints)
                const Center(child: CircularProgressIndicator(color: thixOrange)),

              // ─── PANNEAU FLOTTANT DES RÉSULTATS ───
              if (!provider.isLoadingPickupPoints && provider.pickupPoints.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: thixOrange, size: 20),
                              SizedBox(width: 8),
                              Text('Points relais à proximité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: darkText)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(), // Empêche le double-scroll
                          itemCount: provider.pickupPoints.take(3).length, // Affiche les 3 plus proches
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final point = provider.pickupPoints[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(point['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: darkText)),
                              subtitle: Text('${(point['distance_km'] as num?)?.toStringAsFixed(1)} km', style: const TextStyle(color: thixOrange, fontSize: 13, fontWeight: FontWeight.w600)),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                                child: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                              ),
                              onTap: () => _showPointDetails(point), // Ouvre le pop-up
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
