// ============================================================================
// FICHIER : lib/models/incubator_application.dart
// Module  : thix_incubator
// Table DB: thix_incubator_applications
// ============================================================================
// Candidature à un programme. Statuts :
//   pending | review | accepted | rejected | withdrawn
// ============================================================================

import 'dart:convert';

class IncubatorApplication {
  final String id;
  final String applicantThixId;
  final String programId;
  final String programTitle; // dénormalisé pour affichage rapide
  final String? projectId;
  final String message;
  final String status; // pending|review|accepted|rejected|withdrawn
  final String? reviewerNotes;
  final DateTime submittedAt;
  final DateTime updatedAt;

  const IncubatorApplication({
    required this.id,
    required this.applicantThixId,
    required this.programId,
    required this.programTitle,
    this.projectId,
    required this.message,
    required this.status,
    this.reviewerNotes,
    required this.submittedAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending' || status == 'review';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  String get submittedAtLabel {
    final diff = DateTime.now().difference(submittedAt);
    if (diff.inDays > 30) return 'Il y a ${(diff.inDays / 30).floor()} mois';
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'applicant_thix_id': applicantThixId,
    'program_id': programId,
    'program_title': programTitle,
    'project_id': projectId,
    'message': message,
    'status': status,
    'reviewer_notes': reviewerNotes,
    'submitted_at': submittedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static DateTime _parseDate(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static String _str(Object? v, [String fallback = '']) =>
      (v ?? fallback).toString();

  factory IncubatorApplication.fromJson(Map<String, dynamic> json) {
    return IncubatorApplication(
      id: _str(json['id']),
      applicantThixId: _str(json['applicant_thix_id'] ?? json['applicantThixId']),
      programId: _str(json['program_id'] ?? json['programId']),
      programTitle: _str(json['program_title'] ?? json['programTitle'], 'Programme'),
      projectId: json['project_id']?.toString() ?? json['projectId']?.toString(),
      message: _str(json['message']),
      status: _str(json['status'], 'pending'),
      reviewerNotes: json['reviewer_notes']?.toString() ?? json['reviewerNotes']?.toString(),
      submittedAt: _parseDate(json['submitted_at'] ?? json['createdAt'] ?? json['submittedAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static List<IncubatorApplication> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = const JsonEncoder().convert(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => IncubatorApplication.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String encodeList(List<IncubatorApplication> items) {
    return const JsonEncoder().convert(items.map((e) => e.toJson()).toList());
  }
}
