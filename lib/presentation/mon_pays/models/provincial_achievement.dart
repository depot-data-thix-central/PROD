// lib/presentation/mon_pays/models/provincial_achievement.dart

class ProvincialAchievement {
  final String id;
  final String provinceId;
  final String title;
  final String? description;
  final String category;
  final DateTime? date;
  final String? coverImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProvincialAchievement({
    required this.id,
    required this.provinceId,
    required this.title,
    this.description,
    required this.category,
    this.date,
    this.coverImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ProvincialAchievement.fromJson(Map<String, dynamic> json) {
    return ProvincialAchievement(
      id: json['id'] as String,
      provinceId: json['province_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      coverImageUrl: json['cover_image_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'province_id': provinceId,
    'title': title,
    'description': description,
    'category': category,
    'date': date?.toIso8601String(),
    'cover_image_url': coverImageUrl,
  };
}
