// lib/models/news_article.dart

class NewsArticle {
  final String id;
  final String title;
  final String? summary;
  final String content;
  final String category;
  final String? imageUrl;
  final String? videoUrl;

  final int viewsCount;
  final bool isFeatured;
  final bool isBreaking;
  final String status;

  final DateTime publishedAt;
  final DateTime createdAt;

  final String? createdBy;

  bool isLiked;
  bool isSaved;

  /// Données spécifiques au format Magazine.
  ///
  /// Exemple :
  /// {
  ///   "tags": ["RDC", "Kinshasa", "Dialogue national"],
  ///   "pull_quote": "Une initiative qui entend mobiliser les 26 provinces.",
  ///   "key_points": [
  ///     "26 provinces",
  ///     "Dialogue national",
  ///     "Mobilisation politique"
  ///   ],
  ///   "author_role": "Rédaction THIX Magazine",
  ///   "video_duration": "02:34",
  ///   "image_caption": "La délégation de l'AAAP..."
  /// }
  final Map<String, dynamic> magazineExtras;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  String? get coverImageUrl => imageUrl;

  String? get author => createdBy;

  /// Tags du magazine
  List<String> get magazineTags {
    final value = magazineExtras['tags'];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  /// Citation mise en avant
  String get pullQuote {
    final value = magazineExtras['pull_quote'];

    if (value == null) return '';

    return value.toString().trim();
  }

  /// Points importants
  List<String> get keyPoints {
    final value = magazineExtras['key_points'];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  /// Fonction / rôle de l'auteur
  String get authorRole {
    final value = magazineExtras['author_role'];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Rédaction THIX Magazine';
    }

    return value.toString().trim();
  }

  /// Durée de la vidéo
  String get videoDuration {
    final value = magazineExtras['video_duration'];

    if (value == null) return '';

    return value.toString().trim();
  }

  /// Légende de l'image
  String get imageCaption {
    final value = magazineExtras['image_caption'];

    if (value == null) return '';

    return value.toString().trim();
  }

  // ===========================================================================
  // CONSTRUCTOR
  // ===========================================================================

  NewsArticle({
    required this.id,
    required this.title,
    this.summary,
    required this.content,
    required this.category,
    this.imageUrl,
    this.videoUrl,
    this.viewsCount = 0,
    this.isFeatured = false,
    this.isBreaking = false,
    this.status = 'published',
    required this.publishedAt,
    required this.createdAt,
    this.createdBy,
    this.isLiked = false,
    this.isSaved = false,
    this.magazineExtras = const {},
  });

  // ===========================================================================
  // FROM JSON
  // ===========================================================================

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: _stringValue(json['id']),
      title: _stringValue(
        json['title'],
        fallback: 'Sans titre',
      ),
      summary: _nullableString(json['summary']),
      content: _stringValue(json['content']),
      category: _stringValue(
        json['category'],
        fallback: 'Général',
      ),
      imageUrl: _nullableString(json['image_url']),
      videoUrl: _nullableString(json['video_url']),
      viewsCount: _intValue(json['views_count']),
      isFeatured: _boolValue(json['is_featured']),
      isBreaking: _boolValue(json['is_breaking']),
      status: _stringValue(
        json['status'],
        fallback: 'published',
      ),
      publishedAt: _dateValue(json['published_at']),
      createdAt: _dateValue(json['created_at']),
      createdBy: _nullableString(json['created_by']),
      isLiked: _boolValue(json['is_liked']),
      isSaved: _boolValue(json['is_saved']),
      magazineExtras: _mapValue(json['magazine_extras']),
    );
  }

  // ===========================================================================
  // TO JSON
  // ===========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'views_count': viewsCount,
      'is_featured': isFeatured,
      'is_breaking': isBreaking,
      'status': status,
      'published_at': publishedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'magazine_extras': magazineExtras,
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  NewsArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? category,
    String? imageUrl,
    String? videoUrl,
    int? viewsCount,
    bool? isFeatured,
    bool? isBreaking,
    String? status,
    DateTime? publishedAt,
    DateTime? createdAt,
    String? createdBy,
    bool? isLiked,
    bool? isSaved,
    Map<String, dynamic>? magazineExtras,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      viewsCount: viewsCount ?? this.viewsCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isBreaking: isBreaking ?? this.isBreaking,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      magazineExtras: magazineExtras ?? this.magazineExtras,
    );
  }

  // ===========================================================================
  // JSON HELPERS
  // ===========================================================================

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static int _intValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  static bool _boolValue(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final normalized = value.toString().toLowerCase().trim();

    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes';
  }

  static DateTime _dateValue(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    }

    return const {};
  }
}

// =============================================================================
// EXTENSIONS
// =============================================================================

extension NewsArticleListExtension on List<NewsArticle> {
  List<NewsArticle> get featured {
    return where((a) => a.isFeatured).toList();
  }

  List<NewsArticle> get breaking {
    return where((a) => a.isBreaking).toList();
  }

  List<NewsArticle> get published {
    return where((a) => a.status == 'published').toList();
  }

  List<NewsArticle> byCategory(String category) {
    return where(
      (a) => a.category.toLowerCase() == category.toLowerCase(),
    ).toList();
  }

  List<NewsArticle> mostViewed({
    int limit = 10,
  }) {
    final sorted = [...this]
      ..sort(
        (a, b) => b.viewsCount.compareTo(a.viewsCount),
      );

    return sorted.take(limit).toList();
  }

  List<NewsArticle> mostRecent({
    int limit = 10,
  }) {
    final sorted = [...this]
      ..sort(
        (a, b) => b.publishedAt.compareTo(a.publishedAt),
      );

    return sorted.take(limit).toList();
  }
}
