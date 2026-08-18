// lib/presentation/mon_pays/models/government.dart
// Entité Gouvernement

class Government {
  final String id;
  final String name;
  final String? imageUrl;
  final String description;
  final String? primeMinister;
  final List<String> ministers;
  final String? formationDate;
  final String? dissolutionDate;
  final List<Map<String, String>> composition;

  Government({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.description,
    this.primeMinister,
    this.ministers = const [],
    this.formationDate,
    this.dissolutionDate,
    this.composition = const [],
  });

  factory Government.fromJson(Map<String, dynamic> json) {
    return Government(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String? ?? '',
      primeMinister: json['prime_minister'] as String?,
      ministers: List<String>.from(json['ministers'] ?? []),
      formationDate: json['formation_date'] as String?,
      dissolutionDate: json['dissolution_date'] as String?,
      composition: (json['composition'] as List?)
          ?.map((e) => Map<String, String>.from(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'description': description,
    'prime_minister': primeMinister,
    'ministers': ministers,
    'formation_date': formationDate,
    'dissolution_date': dissolutionDate,
    'composition': composition,
  };
}
