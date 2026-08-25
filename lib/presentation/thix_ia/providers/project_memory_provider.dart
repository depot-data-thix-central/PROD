// lib/presentation/thix_ia/providers/project_memory_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_memory.dart';
import '../repositories/memory_repository.dart';
import 'thix_ia_provider.dart';
import 'active_project_provider.dart';

/// ============================================================================
/// PROJECT MEMORY PROVIDER - Mémoire durable §7
/// ============================================================================

class ProjectMemoryNotifier extends AsyncNotifier<ProjectMemory?> {
  @override
  Future<ProjectMemory?> build() async {
    final code = ref.watch(activeProjectCodeProvider);
    if (code == null) return null;
    final repo = ref.watch(memoryRepositoryProvider);
    return repo.getMemory(code);
  }

  Future<void> refresh() async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(memoryRepositoryProvider);
      return repo.getMemory(code, forceRefresh: true);
    });
  }

  Future<void> addFact({
    required String type,
    required String content,
    String? sourceUrl,
    String? sourceName,
    double confidence = 0.8,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) {
      throw Exception('Aucun projet actif');
    }

    final repo = ref.read(memoryRepositoryProvider);
    await repo.addFact(
      projectCode: code,
      type: type,
      content: content,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      confidence: confidence,
    );
    await refresh();
  }

  Future<void> addIdea({required String title, String? description}) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) return;
    final repo = ref.read(memoryRepositoryProvider);
    await repo.addIdea(
        projectCode: code, title: title, description: description);
    await refresh();
  }
}

final projectMemoryProvider =
    AsyncNotifierProvider<ProjectMemoryNotifier, ProjectMemory?>(() {
  return ProjectMemoryNotifier();
});

final projectFactsProvider = Provider<List<ProjectFact>>((ref) {
  return ref.watch(projectMemoryProvider).value?.facts ?? [];
});

final verifiedFactsProvider = Provider<List<ProjectFact>>((ref) {
  final facts = ref.watch(projectFactsProvider);
  return facts.where((f) => f.type == 'fact' && f.confidence >= 0.85).toList();
});

final openQuestionsProvider = Provider<List<String>>((ref) {
  return ref.watch(projectMemoryProvider).value?.openQuestions ?? [];
});
