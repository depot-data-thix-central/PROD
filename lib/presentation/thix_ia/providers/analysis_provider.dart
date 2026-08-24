// lib/presentation/thix_ia/providers/analysis_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_analysis.dart';
import '../services/analysis_service.dart';
import 'thix_ia_provider.dart';
import 'active_project_provider.dart';

class AnalysesNotifier extends AsyncNotifier<List<ProjectAnalysis>> {
  @override
  Future<List<ProjectAnalysis>> build() async {
    final code = ref.watch(activeProjectCodeProvider);
    if (code == null) return [];
    final service = ref.watch(analysisServiceProvider);
    return service.getProjectAnalyses(code);
  }

  Future<void> refresh() async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(analysisServiceProvider);
      return service.getProjectAnalyses(code);
    });
  }

  // ====================== HELPERS ======================

  /// Vérifie si une analyse du même type existe déjà (non annulée)
  bool hasExistingAnalysis(String type) {
    final analyses = state.value ?? [];
    return analyses.any((a) =>
        a.type == type &&
        a.status != AnalysisStatus.cancelled &&
        a.status != AnalysisStatus.failed);
  }

  // ====================== LANCEMENT DES ANALYSES ======================

  Future<ProjectAnalysis> startMarketAnalysis({
    required String country,
    required String sector,
    String? ideaDescription,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    if (hasExistingAnalysis('market')) {
      throw Exception('Une étude de marché existe déjà. Supprimez-la d\'abord.');
    }

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startMarketAnalysis(
      projectCode: code,
      country: country,
      sector: sector,
      additionalContext: ideaDescription,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startLegalAnalysis({
    required String jurisdiction,
    required String sector,
    String? ideaDescription,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    if (hasExistingAnalysis('legal')) {
      throw Exception('Une analyse réglementaire existe déjà. Supprimez-la d\'abord.');
    }

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startLegalAnalysis(
      projectCode: code,
      jurisdiction: jurisdiction,
      sector: sector,
      activityDescription: ideaDescription,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startCompetitorAnalysis({
    required String country,
    required String sector,
    String? ideaDescription,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    if (hasExistingAnalysis('competitor')) {
      throw Exception('Une analyse concurrentielle existe déjà. Supprimez-la d\'abord.');
    }

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startCompetitorAnalysis(
      projectCode: code,
      country: country,
      sector: sector,
      productDescription: ideaDescription,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startFinanceAnalysis({
    Map<String, dynamic> inputs = const {},
    String? ideaDescription,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    if (hasExistingAnalysis('finance')) {
      throw Exception('Un modèle financier existe déjà. Supprimez-le d\'abord.');
    }

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startFinanceAnalysis(
      projectCode: code,
      financialInputs: {
        ...inputs,
        if (ideaDescription != null) 'idea_context': ideaDescription,
      },
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startBusinessPlanAnalysis({
    String? ideaDescription,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    if (hasExistingAnalysis('business_plan')) {
      throw Exception('Un business plan existe déjà. Supprimez-le d\'abord.');
    }

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startBusinessPlanAnalysis(
      projectCode: code,
      ideaDescription: ideaDescription ?? 'Business plan complet',
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  // ====================== CONTRÔLE ======================

  Future<void> pauseAnalysis(String analysisId) async {
    final service = ref.read(analysisServiceProvider);
    await service.pauseAnalysis(analysisId);
    await refresh();
  }

  Future<void> cancelAnalysis(String analysisId) async {
    final service = ref.read(analysisServiceProvider);
    await service.cancelAnalysis(analysisId);
    await refresh();
  }

  Future<void> deleteAnalysis(String analysisId) async {
    final service = ref.read(analysisServiceProvider);
    await service.deleteAnalysis(analysisId);
    final current = state.value ?? [];
    state = AsyncData(current.where((a) => a.id != analysisId).toList());
  }

  // ====================== FILTRES ======================

  List<ProjectAnalysis> byType(String type) {
    final all = state.value ?? [];
    return all.where((a) => a.type == type).toList();
  }

  List<ProjectAnalysis> get completed =>
      (state.value ?? []).where((a) => a.isCompleted).toList();

  List<ProjectAnalysis> get running =>
      (state.value ?? []).where((a) => a.isRunning).toList();
}

final analysesProvider =
    AsyncNotifierProvider<AnalysesNotifier, List<ProjectAnalysis>>(() {
  return AnalysesNotifier();
});

final analysesByTypeProvider =
    Provider.family<List<ProjectAnalysis>, String>((ref, type) {
  final analyses = ref.watch(analysesProvider).value ?? [];
  return analyses.where((a) => a.type == type).toList();
});

final lastAnalysesProvider = Provider<List<ProjectAnalysis>>((ref) {
  final analyses = ref.watch(analysesProvider).value ?? [];
  final sorted = [...analyses]
    ..sort((a, b) => (b.createdAt ?? DateTime.now())
        .compareTo(a.createdAt ?? DateTime.now()));
  return sorted.take(5).toList();
});
