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

  Future<ProjectAnalysis> startMarketAnalysis({
    required String country,
    required String sector,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startMarketAnalysis(
      projectCode: code,
      country: country,
      sector: sector,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startLegalAnalysis({
    required String jurisdiction,
    required String sector,
  }) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startLegalAnalysis(
      projectCode: code,
      jurisdiction: jurisdiction,
      sector: sector,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  Future<ProjectAnalysis> startFinanceAnalysis(Map<String, dynamic> inputs) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    final service = ref.read(analysisServiceProvider);
    final analysis = await service.startFinanceAnalysis(
      projectCode: code,
      financialInputs: inputs,
    );

    final current = state.value ?? [];
    state = AsyncData([analysis, ...current]);
    return analysis;
  }

  // ====================== ACTIONS DE CONTRÔLE ======================

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

  // Filtres
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
