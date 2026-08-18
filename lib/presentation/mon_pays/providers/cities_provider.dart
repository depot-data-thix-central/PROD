// Fichier n°14 : providers/cities_provider.dart
// lib/presentation/mon_pays/providers/cities_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city.dart';
import '../services/cities_service.dart';

final citiesServiceProvider = Provider<CitiesService>((ref) {
  return CitiesService();
});

final citiesByProvinceProvider = FutureProvider.family<List<City>, String>((ref, provinceId) async {
  final service = ref.watch(citiesServiceProvider);
  return service.getCitiesByProvince(provinceId);
});

// Admin – CRUD villes (optionnel)
final adminCitiesProvider = StateNotifierProvider<AdminCitiesNotifier, AsyncValue<List<City>>>((ref) {
  return AdminCitiesNotifier(ref);
});

class AdminCitiesNotifier extends StateNotifier<AsyncValue<List<City>>> {
  final Ref _ref;
  String? _currentProvinceId;

  AdminCitiesNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> loadCities(String provinceId) async {
    _currentProvinceId = provinceId;
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(citiesServiceProvider);
      final list = await service.getCitiesByProvince(provinceId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createCity(City city) async {
    try {
      final service = _ref.read(citiesServiceProvider);
      await service.createCity(city);
      if (_currentProvinceId != null) {
        await loadCities(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateCity(City city) async {
    try {
      final service = _ref.read(citiesServiceProvider);
      await service.updateCity(city);
      if (_currentProvinceId != null) {
        await loadCities(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteCity(String id) async {
    try {
      final service = _ref.read(citiesServiceProvider);
      await service.deleteCity(id);
      if (_currentProvinceId != null) {
        await loadCities(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
