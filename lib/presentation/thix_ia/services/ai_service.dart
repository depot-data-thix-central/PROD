import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Providers supportés par la Edge Function thix_ai
enum ThixAiProvider {
  auto,
  openai,
  xai,
  gemini,
  anthropic,
  mistral,
}

/// Actions métier disponibles
enum ThixAiAction {
  chat,
  analyzeIdea,
  marketStudy,
  competitor,
  legalTax,
  businessPlan,
  research,
  factCheck,
  smartReply,
  translate,
  summarize,
}

extension ThixAiActionX on ThixAiAction {
  String get value {
    switch (this) {
      case ThixAiAction.chat:
        return 'chat';
      case ThixAiAction.analyzeIdea:
        return 'analyze_idea';
      case ThixAiAction.marketStudy:
        return 'market_study';
      case ThixAiAction.competitor:
        return 'competitor';
      case ThixAiAction.legalTax:
        return 'legal_tax';
      case ThixAiAction.businessPlan:
        return 'business_plan';
      case ThixAiAction.research:
        return 'research';
      case ThixAiAction.factCheck:
        return 'fact_check';
      case ThixAiAction.smartReply:
        return 'smart_reply';
      case ThixAiAction.translate:
        return 'translate';
      case ThixAiAction.summarize:
        return 'summarize';
    }
  }
}

class ThixAiResponse {
  final bool success;
  final String? content;
  final Map<String, dynamic>? parsed;
  final Map<String, dynamic>? search;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic>? meta;
  final String? error;
  final String? provider;
  final String? model;
  final String? projectCode;

  ThixAiResponse({
    required this.success,
    this.content,
    this.parsed,
    this.search,
    this.usage,
    this.meta,
    this.error,
    this.provider,
    this.model,
    this.projectCode,
  });

  factory ThixAiResponse.fromJson(Map<String, dynamic> json) {
    return ThixAiResponse(
      success: json['success'] == true,
      content: json['content'] as String?,
      parsed: json['parsed'] is Map ? Map<String, dynamic>.from(json['parsed']) : null,
      search: json['search'] is Map ? Map<String, dynamic>.from(json['search']) : null,
      usage: json['usage'] is Map ? Map<String, dynamic>.from(json['usage']) : null,
      meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta']) : null,
      error: json['error'] as String?,
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      projectCode: json['project_code'] as String?,
    );
  }
}

class AiService {
  final SupabaseClient _supabase;

  AiService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  /// Appel principal à la Edge Function thix_ai
  Future<ThixAiResponse> call({
    required ThixAiAction action,
    String? message,
    List<Map<String, String>>? messages,
    ThixAiProvider provider = ThixAiProvider.auto,
    String? model,
    String? projectCode,
    String? systemPrompt,
    double temperature = 0.3,
    int maxTokens = 4096,
    bool jsonMode = false,
    String? searchQuery,
    String searchDepth = 'advanced',
    int maxResults = 8,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': action.value,
        'provider': provider.name,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'json_mode': jsonMode,
      };

      if (message != null) body['message'] = message;
      if (messages != null) body['messages'] = messages;
      if (model != null) body['model'] = model;
      if (projectCode != null) body['project_code'] = projectCode;
      if (systemPrompt != null) body['system_prompt'] = systemPrompt;
      if (searchQuery != null) body['search_query'] = searchQuery;
      body['search_depth'] = searchDepth;
      body['max_results'] = maxResults;

      final response = await _supabase.functions.invoke(
        'thix_ai',
        body: body,
      );

      if (response.status != 200 || response.data == null) {
        return ThixAiResponse(
          success: false,
          error: 'Erreur HTTP ${response.status}',
        );
      }

      final data = response.data;
      if (data is! Map) {
        return ThixAiResponse(success: false, error: 'Réponse invalide');
      }

      return ThixAiResponse.fromJson(Map<String, dynamic>.from(data));
    } catch (e, st) {
      debugPrint('❌ AiService error: $e\n$st');
      return ThixAiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ====================== HELPERS PRATIQUES ======================

  /// Analyse d'idée business
  Future<ThixAiResponse> analyzeIdea({
    required String idea,
    String? projectCode,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) {
    return call(
      action: ThixAiAction.analyzeIdea,
      message: idea,
      projectCode: projectCode,
      provider: provider,
    );
  }

  /// Étude de marché (avec recherche Tavily automatique)
  Future<ThixAiResponse> marketStudy({
    required String query,
    String? projectCode,
    ThixAiProvider provider = ThixAiProvider.anthropic,
  }) {
    return call(
      action: ThixAiAction.marketStudy,
      message: query,
      searchQuery: query,
      projectCode: projectCode,
      provider: provider,
    );
  }

  /// Recherche web intelligente
  Future<ThixAiResponse> research({
    required String query,
    String? projectCode,
    ThixAiProvider provider = ThixAiProvider.openai,
  }) {
    return call(
      action: ThixAiAction.research,
      message: query,
      searchQuery: query,
      projectCode: projectCode,
      provider: provider,
    );
  }

  /// Chat libre
  Future<ThixAiResponse> chat({
    required String message,
    String? projectCode,
    ThixAiProvider provider = ThixAiProvider.auto,
    List<Map<String, String>>? history,
  }) {
    return call(
      action: ThixAiAction.chat,
      message: message,
      messages: history,
      projectCode: projectCode,
      provider: provider,
    );
  }

  /// Réponses intelligentes (smart replies)
  Future<List<String>> smartReplies({
    required String lastMessage,
    List<Map<String, String>>? history,
  }) async {
    final res = await call(
      action: ThixAiAction.smartReply,
      message: lastMessage,
      messages: history,
      jsonMode: true,
      provider: ThixAiProvider.openai,
    );

    if (!res.success || res.parsed == null) return [];

    final replies = res.parsed!['replies'];
    if (replies is List) {
      return replies.whereType<String>().toList();
    }
    return [];
  }
}
