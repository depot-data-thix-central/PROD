// lib/presentation/thix_ia/repositories/analysis_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../models/project_analysis.dart';

/// ============================================================================
/// ANALYSIS REPOSITORY - Gestion analyses avec streaming progress
/// ============================================================================

abstract class AnalysisRepository {
  Future<List<ProjectAnalysis>> getAnalyses(String projectCode, {String? type, bool forceRefresh = false});
  Future<ProjectAnalysis> startAnalysis({required String projectCode, required String type, String? title, Map<String, dynamic>? payload});
  Future<ProjectAnalysis> updateProgress(String analysisId, {required String status, int? progress});
  Stream<ProjectAnalysis> watchAnalysis(String analysisId); // Pour UI temps réel
}

class AnalysisRepositoryImpl implements AnalysisRepository {
  AnalysisRepositoryImpl({required this.remote, required this.local});

  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  @override
  Future<List<ProjectAnalysis>> getAnalyses(String projectCode, {String? type, bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await local.getCachedAnalyses(projectCode);
      if (cached.isNotEmpty) {
        final filtered = type== null? cached : cached.where((a) => a.type == type).toList();
        if (filtered.isNotEmpty) return filtered;
      }
    }

    final fresh = await remote.getAnalyses(projectCode, type: type);
    await local.cacheAnalyses(projectCode, fresh);
    return fresh;
  }

  @override
  Future<ProjectAnalysis> startAnalysis({required String projectCode, required String type, String? title, Map<String, dynamic>? payload}) async {
    final data = {
      'project_code': projectCode,
      'type': type,
      'status': 'queued',
      'progress': 0,
      'title': title?? '${type.toUpperCase()} - ${DateTime.now().toIso8601String()}',
      'result_json': payload?? {},
      'version': 1,
    };

    final created = await remote.createAnalysis(data);
    // Cache optimiste
    final current = await local.getCachedAnalyses(projectCode);
    await local.cacheAnalyses(projectCode, [created, ...current]);
    return created;
  }

  @override
  Future<ProjectAnalysis> updateProgress(String analysisId, {required String status, int? progress}) async {
    return remote.updateAnalysisStatus(analysisId, status, progress: progress);
  }

  @override
  Stream<ProjectAnalysis> watchAnalysis(String analysisId) async* {
    // Supabase Realtime - polling fallback
    // Dans prod on utilisera supabase realtime channel
    // Ici stream simple pour compatibilité
    yield* Stream.periodic(const Duration(seconds: 2), (_) async {
      // Cette implémentation sera remplacée par Realtime en Phase 2
      // Pour l'instant on retourne le dernier état local
      return null;
    }).asyncMap((_) async => null).where((e) => e!= null).cast<ProjectAnalysis>();
  }
}
