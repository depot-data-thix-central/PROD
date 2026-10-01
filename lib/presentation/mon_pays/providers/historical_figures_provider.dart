import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/historical_figure.dart';

const Duration _kTimeout = Duration(seconds: 15);

/// 🏛️ Liste des figures historiques actives
final historicalFiguresProvider =
    FutureProvider<List<HistoricalFigure>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('historical_figures')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_kTimeout);

    final list = (response as List)
        .map((e) =>
            HistoricalFigure.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((f) => f.id.isNotEmpty && f.fullName.isNotEmpty)
        .toList();

    if (kDebugMode) debugPrint('[HistoricalFigures] Loaded ${list.length}');
    return list;
  } catch (e) {
    debugPrint('[HistoricalFigures] Load error: $e');
    rethrow;
  }
});
