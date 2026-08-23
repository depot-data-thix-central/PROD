import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_analysis.dart';

class AnalysisRepository {
  AnalysisRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<ProjectAnalysis> startAnalysis({
    required String projectCode,
    required String type,
    required String title,
    Map<String, dynamic>? payload,
  }) async {
    final row = await _client.from('thix_analyses').insert({
      'project_code': projectCode,
      'type': type,
      'title': title,
      'content': payload ?? {},
      'status': 'pending',
      'progress': 0,
    }).select().single();
    return ProjectAnalysis.fromJson(row);
  }

  Future<List<ProjectAnalysis>> getAnalyses(String projectCode, {String? type}) async {
    var query = _client.from('thix_analyses').select().eq('project_code', projectCode);
    if (type != null) query = query.eq('type', type);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((e) => ProjectAnalysis.fromJson(e)).toList();
  }

  Stream<ProjectAnalysis> watchAnalysis(String analysisId) {
    return _client.from('thix_analyses').stream(primaryKey: ['id']).eq('id', analysisId).map((rows) => ProjectAnalysis.fromJson(rows.first));
  }
}
