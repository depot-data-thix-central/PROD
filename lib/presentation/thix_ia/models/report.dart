// lib/presentation/thix_ia/models/report.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// REPORTS - Tables: reports + report_versions
/// Versioning obligatoire §13 du cahier
/// ============================================================================

enum ReportType { marketStudy, businessPlan, legalStudy, taxStudy, financialModel, executiveSummary, fullDossier }

// 1. Extension sur String pour convertir depuis la Base de Données
extension ReportTypeParser on String {
  ReportType toReportType() {
    switch (toLowerCase()) {
      case 'market_study': return ReportType.marketStudy;
      case 'business_plan': return ReportType.businessPlan;
      case 'legal_study': return ReportType.legalStudy;
      case 'tax_study': return ReportType.taxStudy;
      case 'financial_model': return ReportType.financialModel;
      case 'executive_summary': return ReportType.executiveSummary;
      default: return ReportType.fullDossier;
    }
  }
}

// 2. Extension sur ReportType pour l'affichage UI
extension ReportTypeExtension on ReportType {
  String get label {
    switch (this) {
      case ReportType.marketStudy: return 'Étude de marché';
      case ReportType.businessPlan: return 'Business Plan';
      case ReportType.legalStudy: return 'Analyse réglementaire';
      case ReportType.taxStudy: return 'Analyse fiscale';
      case ReportType.financialModel: return 'Modèle financier';
      case ReportType.executiveSummary: return 'Résumé exécutif';
      case ReportType.fullDossier: return 'Dossier complet';
    }
  }
}

class Report extends Equatable {
  const Report({
    required this.id,
    required this.projectCode,
    required this.type,
    required this.title,
    this.summary,
    this.filePath, // Supabase Storage PDF/DOCX
    this.fileType = 'pdf',
    this.version = 1,
    this.latestVersionId,
    this.confidence = 0.0,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectCode;
  final ReportType type;
  final String title;
  final String? summary;
  final String? filePath;
  final String fileType;
  final int version;
  final String? latestVersionId;
  final double confidence;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        type: JsonUtils.stringValue(json, 'type', fallback: 'fullDossier').toReportType(),
        title: JsonUtils.stringValue(json, 'title'),
        summary: JsonUtils.stringValue(json, 'summary'),
        filePath: JsonUtils.stringValue(json, 'file_path'),
        fileType: JsonUtils.stringValue(json, 'file_type', fallback: 'pdf'),
        version: JsonUtils.intValue(json, 'version', fallback: 1),
        latestVersionId: JsonUtils.stringValue(json, 'latest_version_id'),
        confidence: JsonUtils.doubleValue(json, 'confidence'),
        createdBy: JsonUtils.stringValue(json, 'created_by'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
        updatedAt: JsonUtils.dateTimeValue(json, 'updated_at'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'type': type.name,
        'title': title,
        'summary': summary,
        'file_path': filePath,
        'file_type': fileType,
        'version': version,
        'confidence': confidence,
        'created_by': createdBy,
      });

  @override
  List<Object?> get props => [id, projectCode, type, version];
}

class ReportVersion extends Equatable {
  const ReportVersion({
    required this.id,
    required this.reportId,
    required this.projectCode,
    required this.version,
    this.filePath,
    this.changes,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String projectCode;
  final int version;
  final String? filePath;
  final String? changes; // diff résumé
  final String? createdBy;
  final DateTime? createdAt;

  factory ReportVersion.fromJson(Map<String, dynamic> json) => ReportVersion(
        id: JsonUtils.stringValue(json, 'id'),
        reportId: JsonUtils.stringValue(json, 'report_id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        version: JsonUtils.intValue(json, 'version'),
        filePath: JsonUtils.stringValue(json, 'file_path'),
        changes: JsonUtils.stringValue(json, 'changes'),
        createdBy: JsonUtils.stringValue(json, 'created_by'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      );

  Map<String, dynamic> toSupabase() => {
        'report_id': reportId,
        'project_code': projectCode,
        'version': version,
        'file_path': filePath,
        'changes': changes,
        'created_by': createdBy,
      };

  @override
  List<Object?> get props => [id, reportId, version];
}
