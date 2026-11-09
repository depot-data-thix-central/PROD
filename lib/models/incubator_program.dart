// ============================================================================
// FICHIER : lib/models/incubator_program.dart
// Module  : thix_incubator
// Table DB: thix_incubator_programs
// ============================================================================
// Modèle Programme d'incubation — alignement strict DB (snake_case JSON).
// Statuts : 'draft' | 'upcoming' | 'open' | 'closed' | 'archived'
// ============================================================================

import 'dart:convert';

class IncubatorProgram {
  final String id;
  final String title;
  final String organizer;
  final String category;
  final String description;
  final String location;
  final int durationWeeks;
  final int totalSeats;
  final int seatsRemaining;
  final DateTime deadline;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // draft|upcoming|open|closed|archived
  final String? coverUrl;
  final List<String> eligibility;
  final List<String> benefits;
  final List<String> mentorIds;
  final String? incubatorLinkedOpportunityId; // lien retour vers opportunities
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncubatorProgram({
    required this.id,
    required this.title,
    required this.organizer,
    required this.category,
    required this.description,
    required this.location,
    required this.durationWeeks,
    required this.totalSeats,
    required this.seatsRemaining,
    required this.deadline,
    this.startDate,
    this.endDate,
    required this.status,
    this.coverUrl,
    this.eligibility = const [],
    this.benefits = const [],
    this.mentorIds = const [],
    this.incubatorLinkedOpportunityId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';
  bool get isUpcoming => status == 'upcoming';
  bool get isClosed => status == 'closed' || status == 'archived';
  bool get hasSeats => seatsRemaining > 0;
  bool get isExpired => deadline.isBefore(DateTime.now());

  String get deadlineLabel {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return 'Expiré';
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} mois';
    }
    if (diff.inDays > 0) return '${diff.inDays}j restants';
    if (diff.inHours > 0) return '${diff.inHours}h restantes';
    return '${diff.inMinutes}min';
  }

  String get durationLabel => '$durationWeeks semaines';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'organizer': organizer,
    'category': category,
    'description': description,
    'location': location,
    'duration_weeks': durationWeeks,
    'total_seats': totalSeats,
    'seats_remaining': seatsRemaining,
    'deadline': deadline.toIso8601String(),
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'status': status,
    'cover_url': coverUrl,
    'eligibility': eligibility,
    'benefits': benefits,
    'mentor_ids': mentorIds,
    'incubator_linked_opportunity_id': incubatorLinkedOpportunityId,
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

  static List<String> _strList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  factory IncubatorProgram.fromJson(Map<String, dynamic> json) {
    return IncubatorProgram(
      id: _str(json['id']),
      title: _str(json['title'], 'Programme sans titre'),
      organizer: _str(json['organizer']),
      category: _str(json['category'], 'Incubation'),
      description: _str(json['description']),
      location: _str(json['location']),
      durationWeeks: (json['duration_weeks'] ?? json['durationWeeks'] ?? 0) as int,
      totalSeats: (json['total_seats'] ?? json['totalSeats'] ?? 0) as int,
      seatsRemaining: (json['seats_remaining'] ?? json['seatsRemaining'] ?? 0) as int,
      deadline: _parseDate(json['deadline'] ?? json['deadline_at']),
      startDate: json['start_date'] != null ? _parseDate(json['start_date']) : null,
      endDate: json['end_date'] != null ? _parseDate(json['end_date']) : null,
      status: _str(json['status'], 'draft'),
      coverUrl: (json['cover_url'] ?? json['coverUrl'])?.toString(),
      eligibility: _strList(json['eligibility']),
      benefits: _strList(json['benefits']),
      mentorIds: _strList(json['mentor_ids'] ?? json['mentorIds']),
      incubatorLinkedOpportunityId:
          (json['incubator_linked_opportunity_id'] ?? json['incubatorLinkedOpportunityId'])?.toString(),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static List<IncubatorProgram> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = const JsonDecoder().convert(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => IncubatorProgram.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String encodeList(List<IncubatorProgram> items) {
    return const JsonEncoder().convert(items.map((e) => e.toJson()).toList());
  }
}
