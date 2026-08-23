// lib/presentation/thix_ia/providers/active_project_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/project_intelligence_service.dart';
import 'thix_ia_provider.dart';

/// ============================================================================
/// ACTIVE PROJECT INTELLIGENCE - Vue 360° temps réel
/// ============================================================================

class ProjectIntelligenceNotifier extends AsyncNotifier<ProjectIntelligence?> {
  @override
  Future<ProjectIntelligence?> build() async {
    final activeProject = await ref.watch(activeProjectProvider.future);
    if (activeProject == null) return null;

    final intelligenceService = ref.watch(projectIntelligenceServiceProvider);
    return intelligenceService.getIntelligence(activeProject.projectCode);
  }

  Future<void> refresh() async {
    final active = ref.read(activeProjectProvider).value;
    if (active == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(projectIntelligenceServiceProvider);
      return service.getIntelligence(active.projectCode);
    });
  }
}

final projectIntelligenceProvider = AsyncNotifierProvider<ProjectIntelligenceNotifier, ProjectIntelligence?>(() {
  return ProjectIntelligenceNotifier();
});

// Selector ultra-performant pour header uniquement
final activeProjectCodeProvider = Provider<String?>((ref) {
  return ref.watch(activeProjectProvider).value?.projectCode;
});

final activeProjectProgressProvider = Provider<double>((ref) {
  final intel = ref.watch(projectIntelligenceProvider).value;
  return intel?.progress?? 0.0;
});

final activeProjectNextActionsProvider = Provider<List<String>>((ref) {
  final intel = ref.watch(projectIntelligenceProvider).value;
  return intel?.nextActions?? [];
});
