// lib/presentation/mon_pays/providers/featured_provinces_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/province.dart';
import 'provinces_provider.dart';

final featuredProvincesProvider = FutureProvider<List<Province>>((ref) async {
  // Si provincesProvider prend un filtre optionnel (ex: null), on le lui transmet
  final provinces = await ref.watch(provincesProvider(null).future);
  return provinces;
});

