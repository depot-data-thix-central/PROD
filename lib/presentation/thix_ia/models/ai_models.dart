// lib/presentation/thix_ia/models/ai_models.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// AI MODELS - Orchestration multi-modèles §6 du cahier
/// Table: ai_runs - Aucun modèle hardcodé, tout configurable serveur
/// ============================================================================

enum AiProvider { openai, gemini, anthropic, mistral, local }

extension AiProviderParser on String {
  AiProvider toProvider() {
    switch (toLowerCase()) {
      case 'openai': return AiProvider.openai;
      case 'gemini': return AiProvider.gemini;
      case 'anthropic': return AiProvider.anthropic;
      case 'mistral': return AiProvider.mistral;
      default: return AiProvider.openai;
    }
  }
}

enum AiTaskType {
  reasoning,
  research,
  extraction,
  summarization,
  financeCalc,
  imageGen,
  embedding,
  factCheck,
}

class AiModelConfig extends Equatable {
  const AiModelConfig({
    required this.id,
    required this.provider,
    required this.modelName,
    required this.taskType,
    this.isActive = true,
    this.maxTokens = 4096,
    this.temperature = 0.7,
    this.version,
  });

  final String id;
  final AiProvider provider;
  final String modelName; // gpt-4o, gemini-1.5-pro...
  final AiTaskType taskType;
  final bool isActive;
  final int maxTokens;
  final double temperature;
  final String? version;

  factory AiModelConfig.fromJson(Map<String, dynamic> json) => AiModelConfig(
        id: JsonUtils.stringValue(json, 'id'),
        provider: JsonUtils.stringValue(json, 'provider', fallback: 'openai').toProvider(),
        modelName: JsonUtils.stringValue(json, 'model_name'),
        taskType: _parseTask(JsonUtils.stringValue(json, 'task_type')),
        isActive: JsonUtils.boolValue(json, 'is_active', fallback: true),
        maxTokens: JsonUtils.intValue(json, 'max_tokens', fallback: 4096),
        temperature: JsonUtils.doubleValue(json, 'temperature', fallback: 0.7),
        version: JsonUtils.stringValue(json, 'version'),
      );

  static AiTaskType _parseTask(String s) {
    switch (s) {
      case 'research': return AiTaskType.research;
      case 'extraction': return AiTaskType.extraction;
      case 'financeCalc': return AiTaskType.financeCalc;
      case 'imageGen': return AiTaskType.imageGen;
      default: return AiTaskType.reasoning;
    }
  }

  @override
  List<Object?> get props => [id, provider, modelName, taskType];
}

class AiRun extends Equatable {
  const AiRun({
    required this.id,
    required this.projectCode,
    required this.analysisId,
    required this.provider,
    required this.modelName,
    required this.taskType,
    this.prompt,
    this.response,
    this.tokensInput,
    this.tokensOutput,
    this.costUsd,
    this.durationMs,
    this.status = 'completed',
    this.error,
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String analysisId;
  final AiProvider provider;
  final String modelName;
  final AiTaskType taskType;
  final String? prompt;
  final String? response;
  final int? tokensInput;
  final int? tokensOutput;
  final double? costUsd;
  final int? durationMs;
  final String status;
  final String? error;
  final DateTime? createdAt;

  factory AiRun.fromJson(Map<String, dynamic> json) => AiRun(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        analysisId: JsonUtils.stringValue(json, 'analysis_id'),
        provider: JsonUtils.stringValue(json, 'provider').toProvider(),
        modelName: JsonUtils.stringValue(json, 'model_name'),
        taskType: AiModelConfig._parseTask(JsonUtils.stringValue(json, 'task_type')),
        prompt: JsonUtils.stringValue(json, 'prompt'),
        response: JsonUtils.stringValue(json, 'response'),
        tokensInput: json['tokens_input'] as int?,
        tokensOutput: json['tokens_output'] as int?,
        costUsd: json['cost_usd'] is num? (json['cost_usd'] as num).toDouble() : null,
        durationMs: json['duration_ms'] as int?,
        status: JsonUtils.stringValue(json, 'status', fallback: 'completed'),
        error: JsonUtils.stringValue(json, 'error'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'analysis_id': analysisId,
        'provider': provider.name,
        'model_name': modelName,
        'task_type': taskType.name,
        'prompt': prompt,
        'response': response,
        'tokens_input': tokensInput,
        'tokens_output': tokensOutput,
        'cost_usd': costUsd,
        'duration_ms': durationMs,
        'status': status,
        'error': error,
      });

  @override
  List<Object?> get props => [id, projectCode, analysisId];
}
