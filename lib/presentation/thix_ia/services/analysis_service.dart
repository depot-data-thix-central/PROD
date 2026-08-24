// lib/presentation/thix_ia/services/analysis_service.dart
import 'package:flutter/foundation.dart';

import '../repositories/analysis_repository.dart';
import '../repositories/memory_repository.dart';
import '../models/project_analysis.dart';
import '../core/errors/thix_ia_exception.dart';
import 'ai_service.dart';

class AnalysisService {
  AnalysisService({
    required this.analysisRepo,
    required this.memoryRepo,
    required this.aiService,
  });

  final AnalysisRepository analysisRepo;
  final MemoryRepository memoryRepo;
  final AiService aiService;

  static const supportedTypes = [
    'idea',
    'market',
    'competitor',
    'legal',
    'tax',
    'finance',
    'business_plan',
    'strategy',
    'design',
  ];

  // ============================================================
  // ANALYSE D'IDÉE
  // ============================================================
  Future<ProjectAnalysis> startIdeaAnalysis({
    required String projectCode,
    required String ideaDescription,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) async {
    // 1. Créer l'analyse en base (statut running)
    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'idea',
      title: 'Analyse d\'idée',
      payload: {
        'idea': ideaDescription,
        'require_verdict': true,
      },
    );

    // 2. Appel IA en arrière-plan
    _runIdeaAnalysisInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      idea: ideaDescription,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runIdeaAnalysisInBackground({
    required String analysisId,
    required String projectCode,
    required String idea,
    required ThixAiProvider provider,
  }) async {
    try {
      final response = await aiService.analyzeIdea(
        idea: idea,
        projectCode: projectCode,
        provider: provider,
      );

      if (response.success && response.content != null) {
        await analysisRepo.completeAnalysis(
          analysisId: analysisId,
          result: {
            'content': response.content,
            'provider': response.provider,
            'model': response.model,
            'generated_at': DateTime.now().toIso8601String(),
          },
        );
      } else {
        await analysisRepo.failAnalysis(
          analysisId: analysisId,
          error: response.error ?? 'Erreur inconnue lors de l\'analyse d\'idée',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Idea analysis failed: $e\n$st');
      await analysisRepo.failAnalysis(
        analysisId: analysisId,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ÉTUDE DE MARCHÉ
  // ============================================================
  Future<ProjectAnalysis> startMarketAnalysis({
    required String projectCode,
    required String country,
    required String sector,
    String? additionalContext,
    ThixAiProvider provider = ThixAiProvider.anthropic,
  }) async {
    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'market',
      title: 'Étude de marché - $sector - $country',
      payload: {
        'country': country,
        'sector': sector,
        'country_context': country == 'RDC'
            ? 'République Démocratique du Congo, marché émergent Afrique centrale'
            : country,
        'require_sources': true,
        'require_facts': true,
        'min_sources': 3,
      },
    );

    _runMarketAnalysisInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      country: country,
      sector: sector,
      additionalContext: additionalContext,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runMarketAnalysisInBackground({
    required String analysisId,
    required String projectCode,
    required String country,
    required String sector,
    String? additionalContext,
    required ThixAiProvider provider,
  }) async {
    try {
      final query = '''
Étude de marché complète pour le secteur "$sector" en $country.
${additionalContext != null ? 'Contexte supplémentaire : $additionalContext' : ''}
Fournis une analyse structurée avec sources si possible.
''';

      final response = await aiService.marketStudy(
        query: query,
        projectCode: projectCode,
        provider: provider,
      );

      if (response.success && response.content != null) {
        await analysisRepo.completeAnalysis(
          analysisId: analysisId,
          result: {
            'content': response.content,
            'search': response.search,
            'provider': response.provider,
            'model': response.model,
            'generated_at': DateTime.now().toIso8601String(),
          },
        );
      } else {
        await analysisRepo.failAnalysis(
          analysisId: analysisId,
          error: response.error ?? 'Erreur lors de l\'étude de marché',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Market analysis failed: $e\n$st');
      await analysisRepo.failAnalysis(
        analysisId: analysisId,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ANALYSE CONCURRENTIELLE
  // ============================================================
  Future<ProjectAnalysis> startCompetitorAnalysis({
    required String projectCode,
    required String sector,
    required String country,
    String? productDescription,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) async {
    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'competitor',
      title: 'Intelligence concurrentielle - $sector',
      payload: {
        'sector': sector,
        'country': country,
        'product': productDescription,
      },
    );

    _runCompetitorAnalysisInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      sector: sector,
      country: country,
      productDescription: productDescription,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runCompetitorAnalysisInBackground({
    required String analysisId,
    required String projectCode,
    required String sector,
    required String country,
    String? productDescription,
    required ThixAiProvider provider,
  }) async {
    try {
      final query = '''
Analyse concurrentielle pour le secteur "$sector" en $country.
${productDescription != null ? 'Produit/Service : $productDescription' : ''}
Identifie les principaux acteurs, leurs forces/faiblesses, positionnement et opportunités de différenciation.
''';

      final response = await aiService.call(
        action: ThixAiAction.competitor,
        message: query,
        searchQuery: 'concurrents $sector $country',
        projectCode: projectCode,
        provider: provider,
      );

      if (response.success && response.content != null) {
        await analysisRepo.completeAnalysis(
          analysisId: analysisId,
          result: {
            'content': response.content,
            'search': response.search,
            'provider': response.provider,
            'model': response.model,
            'generated_at': DateTime.now().toIso8601String(),
          },
        );
      } else {
        await analysisRepo.failAnalysis(
          analysisId: analysisId,
          error: response.error ?? 'Erreur analyse concurrentielle',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Competitor analysis failed: $e\n$st');
      await analysisRepo.failAnalysis(
        analysisId: analysisId,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ANALYSE LÉGALE / RÉGLEMENTAIRE
  // ============================================================
  Future<ProjectAnalysis> startLegalAnalysis({
    required String projectCode,
    required String jurisdiction,
    required String sector,
    String? activityDescription,
    ThixAiProvider provider = ThixAiProvider.anthropic,
  }) async {
    final analysis = await analysisRepo.startAnalysis(
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

    _runLegalAnalysisInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      jurisdiction: jurisdiction,
      sector: sector,
      activityDescription: activityDescription,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runLegalAnalysisInBackground({
    required String analysisId,
    required String projectCode,
    required String jurisdiction,
    required String sector,
    String? activityDescription,
    required ThixAiProvider provider,
  }) async {
    try {
      final query = '''
Analyse réglementaire et légale pour une activité dans le secteur "$sector" en $jurisdiction.
${activityDescription != null ? 'Description de l\'activité : $activityDescription' : ''}

Important :
- Ne jamais inventer une loi ou une obligation.
- Indiquer clairement les sources et le niveau de certitude.
- Ajouter un avertissement recommandant une validation par un professionnel.
''';

      final response = await aiService.call(
        action: ThixAiAction.legalTax,
        message: query,
        searchQuery: 'réglementation $sector $jurisdiction licences obligations',
        projectCode: projectCode,
        provider: provider,
      );

      if (response.success && response.content != null) {
        await analysisRepo.completeAnalysis(
          analysisId: analysisId,
          result: {
            'content': response.content,
            'search': response.search,
            'provider': response.provider,
            'model': response.model,
            'generated_at': DateTime.now().toIso8601String(),
            'disclaimer': true,
          },
        );
      } else {
        await analysisRepo.failAnalysis(
          analysisId: analysisId,
          error: response.error ?? 'Erreur analyse légale',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Legal analysis failed: $e\n$st');
      await analysisRepo.failAnalysis(
        analysisId: analysisId,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ANALYSE FINANCIÈRE
  // ============================================================
  Future<ProjectAnalysis> startFinanceAnalysis({
    required String projectCode,
    required Map<String, dynamic> financialInputs,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) async {
    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'finance',
      title: 'Modèle financier prévisionnel',
      payload: {
        'inputs': financialInputs,
        'deterministic': true,
        'require_scenarios': ['base', 'optimistic', 'pessimistic'],
      },
    );

    // Note : pour la finance, on peut faire un traitement plus déterministe plus tard.
    // Pour l'instant on passe par l'IA.
    _runFinanceAnalysisInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      inputs: financialInputs,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runFinanceAnalysisInBackground({
    required String analysisId,
    required String projectCode,
    required Map<String, dynamic> inputs,
    required ThixAiProvider provider,
  }) async {
    try {
      final query = '''
Construis un modèle financier prévisionnel à partir des hypothèses suivantes :
${inputs.toString()}

Inclus :
- CAPEX / OPEX
- Hypothèses de revenus
- Seuil de rentabilité
- Scénarios (pessimiste, réaliste, optimiste)
- Besoin de financement
''';

      final response = await aiService.call(
        action: ThixAiAction.businessPlan, // on réutilise pour l'instant
        message: query,
        projectCode: projectCode,
        provider: provider,
      );

      if (response.success && response.content != null) {
        await analysisRepo.completeAnalysis(
          analysisId: analysisId,
          result: {
            'content': response.content,
            'inputs': inputs,
            'provider': response.provider,
            'model': response.model,
            'generated_at': DateTime.now().toIso8601String(),
          },
        );
      } else {
        await analysisRepo.failAnalysis(
          analysisId: analysisId,
          error: response.error ?? 'Erreur modèle financier',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Finance analysis failed: $e\n$st');
      await analysisRepo.failAnalysis(
        analysisId: analysisId,
        error: e.toString(),
      );
    }
  }
// ============================================================
  // CONTRÔLE DES ANALYSES (Pause / Cancel / Delete)
  // ============================================================

  Future<void> pauseAnalysis(String analysisId) async {
    await analysisRepo.updateStatus(analysisId, 'paused');
  }

  Future<void> cancelAnalysis(String analysisId) async {
    await analysisRepo.updateStatus(analysisId, 'cancelled');
  }

  Future<void> deleteAnalysis(String analysisId) async {
    await analysisRepo.deleteAnalysis(analysisId);
  }
  // ============================================================
  // LECTURE
  // ============================================================
  Future<List<ProjectAnalysis>> getProjectAnalyses(String projectCode, {String? type}) {
    return analysisRepo.getAnalyses(projectCode, type: type);
  }

  Stream<ProjectAnalysis> watchProgress(String analysisId) {
    return analysisRepo.watchAnalysis(analysisId);
  }
}
