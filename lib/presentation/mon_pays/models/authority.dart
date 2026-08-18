// ============================================================
// FICHIER 1 : lib/presentation/mon_pays/models/authority.dart
// MODÈLE AUTHORITY COMPLET (avec relations)
// ============================================================

import 'package:equatable/equatable.dart';

// ---- Sous-modèles ----
class Education extends Equatable {
  final String id;
  final String institution;
  final String degree;
  final String? field;
  final String? startYear;
  final String? endYear;
  final String? description;

  const Education({
    required this.id,
    required this.institution,
    required this.degree,
    this.field,
    this.startYear,
    this.endYear,
    this.description,
  });

  factory Education.fromJson(Map<String, dynamic> json) => Education(
        id: json['id'] as String,
        institution: json['institution'] as String,
        degree: json['degree'] as String,
        field: json['field'] as String?,
        startYear: json['start_year'] as String?,
        endYear: json['end_year'] as String?,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'institution': institution,
        'degree': degree,
        'field': field,
        'start_year': startYear,
        'end_year': endYear,
        'description': description,
      };

  @override
  List<Object?> get props => [id, institution, degree];
}

class Career extends Equatable {
  final String id;
  final String title;
  final String organization;
  final String startDate;
  final String? endDate;
  final String? description;

  const Career({
    required this.id,
    required this.title,
    required this.organization,
    required this.startDate,
    this.endDate,
    this.description,
  });

  factory Career.fromJson(Map<String, dynamic> json) => Career(
        id: json['id'] as String,
        title: json['title'] as String,
        organization: json['organization'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String?,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'organization': organization,
        'start_date': startDate,
        'end_date': endDate,
        'description': description,
      };

  @override
  List<Object?> get props => [id, title, organization];
}

class Achievement extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? date;
  final String? category;
  final String? imageUrl;

  const Achievement({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.category,
    this.imageUrl,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        date: json['date'] as String?,
        category: json['category'] as String?,
        imageUrl: json['image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'category': category,
        'image_url': imageUrl,
      };

  @override
  List<Object?> get props => [id, title];
}

class AuthorityVideo extends Equatable {
  final String id;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? description;

  const AuthorityVideo({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.description,
  });

  factory AuthorityVideo.fromJson(Map<String, dynamic> json) => AuthorityVideo(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'description': description,
      };

  @override
  List<Object?> get props => [id, title];
}

class AuthorityPhoto extends Equatable {
  final String id;
  final String url;
  final String? title;
  final bool isCover;

  const AuthorityPhoto({
    required this.id,
    required this.url,
    this.title,
    this.isCover = false,
  });

  factory AuthorityPhoto.fromJson(Map<String, dynamic> json) => AuthorityPhoto(
        id: json['id'] as String,
        url: json['url'] as String,
        title: json['title'] as String?,
        isCover: json['is_cover'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'is_cover': isCover,
      };

  @override
  List<Object?> get props => [id, url];
}

class AuthorityDocument extends Equatable {
  final String id;
  final String title;
  final String url;
  final String type;
  final String? description;

  const AuthorityDocument({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
    this.description,
  });

  factory AuthorityDocument.fromJson(Map<String, dynamic> json) => AuthorityDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        type: json['type'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'type': type,
        'description': description,
      };

  @override
  List<Object?> get props => [id, title];
}

// ---- MODÈLE PRINCIPAL AUTHORITY ----
class Authority extends Equatable {
  final String id;
  final String? provinceId; // 🚀 NOUVEAU CHAMP AJOUTÉ ICI
  final String name;
  final String title;
  final String? imageUrl;
  final String? coverImageUrl;
  final String biography;
  final String? explanation;
  final String mandate;
  final DateTime? mandateStart;
  final DateTime? mandateEnd;
  final String party;
  final String? category;
  final bool isActive;

  // Nouvelles relations
  final List<Education> education;
  final List<Career> career;
  final List<Achievement> achievements;
  final List<AuthorityPhoto> photos;
  final List<AuthorityVideo> videos;
  final List<AuthorityDocument> documents;
  final List<String> speeches;
  final List<String> publications;
  final Map<String, String> socialNetworks;
  final List<Map<String, String>> agenda;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Authority({
    required this.id,
    this.provinceId, // 🚀 AJOUTÉ AU CONSTRUCTEUR
    required this.name,
    required this.title,
    this.imageUrl,
    this.coverImageUrl,
    required this.biography,
    this.explanation,
    required this.mandate,
    this.mandateStart,
    this.mandateEnd,
    required this.party,
    this.category,
    this.isActive = true,
    this.education = const [],
    this.career = const [],
    this.achievements = const [],
    this.photos = const [],
    this.videos = const [],
    this.documents = const [],
    this.speeches = const [],
    this.publications = const [],
    this.socialNetworks = const {},
    this.agenda = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Calcul automatique du statut actif
  bool get isCurrentlyActive {
    if (mandateEnd == null) return true;
    return DateTime.now().isBefore(mandateEnd!);
  }

  factory Authority.fromJson(Map<String, dynamic> json) {
    return Authority(
      id: json['id'] as String,
      provinceId: json['province_id'] as String?, // 🚀 PARSÉ DEPUIS LE JSON
      name: json['name'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      biography: json['biography'] as String? ?? '',
      explanation: json['explanation'] as String?,
      mandate: json['mandate'] as String? ?? '',
      mandateStart: json['mandate_start'] != null
          ? DateTime.parse(json['mandate_start'])
          : null,
      mandateEnd: json['mandate_end'] != null
          ? DateTime.parse(json['mandate_end'])
          : null,
      party: json['party'] as String? ?? '',
      category: json['category'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      education: (json['education'] as List?)
              ?.map((e) => Education.fromJson(e))
              .toList() ??
          [],
      career: (json['career'] as List?)
              ?.map((e) => Career.fromJson(e))
              .toList() ??
          [],
      achievements: (json['achievements'] as List?)
              ?.map((e) => Achievement.fromJson(e))
              .toList() ??
          [],
      photos: (json['photos'] as List?)
              ?.map((e) => AuthorityPhoto.fromJson(e))
              .toList() ??
          [],
      videos: (json['videos'] as List?)
              ?.map((e) => AuthorityVideo.fromJson(e))
              .toList() ??
          [],
      documents: (json['documents'] as List?)
              ?.map((e) => AuthorityDocument.fromJson(e))
              .toList() ??
          [],
      speeches: List<String>.from(json['speeches'] ?? []),
      publications: List<String>.from(json['publications'] ?? []),
      socialNetworks: Map<String, String>.from(json['social_networks'] ?? {}),
      agenda: (json['agenda'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'province_id': provinceId, // 🚀 AJOUTÉ AU TOJSON
        'name': name,
        'title': title,
        'image_url': imageUrl,
        'cover_image_url': coverImageUrl,
        'biography': biography,
        'explanation': explanation,
        'mandate': mandate,
        'mandate_start': mandateStart?.toIso8601String(),
        'mandate_end': mandateEnd?.toIso8601String(),
        'party': party,
        'category': category,
        'is_active': isActive,
        'education': education.map((e) => e.toJson()).toList(),
        'career': career.map((e) => e.toJson()).toList(),
        'achievements': achievements.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'videos': videos.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'speeches': speeches,
        'publications': publications,
        'social_networks': socialNetworks,
        'agenda': agenda,
      };

  @override
  List<Object?> get props => [id, name, title];
}
