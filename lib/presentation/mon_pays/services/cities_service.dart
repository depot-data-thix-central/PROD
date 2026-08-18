// lib/presentation/mon_pays/services/cities_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/city.dart'; // ✅ IMPORT AJOUTÉ

class CitiesService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<City>> getCitiesByProvince(String provinceId) async {
    try {
      final response = await _client
          .from('cities')
          .select('*')
          .eq('province_id', provinceId)
          .order('is_capital', ascending: false)
          .order('name');
      return response.map((e) => City.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Erreur chargement villes: $e');
    }
  }

  Future<City> createCity(City city) async {
    try {
      final data = city.toJson();
      data.remove('id');
      final response = await _client
          .from('cities')
          .insert(data)
          .select()
          .single();
      return City.fromJson(response);
    } catch (e) {
      throw Exception('Erreur création ville: $e');
    }
  }

  Future<City> updateCity(City city) async {
    try {
      final response = await _client
          .from('cities')
          .update(city.toJson())
          .eq('id', city.id)
          .select()
          .single();
      return City.fromJson(response);
    } catch (e) {
      throw Exception('Erreur mise à jour ville: $e');
    }
  }

  Future<void> deleteCity(String id) async {
    try {
      await _client.from('cities').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression ville: $e');
    }
  }
}
