import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeolocationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Position? _currentPosition;

  // Request location permission
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  // Get address from coordinates (reverse geocoding)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // ✅ Fonction top-level du package geocoding (pas de classe "Geocoding")
      final places = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        final address = [
          place.street,
          place.postalCode,
          place.locality,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        return address;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get coordinates from address (forward geocoding)
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      // ✅ Placemark n'a pas de coordonnées : il faut locationFromAddress
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Calculate distance between two points (in km)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // Get nearby shops
  Future<List<Map<String, dynamic>>> getNearbyShops({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.rpc('nearby_shops', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Get nearby products
  Future<List<Map<String, dynamic>>> getNearbyProducts({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.rpc('nearby_products', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Save user location to profile
  Future<void> saveUserLocation(double lat, double lng) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('users').update({
        'latitude': lat,
        'longitude': lng,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      // Silently fail
    }
  }

  // Get user saved location
  Future<LatLng?> getUserLocation() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .single();
      final lat = response['latitude'] as double?;
      final lng = response['longitude'] as double?;
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Watch position changes
  Stream<Position> watchPosition({
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  }) {
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}
