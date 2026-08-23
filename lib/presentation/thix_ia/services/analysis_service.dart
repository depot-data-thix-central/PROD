// lib/presentation/thix_ia/services/analysis_service.dart
import '../repositories/analysis_repository.dart';
import '../repositories/memory_repository.dart';
import '../models/project_analysis.dart';
import '../core/errors/thix_ia_exception.dart';

class AnalysisService {
  AnalysisService({required this.analysisRepo, required this.memoryRepo});

  final AnalysisRepository analysisRepo;
  final MemoryRepository memoryRepo;

  static const supportedTypes = ['idea', 'market', 'competitor', 'legal', 'tax', 'finance', 'business_plan', 'strategy', 'design'];

  Future<ProjectAnalysis> startMarketAnalysis({required String projectCode, required String country, required String sector}) async {
    if (!supportedTypes.contains('market')) {
      throw const ThixIAValidationException(message: 'Type analyse non supporté');
    }
    return analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'market',
      title: 'Étude de marché - $sector - $country',
      payload: {
        'country': country,
        'sector': sector,
        'country_context': country == 'RDC' ? 'République Démocratique du Congo, marché émergent Afrique centrale' : country,
        'require_sources': true,
        'require_facts': true,
        'min_sources': 3,
      },
    );
  }

  Future<ProjectAnalysis> startLegalAnalysis({required String projectCode, required String jurisdiction, required String sector}) async {
    return analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'legal',
      title: 'Réglementation - $sector - $jurisdiction',
      payload: {
        'jurisdiction': jurisdiction,
        'sector': sector,
        'require_law_reference': true,
        'require_authority': true,
        'require_disclaimer': true,
      },
    );
  }

  Future<ProjectAnalysis> startFinanceAnalysis({required String projectCode, required Map<String, dynamic> financialInputs}) async {
    return analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'finance',
      title: 'Modèle financier prévisionnel',
      payload: {
        'inputs': financialInputs,
        'deterministic': true,
        'require_scenarios': ['base', 'optimistic', 'pessimistic'],
      },
    );
  }

  Future<List<ProjectAnalysis>> getProjectAnalyses(String projectCode, {String? type}) {
    return analysisRepo.getAnalyses(projectCode, type: type);
  }

  Stream<ProjectAnalysis> watchProgress(String analysisId) {
    return analysisRepo.watchAnalysis(analysisId);
  }
}
