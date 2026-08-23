// lib/presentation/thix_ia/models/project_items.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// PROJECT ITEMS - Tables Supabase: questions, sources, competitors, legal
/// ============================================================================

class ProjectQuestion extends Equatable {
  const ProjectQuestion({
    required this.id,
    required this.projectCode,
    required this.question,
    this.answer,
    this.isCritical = false,
    this.isAnswered = false,
    this.createdAt,
  });

  final String id; // uuid
  final String projectCode; // FK projects.project_code
  final String question;
  final String? answer;
  final bool isCritical;
  final bool isAnswered;
  final DateTime? createdAt;

  factory ProjectQuestion.fromJson(Map<String, dynamic> json) => ProjectQuestion(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        question: JsonUtils.stringValue(json, 'question'),
        answer: JsonUtils.stringValue(json, 'answer'),
        isCritical: JsonUtils.boolValue(json, 'is_critical'),
        isAnswered: JsonUtils.boolValue(json, 'is_answered'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'id': id,
        'project_code': projectCode,
        'question': question,
        'answer': answer,
        'is_critical': isCritical,
        'is_answered': isAnswered,
      });

  @override
  List<Object?> get props => [id, projectCode, isAnswered];
}

class ProjectSource extends Equatable {
  const ProjectSource({
    required this.id,
    required this.projectCode,
    required this.url,
    this.title,
    this.authority,
    this.country,
    this.sector,
    this.documentType,
    this.publishedAt,
    this.verifiedAt,
    this.reliabilityScore = 0.8,
    this.language = 'fr',
  });

  final String id;
  final String projectCode;
  final String url;
  final String? title;
  final String? authority;
  final String? country;
  final String? sector;
  final String? documentType;
  final DateTime? publishedAt;
  final DateTime? verifiedAt;
  final double reliabilityScore;
  final String language;

  factory ProjectSource.fromJson(Map<String, dynamic> json) => ProjectSource(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        url: JsonUtils.stringValue(json, 'url'),
        title: JsonUtils.stringValue(json, 'title'),
        authority: JsonUtils.stringValue(json, 'authority'),
        country: JsonUtils.stringValue(json, 'country'),
        sector: JsonUtils.stringValue(json, 'sector'),
        documentType: JsonUtils.stringValue(json, 'document_type'),
        publishedAt: JsonUtils.dateTimeValue(json, 'published_at'),
        verifiedAt: JsonUtils.dateTimeValue(json, 'verified_at'),
        reliabilityScore: JsonUtils.doubleValue(json, 'reliability_score', fallback: 0.8),
        language: JsonUtils.stringValue(json, 'language', fallback: 'fr'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'url': url,
        'title': title,
        'authority': authority,
        'country': country,
        'sector': sector,
        'document_type': documentType,
        'published_at': publishedAt?.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
        'reliability_score': reliabilityScore,
        'language': language,
      });

  @override
  List<Object?> get props => [id, url];
}

class ProjectCompetitor extends Equatable {
  const ProjectCompetitor({
    required this.id,
    required this.projectCode,
    required this.name,
    this.website,
    this.description,
    this.pricing,
    this.coverage,
    this.strengths = const [],
    this.weaknesses = const [],
    this.positioning,
  });

  final String id;
  final String projectCode;
  final String name;
  final String? website;
  final String? description;
  final String? pricing;
  final String? coverage;
  final List<String> strengths;
  final List<String> weaknesses;
  final String? positioning;

  factory ProjectCompetitor.fromJson(Map<String, dynamic> json) => ProjectCompetitor(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        name: JsonUtils.stringValue(json, 'name'),
        website: JsonUtils.stringValue(json, 'website'),
        description: JsonUtils.stringValue(json, 'description'),
        pricing: JsonUtils.stringValue(json, 'pricing'),
        coverage: JsonUtils.stringValue(json, 'coverage'),
        strengths: JsonUtils.stringList(json, 'strengths'),
        weaknesses: JsonUtils.stringList(json, 'weaknesses'),
        positioning: JsonUtils.stringValue(json, 'positioning'),
      );

  Map<String, dynamic> toSupabase() => {
        'project_code': projectCode,
        'name': name,
        'website': website,
        'description': description,
        'pricing': pricing,
        'coverage': coverage,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'positioning': positioning,
      };

  @override
  List<Object?> get props => [id, projectCode, name];
}

class ProjectLegalFinding extends Equatable {
  const ProjectLegalFinding({
    required this.id,
    required this.projectCode,
    required this.jurisdiction,
    required this.sector,
    required this.title,
    required this.content,
    this.lawReference,
    this.authority,
    this.licenseRequired = false,
    this.sourceUrl,
    this.verifiedAt,
  });

  final String id;
  final String projectCode;
  final String jurisdiction;
  final String sector;
  final String title;
  final String content;
  final String? lawReference;
  final String? authority;
  final bool licenseRequired;
  final String? sourceUrl;
  final DateTime? verifiedAt;

  factory ProjectLegalFinding.fromJson(Map<String, dynamic> json) =>
     ProjectLegalFinding(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        jurisdiction: JsonUtils.stringValue(json, 'jurisdiction'),
        sector: JsonUtils.stringValue(json, 'sector'),
        title: JsonUtils.stringValue(json, 'title'),
        content: JsonUtils.stringValue(json, 'content'),
        lawReference: JsonUtils.stringValue(json, 'law_reference'),
        authority: JsonUtils.stringValue(json, 'authority'),
        licenseRequired: JsonUtils.boolValue(json, 'license_required'),
        sourceUrl: JsonUtils.stringValue(json, 'source_url'),
        verifiedAt: JsonUtils.dateTimeValue(json, 'verified_at'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'jurisdiction': jurisdiction,
        'sector': sector,
        'title': title,
        'content': content,
        'law_reference': lawReference,
        'authority': authority,
        'license_required': licenseRequired,
        'source_url': sourceUrl,
      });

  @override
  List<Object?> get props => [id, projectCode];
}
