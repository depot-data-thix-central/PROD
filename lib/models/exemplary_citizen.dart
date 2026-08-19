// lib/models/exemplary_citizen.dart

class ExemplaryCitizen {
  final String id;
  final String fullName;
  final String domain;
  final String? shortDescription;
  final String biography;
  final String? photoUrl;
  final DateTime? recognitionDate;
  final List<Map<String, dynamic>> media;

  ExemplaryCitizen({
    required this.id,
    required this.fullName,
    required this.domain,
    this.shortDescription,
    required this.biography,
    this.photoUrl,
    this.recognitionDate,
    this.media = const [],
  });

  factory ExemplaryCitizen.fromJson(Map<String, dynamic> json) {
    return ExemplaryCitizen(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      domain: json['domain'] as String,
      shortDescription: json['short_description'] as String?,
      biography: json['biography'] as String,
      photoUrl: json['photo_url'] as String?,
      recognitionDate: json['recognition_date'] != null ? DateTime.tryParse(json['recognition_date']) : null,
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'full_name': fullName,
      'domain': domain,
      'short_description': shortDescription,
      'biography': biography,
      'photo_url': photoUrl,
      'recognition_date': recognitionDate?.toIso8601String().split('T').first,
      'media': media,
    };
  }
}
