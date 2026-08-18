// lib/presentation/mon_pays/models/province_tourism.dart

class ProvinceTourism {
  final String id;
  final String provinceId;
  final String name;
  final String type;
  final String? description;
  final String? imageUrl;
  
  // NOUVEAUX CHAMPS : Localisation et Site Web
  final String? location;
  final String? website;

  // Liste dynamique pour la galerie multimédia
  final List<Map<String, dynamic>>? media;

  const ProvinceTourism({
    required this.id,
    required this.provinceId,
    required this.name,
    required this.type,
    this.description,
    this.imageUrl,
    this.location,
    this.website,
    this.media,
  });

  factory ProvinceTourism.fromJson(Map<String, dynamic> json) {
    return ProvinceTourism(
      id: json['id']?.toString() ?? '',
      provinceId: json['province_id']?.toString() ?? json['provinceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url'] ?? json['imageUrl'],
      location: json['location']?.toString(),
      website: json['website']?.toString(),
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.isEmpty ? null : id,
    'province_id': provinceId,
    'name': name,
    'type': type,
    'description': description,
    'image_url': imageUrl,
    'location': location,
    'website': website,
    'media': media,
  };
}
