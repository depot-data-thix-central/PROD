// lib/presentation/thix_ia/repositories/analysis_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_analysis.dart';

class AnalysisRepository {
  AnalysisRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Assure que le projet existe dans la table parentée par la FK
  /// (thix_analyses.project_code → projects.project_code)
  /// + thix_projects pour le reste de l'app
  Future<void> ensureProjectExists(String projectCode, {String? name}) async {
    final now = DateTime.now().toIso8601String();
    final payload = {
      'project_code': projectCode,
      'name': name ?? 'Projet $projectCode',
      'sector': 'General',
      'country': 'RDC',
      'status': 'active',
      'progress': 0.1,
      'analyses_count': 0,
      'documents_count': 0,
      'updated_at': now,
    };

    // 1) Table "projects" (celle de la contrainte FK de thix_analyses)
    try {
      final exists = await _client
          .from('projects')
          .select('project_code')
          .eq('project_code', projectCode)
          .maybeSingle();

      if (exists == null) {
        await _client.from('projects').upsert(
          payload,
          onConflict: 'project_code',
        );
      }
    } catch (_) {
      // Si la table "projects" n'existe pas, on ignore et on continue
    }

    // 2) Table "thix_projects" (utilisée par le reste de THIX)
    try {
      final existsThix = await _client
          .from('thix_projects')
          .select('project_code')
          .eq('project_code', projectCode)
          .maybeSingle();

      if (existsThix == null) {
        await _client.from('thix_projects').upsert(
          payload,
          onConflict: 'project_code',
        );
      }
    } catch (_) {
      // ignore
    }
  }

  // ============================================================
  // CRÉATION
  // ============================================================
  Future<ProjectAnalysis> startAnalysis({
    required String projectCode,
    required String type,
    required String title,
    Map<String, dynamic>? payload,
  }) async {
    // ★ CORRECTION FK : créer le projet parent AVANT l'insert
    await ensureProjectExists(projectCode);

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
