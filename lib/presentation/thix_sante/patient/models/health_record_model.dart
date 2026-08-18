// lib/presentation/thix_sante/patient/models/health_record_model.dart
// =============================================================================
// Model: HealthRecordModel
// Role: Document medical avec support fichier image/PDF
// Fonctionnalites modernes: upload, preview, download, type categorise
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/thix_sante_colors.dart';
/// Type de document medical, categorise pour filtrage et UI.
enum RecordType {
  consultation,
  ordonnance,
  laboratoire,
  radiologie,
  vaccin,
  certificat,
  autre;

  static RecordType fromString(String? value) {
    switch (value) {
      case 'ordonnance':
        return RecordType.ordonnance;
      case 'laboratoire':
        return RecordType.laboratoire;
      case 'radiologie':
        return RecordType.radiologie;
      case 'vaccin':
        return RecordType.vaccin;
      case 'certificat':
        return RecordType.certificat;
      case 'consultation':
        return RecordType.consultation;
      default:
        return RecordType.autre;
    }
  }

  String get label {
    switch (this) {
      case RecordType.consultation:
        return 'Consultation';
      case RecordType.ordonnance:
        return 'Ordonnance';
      case RecordType.laboratoire:
        return 'Laboratoire';
      case RecordType.radiologie:
        return 'Radiologie';
      case RecordType.vaccin:
        return 'Vaccin';
      case RecordType.certificat:
        return 'Certificat';
      case RecordType.autre:
        return 'Autre';
    }
  }
}

/// Document medical immutable avec support fichier.
/// Gere photo, PDF, ordonnance telechargeable depuis Supabase Storage.
@immutable
class HealthRecordModel {
  final String id;
  final String patientUid;
  final String patientThixId;
  final String title;
  final RecordType type;
  final String? description;
  final String? fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? mimeType;
  final String createdByUid;
  final String? doctorName;
  final DateTime createdAt;
  final DateTime? examDate;

  const HealthRecordModel({
    required this.id,
    required this.patientUid,
    required this.patientThixId,
    required this.title,
    required this.type,
    this.description,
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    required this.createdByUid,
    this.doctorName,
    required this.createdAt,
    this.examDate,
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'] as String,
      patientUid: json['patient_uid'] as String,
      patientThixId: json['patient_thix_id'] as String,
      title: json['title'] as String,
      type: RecordType.fromString(json['type'] as String?),
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSizeBytes: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      createdByUid: (json['created_by_uid'] as String?)?? json['patient_uid'] as String,
      doctorName: json['doctor_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      examDate: json['exam_date']!= null
         ? DateTime.tryParse(json['exam_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'patient_uid': patientUid,
        'patient_thix_id': patientThixId,
        'title': title,
        'type': type.name,
        'description': description,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSizeBytes,
        'mime_type': mimeType,
        'created_by_uid': createdByUid,
        'doctor_name': doctorName,
        'exam_date': examDate?.toIso8601String(),
      };

  // --- Helpers modernes ---
  bool get hasFile => fileUrl!= null && fileUrl!.isNotEmpty;
  bool get isImage => mimeType?.startsWith('image/')?? false;
  bool get isPdf => mimeType == 'application/pdf' || (fileName?.toLowerCase().endsWith('.pdf')?? false);

  String get fileSizeLabel {
    if (fileSizeBytes == null) return '';
    if (fileSizeBytes! < 1024) return '${fileSizeBytes} B';
    if (fileSizeBytes! < 1048576) return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes! / 1048576).toStringAsFixed(1)} MB';
  }

  IconData get typeIcon {
    switch (type) {
      case RecordType.consultation:
        return Icons.medical_services_rounded;
      case RecordType.ordonnance:
        return Icons.receipt_long_rounded;
      case RecordType.laboratoire:
        return Icons.biotech_rounded;
      case RecordType.radiologie:
        return Icons.medical_services_rounded; 
      case RecordType.vaccin:
        return Icons.vaccines_rounded;
      case RecordType.certificat:
        return Icons.verified_user_rounded;
      case RecordType.autre:
        return Icons.folder_rounded;
    }
  }

  Color get typeColor {
    switch (type) {
      case RecordType.consultation:
        return ThixSanteColors.primary;
      case RecordType.ordonnance:
        return ThixSanteColors.purple;
      case RecordType.laboratoire:
        return ThixSanteColors.success;
      case RecordType.radiologie:
        return ThixSanteColors.sky;
      case RecordType.vaccin:
        return ThixSanteColors.warning;
      case RecordType.certificat:
        return ThixSanteColors.success;
      case RecordType.autre:
        return ThixSanteColors.muted;
    }
  }

  Color get typeLightColor {
    switch (type) {
      case RecordType.consultation:
        return ThixSanteColors.primaryLight;
      case RecordType.ordonnance:
        return ThixSanteColors.purpleLight;
      case RecordType.laboratoire:
        return ThixSanteColors.successLight;
      case RecordType.radiologie:
        return ThixSanteColors.skyLight;
      default:
        return ThixSanteColors.borderLight;
    }
  }
}
