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
    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'idea',
      title: 'Analyse d\'idée',
      payload: {
        'idea': ideaDescription,
        'require_verdict': true,
      },
    );

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
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
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
    final shortIdea = additionalContext != null && additionalContext.length > 60
        ? '${additionalContext.substring(0, 57)}...'
        : additionalContext;

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'market',
      title: shortIdea != null
          ? 'Étude de marché – $shortIdea'
          : 'Étude de marché - $sector - $country',
      payload: {
        'country': country,
        'sector': sector,
        'idea_context': additionalContext,
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
Tu es un expert en analyse de marché en Afrique centrale (spécialement RDC).

**Idée business exacte à analyser en priorité :**
${additionalContext ?? 'Non spécifiée'}

Secteur : $sector
Pays : $country

Fais une étude de marché **spécifique à cette idée**, pas une analyse générale du secteur.
Structure claire, données locales si possible, sources et recommandations concrètes.
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
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
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
    final shortIdea = productDescription != null && productDescription.length > 50
        ? '${productDescription.substring(0, 47)}...'
        : productDescription;

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'competitor',
      title: shortIdea != null
          ? 'Concurrents – $shortIdea'
          : 'Intelligence concurrentielle - $sector',
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
Tu es un expert en intelligence concurrentielle en RDC / Afrique centrale.

**Idée / Produit / Service à analyser :**
${productDescription ?? 'Non spécifié'}

Secteur : $sector
Pays : $country

Identifie les principaux acteurs (directs et indirects), leurs forces/faiblesses, 
positionnement et les opportunités de différenciation pour cette idée précise.
''';

      final response = await aiService.call(
        action: ThixAiAction.competitor,
        message: query,
        searchQuery: 'concurrents $sector $country ${productDescription ?? ''}',
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
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
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
    final shortIdea = activityDescription != null && activityDescription.length > 50
        ? '${activityDescription.substring(0, 47)}...'
        : activityDescription;

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'legal',
      title: shortIdea != null
          ? 'Réglementation – $shortIdea'
          : 'Réglementation - $sector - $jurisdiction',
      payload: {
        'jurisdiction': jurisdiction,
        'sector': sector,
        'activity': activityDescription,
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
Tu es un expert en réglementation et formalités administratives en RDC / Afrique centrale.

**Activité / Idée exacte à analyser :**
${activityDescription ?? 'Non spécifiée'}

Secteur : $sector
Juridiction : $jurisdiction

Important :
- Ne jamais inventer une loi ou une obligation.
- Indiquer clairement les sources et le niveau de certitude.
- Ajouter un avertissement recommandant une validation par un professionnel.
''';

      final response = await aiService.call(
        action: ThixAiAction.legalTax,
        message: query,
        searchQuery: 'réglementation $sector $jurisdiction licences obligations ${activityDescription ?? ''}',
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
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
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
    final idea = financialInputs['idea_context'] as String?;

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'finance',
      title: idea != null && idea.isNotEmpty
          ? 'Modèle financier – \( {idea.length > 40 ? ' \){idea.substring(0, 37)}...' : idea}'
          : 'Modèle financier prévisionnel',
      payload: {
        'inputs': financialInputs,
        'deterministic': true,
        'require_scenarios': ['base', 'optimistic', 'pessimistic'],
      },
    );

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
      final idea = inputs['idea_context'] as String? ?? 'Non spécifiée';

      final query = '''
Tu es un expert en modélisation financière pour startups et PME en RDC.

**Idée business :**
$idea

Hypothèses fournies :
${inputs.toString()}

Construis un modèle financier prévisionnel réaliste.
Inclus :
- CAPEX / OPEX
- Hypothèses de revenus
- Seuil de rentabilité
- Scénarios (pessimiste, réaliste, optimiste)
- Besoin de financement
''';

      final response = await aiService.call(
        action: ThixAiAction.businessPlan,
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
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
    }
  }

  // ============================================================
  // BUSINESS PLAN
  // ============================================================
  Future<ProjectAnalysis> startBusinessPlanAnalysis({
    required String projectCode,
    required String ideaDescription,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) async {
    final shortIdea = ideaDescription.length > 50
        ? '${ideaDescription.substring(0, 47)}...'
        : ideaDescription;

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'business_plan',
      title: 'Business plan – $shortIdea',
      payload: {
        'idea': ideaDescription,
        'require_full_plan': true,
      },
    );

    _runBusinessPlanInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      idea: ideaDescription,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runBusinessPlanInBackground({
    required String analysisId,
    required String projectCode,
    required String idea,
    required ThixAiProvider provider,
  }) async {
    try {
      final query = '''
Tu es un expert en business plan pour l'Afrique centrale (RDC).

**Idée business exacte :**
$idea

Génère un business plan structuré et actionnable comprenant :
1. Résumé exécutif
2. Description de l'idée et proposition de valeur
3. Analyse de marché
4. Stratégie commerciale
5. Organisation et équipe
6. Plan financier sommaire
7. Risques et mitigation
8. Feuille de route (12-24 mois)
''';

      final response = await aiService.call(
        action: ThixAiAction.businessPlan,
        message: query,
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
          error: response.error ?? 'Erreur génération business plan',
        );
      }
    } catch (e, st) {
      debugPrint('❌ Business plan failed: $e\n$st');
      await analysisRepo.failAnalysis(analysisId: analysisId, error: e.toString());
    }
  }

  // ============================================================
  // CONTRÔLE
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

  Future<List<ProjectAnalysis>> getProjectAnalyses(String projectCode, {String? type}) {
    return analysisRepo.getAnalyses(projectCode, type: type);
  }

  Stream<ProjectAnalysis> watchProgress(String analysisId) {
    return analysisRepo.watchAnalysis(analysisId);
  }
}
