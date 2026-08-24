// lib/presentation/thix_ia/datasources/thix_ia_remote_datasource.dart
import 'dart:typed_data'; // <-- Ajout obligatoire pour Uint8List
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/thix_ia_constants.dart';
import '../core/errors/thix_ia_exception.dart';
import '../core/errors/thix_ia_error_mapper.dart';
import '../models/thix_project.dart';
import '../models/project_analysis.dart';
import '../models/project_memory.dart';
import '../models/document.dart';
import '../models/report.dart';
import '../models/project_items.dart';

/// ============================================================================
/// REMOTE DATASOURCE - SUPABASE ONLY
/// Connexion directe, pagination scalable pour millions d'users
/// ============================================================================

abstract class ThixIaRemoteDatasource {
  // Projects
  Future<List<ThixProject>> getProjects({int page = 1, int limit = 20, String? status, String? search});
  Future<ThixProject> getProjectByCode(String projectCode);
  Future<ThixProject> createProject(Map<String, dynamic> data);
  Future<ThixProject> updateProject(String projectCode, Map<String, dynamic> data);
  Future<void> archiveProject(String projectCode);
  Future<void> deleteProject(String projectCode);   

  // Memory
  Future<ProjectMemory> getProjectMemory(String projectCode);
  Future<void> upsertProjectFact(Map<String, dynamic> fact);

  // Analyses
  Future<List<ProjectAnalysis>> getAnalyses(String projectCode, {String? type});
  Future<ProjectAnalysis> createAnalysis(Map<String, dynamic> data);
  Future<ProjectAnalysis> updateAnalysisStatus(String id, String status, {int? progress});

  // Documents
  Future<List<ProjectDocument>> getDocuments(String projectCode);
  Future<ProjectDocument> createDocument(Map<String, dynamic> data);
  Future<String> uploadFile(String projectCode, String fileName, List<int> bytes, String mimeType);

  // Reports
  Future<List<Report>> getReports(String projectCode);
  Future<Report> createReport(Map<String, dynamic> data);
}

class ThixIaRemoteDatasourceImpl implements ThixIaRemoteDatasource {
  ThixIaRemoteDatasourceImpl(this._supabase);

  final SupabaseClient _supabase;

  // ────────────────────────────────────────────────────────────────────────
  // PROJECTS
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<List<ThixProject>> getProjects({int page = 1, int limit = 20, String? status, String? search}) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      // 1. Initialisation de la requête SANS order ni range
      var query = _supabase.from('projects').select();

      // 2. Application des filtres en premier
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,project_code.ilike.%$search%,sector.ilike.%$search%');
      }

      // 3. Application du tri et de la pagination à la fin de la chaîne
      final res = await query.order('updated_at', ascending: false).range(from, to);
      
      return (res as List).map((e) => ThixProject.fromJson(e)).toList();
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ThixProject> getProjectByCode(String projectCode) async {
    try {
      final res = await _supabase.from('projects').select().eq('project_code', projectCode).single();
      return ThixProject.fromJson(res);
    } catch (e, s) {
      if (e is PostgrestException && e.code == 'PGRST116') {
        throw ThixIAProjectNotFoundException(projectCode);
      }
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ThixProject> createProject(Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('projects').insert(data).select().single();
      // Audit log
      await _supabase.from('audit_logs').insert({
        'action': 'create_project',
        'entity_type': 'project',
        'entity_id': res['id'],
        'project_code': res['project_code'],
        'metadata': {'name': res['name']},
      });
      return ThixProject.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ThixProject> updateProject(String projectCode, Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('projects').update(data).eq('project_code', projectCode).select().single();
      return ThixProject.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

@override
  Future<void> archiveProject(String projectCode) async {
    try {
      await _supabase
          .from('projects')
          .update({'status': 'archived'})
          .eq('project_code', projectCode);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<void> deleteProject(String projectCode) async {
    try {
      // Suppression définitive du projet
      await _supabase
          .from('projects')
          .delete()
          .eq('project_code', projectCode);

      // Optionnel : log d'audit
      await _supabase.from('audit_logs').insert({
        'action': 'delete_project',
        'entity_type': 'project',
        'project_code': projectCode,
        'metadata': {'deleted_at': DateTime.now().toIso8601String()},
      });
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // MEMORY
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<ProjectMemory> getProjectMemory(String projectCode) async {
    try {
      // Récupère en parallèle pour perf - Typage sécurisé pour la compilation Web
      final results = await Future.wait<dynamic>([
        _supabase.from('project_context').select().eq('project_code', projectCode).maybeSingle(),
        _supabase.from('project_facts').select().eq('project_code', projectCode).order('created_at'),
        _supabase.from('project_ideas').select().eq('project_code', projectCode),
        _supabase.from('project_decisions').select().eq('project_code', projectCode),
        _supabase.from('projects').select('name,sector,country,city').eq('project_code', projectCode).single(),
      ]);

      final contextData = results[0] as Map<String, dynamic>?;
      final factsData = results[1] as List;
      final projData = results[4] as Map<String, dynamic>;

      return ProjectMemory(
        projectCode: projectCode,
        identity: ProjectIdentity(
          name: projData['name'] ?? '',
          sector: projData['sector'] ?? '',
          country: projData['country'] ?? 'RDC',
          city: projData['city'],
        ),
        context: contextData != null ? ProjectContext.fromJson(contextData) : const ProjectContext(),
        facts: factsData.map((e) => ProjectFact.fromJson(e)).toList(),
        lastUpdated: DateTime.now(),
      );
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<void> upsertProjectFact(Map<String, dynamic> fact) async {
    try {
      await _supabase.from('project_facts').upsert(fact);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // ANALYSES
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<List<ProjectAnalysis>> getAnalyses(String projectCode, {String? type}) async {
    try {
      // 1. Initialisation + filtre principal
      var query = _supabase.from('project_analyses').select().eq('project_code', projectCode);
      
      // 2. Filtres additionnels
      if (type != null) {
        query = query.eq('type', type);
      }
      
      // 3. Tri à la fin
      final res = await query.order('created_at', ascending: false);
      
      return (res as List).map((e) => ProjectAnalysis.fromJson(e)).toList();
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ProjectAnalysis> createAnalysis(Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('project_analyses').insert(data).select().single();
      return ProjectAnalysis.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ProjectAnalysis> updateAnalysisStatus(String id, String status, {int? progress}) async {
    try {
      final update = {'status': status, if (progress != null) 'progress': progress, 'updated_at': DateTime.now().toIso8601String()};
      final res = await _supabase.from('project_analyses').update(update).eq('id', id).select().single();
      return ProjectAnalysis.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // DOCUMENTS
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<List<ProjectDocument>> getDocuments(String projectCode) async {
    try {
      final res = await _supabase.from('project_documents').select().eq('project_code', projectCode).order('created_at', ascending: false);
      return (res as List).map((e) => ProjectDocument.fromJson(e)).toList();
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<ProjectDocument> createDocument(Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('project_documents').insert(data).select().single();
      return ProjectDocument.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<String> uploadFile(String projectCode, String fileName, List<int> bytes, String mimeType) async {
    try {
      final path = '$projectCode/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Correction de l'erreur Uint8List
      await _supabase.storage.from('thix-documents').uploadBinary(
        path, 
        Uint8List.fromList(bytes), 
        fileOptions: FileOptions(contentType: mimeType, upsert: false)
      );
      
      final publicUrl = _supabase.storage.from('thix-documents').getPublicUrl(path);
      return publicUrl;
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // REPORTS
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<List<Report>> getReports(String projectCode) async {
    try {
      final res = await _supabase.from('reports').select().eq('project_code', projectCode).order('created_at', ascending: false);
      return (res as List).map((e) => Report.fromJson(e)).toList();
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }

  @override
  Future<Report> createReport(Map<String, dynamic> data) async {
    try {
      final res = await _supabase.from('reports').insert(data).select().single();
      return Report.fromJson(res);
    } catch (e, s) {
      throw ThixIAErrorMapper.map(e, s);
    }
  }
}
