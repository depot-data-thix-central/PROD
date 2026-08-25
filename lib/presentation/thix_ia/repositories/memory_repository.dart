// lib/presentation/thix_ia/repositories/memory_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../models/project_memory.dart';
import '../core/errors/thix_ia_exception.dart';

abstract class MemoryRepository {
  Future<ProjectMemory> getMemory(String projectCode,
      {bool forceRefresh = false});
  Future<ProjectFact> addFact({
    required String projectCode,
    required String type,
    required String content,
    String? sourceUrl,
    String? sourceName,
    double confidence,
  });
  Future<void> addIdea({
    required String projectCode,
    required String title,
    String? description,
  });
  Future<void> addDecision({
    required String projectCode,
    required String title,
    String? reason,
  });
}

class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({required this.remote, required this.local});

  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  ProjectMemory _empty(String projectCode) {
    return ProjectMemory(
      projectCode: projectCode,
      identity: const ProjectIdentity(
        name: '',
        sector: '',
        country: 'RDC',
      ),
      context: const ProjectContext(),
      facts: const [],
      ideas: const [],
      decisions: const [],
    );
  }

  @override
  Future<ProjectMemory> getMemory(
    String projectCode, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cached = await local.getCachedMemory(projectCode);
        if (cached != null && cached.facts.isNotEmpty) return cached;
      } catch (_) {}
    }

    try {
      final fresh = await remote.getProjectMemory(projectCode);
      try {
        await local.cacheProjectMemory(fresh);
      } catch (_) {}
      return fresh;
    } catch (_) {
      return _empty(projectCode);
    }
  }

  @override
  Future<ProjectFact> addFact({
    required String projectCode,
    required String type,
    required String content,
    String? sourceUrl,
    String? sourceName,
    double confidence = 0.8,
  }) async {
    if (content.trim().isEmpty) {
      throw const ThixIAValidationException(
        message: 'Le contenu du fait est requis',
      );
    }

    final fact = ProjectFact(
      id: '',
      type: type,
      content: content.trim(),
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      confidence: confidence,
    );

    // UNIQUEMENT les colonnes qui existent en DB
    final payload = <String, dynamic>{
      'project_code': projectCode,
      'type': fact.type,
      'content': fact.content,
      'confidence': fact.confidence,
    };
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      payload['source_url'] = sourceUrl;
    }
    if (sourceName != null && sourceName.isNotEmpty) {
      payload['source_name'] = sourceName;
    }

    await remote.upsertProjectFact(payload);

    try {
      final updated = await remote.getProjectMemory(projectCode);
      await local.cacheProjectMemory(updated);
    } catch (_) {}

    return fact;
  }

  @override
  Future<void> addIdea({
    required String projectCode,
    required String title,
    String? description,
  }) async {
    await remote.upsertProjectFact({
      'project_code': projectCode,
      'type': 'idea',
      'content': description?.trim().isNotEmpty == true
          ? '\( {title.trim()}\n\n \){description!.trim()}'
          : title.trim(),
      'source_name': title.trim(),
      'confidence': 0.7,
    });
  }

  @override
  Future<void> addDecision({
    required String projectCode,
    required String title,
    String? reason,
  }) async {
    await remote.upsertProjectFact({
      'project_code': projectCode,
      'type': 'decision',
      'content': reason?.trim().isNotEmpty == true
          ? '\( {title.trim()}\n\n \){reason!.trim()}'
          : title.trim(),
      'source_name': title.trim(),
      'confidence': 0.9,
    });
  }
}
