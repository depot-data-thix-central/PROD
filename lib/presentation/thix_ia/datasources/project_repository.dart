// lib/presentation/thix_ia/datasources/project_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/thix_ia_exception.dart';
import '../core/utils/project_code_generator.dart';
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../models/thix_project.dart';
import '../models/project_memory.dart';

/// ============================================================================
/// PROJECT REPOSITORY - Single Source of Truth
/// Remote first, cache fallback, offline-first pour projet actif
/// ============================================================================

abstract class ProjectRepository {
  Future<List<ThixProject>> getProjects({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    bool forceRefresh = false,
  });
  Future<ThixProject> getProjectByCode(String code, {bool forceRefresh = false});
  Future<ThixProject> createProject({
    required String name,
    required String sector,
    required String country,
    String? city,
    String? summary,
  });
  Future<ThixProject> updateProject(
    String code, {
    String? name,
    String? status,
    String? summary,
    Map<String, dynamic>? data,
  });
  Future<void> setActiveProject(String code);
  Future<ThixProject?> getActiveProject();
  Future<ProjectMemory> getProjectMemory(String code, {bool forceRefresh = false});
  Future<void> deleteProject(String projectCode);
}

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({required this.remote, required this.local});

  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  @override
  Future<List<ThixProject>> getProjects({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    bool forceRefresh = false,
  }) async {
    // Page 1 sans recherche = cache d'abord pour instantanéité
    if (page == 1 && !forceRefresh && (search == null || search.isEmpty)) {
      final cached = await local.getCachedProjects();
      if (cached.isNotEmpty) {
        // Fire and forget refresh en background
        remote
            .getProjects(page: page, limit: limit, status: status, search: search)
            .then((fresh) {
          local.cacheProjects(fresh);
        }).catchError((_) {});
        return cached;
      }
    }

    try {
      final fresh = await remote.getProjects(
        page: page,
        limit: limit,
        status: status,
        search: search,
      );
      if (page == 1) await local.cacheProjects(fresh);
      return fresh;
    } on ThixIANetworkException {
      // Offline fallback
      final cached = await local.getCachedProjects();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<ThixProject> getProjectByCode(String code, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await local.getCachedProjectByCode(code);
      if (cached != null) return cached;
    }
    final fresh = await remote.getProjectByCode(code);
    await local.cacheProject(fresh);
    return fresh;
  }

  @override
  Future<ThixProject> createProject({
    required String name,
    required String sector,
    required String country,
    String? city,
    String? summary,
  }) async {
    if (name.trim().isEmpty) {
      throw const ThixIAValidationException(message: 'Le nom du projet est requis');
    }

    final projectCode = ProjectCodeGenerator.generate();
    final userId = Supabase.instance.client.auth.currentUser?.id;

        final data = {
      'code': projectCode, 
      'name': name.trim(),
      'sector': sector.trim(),
      'country': country.trim(),
      'city': city?.trim(),
      'status': 'draft',
      'summary': summary?.trim(),
      'progress': 0.05,
      'analyses_count': 0,
      'documents_count': 0,
      if (userId != null) 'owner_id': userId,
    };


    final created = await remote.createProject(data);
    await local.cacheProject(created);
    await local.cacheActiveProject(created);
    return created;
  }

  @override
  Future<ThixProject> updateProject(
    String code, {
    String? name,
    String? status,
    String? summary,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (summary != null) 'summary': summary,
      if (data != null) ...data,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await remote.updateProject(code, payload);
    await local.cacheProject(updated);
    return updated;
  }

  @override
  Future<void> setActiveProject(String code) async {
    final project = await getProjectByCode(code);
    await local.setActiveProjectCode(code);
    await local.cacheActiveProject(project);
  }

  @override
  Future<ThixProject?> getActiveProject() async {
    final code = await local.getActiveProjectCode();
    if (code == null) return null;
    return getProjectByCode(code);
  }

  @override
  Future<ProjectMemory> getProjectMemory(String code, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await local.getCachedMemory(code);
      if (cached != null) return cached;
    }
    final fresh = await remote.getProjectMemory(code);
    await local.cacheProjectMemory(fresh);
    return fresh;
  }

  @override
  Future<void> deleteProject(String projectCode) async {
    await remote.deleteProject(projectCode);
    // Optionnel : nettoyer le cache local
    // await local.removeProjectFromCache(projectCode);
  }
}
