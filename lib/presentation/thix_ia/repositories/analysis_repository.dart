// lib/presentation/thix_ia/repositories/analysis_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_analysis.dart';

class AnalysisRepository {
  AnalysisRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ============================================================
  // CRÉATION
  // ============================================================
  Future<ProjectAnalysis> startAnalysis({
    required String projectCode,
    required String type,
    required String title,
    Map<String, dynamic>? payload,
  }) async {
    final row = await _client
        .from('thix_analyses')
        .insert({
          'project_code': projectCode,
          'type': type,
          'title': title,
          'content': payload ?? {},
          'status': 'running',
          'progress': 0,
        })
        .select()
        .single();

    return ProjectAnalysis.fromJson(row);
  }

  // ============================================================
  // LECTURE
  // ============================================================
  Future<List<ProjectAnalysis>> getAnalyses(
    String projectCode, {
    String? type,
  }) async {
    var query = _client
        .from('thix_analyses')
        .select()
        .eq('project_code', projectCode);

    if (type != null) {
      query = query.eq('type', type);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((e) => ProjectAnalysis.fromJson(e)).toList();
  }

  Stream<ProjectAnalysis> watchAnalysis(String analysisId) {
    return _client
        .from('thix_analyses')
        .stream(primaryKey: ['id'])
        .eq('id', analysisId)
        .map((rows) => ProjectAnalysis.fromJson(rows.first));
  }

  // ============================================================
  // MISE À JOUR DE STATUT
  // ============================================================
  Future<void> updateStatus(String analysisId, String status) async {
    await _client.from('thix_analyses').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', analysisId);
  }

  Future<void> completeAnalysis({
    required String analysisId,
    required Map<String, dynamic> result,
  }) async {
    await _client.from('thix_analyses').update({
      'status': 'completed',
      'progress': 100,
      'content': result,
      'completed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', analysisId);
  }

  Future<void> failAnalysis({
    required String analysisId,
    required String error,
  }) async {
    await _client.from('thix_analyses').update({
      'status': 'failed',
      'error_message': error,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', analysisId);
  }

  // ============================================================
  // SUPPRESSION
  // ============================================================
  Future<void> deleteAnalysis(String analysisId) async {
    await _client.from('thix_analyses').delete().eq('id', analysisId);
  }
}
