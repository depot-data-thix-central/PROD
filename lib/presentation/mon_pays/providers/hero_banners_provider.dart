import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hero_banner.dart';

/// 🎠 Bannières hero actives (triées par position).
/// Retourne [] en cas d'erreur → l'app bascule sur les slides locaux.
final heroBannersProvider = FutureProvider<List<HeroBanner>>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('mon_pays_banners')
        .select()
        .eq('is_active', true)
        .order('position', ascending: true)
        .limit(10)
        .timeout(const Duration(seconds: 10));

    return (res as List)
        .map((e) => HeroBanner.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((b) => b.title.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('[HeroBanners] Load error: $e');
    return const <HeroBanner>[];
  }
});
