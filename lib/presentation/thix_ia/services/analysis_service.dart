// lib/presentation/thix_ia/services/analysis_service.dart
import 'package:flutter/foundation.dart';
import '../repositories/bp_config_repository.dart';
import '../models/business_plan_config.dart';
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
  // BUSINESS PLAN (données fondateur = Supabase uniquement)
  // ============================================================
  Future<ProjectAnalysis> startBusinessPlanAnalysis({
    required String projectCode,
    required String ideaDescription,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) async {
    final bpRepo = BpConfigRepository();

    // 1) Config fondateur depuis Supabase (peut être null)
    final founderConfig = await bpRepo.getByProject(projectCode);

    // 2) Seed Execution (capital → thix_execution_finances)
    await bpRepo.seedExecution(projectCode);

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
        if (founderConfig != null) 'founder_config_id': founderConfig.id,
        if (founderConfig != null) 'founder_config': founderConfig.toJson(),
      },
    );

    _runBusinessPlanInBackground(
      analysisId: analysis.id,
      projectCode: projectCode,
      idea: ideaDescription,
      founderConfig: founderConfig,
      provider: provider,
    );

    return analysis;
  }

  Future<void> _runBusinessPlanInBackground({
    required String analysisId,
    required String projectCode,
    required String idea,
    BusinessPlanConfig? founderConfig,
    required ThixAiProvider provider,
  }) async {
    try {
      final founderBlock = founderConfig != null
          ? founderConfig.toPromptBlock()
          : 'Aucune donnée fondateur en base (thix_bp_config vide). '
              'Estime de façon réaliste pour le pays / secteur du projet.';

      final query = '''
Tu es le directeur stratégique de THIX IA.

**IDÉE DE PROJET EXACTE :**
"$idea"

$founderBlock

DIRECTIVE CRITIQUE :
- Utilise IMPÉRATIVEMENT les données fondateur ci-dessus si présentes (nom produit, capital, USP, cible, levée, équipe).
- Ne contredis JAMAIS les chiffres fournis par le fondateur.
- Si un champ est absent, estime de façon réaliste pour l'Afrique / le pays du projet.
- BP prêt investisseurs, ultra-personnalisé et actionnable.

Structure obligatoire :
1. Résumé exécutif
2. Présentation du projet et Proposition de valeur unique
3. Analyse de marché (ciblée)
4. Stratégie commerciale et Marketing
5. Organisation, Logistique et Équipe
6. Plan financier sommaire (aligné sur capital / levée indiqués)
7. Risques et mesures d'atténuation
8. Feuille de route (12 à 24 mois)
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
            if (founderConfig != null)
              'founder_config': founderConfig.toJson(),
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
Tu es un expert en analyse de marché en Afrique (spécialement $country).

**PROJET SPÉCIFIQUE À ANALYSER IMPÉRATIVEMENT :**
"${additionalContext ?? 'Non spécifiée'}"

Secteur général : $sector
Pays cible : $country

DIRECTIVE CRITIQUE : Ton étude de marché doit être **ultra-ciblée** sur le projet spécifique mentionné ci-dessus (ex: si le projet est une usine d'eau à Kinshasa, ne parle pas du commerce général, mais uniquement du marché de l'eau potable à Kinshasa). 
Structure : Taille du marché cible, Segments de clients potentiels pour CE projet, Tendances actuelles, Opportunités spécifiques et Menaces.
Cite tes sources.
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
Tu es un expert en intelligence concurrentielle pour le marché de $country.

**PROJET/PRODUIT SPÉCIFIQUE :**
"${productDescription ?? 'Non spécifié'}"

DIRECTIVE CRITIQUE : Identifie les concurrents directs et indirects qui s'opposent EXACTEMENT à cette idée précise dans la région cible. 
Pour chaque concurrent pertinent, donne : Ses forces, ses faiblesses, et surtout les opportunités de différenciation pour notre projet spécifique. Ne fais pas de généralités sur le secteur $sector.
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
Tu es un avocat spécialisé en droit des affaires et réglementations en $jurisdiction.

**ACTIVITÉ EXACTE DU PROJET :**
"${activityDescription ?? 'Non spécifiée'}"

DIRECTIVE CRITIQUE : Tu dois analyser les lois, les licences nécessaires, et les normes IMPÉRATIVES (ex: normes d'hygiène, autorisations environnementales, agréments) EXCLUSIVEMENT pour cette activité précise en $jurisdiction. 
Quels ministères ou entités l'entrepreneur doit-il contacter ? Quelles sont les interdictions potentielles ?
Ne jamais inventer une loi. Cite les institutions officielles.
''';

      final response = await aiService.call(
        action: ThixAiAction.legalTax,
        message: query,
        searchQuery: 'réglementation lois licences $jurisdiction ${activityDescription ?? sector}',
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

    final titleString = (idea != null && idea.isNotEmpty)
        ? 'Modèle financier – ' + (idea.length > 40 ? '${idea.substring(0, 37)}...' : idea)
        : 'Modèle financier prévisionnel';

    final analysis = await analysisRepo.startAnalysis(
      projectCode: projectCode,
      type: 'finance',
      title: titleString,
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
Tu es un directeur financier expert en modélisation pour startups en Afrique.

**PROJET EXACT :**
"$idea"

Hypothèses fournies :
${inputs.toString()}

DIRECTIVE CRITIQUE : Construis un modèle financier prévisionnel réaliste, SUR MESURE pour ce projet spécifique.
Inclus :
- CAPEX (investissements initiaux typiques pour ce projet) / OPEX (coûts récurrents)
- Modèle de revenus adapté
- Scénarios (pessimiste, réaliste, optimiste)
- Évaluation globale du besoin de financement
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
