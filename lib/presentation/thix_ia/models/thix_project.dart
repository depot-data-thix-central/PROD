// lib/presentation/thix_ia/models/thix_project.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/project_code_generator.dart';

/// ============================================================================
/// THIX PROJECT - Entité centrale §3.1 du cahier
/// Une idée = un Project ID permanent
/// ============================================================================

class ThixProject extends Equatable {
  const ThixProject({
    required this.id,
    required this.projectCode,
    required this.name,
    required this.sector,
    required this.country,
    this.city,
    required this.status,
    this.summary,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.progress = 0.0,
    this.analysesCount = 0,
    this.documentsCount = 0,
    this.tags = const [],
    this.metadata = const {},
  });

  final String id; // UUID interne
  final String projectCode; // THX-BIZ-YYYY-NNNNNN
  final String name;
  final String sector;
  final String country; // ISO 2 ou nom
  final String? city;
  final String status; // draft/active/analyzing/paused/archived
  final String? summary;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double progress; // 0.0 - 1.0
  final int analysesCount;
  final int documentsCount;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  // Validation
  bool get isValidCode => ProjectCodeGenerator.isValid(projectCode);
  bool get isActive => status == 'active' || status == 'analyzing';
  bool get isArchived => status == 'archived';

  // Factory from JSON (API)
  factory ThixProject.fromJson(Map<String, dynamic> json) {
    return ThixProject(
      id: JsonUtils.stringValue(json, 'id'),
      projectCode: JsonUtils.stringValue(json, 'project_code'),
      name: JsonUtils.stringValue(json, 'name', fallback: 'Sans nom'),
      sector: JsonUtils.stringValue(json, 'sector', fallback: 'General'),
      country: JsonUtils.stringValue(json, 'country', fallback: 'RDC'),
      city: JsonUtils.stringValue(json, 'city').isEmpty
         ? null
          : JsonUtils.stringValue(json, 'city'),
      status: JsonUtils.stringValue(json, 'status', fallback: 'draft'),
      summary: JsonUtils.stringValue(json, 'summary').isEmpty
         ? null
          : JsonUtils.stringValue(json, 'summary'),
      ownerId: JsonUtils.stringValue(json, 'owner_id'),
      createdAt: JsonUtils.dateTimeValue(json, 'created_at')?? DateTime.now(),
      updatedAt: JsonUtils.dateTimeValue(json, 'updated_at')?? DateTime.now(),
      progress: JsonUtils.doubleValue(json, 'progress'),
      analysesCount: JsonUtils.intValue(json, 'analyses_count'),
      documentsCount: JsonUtils.intValue(json, 'documents_count'),
      tags: JsonUtils.stringList(json, 'tags'),
      metadata: JsonUtils.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_code': projectCode,
        'name': name,
        'sector': sector,
        'country': country,
        'city': city,
        'status': status,
        'summary': summary,
        'owner_id': ownerId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'progress': progress,
        'analyses_count': analysesCount,
        'documents_count': documentsCount,
        'tags': tags,
        'metadata': metadata,
      };

  ThixProject copyWith({
    String? name,
    String? sector,
    String? country,
    String? city,
    String? status,
    String? summary,
    double? progress,
    int? analysesCount,
    int? documentsCount,
    DateTime? updatedAt,
  }) {
    return ThixProject(
      id: id,
      projectCode: projectCode,
      name: name?? this.name,
      sector: sector?? this.sector,
      country: country?? this.country,
      city: city?? this.city,
      status: status?? this.status,
      summary: summary?? this.summary,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: updatedAt?? DateTime.now(),
      progress: progress?? this.progress,
      analysesCount: analysesCount?? this.analysesCount,
      documentsCount: documentsCount?? this.documentsCount,
      tags: tags,
      metadata: metadata,
    );
  }

  @override
  List<Object?> get props => [id, projectCode, status, updatedAt, progress];
}
