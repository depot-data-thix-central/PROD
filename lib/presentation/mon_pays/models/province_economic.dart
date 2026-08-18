// lib/presentation/mon_pays/models/province_economic.dart

class ProvinceEconomicResource {
  final String id;
  final String provinceId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? category;
  final String? iconUrl;
  final bool isKeySector;
  
  // NOUVEAU : Liste dynamique pour la galerie multimédia
  final List<Map<String, dynamic>>? media;

  const ProvinceEconomicResource({
    required this.id,
    required this.provinceId,
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
    this.iconUrl,
    this.isKeySector = false,
    this.media,
  });

  factory ProvinceEconomicResource.fromJson(Map<String, dynamic> json) {
    return ProvinceEconomicResource(
      id: json['id']?.toString() ?? '',
      provinceId: json['province_id']?.toString() ?? json['provinceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url'] ?? json['imageUrl'],
      category: json['category']?.toString(),
      iconUrl: json['icon_url'] ?? json['iconUrl'],
      isKeySector: json['is_key_sector'] ?? json['isKeySector'] ?? false,
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.isEmpty ? null : id,
    'province_id': provinceId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'category': category,
    'icon_url': iconUrl,
    'is_key_sector': isKeySector,
    'media': media,
  };
}
