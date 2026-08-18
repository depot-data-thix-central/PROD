// lib/presentation/mon_pays/providers/ministries_provider.dart
// Riverpod : Ministères

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ministry.dart';
import '../services/ministries_service.dart';

final ministriesServiceProvider = Provider((ref) => MinistriesService());

// Liste des ministères
final ministriesProvider = FutureProvider<List<Ministry>>((ref) async {
  final service = ref.watch(ministriesServiceProvider);
  return service.getAllMinistries();
});

// Détail d'un ministère
final ministryDetailProvider = FutureProvider.family<Ministry, String>((ref, id) async {
  final service = ref.watch(ministriesServiceProvider);
  return service.getMinistryById(id);
});

// Recherche de ministères
final searchMinistriesProvider = FutureProvider.family<List<Ministry>, String>((ref, query) async {
  final service = ref.watch(ministriesServiceProvider);
  if (query.isEmpty) return [];
  return service.searchMinistries(query);
});

// ADMIN
final adminMinistriesProvider = StateNotifierProvider<AdminMinistriesNotifier, AsyncValue<List<Ministry>>>((ref) {
  return AdminMinistriesNotifier(ref);
});

class AdminMinistriesNotifier extends StateNotifier<AsyncValue<List<Ministry>>> {
  final Ref _ref;

  AdminMinistriesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadMinistries();
  }

  Future<void> loadMinistries() async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(ministriesServiceProvider);
      final list = await service.getAllMinistries();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createMinistry(Ministry ministry) async {
    try {
      final service = _ref.read(ministriesServiceProvider);
      await service.createMinistry(ministry);
      await loadMinistries();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateMinistry(Ministry ministry) async {
    try {
      final service = _ref.read(ministriesServiceProvider);
      await service.updateMinistry(ministry);
      await loadMinistries();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteMinistry(String id) async {
    try {
      final service = _ref.read(ministriesServiceProvider);
      await service.deleteMinistry(id);
      await loadMinistries();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
