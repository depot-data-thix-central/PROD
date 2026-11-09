// ============================================================================
// FICHIER : lib/models/incubator_project.dart
// Module  : thix_incubator
// Table DB: thix_incubator_projects
// ============================================================================
// Modèle Projet entrepreneur — multi-projets par utilisateur.
// Étapes (enum stage) :
//   submission | screening | training | prototyping | pitching | post_incubation
// ============================================================================

import 'dart:convert';

enum IncubatorStage {
  submission,     // Candidature déposée
  screening,      // En évaluation
  training,       // Formation en cours
  prototyping,    // Prototypage
  pitching,       // Préparation au pitch
  postIncubation; // Post-incubation

  String get label => switch (this) {
    IncubatorStage.submission      => 'Soumission',
    IncubatorStage.screening       => 'Évaluation',
    IncubatorStage.training        => 'Formation',
    IncubatorStage.prototyping     => 'Prototypage',
    IncubatorStage.pitching        => 'Pitch',
    IncubatorStage.postIncubation  => 'Post-incubation',
  };

  static IncubatorStage fromString(String? s) {
    return switch (s) {
      'submission'      => IncubatorStage.submission,
      'screening'       => IncubatorStage.screening,
      'training'        => IncubatorStage.training,
      'prototyping'     => IncubatorStage.prototyping,
      'pitching'        => IncubatorStage.pitching,
      'post_incubation' => IncubatorStage.postIncubation,
      _                 => IncubatorStage.submission,
    };
  }

  String get dbValue => switch (this) {
    IncubatorStage.submission      => 'submission',
    IncubatorStage.screening       => 'screening',
    IncubatorStage.training        => 'training',
    IncubatorStage.prototyping     => 'prototyping',
    IncubatorStage.pitching        => 'pitching',
    IncubatorStage.postIncubation  => 'post_incubation',
  };
}

class IncubatorProject {
  final String id;
  final String ownerThixId;
  final String title;
  final String sector;
  final String pitch;
  final IncubatorStage stage;
  final int progress; // 0-100
  final String? programId;
  final String? mentorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncubatorProject({
    required this.id,
    required this.ownerThixId,
    required this.title,
    required this.sector,
    this.pitch = '',
    required this.stage,
    required this.progress,
    this.programId,
    this.mentorId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get currentStageLabel => stage.label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_thix_id': ownerThixId,
    'title': title,
    'sector': sector,
    'pitch': pitch,
    'stage': stage.dbValue,
    'progress': progress,
    'program_id': programId,
    'mentor_id': mentorId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static DateTime _parseDate(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static String _str(Object? v, [String fallback = '']) =>
      (v ?? fallback).toString();

  factory IncubatorProject.fromJson(Map<String, dynamic> json) {
    return IncubatorProject(
      id: _str(json['id']),
      ownerThixId: _str(json['owner_thix_id'] ?? json['ownerThixId']),
      title: _str(json['title'], 'Projet sans titre'),
      sector: _str(json['sector']),
      pitch: _str(json['pitch']),
      stage: IncubatorStage.fromString(_str(json['stage'])),
      progress: (json['progress'] ?? 0) as int,
      programId: json['program_id']?.toString() ?? json['programId']?.toString(),
      mentorId: json['mentor_id']?.toString() ?? json['mentorId']?.toString(),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static List<IncubatorProject> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = const JsonDecoder().convert(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => IncubatorProject.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String encodeList(List<IncubatorProject> items) {
    return const JsonEncoder().convert(items.map((e) => e.toJson()).toList());
  }
}
