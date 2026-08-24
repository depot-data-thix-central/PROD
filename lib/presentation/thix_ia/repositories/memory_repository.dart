// lib/presentation/thix_ia/repositories/memory_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';
import '../models/project_memory.dart';
import '../core/errors/thix_ia_exception.dart';

/// ============================================================================
/// MEMORY REPOSITORY - Project Memory Engine §7
/// ============================================================================

abstract class MemoryRepository {
  Future<ProjectMemory> getMemory(String projectCode, {bool forceRefresh = false});
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
    // 1) Cache local (jamais faire planter l'UI)
    if (!forceRefresh) {
      try {
        final cached = await local.getCachedMemory(projectCode);
        if (cached != null) return cached;
      } catch (_) {
        // Hive / late non init → on ignore le cache
      }
    }

    // 2) Supabase
    try {
      final fresh = await remote.getProjectMemory(projectCode);
      try {
        await local.cacheProjectMemory(fresh);
      } catch (_) {
        // cache en échec = non bloquant
      }
      return fresh;
    } catch (_) {
      // Tables vides / erreur parse → mémoire vide (empty state UI)
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
      dateCollected: DateTime.now(),
      dateVerified: DateTime.now(),
    );

    await remote.upsertProjectFact({
      'project_code': projectCode,
      'type': fact.type,
      'content': fact.content,
      'source_url': fact.sourceUrl,
      'source_name': fact.sourceName,
      'confidence': fact.confidence,
      'date_collected': fact.dateCollected?.toIso8601String(),
      'date_verified': fact.dateVerified?.toIso8601String(),
    });

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
      'title': title,
      'description': description,
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
      'title': title,
      'reason': reason,
      'decided_at': DateTime.now().toIso8601String(),
    });
  }
}
