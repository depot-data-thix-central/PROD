// ============================================================================
// FICHIER : lib/models/incubator_mentor.dart
// Module  : thix_incubator
// Table DB: thix_incubator_mentors
// ============================================================================

import 'dart:convert';

class IncubatorMentor {
  final String id;
  final String mentorThixId;
  final String name;
  final String? photoUrl;
  final String title;
  final String organization;
  final List<String> expertises;
  final List<String> domains;
  final String bio;
  final int rating; // 0-5
  final int menteesCount;
  final DateTime createdAt;

  const IncubatorMentor({
    required this.id,
    required this.mentorThixId,
    required this.name,
    this.photoUrl,
    required this.title,
    required this.organization,
    this.expertises = const [],
    this.domains = const [],
    this.bio = '',
    this.rating = 0,
    this.menteesCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mentor_thix_id': mentorThixId,
    'name': name,
    'photo_url': photoUrl,
    'title': title,
    'organization': organization,
    'expertises': expertises,
    'domains': domains,
    'bio': bio,
    'rating': rating,
    'mentees_count': menteesCount,
    'created_at': createdAt.toIso8601String(),
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

  factory IncubatorMentor.fromJson(Map<String, dynamic> json) {
    return IncubatorMentor(
      id: _str(json['id']),
      mentorThixId: _str(json['mentor_thix_id'] ?? json['mentorThixId']),
      name: _str(json['name'], 'Mentor'),
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
      title: _str(json['title']),
      organization: _str(json['organization']),
      expertises: _strList(json['expertises']),
      domains: _strList(json['domains']),
      bio: _str(json['bio']),
      rating: (json['rating'] ?? 0) as int,
      menteesCount: (json['mentees_count'] ?? json['menteesCount'] ?? 0) as int,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  static List<IncubatorMentor> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = const JsonDecoder().convert(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => IncubatorMentor.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String encodeList(List<IncubatorMentor> items) {
    return const JsonEncoder().convert(items.map((e) => e.toJson()).toList());
  }
}
