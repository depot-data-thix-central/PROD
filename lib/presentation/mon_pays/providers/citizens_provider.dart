// lib/presentation/mon_pays/providers/citizens_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/mon_pays/models/exemplary_citizen.dart';


class CitizensService {
  CitizensService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const Duration _kTimeout = Duration(seconds: 15);
  static const int _kMaxLimit = 100;

  Future<List<ExemplaryCitizen>> fetchCitizens({int limit = 50}) async {
    final safeLimit = limit.clamp(1, _kMaxLimit);

    final response = await _client
        .from('exemplary_citizens')
        .select()
        .eq('is_active', true)
        .order('recognition_date', ascending: false)
        .limit(safeLimit)
        .timeout(_kTimeout);

    final list = (response as List)
        .map((e) => ExemplaryCitizen.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.id.isNotEmpty)
        .toList();

    if (kDebugMode) debugPrint('[Citizens] Loaded ${list.length} profiles');
    return list;
  }
}

final citizensServiceProvider = Provider<CitizensService>(
  (ref) => CitizensService(),
);

final citizensProvider = FutureProvider<List<ExemplaryCitizen>>((ref) async {
  final service = ref.read(citizensServiceProvider);
  try {
    return await service.fetchCitizens();
  } catch (e, stack) {
    debugPrint('[Citizens] Load error: $e');
    // Remonte l'erreur telle quelle pour affichage + retry côté UI
    throw e is Exception ? e : Exception('$e');
  }
});
