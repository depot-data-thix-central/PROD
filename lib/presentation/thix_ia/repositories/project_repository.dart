// lib/presentation/thix_ia/repositories/project_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../models/thix_project.dart';

class ProjectRepository {
  ProjectRepository({required this.remote, required this.local});

  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  Future<List<ThixProject>> getProjects({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    return remote.getProjects(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
  }

  Future<ThixProject?> getProjectByCode(String code) async {
    return remote.getProjectByCode(code);
  }

  Future<ThixProject> createProject({
    required String name,
    required String sector,
    required String country,
    String? city,
    required String summary,
  }) async {
    final data = {
      'name': name,
      'sector': sector,
      'country': country,
      if (city != null) 'city': city,
      'description': summary,
    };
    return remote.createProject(data);
  }

  Future<ThixProject> updateProject(
    String code, {
    required Map<String, dynamic> data,
  }) async {
    return remote.updateProject(code, data);
  }

  Future<void> deleteProject(String projectCode) async {
    await remote.deleteProject(projectCode);
  }

  Future<void> setActiveProject(String code) async {
    // Optionnel : stocker le projet actif en local
    // await local.setActiveProject(code);
  }

  Future<ThixProject?> getActiveProject() async {
    // Optionnel : récupérer le projet actif depuis le local
    // final code = await local.getActiveProjectCode();
    // if (code != null) return getProjectByCode(code);
    return null;
  }
}
