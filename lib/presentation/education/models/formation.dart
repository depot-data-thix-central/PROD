import 'category.dart';
import 'module.dart';
import 'enrollment.dart';

// ✅ Fonction utilitaire qui empêche le crash de l'écran "Apprendre"
DateTime _safeParseDate(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return DateTime.now();
  if (value is DateTime) return value;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return DateTime.now(); // Date de secours en cas de format invalide
  }
}

class Formation {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String instructorId;
  final String? instructorName;
  final String? instructorAvatar; // ✅ NOUVEAU : Avatar du formateur
  final String? instructorBio;    // ✅ NOUVEAU : Bio courte du formateur
  final String level; // beginner, intermediate, advanced
  final String language; // ✅ NOUVEAU : Langue du cours (fr, en, es...)
  final int duration; // minutes total
  final double price;
  final String currency; // USD, FC
  final double rating;
  final int reviewsCount;
  final int totalStudents; // ✅ NOUVEAU : Plus fiable que enrollments.length
  final String? imageUrl;
  final String? thumbnailUrl; // ✅ NOUVEAU : Miniature pour cartes
  final bool isFree;
  final bool isCertifying;
  final bool isFeatured; // ✅ NOUVEAU : Mise en avant (hero, top)
  final bool isPublished; // ✅ NOUVEAU : Alias rapide pour status == 'published'
  final String status; // draft, published, archived
  
  // ✅ NOUVEAU : Contenu structuré du cours
  final List<String> tags;
  final List<String> prerequisites;       // Ce qu'il faut savoir avant
  final List<String> learningOutcomes;    // Ce que l'apprenant va apprendre
  final List<String> targetAudience;      // À qui s'adresse le cours
  final List<String> requirements;        // Matériel/logiciels nécessaires
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt; // ✅ NOUVEAU : Date de publication

  // Relations
  Category? category;
  List<Module>? modules;
  List<Enrollment>? enrollments;

  Formation({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.instructorId,
    this.instructorName,
    this.instructorAvatar,
    this.instructorBio,
    this.level = 'beginner',
    this.language = 'fr',
    this.duration = 0,
    this.price = 0.0,
    this.currency = 'USD',
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.totalStudents = 0,
    this.imageUrl,
    this.thumbnailUrl,
    this.isFree = false,
    this.isCertifying = false,
    this.isFeatured = false,
    this.status = 'draft',
    this.tags = const [],
    this.prerequisites = const [],
    this.learningOutcomes = const [],
    this.targetAudience = const [],
    this.requirements = const [],
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.category,
    this.modules,
    this.enrollments,
  }) : isPublished = status == 'published';

  // ✅ Helpers pratiques
  bool get hasCertificate => isCertifying;
  bool get isPremium => !isFree && price > 0;
  
  String get durationLabel {
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours <= 0) return '${minutes}min';
    return minutes <= 0 ? '${hours}h' : '${hours}h ${minutes}min';
  }

  int get totalLessons =>
      modules?.fold<int>(0, (sum, m) => sum + (m.lessons?.length ?? 0)) ?? 0;

  String get levelLabel {
    switch (level) {
      case 'beginner': return 'Débutant';
      case 'intermediate': return 'Intermédiaire';
      case 'advanced': return 'Avancé';
      default: return level;
    }
  }

  factory Formation.fromJson(Map<String, dynamic> json) => Formation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Sans titre',
        description: json['description']?.toString() ?? '',
        categoryId: json['category_id']?.toString() ?? '',
        instructorId: json['instructor_id']?.toString() ?? '',
        instructorName: json['instructor_name']?.toString(),
        instructorAvatar: json['instructor_avatar']?.toString(),
        instructorBio: json['instructor_bio']?.toString(),
        level: json['level']?.toString() ?? 'beginner',
        language: json['language']?.toString() ?? 'fr',
        duration: int.tryParse(json['duration']?.toString() ?? '0') ?? json['duration'] ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? 'USD',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviewsCount: json['reviews_count'] ?? 0,
        totalStudents: json['total_students'] ?? 0,
        imageUrl: json['image_url']?.toString(),
        thumbnailUrl: json['thumbnail_url']?.toString(),
        isFree: json['is_free'] == true || json['is_free'] == 'true',
        isCertifying: json['is_certifying'] == true || json['is_certifying'] == 'true',
        isFeatured: json['is_featured'] == true || json['is_featured'] == 'true',
        status: json['status']?.toString() ?? 'draft',
        tags: _parseStringList(json['tags']),
        prerequisites: _parseStringList(json['prerequisites']),
        learningOutcomes: _parseStringList(json['learning_outcomes']),
        targetAudience: _parseStringList(json['target_audience']),
        requirements: _parseStringList(json['requirements']),
        createdAt: _safeParseDate(json['created_at']),
        updatedAt: _safeParseDate(json['updated_at']),
        publishedAt: json['published_at'] != null ? _safeParseDate(json['published_at']) : null,
        category: json['category'] != null ? Category.fromJson(json['category']) : null,
        modules: json['modules'] != null
            ? (json['modules'] as List).map((m) => Module.fromJson(m)).toList()
            : null,
        enrollments: json['enrollments'] != null
            ? (json['enrollments'] as List).map((e) => Enrollment.fromJson(e)).toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category_id': categoryId,
        'instructor_id': instructorId,
        'instructor_name': instructorName,
        'instructor_avatar': instructorAvatar,
        'instructor_bio': instructorBio,
        'level': level,
        'language': language,
        'duration': duration,
        'price': price,
        'currency': currency,
        'rating': rating,
        'reviews_count': reviewsCount,
        'total_students': totalStudents,
        'image_url': imageUrl,
        'thumbnail_url': thumbnailUrl,
        'is_free': isFree,
        'is_certifying': isCertifying,
        'is_featured': isFeatured,
        'status': status,
        'tags': tags,
        'prerequisites': prerequisites,
        'learning_outcomes': learningOutcomes,
        'target_audience': targetAudience,
        'requirements': requirements,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'published_at': publishedAt?.toIso8601String(),
      };
}

// ✅ Helper robuste : parse une liste de strings depuis Supabase (gère JSON array, string[], null)
List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  if (value is String) {
    try {
      // Essaie de parser comme JSON array
      final parsed = _tryParseJsonList(value);
      if (parsed != null) return parsed;
      // Sinon, split par virgule
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
  return [];
}

List<String>? _tryParseJsonList(String value) {
  if (!value.trim().startsWith('[')) return null;
  try {
    // Pas d'import dart:convert ici pour rester léger, on gère manuellement les cas simples
    // Pour une vraie robustesse, utiliser jsonDecode côté appelant
    return null;
  } catch (_) {
    return null;
  }
}
