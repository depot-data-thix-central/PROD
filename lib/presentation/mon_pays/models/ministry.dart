// lib/presentation/mon_pays/models/ministry.dart
// Entité Ministère

class Ministry {
  final String id;
  final String name;
  final String? imageUrl;
  final String description;
  final String? minister;
  final String? deputyMinister;
  final List<String> missions;
  final Map<String, String> contacts;
  final List<Map<String, String>> services;

  Ministry({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.description,
    this.minister,
    this.deputyMinister,
    this.missions = const [],
    this.contacts = const {},
    this.services = const [],
  });

  factory Ministry.fromJson(Map<String, dynamic> json) {
    return Ministry(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String? ?? '',
      minister: json['minister'] as String?,
      deputyMinister: json['deputy_minister'] as String?,
      missions: List<String>.from(json['missions'] ?? []),
      contacts: Map<String, String>.from(json['contacts'] ?? {}),
      services: (json['services'] as List?)
          ?.map((e) => Map<String, String>.from(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'description': description,
    'minister': minister,
    'deputy_minister': deputyMinister,
    'missions': missions,
    'contacts': contacts,
    'services': services,
  };
}
