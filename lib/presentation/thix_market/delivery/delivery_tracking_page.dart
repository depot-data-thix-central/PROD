import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'delivery_provider.dart'; // Assure-toi que ce fichier exporte bien ton `final deliveryProvider = ...`

class DeliveryTrackingPage extends ConsumerStatefulWidget {
  final String orderId;
  const DeliveryTrackingPage({super.key, required this.orderId});

  @override
  ConsumerState<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends ConsumerState<DeliveryTrackingPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng? _currentLocation;

  static const Color thixOrange = Color(0xFFE5592F);
  static const Color darkText = Color(0xFF10192E);
  static const Color mutedText = Color(0xFF7386A8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Appel de l'action via Riverpod
      ref.read(deliveryProvider).trackDelivery(widget.orderId);
    });
  }

  double? _safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void _updateMap(Map<String, dynamic> tracking) {
    final driver = tracking['driver'] as Map<String, dynamic>?;
    final driverLat = _safeDouble(driver?['current_lat'] ?? tracking['driver_lat']);
    final driverLng = _safeDouble(driver?['current_lng'] ?? tracking['driver_lng']);
    final destLat = _safeDouble(tracking['dest_lat'] ?? tracking['dest_latitude'] ?? tracking['delivery_lat']);
    final destLng = _safeDouble(tracking['dest_lng'] ?? tracking['dest_longitude'] ?? tracking['delivery_lng']);

    _markers.clear();

    if (driverLat != null && driverLng != null) {
      _currentLocation = LatLng(driverLat, driverLng);
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Votre livreur'),
      ));
    }

    if (destLat != null && destLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(destLat, destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Lieu de livraison'),
      ));
    }

    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute réactive de l'état via Riverpod
    final provider = ref.watch(deliveryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Suivi de commande', style: TextStyle(fontWeight: FontWeight.w800, color: darkText)),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkText),
      ),
      // Remplacement de Consumer par l'utilisation directe de 'provider'
      body: Builder(
        builder: (context) {
          if (provider.isLoadingTracking) {
            return const Center(child: CircularProgressIndicator(color: thixOrange));
          }
          if (provider.errorTracking != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Erreur: ${provider.errorTracking}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      // Relance de l'action via Riverpod
                      onPressed: () => ref.read(deliveryProvider).trackDelivery(widget.orderId),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final tracking = provider.currentTracking;
          if (tracking == null) return _buildEmptyState();

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMap(tracking);
                  },
                  initialCameraPosition: const CameraPosition(target: LatLng(-4.322447, 15.307045), zoom: 13),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 16),
                      if (tracking['driver'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildDriverCard(tracking['driver'] as Map<String, dynamic>),
                        ),
                      if (tracking['driver'] != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Divider(height: 1),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: _buildStatusTimeline(tracking),
                        ),
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

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: thixOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: thixOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: thixOrange.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: thixOrange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver['name']?.toString() ?? 'Livreur', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: darkText)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 14, color: mutedText),
                    const SizedBox(width: 4),
                    Text(driver['vehicle']?.toString() ?? 'Véhicule THIX', style: const TextStyle(fontSize: 13, color: mutedText)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16)),
            child: IconButton(icon: const Icon(Icons.phone_rounded, color: Colors.white), onPressed: () {}),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(Map<String, dynamic> tracking) {
    final statuses = [
      {'key': 'preparing', 'label': 'Commande confirmée', 'desc': 'Votre commande est en préparation', 'icon': Icons.inventory_2_rounded},
      {'key': 'picked_up', 'label': 'Colis récupéré', 'desc': 'Le livreur a récupéré votre commande', 'icon': Icons.storefront_rounded},
      {'key': 'in_transit', 'label': 'En route', 'desc': 'Votre commande est en chemin', 'icon': Icons.local_shipping_rounded},
      {'key': 'out_for_delivery', 'label': 'En approche', 'desc': 'Le livreur est proche', 'icon': Icons.location_on_rounded},
      {'key': 'delivered', 'label': 'Livré', 'desc': 'Commande remise avec succès', 'icon': Icons.check_circle_rounded},
    ];
    final currentStatus = (tracking['status'] as String?) ?? 'preparing';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Détails de la livraison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText)),
        const SizedBox(height: 24),
       ...List.generate(statuses.length, (i) {
          final s = statuses[i];
          final k = s['key'] as String;
          return _buildTimelineItem(status: s, isCompleted: _isCompleted(currentStatus, k), isCurrent: currentStatus == k, isLast: i == statuses.length - 1);
        }),
      ],
    );
  }

  Widget _buildTimelineItem({required Map<String, dynamic> status, required bool isCompleted, required bool isCurrent, required bool isLast}) {
    final activeColor = isCompleted ? Colors.green : (isCurrent ? thixOrange : Colors.grey[300]!);
    final iconColor = (isCompleted || isCurrent) ? Colors.white : Colors.grey[500]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                boxShadow: isCurrent ? [BoxShadow(color: thixOrange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Icon(status['icon'] as IconData, color: iconColor, size: 20),
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: isCompleted ? Colors.green : Colors.grey[200], borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status['label'] as String, style: TextStyle(fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600, fontSize: 16, color: (isCompleted || isCurrent) ? darkText : Colors.grey[500])),
                const SizedBox(height: 4),
                Text(status['desc'] as String, style: TextStyle(fontSize: 13, color: isCurrent ? mutedText : Colors.grey[400])),
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Suivi indisponible', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkText)),
          const SizedBox(height: 8),
          const Text('Les informations de suivi pour cette\ncommande ne sont pas encore prêtes.', textAlign: TextAlign.center, style: TextStyle(color: mutedText)),
          const SizedBox(height: 16),
          ElevatedButton(
            // Relance de l'action via Riverpod
            onPressed: () => ref.read(deliveryProvider).trackDelivery(widget.orderId), 
            child: const Text('Actualiser')
          ),
        ],
      ),
    );
  }

  bool _isCompleted(String current, String key) {
    const order = ['preparing', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered'];
    return order.indexOf(key) < order.indexOf(current);
  }
}
