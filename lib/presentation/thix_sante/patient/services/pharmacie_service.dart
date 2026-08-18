// lib/presentation/thix_sante/patient/services/pharmacie_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PharmacieService {
  final _db = Supabase.instance.client;

  Future<Position> getCurrentPosition() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) throw Exception('Permission GPS refusée');
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<List<Map<String, dynamic>>> getPharmaciesProches({double? lat, double? lng, int radiusKm = 10}) async {
    if (lat == null || lng == null) {
      final pos = await getCurrentPosition();
      lat = pos.latitude; lng = pos.longitude;
    }
    final res = await _db.rpc('pharmacies_proches', params: {'lat': lat, 'lng': lng, 'radius_km': radiusKm});
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getGardes() async {
    final res = await _db.from('pharmacies').select().eq('is_garde', true).eq('is_open', true).limit(20);
    return List<Map<String, dynamic>>.from(res);
  }
}
