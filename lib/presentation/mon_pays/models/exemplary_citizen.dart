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

  /// ✅ Parsing défensif : aucune colonne NULL ou absente ne peut crasher
  factory ExemplaryCitizen.fromJson(Map<String, dynamic> json) {
    return ExemplaryCitizen(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? 'Citoyen').toString(),
      domain: (json['domain'] ?? 'Général').toString(),
      shortDescription: json['short_description']?.toString(),
      biography: (json['biography'] ?? '').toString(),
      photoUrl: (json['photo_url'] ?? json['photoUrl'])?.toString(),
      recognitionDate: json['recognition_date'] != null
          ? DateTime.tryParse(json['recognition_date'].toString())
          : null,
      media: json['media'] is List
          ? (json['media'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
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
