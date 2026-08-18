// lib/presentation/thix_sante/patient/providers/pharmacie_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/pharmacie_service.dart';

final pharmacieServiceProvider = Provider((_) => PharmacieService());
final positionProvider = FutureProvider<Position>((ref) => ref.read(pharmacieServiceProvider).getCurrentPosition());
final pharmaciesProchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final pos = await ref.watch(positionProvider.future).catchError((_) => null);
  if (pos == null) return ref.read(pharmacieServiceProvider).getPharmaciesProches(lat: -4.32, lng: 15.31); // fallback Kin
  return ref.read(pharmacieServiceProvider).getPharmaciesProches(lat: pos.latitude, lng: pos.longitude);
});
final pharmaciesGardeProvider = FutureProvider((ref) => ref.read(pharmacieServiceProvider).getGardes());
