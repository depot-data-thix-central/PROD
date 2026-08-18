// lib/presentation/mon_pays/services/achievements_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provincial_achievement.dart'; // <--- Import harmonisé

class AchievementsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ProvincialAchievement>> getAchievementsByProvince(String provinceId) async {
    final response = await _client
        .from('province_achievements')
        .select('*')
        .eq('province_id', provinceId)
        .order('date', ascending: false);
    
    return (response as List).map((e) => ProvincialAchievement.fromJson(e)).toList();
  }

  Future<ProvincialAchievement> createAchievement(ProvincialAchievement achievement) async {
    final data = achievement.toJson();
    data.remove('id');
    final response = await _client
        .from('province_achievements')
        .insert(data)
        .select()
        .single();
    return ProvincialAchievement.fromJson(response);
  }

  Future<ProvincialAchievement> updateAchievement(ProvincialAchievement achievement) async {
    final response = await _client
        .from('province_achievements')
        .update(achievement.toJson())
        .eq('id', achievement.id)
        .select()
        .single();
    return ProvincialAchievement.fromJson(response);
  }

  Future<void> deleteAchievement(String id) async {
    await _client.from('province_achievements').delete().eq('id', id);
  }
}
