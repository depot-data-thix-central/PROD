// lib/presentation/mon_pays/providers/citizens_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/exemplary_citizen.dart';

class CitizensService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ExemplaryCitizen>> fetchCitizens() async {
    final response = await _client
        .from('exemplary_citizens')
        .select()
        .order('recognition_date', ascending: false);

    return (response as List<dynamic>)
        .map((e) => ExemplaryCitizen.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final citizensServiceProvider = Provider<CitizensService>((ref) => CitizensService());

final citizensProvider = FutureProvider<List<ExemplaryCitizen>>((ref) async {
  final service = ref.read(citizensServiceProvider);
  return await service.fetchCitizens();
});
