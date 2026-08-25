// lib/presentation/thix_ia/models/project_analysis.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// PROJECT ANALYSIS - Table: project_analyses / thix_analyses
/// ============================================================================

enum AnalysisStatus { queued, running, completed, failed, cancelled }

extension AnalysisStatusParser on String {
  AnalysisStatus toAnalysisStatus() {
    switch (toLowerCase()) {
      case 'queued':
        return AnalysisStatus.queued;
      case 'running':
        return AnalysisStatus.running;
      case 'completed':
        return AnalysisStatus.completed;
      case 'failed':
        return AnalysisStatus.failed;
      case 'cancelled':
        return AnalysisStatus.cancelled;
      default:
        return AnalysisStatus.queued;
    }
  }
}

class ProjectAnalysis extends Equatable {
  const ProjectAnalysis({
    required this.id,
    required this.projectCode,
    required this.type,
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
  final int progress;
  final String? title;
  final String? summary;
  final Map<String, dynamic>? resultJson;
  final double confidence;
  final List<String> sources;
  final List<Citation> citations;
  final String? aiModelUsed;
  final String? promptVersion;
  final int? tokensUsed;
  final int? executionTimeMs;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final int version;

  bool get isRunning =>
      status == AnalysisStatus.running || status == AnalysisStatus.queued;
  bool get isCompleted => status == AnalysisStatus.completed;
  bool get isFailed => status == AnalysisStatus.failed;

  factory ProjectAnalysis.fromJson(Map<String, dynamic> json) {
    // ── Parse content / result_json de façon robuste ──
    final parsed = _parseContentAndSummary(json);

    return ProjectAnalysis(
      id: JsonUtils.stringValue(json, 'id'),
      projectCode: JsonUtils.stringValue(json, 'project_code'),
      type: JsonUtils.stringValue(json, 'type', fallback: 'idea'),
      status: JsonUtils.stringValue(json, 'status', fallback: 'queued')
          .toAnalysisStatus(),
      progress: JsonUtils.intValue(json, 'progress'),
      title: JsonUtils.stringValue(json, 'title').isEmpty
          ? null
          : JsonUtils.stringValue(json, 'title'),
      summary: parsed.summary,
      resultJson: parsed.resultJson,
      confidence: JsonUtils.doubleValue(json, 'confidence'),
      sources: JsonUtils.stringList(json, 'sources'),
      citations:
          JsonUtils.asList(json['citations'], fromMap: Citation.fromJson),
      aiModelUsed: _nullableString(json, 'ai_model_used'),
      promptVersion: _nullableString(json, 'prompt_version'),
      tokensUsed: json['tokens_used'] is int ? json['tokens_used'] as int : null,
      executionTimeMs: json['execution_time_ms'] is int
          ? json['execution_time_ms'] as int
          : null,
      createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      completedAt: JsonUtils.dateTimeValue(json, 'completed_at'),
      version: JsonUtils.intValue(json, 'version', fallback: 1),
    );
  }

  /// content peut être :
  /// - String Markdown (marché, légal…) → summary
  /// - String JSON → resultJson
  /// - Map / jsonb (business plan…) → resultJson
  static ({String? summary, Map<String, dynamic>? resultJson})
      _parseContentAndSummary(Map<String, dynamic> json) {
    Map<String, dynamic>? resultJson;
    String? summary;

    final contentRaw = json['content'];
    final resultRaw = json['result_json'];
    final summaryRaw = json['summary'];

    // 1) content = Map (jsonb business plan)
    if (contentRaw is Map) {
      resultJson = Map<String, dynamic>.from(contentRaw);
    }
    // 2) content = String
    else if (contentRaw is String) {
      final s = contentRaw.trim();
      if (s.isEmpty) {
        // ignore
      } else if (s.startsWith('{') || s.startsWith('[')) {
        // JSON string
        final asMap = JsonUtils.asMap(s);
        if (asMap.isNotEmpty) {
          resultJson = asMap;
        } else {
          // JSON invalide / format Dart → garder en summary pour _tryParseToMarkdown
          summary = s;
        }
      } else {
        // Markdown / texte libre
        summary = s;
      }
    }

    // 3) result_json en secours
    if (resultJson == null || resultJson.isEmpty) {
      final fromResult = JsonUtils.asMap(resultRaw);
      if (fromResult.isNotEmpty) {
        resultJson = fromResult;
      }
    }

    // 4) summary colonne
    if (summary == null || summary.isEmpty) {
      if (summaryRaw is String && summaryRaw.trim().isNotEmpty) {
        final s = summaryRaw.trim();
        // Si summary est du JSON et qu'on n'a pas encore de resultJson
        if ((s.startsWith('{') || s.startsWith('[')) &&
            (resultJson == null || resultJson.isEmpty)) {
          final asMap = JsonUtils.asMap(s);
          if (asMap.isNotEmpty) {
            resultJson = asMap;
          } else {
            summary = s;
          }
        } else if (!s.startsWith('{')) {
          summary = s;
        } else {
          summary = s; // pour parse côté UI
        }
      }
    }

    // 5) Si resultJson a un champ textuel utile pour le résumé court (cartes)
    if ((summary == null || summary.isEmpty) &&
        resultJson != null &&
        resultJson.isNotEmpty) {
      summary = _shortSummaryFromMap(resultJson);
    }

    if (resultJson != null && resultJson.isEmpty) {
      resultJson = null;
    }

    return (summary: summary, resultJson: resultJson);
  }

  static String? _shortSummaryFromMap(Map<String, dynamic> m) {
    // Essayer d'extraire un titre / objectif pour les cartes
    final bp = m['business_plan'];
    if (bp is Map) {
      final titre = bp['titre'] ?? bp['title'];
      if (titre != null) return titre.toString();
      final re = bp['resume_executif'];
      if (re is Map) {
        final obj = re['objectif'] ?? re['mission'] ?? re['titre'];
        if (obj != null) {
          final t = obj.toString();
          return t.length > 140 ? '${t.substring(0, 140)}…' : t;
        }
      }
    }
    final titre = m['titre'] ?? m['title'] ?? m['objectif'];
    if (titre != null) {
      final t = titre.toString();
      return t.length > 140 ? '${t.substring(0, 140)}…' : t;
    }
    return null;
  }

  static String? _nullableString(Map json, String key) {
    final v = JsonUtils.stringValue(json, key);
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'type': type,
        'status': status.name,
        'progress': progress,
        'title': title,
        'summary': summary,
        // content : préférer l'objet structuré si dispo
        'content': resultJson ?? summary,
        'result_json': resultJson,
        'confidence': confidence,
        'sources': sources,
        'ai_model_used': aiModelUsed,
        'prompt_version': promptVersion,
        'version': version,
      });

  ProjectAnalysis copyWith({
    AnalysisStatus? status,
    int? progress,
    Map<String, dynamic>? resultJson,
    String? summary,
  }) {
    return ProjectAnalysis(
      id: id,
      projectCode: projectCode,
      type: type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: title,
      summary: summary ?? this.summary,
      resultJson: resultJson ?? this.resultJson,
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
        quote: JsonUtils.stringValue(json, 'quote').isEmpty
            ? null
            : JsonUtils.stringValue(json, 'quote'),
        page: json['page'] is int ? json['page'] as int : null,
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
