// lib/presentation/thix_ia/di/thix_ia_dependencies.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core
import '../../../core/network/supabase_client.dart';

// Datasources
import '../datasources/thix_ia_remote_datasource.dart';
import '../datasources/thix_ia_local_datasource.dart';

// Repositories
import '../repositories/project_repository.dart';
import '../repositories/analysis_repository.dart';

// Services - 5 services prod
import '../services/project_service.dart';
import '../services/project_intelligence_service.dart';
import '../services/analysis_service.dart';
import '../services/document_service.dart';
import '../services/report_service.dart';

// ============================================================
// SUPABASE CLIENT (réutilise ton singleton existant)
// ============================================================
final thixIaSupabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ============================================================
// DATASOURCES
// ============================================================
final thixIaRemoteDatasourceProvider = Provider<ThixIaRemoteDatasource>((ref) {
  final supabase = ref.watch(thixIaSupabaseProvider);
  return ThixIaRemoteDatasource(supabase);
});

final thixIaLocalDatasourceProvider = Provider<ThixIaLocalDatasource>((ref) {
  return ThixIaLocalDatasource();
});

// ============================================================
// REPOSITORIES
// ============================================================
final thixIaProjectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  final local = ref.watch(thixIaLocalDatasourceProvider);
  return ProjectRepository(remote: remote, local: local);
});

final thixIaAnalysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return AnalysisRepository(remote);
});

// ============================================================
// SERVICES - 5 SERVICES FULL PROD
// ============================================================
final projectServiceProvider = Provider<ProjectService>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return ProjectService(remote);
});

final projectIntelligenceServiceProvider = Provider<ProjectIntelligenceService>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return ProjectIntelligenceService(remote);
});

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return AnalysisService(remote);
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return DocumentService(remote);
});

final reportServiceProvider = Provider<ReportService>((ref) {
  final remote = ref.watch(thixIaRemoteDatasourceProvider);
  return ReportService(remote);
});

// ============================================================
// COMBINED INITIALIZATION - Pour main.dart si besoin
// ============================================================
class ThixIaDependencies {
  static Future<void> init(WidgetRef ref) async {
    // Pré-charge local cache
    final local = ref.read(thixIaLocalDatasourceProvider);
    await local.init();

    // Vérifie connexion Supabase
    final supabase = ref.read(thixIaSupabaseProvider);
    try {
      await supabase.from('thix_projects').select('id').limit(1);
    } catch (e) {
      throw Exception('THIX IA Supabase not ready: $e');
    }
  }

  static List<ProviderBase> get allProviders => [
        thixIaSupabaseProvider,
        thixIaRemoteDatasourceProvider,
        thixIaLocalDatasourceProvider,
        thixIaProjectRepositoryProvider,
        thixIaAnalysisRepositoryProvider,
        projectServiceProvider,
        projectIntelligenceServiceProvider,
        analysisServiceProvider,
        documentServiceProvider,
        reportServiceProvider,
      ];
}

// ============================================================
// PROVIDERS EXISTANTS - Références pour compatibilité
// ============================================================
// Ces providers sont déjà dans lib/presentation/thix_ia/providers/
// et utilisent les services ci-dessus

// project_provider.dart -> utilise projectServiceProvider
// active_project_provider.dart -> StateProvider<String?>
// analysis_provider.dart -> utilise analysisServiceProvider
// project_memory_provider.dart -> utilise projectIntelligenceServiceProvider
// document_provider.dart -> utilise documentServiceProvider
// chat_provider.dart -> utilise projectIntelligenceServiceProvider

// Exemple d'usage dans providers/analysis_provider.dart
// final analysesProvider = StateNotifierProvider<AnalysesNotifier, List<ProjectAnalysis>>((ref) {
//   final service = ref.watch(analysisServiceProvider);
//   return AnalysesNotifier(service);
// });
