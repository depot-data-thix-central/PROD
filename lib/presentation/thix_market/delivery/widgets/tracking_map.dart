import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../delivery_provider.dart';

class TrackingMap extends StatefulWidget {
  final String orderId;
  final double? destLatitude;
  final double? destLongitude;

  const TrackingMap({
    super.key,
    required this.orderId,
    this.destLatitude,
    this.destLongitude,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      provider.trackDelivery(widget.orderId);
    });
  }

  void _updateMarkers(DeliveryProvider provider) {
    _markers.clear();

    // Position du livreur
    final driver = provider.currentTracking?['driver'];
    final driverLat = driver?['current_lat'] as double?;
    final driverLng = driver?['current_lng'] as double?;
    if (driverLat != null && driverLng != null) {
      _driverLocation = LatLng(driverLat, driverLng);
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Livreur'),
        ),
      );
    }

    // Destination
    final destLat = widget.destLatitude ?? provider.currentTracking?['dest_latitude'] as double?;
    final destLng = widget.destLongitude ?? provider.currentTracking?['dest_longitude'] as double?;
    if (destLat != null && destLng != null) {
      _destinationLocation = LatLng(destLat, destLng);
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Livraison'),
        ),
      );
    }

    setState(() {});

    // Centrer la carte sur le livreur s'il existe
    if (_isMapReady && _driverLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_driverLocation!, 14),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingTracking) {
          return const Center(child: CircularProgressIndicator());
        }

        _updateMarkers(provider);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _isMapReady = true;
              if (_driverLocation != null) {
                controller.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation!, 14));
              }
            },
            initialCameraPosition: CameraPosition(
              target: _driverLocation ?? const LatLng(5.359952, -4.008256),
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
        );
      },
    );
  }
}
