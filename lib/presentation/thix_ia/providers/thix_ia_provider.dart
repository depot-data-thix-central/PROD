// lib/presentation/thix_ia/providers/thix_ia_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../repositories/project_repository.dart';
import '../repositories/analysis_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/document_repository.dart';
import '../services/project_service.dart';
import '../services/project_intelligence_service.dart';
import '../services/analysis_service.dart';
import '../models/thix_project.dart';

// ────────────────────────────────────────────────────────────────────────────
// SUPABASE & DATASOURCES
// ────────────────────────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final thixLocalDatasourceProvider = Provider<ThixIaLocalDatasource>((ref) => ThixIaLocalDatasourceImpl());

final thixRemoteDatasourceProvider = Provider<ThixIaRemoteDatasource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ThixIaRemoteDatasourceImpl(client);
});

// ────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ────────────────────────────────────────────────────────────────────────────
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    remote: ref.watch(thixRemoteDatasourceProvider),
    local: ref.watch(thixLocalDatasourceProvider),
  );
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl(
    remote: ref.watch(thixRemoteDatasourceProvider),
    local: ref.watch(thixLocalDatasourceProvider),
  );
});

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  // <-- CORRECTION ICI : AnalysisRepository attend un client, pas un remote/local
  return AnalysisRepository(
    client: ref.watch(supabaseClientProvider),
  );
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(ref.watch(thixRemoteDatasourceProvider));
});

// ────────────────────────────────────────────────────────────────────────────
// SERVICES
// ────────────────────────────────────────────────────────────────────────────
final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(ref.watch(projectRepositoryProvider));
});

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  return AnalysisService(
    analysisRepo: ref.watch(analysisRepositoryProvider),
    memoryRepo: ref.watch(memoryRepositoryProvider),
  );
});

final projectIntelligenceServiceProvider = Provider<ProjectIntelligenceService>((ref) {
  return ProjectIntelligenceService(
    projectRepo: ref.watch(projectRepositoryProvider),
    memoryRepo: ref.watch(memoryRepositoryProvider),
    analysisRepo: ref.watch(analysisRepositoryProvider),
    documentRepo: ref.watch(documentRepositoryProvider),
    projectService: ref.watch(projectServiceProvider),
  );
});

// ────────────────────────────────────────────────────────────────────────────
// ACTIVE PROJECT
// ────────────────────────────────────────────────────────────────────────────
class ActiveProjectNotifier extends AsyncNotifier<ThixProject?> {
  @override
  Future<ThixProject?> build() async {
    final repo = ref.watch(projectRepositoryProvider);
    return repo.getActiveProject();
  }

  Future<void> setActive(String projectCode) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.setActiveProject(projectCode);
      final project = await repo.getProjectByCode(projectCode);
      state = AsyncData(project);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> clear() async {
    state = const AsyncData(null);
  }
}

final activeProjectProvider = AsyncNotifierProvider<ActiveProjectNotifier, ThixProject?>(() {
  return ActiveProjectNotifier();
});

// ────────────────────────────────────────────────────────────────────────────
// FOURNISSEURS ADDITIONNELS (Pour ProjectsPage)
// ────────────────────────────────────────────────────────────────────────────
final projectSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredProjectsProvider = Provider<List<ThixProject>>((ref) {
  final query = ref.watch(projectSearchQueryProvider).toLowerCase();
  final projects = ref.watch(projectsProvider).value ?? [];
  if (query.isEmpty) return projects;
  return projects.where((p) => p.projectCode.toLowerCase().contains(query) || p.name.toLowerCase().contains(query)).toList();
});

// ────────────────────────────────────────────────────────────────────────────
// PROJECTS LIST
// ────────────────────────────────────────────────────────────────────────────
class ProjectsNotifier extends AsyncNotifier<List<ThixProject>> {
  int _page = 1;
  bool _hasMore = true;
  String? _search;
  String? _status;

  @override
  Future<List<ThixProject>> build() async {
    final service = ref.watch(projectServiceProvider);
    final projects = await service.getProjectsPaginated(page: 1);
    _page = 1;
    _hasMore = projects.length >= 20;
    return projects;
  }

  Future<void> refresh() async {
    _page = 1;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(projectServiceProvider);
      return service.getProjectsPaginated(page: 1, search: _search, status: _status);
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    _page++;
    final service = ref.read(projectServiceProvider);
    final more = await service.getProjectsPaginated(page: _page, search: _search, status: _status);
    if (more.isEmpty) {
      _hasMore = false;
      return;
    }
    final current = state.value ?? [];
    state = AsyncData([...current, ...more]);
  }

  Future<void> search(String query) async {
    _search = query;
    _page = 1;
    await refresh();
  }

  Future<ThixProject> createFromIdea(String idea) async {
    final service = ref.read(projectServiceProvider);
    final project = await service.createProjectFromIdea(idea);
    final current = state.value ?? [];
    state = AsyncData([project, ...current]);
    ref.read(activeProjectProvider.notifier).setActive(project.projectCode);
    return project;
  }
}

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<ThixProject>>(() {
  return ProjectsNotifier();
});
