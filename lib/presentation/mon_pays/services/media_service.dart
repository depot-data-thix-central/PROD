// lib/presentation/mon_pays/services/media_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/province_media.dart'; // ✅ IMPORT AJOUTÉ

class MediaService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ProvinceMedia>> getMediaByProvince(String provinceId, {String? type}) async {
    try {
      var query = _client.from('province_media').select('*').eq('province_id', provinceId);
      if (type != null && type.isNotEmpty) {
        query = query.eq('type', type);
      }
      final response = await query.order('created_at', ascending: false);
      return response.map((e) => ProvinceMedia.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Erreur chargement médias: $e');
    }
  }

  Future<ProvinceMedia> createMedia(ProvinceMedia media) async {
    try {
      final data = media.toJson();
      data.remove('id');
      final response = await _client
          .from('province_media')
          .insert(data)
          .select()
          .single();
      return ProvinceMedia.fromJson(response);
    } catch (e) {
      throw Exception('Erreur création média: $e');
    }
  }

  Future<ProvinceMedia> updateMedia(ProvinceMedia media) async {
    try {
      final response = await _client
          .from('province_media')
          .update(media.toJson())
          .eq('id', media.id)
          .select()
          .single();
      return ProvinceMedia.fromJson(response);
    } catch (e) {
      throw Exception('Erreur mise à jour média: $e');
    }
  }

  Future<void> deleteMedia(String id) async {
    try {
      await _client.from('province_media').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression média: $e');
    }
  }
}
