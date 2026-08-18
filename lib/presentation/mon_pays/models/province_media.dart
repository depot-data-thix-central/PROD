// lib/presentation/mon_pays/models/province_media.dart

class ProvinceMedia {
  final String id;
  final String provinceId;
  final String? achievementId;
  final String type; // 'photo' ou 'video'
  final String url;
  final String? title;
  final String? description;
  final bool isCover;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProvinceMedia({
    required this.id,
    required this.provinceId,
    this.achievementId,
    required this.type,
    required this.url,
    this.title,
    this.description,
    this.isCover = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ProvinceMedia.fromJson(Map<String, dynamic> json) {
    return ProvinceMedia(
      id: json['id'] as String,
      provinceId: json['province_id'] as String,
      achievementId: json['achievement_id'] as String?,
      type: json['type'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      isCover: json['is_cover'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'province_id': provinceId,
    'achievement_id': achievementId,
    'type': type,
    'url': url,
    'title': title,
    'description': description,
    'is_cover': isCover,
  };
}
