// lib/presentation/thix_ia/repositories/analysis_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';

class AnalysisRepository {
  AnalysisRepository(this._remote);
  final ThixIaRemoteDatasource _remote;

  Future<List<Map<String, dynamic>>> getAnalyses(String projectCode) => _remote.getAnalyses(projectCode);
  Future<Map<String, dynamic>> createAnalysis(Map<String, dynamic> data) => _remote.createAnalysis(data);
  Future<void> updateAnalysis(String id, Map<String, dynamic> data) => _remote.updateAnalysis(id, data);
}
