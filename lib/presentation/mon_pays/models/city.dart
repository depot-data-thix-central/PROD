// lib/presentation/mon_pays/models/city.dart

class City {
  final String id;
  final String provinceId;
  final String name;
  final String? population;
  final bool isCapital;
  final String? imageUrl;
  final String? mayor;
  final String? mayorPhotoUrl;
  
  // NOUVEAU : Liste dynamique pour la galerie multimédia (Photos & Vidéos)
  final List<Map<String, dynamic>>? media;

  const City({
    required this.id,
    required this.provinceId,
    required this.name,
    this.population,
    this.isCapital = false,
    this.imageUrl,
    this.mayor,
    this.mayorPhotoUrl,
    this.media,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id']?.toString() ?? '',
      provinceId: json['province_id']?.toString() ?? json['provinceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      population: json['population']?.toString(),
      isCapital: json['is_capital'] ?? json['isCapital'] ?? false,
      imageUrl: json['image_url'] ?? json['imageUrl'],
      mayor: json['mayor']?.toString(),
      mayorPhotoUrl: json['mayor_photo_url'] ?? json['mayorPhotoUrl'],
      // Récupération de la galerie média depuis le format JSON
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.isEmpty ? null : id,
    'province_id': provinceId,
    'name': name,
    'population': population,
    'is_capital': isCapital,
    'image_url': imageUrl,
    'mayor': mayor,
    'mayor_photo_url': mayorPhotoUrl,
    // Sauvegarde de la galerie média vers la base de données
    'media': media,
  };
}
