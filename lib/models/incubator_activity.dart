// ============================================================================
// FICHIER : lib/models/incubator_activity.dart
// Module  : thix_incubator
// Table DB: thix_incubator_activities (alimenté par triggers SQL)
// ============================================================================

import 'dart:convert';

class IncubatorActivity {
  final String id;
  final String userThixId;
  final String type; // application_submitted | stage_changed | mentor_assigned | …
  final String title;
  final String? subtitle;
  final String? targetId;
  final String? targetType; // program | project | application
  final DateTime occurredAt;

  const IncubatorActivity({
    required this.id,
    required this.userThixId,
    required this.type,
    required this.title,
    this.subtitle,
    this.targetId,
    this.targetType,
    required this.occurredAt,
  });

  String get timeLabel {
    final diff = DateTime.now().difference(occurredAt);
    if (diff.inDays > 7) {
      return '${occurredAt.day}/${occurredAt.month}';
    }
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_thix_id': userThixId,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'target_id': targetId,
    'target_type': targetType,
    'occurred_at': occurredAt.toIso8601String(),
  };

  static DateTime _parseDate(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static String _str(Object? v, [String fallback = '']) =>
      (v ?? fallback).toString();

  factory IncubatorActivity.fromJson(Map<String, dynamic> json) {
    return IncubatorActivity(
      id: _str(json['id']),
      userThixId: _str(json['user_thix_id'] ?? json['userThixId']),
      type: _str(json['type'], 'event'),
      title: _str(json['title'], 'Activité'),
      subtitle: json['subtitle']?.toString(),
      targetId: json['target_id']?.toString() ?? json['targetId']?.toString(),
      targetType: json['target_type']?.toString() ?? json['targetType']?.toString(),
      occurredAt: _parseDate(json['occurred_at'] ?? json['occurredAt'] ?? json['created_at']),
    );
  }

  static List<IncubatorActivity> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = const JsonDecoder().convert(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => IncubatorActivity.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String encodeList(List<IncubatorActivity> items) {
    return const JsonEncoder().convert(items.map((e) => e.toJson()).toList());
  }
}
