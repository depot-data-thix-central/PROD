// lib/presentation/thix_ia/services/project_service.dart
import '../repositories/project_repository.dart';
import '../models/thix_project.dart';
import '../core/constants/thix_ia_constants.dart';

/// ============================================================================
/// PROJECT SERVICE - Logique métier pure (calcul progression pondérée §19)
/// ============================================================================

class ProjectService {
  ProjectService(this._projectRepo);

  final ProjectRepository _projectRepo;

  // Calcul progression réelle basée sur livrables, pas arbitraire
  double calculateProgress({
    required bool hasProblem,
    required bool hasCustomer,
    required bool hasMarketResearch,
    required bool hasCompetition,
    required bool hasRegulation,
    required bool hasBusinessModel,
    required bool hasFinancialModel,
    required bool hasStrategy,
    required bool hasValidation,
    required bool hasBusinessPlan,
    bool hasPrototype = false,
  }) {
    final weights = <String, double>{
      'problem': 0.15,
      'customer': 0.10,
      'market': 0.15,
      'competition': 0.10,
      'regulation': 0.10,
      'businessModel': 0.10,
      'financial': 0.10,
      'strategy': 0.05,
      'validation': 0.05,
      'businessPlan': 0.10,
    };

    double score = 0;
    if (hasProblem) score += weights['problem']!;
    if (hasCustomer) score += weights['customer']!;
    if (hasMarketResearch) score += weights['market']!;
    if (hasCompetition) score += weights['competition']!;
    if (hasRegulation) score += weights['regulation']!;
    if (hasBusinessModel) score += weights['businessModel']!;
    if (hasFinancialModel) score += weights['financial']!;
    if (hasStrategy) score += weights['strategy']!;
    if (hasValidation) score += weights['validation']!;
    if (hasBusinessPlan) score += weights['businessPlan']!;
    if (hasPrototype) score += 0.05; // bonus

    return score.clamp(0.0, 1.0);
  }

  Future<List<ThixProject>> getProjectsPaginated({int page = 1, String? search, String? status}) {
    final limit = page == 1? ThixIAConstants.defaultPageSize : ThixIAConstants.defaultPageSize;
    return _projectRepo.getProjects(page: page, limit: limit, search: search, status: status);
  }
Future<void> deleteProject(String projectCode) async {
  await projectRepo.deleteProject(projectCode);
}
  Future<ThixProject> createProjectFromIdea(String rawIdea) async {
    // Extraction simple - Phase 2 utilisera LLM pour extraction structurée
    final ideaLower = rawIdea.toLowerCase();
    String sector = 'General';
    if (ideaLower.contains('agricole') || ideaLower.contains('agri')) sector = 'AgriTech';
    if (ideaLower.contains('fintech') || ideaLower.contains('paiement')) sector = 'Fintech';
    if (ideaLower.contains('santé') || ideaLower.contains('health')) sector = 'HealthTech';

    String country = 'RDC';
    String? city;
    if (ideaLower.contains('kinshasa')) city = 'Kinshasa';
    if (ideaLower.contains('kigali')) { country = 'RW'; city = 'Kigali'; }

    final name = rawIdea.length > 60? '${rawIdea.substring(0, 60)}...' : rawIdea;

    return _projectRepo.createProject(
      name: name,
      sector: sector,
      country: country,
      city: city,
      summary: rawIdea,
    );
  }

  Future<void> setActive(String code) => _projectRepo.setActiveProject(code);
  Future<ThixProject?> getActive() => _projectRepo.getActiveProject();
}
