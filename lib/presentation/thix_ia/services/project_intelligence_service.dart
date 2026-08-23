// lib/presentation/thix_ia/services/project_intelligence_service.dart
import '../repositories/project_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/analysis_repository.dart';
import '../models/thix_project.dart';
import '../models/project_memory.dart';
import '../models/project_analysis.dart';
import '../models/document.dart';
import 'project_service.dart';

/// ============================================================================
/// PROJECT INTELLIGENCE SERVICE - Agrégateur §16 du cahier
/// Construit la vue 360° d'un projet pour THIX IA
/// ============================================================================

class ProjectIntelligence {
  const ProjectIntelligence({
    required this.project,
    required this.memory,
    required this.analyses,
    required this.documents,
    required this.progress,
    required this.nextActions,
  });

  final ThixProject project;
  final ProjectMemory memory;
  final List<ProjectAnalysis> analyses;
  final List<ProjectDocument> documents;
  final double progress;
  final List<String> nextActions;
}

class ProjectIntelligenceService {
  ProjectIntelligenceService({
    required this.projectRepo,
    required this.memoryRepo,
    required this.analysisRepo,
    required this.documentRepo,
    required this.projectService,
  });

  final ProjectRepository projectRepo;
  final MemoryRepository memoryRepo;
  final AnalysisRepository analysisRepo;
  final DocumentRepository documentRepo;
  final ProjectService projectService;

  Future<ProjectIntelligence> getIntelligence(String projectCode) async {
    // Parallélisation pour perf (millions users)
    // CORRECTION : Ajout du typage <Future<dynamic>> pour éviter l'erreur de compilation web
    final results = await Future.wait<dynamic>([
      projectRepo.getProjectByCode(projectCode),
      memoryRepo.getMemory(projectCode),
      analysisRepo.getAnalyses(projectCode),
      documentRepo.getDocuments(projectCode),
    ]);

    final project = results[0] as ThixProject;
    final memory = results[1] as ProjectMemory;
    final analyses = results[2] as List<ProjectAnalysis>;
    final documents = results[3] as List<ProjectDocument>;

    // Calcul progression réelle §19 cahier
    final progress = projectService.calculateProgress(
      hasProblem: memory.context.problem != null && memory.context.problem!.isNotEmpty,
      hasCustomer: memory.context.targetCustomers.isNotEmpty,
      hasMarketResearch: analyses.any((a) => a.type == 'market' && a.isCompleted),
      hasCompetition: analyses.any((a) => a.type == 'competitor' && a.isCompleted),
      hasRegulation: analyses.any((a) => a.type == 'legal' && a.isCompleted),
      hasBusinessModel: memory.context.valueProposition != null,
      hasFinancialModel: analyses.any((a) => a.type == 'finance' && a.isCompleted),
      hasStrategy: analyses.any((a) => a.type == 'strategy' && a.isCompleted),
      hasValidation: memory.openQuestions.isEmpty,
      hasBusinessPlan: analyses.any((a) => a.type == 'business_plan' && a.isCompleted),
      hasPrototype: documents.any((d) => d.fileType == 'figma' || d.fileName.contains('prototype')),
    );

    // Prochaines actions intelligentes
    final nextActions = _suggestNextActions(
      memory: memory,
      analyses: analyses,
      documents: documents,
      progress: progress,
    );

    return ProjectIntelligence(
      project: project.copyWith(progress: progress),
      memory: memory,
      analyses: analyses,
      documents: documents,
      progress: progress,
      nextActions: nextActions,
    );
  }

  List<String> _suggestNextActions({
    required ProjectMemory memory, 
    required List<ProjectAnalysis> analyses, 
    required List<ProjectDocument> documents, 
    required double progress
  }) {
    final actions = <String>[];

    if (memory.context.problem == null) actions.add('Définir le problème client');
    if (memory.context.targetCustomers.isEmpty) actions.add('Identifier vos clients cibles');
    if (!analyses.any((a) => a.type == 'market')) actions.add('Lancer étude de marché');
    if (!analyses.any((a) => a.type == 'legal')) actions.add('Vérifier réglementation');
    if (documents.isEmpty) actions.add('Importer votre pitch ou business plan');
    if (progress < 0.5) actions.add('Compléter l\'analyse d\'idée');
    if (progress >= 0.8 && !analyses.any((a) => a.type == 'business_plan')) actions.add('Générer le Business Plan final');

    return actions.take(3).toList();
  }
}
