// lib/presentation/mon_pays/services/ministries_service.dart
// Service pour les Ministères (Supabase)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ministry.dart';

class MinistriesService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Ministry>> getAllMinistries() async {
    try {
      final response = await _client
          .from('ministries')
          .select('*')
          .order('name');
      return response.map((json) => Ministry.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des ministères: $e');
    }
  }

  Future<Ministry> getMinistryById(String id) async {
    try {
      final response = await _client
          .from('ministries')
          .select('*')
          .eq('id', id)
          .single();
      return Ministry.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors du chargement du ministère: $e');
    }
  }

  Future<List<Ministry>> searchMinistries(String query) async {
    try {
      final response = await _client
          .from('ministries')
          .select('*')
          .ilike('name', '%$query%')
          .order('name');
      return response.map((json) => Ministry.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  Future<Ministry> createMinistry(Ministry ministry) async {
    try {
      final response = await _client
          .from('ministries')
          .insert(ministry.toJson())
          .select()
          .single();
      return Ministry.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création: $e');
    }
  }

  Future<Ministry> updateMinistry(Ministry ministry) async {
    try {
      final response = await _client
          .from('ministries')
          .update(ministry.toJson())
          .eq('id', ministry.id)
          .select()
          .single();
      return Ministry.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  Future<void> deleteMinistry(String id) async {
    try {
      await _client.from('ministries').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }
}
