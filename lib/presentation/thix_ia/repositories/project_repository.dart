// lib/presentation/thix_ia/repositories/project_repository.dart
import '../datasources/thix_ia_remote_datasource.dart'; // "import" en minuscule !
import '../datasources/thix_ia_local_datasource.dart';
import '../models/thix_project.dart'; // On utilise ThixProject, pas Project

class ProjectRepository {
  ProjectRepository({required this.remote, required this.local});
  
  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  // Adapté pour correspondre aux paramètres de ProjectService
  Future<List<ThixProject>> getProjects({int page = 1, int limit = 20, String? search, String? status}) async {
    return remote.getProjects(page: page, limit: limit, search: search, status: status);
  }

  // Adapté pour ProjectIntelligenceService
  Future<ThixProject?> getProjectByCode(String code) async {
    return remote.getProjectByCode(code);
  }

  // Adapté pour ProjectService.createProjectFromIdea
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
      'description': summary, // ou 'summary' selon ta base de données
    };
    return remote.createProject(data);
  }

  // Gestion du projet actif
  Future<void> setActiveProject(String code) async {
    // Si ta méthode s'appelle autrement dans ton localDatasource, ajuste ici (ex: setString('active_project', code))
    // await local.setActiveProject(code); 
  }

  Future<ThixProject?> getActiveProject() async {
    // String? code = await local.getActiveProjectCode();
    // if (code != null) return getProjectByCode(code);
    return null;
  }
}
