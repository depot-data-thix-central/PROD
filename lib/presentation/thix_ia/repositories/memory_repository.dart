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
  Future<ProjectFact> addFact({required String projectCode, required String type, required String content, String? sourceUrl, String? sourceName, double confidence});
  Future<void> addIdea({required String projectCode, required String title, String? description});
  Future<void> addDecision({required String projectCode, required String title, String? reason});
}

class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({required this.remote, required this.local});

  final ThixIaRemoteDatasource remote;
  final ThixIaLocalDatasource local;

  @override
  Future<ProjectMemory> getMemory(String projectCode, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await local.getCachedMemory(projectCode);
      if (cached!= null) return cached;
    }
    final fresh = await remote.getProjectMemory(projectCode);
    await local.cacheProjectMemory(fresh);
    return fresh;
  }

  @override
  Future<ProjectFact> addFact({required String projectCode, required String type, required String content, String? sourceUrl, String? sourceName, double confidence = 0.8}) async {
    if (content.trim().isEmpty) throw const ThixIAValidationException(message: 'Le contenu du fait est requis');

    final fact = ProjectFact(
      id: '', // généré par Supabase
      type: type, // fact, estimation, hypothesis, recommendation
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

    // Invalide le cache pour forcer refresh
    final updated = await remote.getProjectMemory(projectCode);
    await local.cacheProjectMemory(updated);
    return fact;
  }

  @override
  Future<void> addIdea({required String projectCode, required String title, String? description}) async {
    await remote.upsertProjectFact({
      'project_code': projectCode,
      'type': 'idea',
      'title': title,
      'description': description,
    });
  }

  @override
  Future<void> addDecision({required String projectCode, required String title, String? reason}) async {
    await remote.upsertProjectFact({
      'project_code': projectCode,
      'type': 'decision',
      'title': title,
      'reason': reason,
      'decided_at': DateTime.now().toIso8601String(),
    });
  }
}
