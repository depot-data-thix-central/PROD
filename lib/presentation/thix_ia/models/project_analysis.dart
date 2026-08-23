// lib/presentation/thix_ia/models/project_analysis.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// PROJECT ANALYSIS - Table: project_analyses + ai_runs + citations
/// Gère le versioning et la progression réelle (pas arbitraire)
/// ============================================================================

enum AnalysisStatus { queued, running, completed, failed, cancelled }

extension AnalysisStatusParser on String {
  AnalysisStatus toAnalysisStatus() {
    switch (toLowerCase()) {
      case 'queued': return AnalysisStatus.queued;
      case 'running': return AnalysisStatus.running;
      case 'completed': return AnalysisStatus.completed;
      case 'failed': return AnalysisStatus.failed;
      case 'cancelled': return AnalysisStatus.cancelled;
      default: return AnalysisStatus.queued;
    }
  }
}

class ProjectAnalysis extends Equatable {
  const ProjectAnalysis({
    required this.id,
    required this.projectCode,
    required this.type, // idea, market, legal...
    required this.status,
    this.progress = 0,
    this.title,
    this.summary,
    this.resultJson,
    this.confidence = 0.0,
    this.sources = const [],
    this.citations = const [],
    this.aiModelUsed,
    this.promptVersion,
    this.tokensUsed,
    this.executionTimeMs,
    this.createdAt,
    this.completedAt,
    this.version = 1,
  });

  final String id;
  final String projectCode;
  final String type;
  final AnalysisStatus status;
  final int progress; // 0-100 calculé sur livrables
  final String? title;
  final String? summary;
  final Map<String, dynamic>? resultJson; // Résultat structuré
  final double confidence;
  final List<String> sources; // URLs
  final List<Citation> citations;
  final String? aiModelUsed;
  final String? promptVersion;
  final int? tokensUsed;
  final int? executionTimeMs;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final int version;

  bool get isRunning => status == AnalysisStatus.running || status == AnalysisStatus.queued;
  bool get isCompleted => status == AnalysisStatus.completed;
  bool get isFailed => status == AnalysisStatus.failed;

  factory ProjectAnalysis.fromJson(Map<String, dynamic> json) {
    return ProjectAnalysis(
      id: JsonUtils.stringValue(json, 'id'),
      projectCode: JsonUtils.stringValue(json, 'project_code'),
      type: JsonUtils.stringValue(json, 'type', fallback: 'idea'),
      status: JsonUtils.stringValue(json, 'status', fallback: 'queued').toAnalysisStatus(),
      progress: JsonUtils.intValue(json, 'progress'),
      title: JsonUtils.stringValue(json, 'title'),
      summary: JsonUtils.stringValue(json, 'summary'),
      resultJson: JsonUtils.asMap(json['result_json']),
      confidence: JsonUtils.doubleValue(json, 'confidence'),
      sources: JsonUtils.stringList(json, 'sources'),
      citations: JsonUtils.asList(json['citations'], fromMap: Citation.fromJson),
      aiModelUsed: JsonUtils.stringValue(json, 'ai_model_used'),
      promptVersion: JsonUtils.stringValue(json, 'prompt_version'),
      tokensUsed: json['tokens_used'] is int? json['tokens_used'] : null,
      executionTimeMs: json['execution_time_ms'] is int? json['execution_time_ms'] : null,
      createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      completedAt: JsonUtils.dateTimeValue(json, 'completed_at'),
      version: JsonUtils.intValue(json, 'version', fallback: 1),
    );
  }

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'type': type,
        'status': status.name,
        'progress': progress,
        'title': title,
        'summary': summary,
        'result_json': resultJson,
        'confidence': confidence,
        'sources': sources,
        'ai_model_used': aiModelUsed,
        'prompt_version': promptVersion,
        'version': version,
      });

  ProjectAnalysis copyWith({AnalysisStatus? status, int? progress, Map<String, dynamic>? resultJson}) {
    return ProjectAnalysis(
      id: id,
      projectCode: projectCode,
      type: type,
      status: status?? this.status,
      progress: progress?? this.progress,
      title: title,
      summary: summary,
      resultJson: resultJson?? this.resultJson,
      confidence: confidence,
      sources: sources,
      citations: citations,
      aiModelUsed: aiModelUsed,
      promptVersion: promptVersion,
      tokensUsed: tokensUsed,
      executionTimeMs: executionTimeMs,
      createdAt: createdAt,
      completedAt: completedAt,
      version: version,
    );
  }

  @override
  List<Object?> get props => [id, projectCode, type, status, progress, version];
}

class Citation extends Equatable {
  const Citation({
    required this.id,
    required this.sourceUrl,
    this.quote,
    this.page,
    this.confidence = 0.8,
  });

  final String id;
  final String sourceUrl;
  final String? quote;
  final int? page;
  final double confidence;

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        id: JsonUtils.stringValue(json, 'id'),
        sourceUrl: JsonUtils.stringValue(json, 'source_url'),
        quote: JsonUtils.stringValue(json, 'quote'),
        page: json['page'] is int? json['page'] : null,
        confidence: JsonUtils.doubleValue(json, 'confidence', fallback: 0.8),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_url': sourceUrl,
        'quote': quote,
        'page': page,
        'confidence': confidence,
      };

  @override
  List<Object?> get props => [id, sourceUrl];
}
