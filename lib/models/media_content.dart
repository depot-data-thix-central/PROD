import 'package:flutter/foundation.dart';

/// Modèle de contenu média (vidéo, série, etc.)
/// 
/// Conçu pour la production enterprise avec :
/// - Protection XSS optimisée sur tous les champs texte
/// - Sérialisation UTC pour la cohérence des timestamps
/// - Validation et nettoyage rigoureux des URLs
/// - Immutabilité stricte des listes pour Riverpod / Bloc
/// - Support complet des reposts (attribution + compteur)
class MediaContent {
  // ============================================================================
  // REGEX PRE-COMPILÉES (Optimisation des performances mémoire)
  // ============================================================================
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');
  static final RegExp _javascriptRegex = RegExp(r'javascript:', caseSensitive: false);
  static final RegExp _onEventRegex = RegExp(r'on\w+\s*=', caseSensitive: false);
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  // ============================================================================
  // CHAMPS PRINCIPAUX
  // ============================================================================
  final String id;
  final String title;
  final String? subtitle;
  final String type;
  final String? year;
  
  // URLs (validées et sanitizées)
  final String coverUrl;
  final String videoUrl;
  final List<String> episodesUrls;
  
  // Statistiques
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int repostCount;          // ✅ Nombre de fois que ce média a été reposté
  final int? rankPosition;
  
  // Flags
  final bool isTrending;
  final bool isNewRelease;
  final bool isRecommended;
  final bool isPublished;
  final bool isFeedOnly;
  
  // Métadonnées créateur & monétisation
  final String? userId;
  final bool isPaid;
  final double price;
  final String filterApplied;

  // ✅ Repost : ID du média original si celui-ci est un repost
  final String? repostOf;
  
  // Timestamps (toujours UTC)
  final DateTime createdAt;
  final DateTime updatedAt;

  // ============================================================================
  // CONSTRUCTEUR
  // ============================================================================
  MediaContent({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.year,
    required this.coverUrl,
    required this.videoUrl,
    List<String> episodesUrls = const [],
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,           // ✅
    this.rankPosition,
    this.isTrending = false,
    this.isNewRelease = false,
    this.isRecommended = false,
    this.isPublished = true,
    this.isFeedOnly = false,
    this.userId,
    this.isPaid = false,
    this.price = 0.0,
    this.filterApplied = 'Normal',
    this.repostOf,                  // ✅
    required this.createdAt,
    required this.updatedAt,
  })  : episodesUrls = List.unmodifiable(episodesUrls),
        assert(id.isNotEmpty, 'MediaContent.id cannot be empty'),
        assert(title.isNotEmpty, 'MediaContent.title cannot be empty'),
        assert(price >= 0, 'MediaContent.price cannot be negative'),
        assert(repostCount >= 0, 'MediaContent.repostCount cannot be negative');

  // ============================================================================
  // MÉTHODES UTILITAIRES
  // ============================================================================
  
  /// Indique si le contenu est une série (plusieurs épisodes)
  bool get isSeries => episodesUrls.isNotEmpty;
  
  /// Nombre total d'épisodes (inclut la vidéo principale)
  int get totalEpisodes => isSeries ? episodesUrls.length + 1 : 1;
  
  /// Indique si le contenu a une vidéo valide
  bool get hasVideo => videoUrl.trim().isNotEmpty;
  
  /// Indique si le contenu a une couverture valide
  bool get hasCover => coverUrl.trim().isNotEmpty;
  
  /// Affichage du rang (ex: "#1", "#42")
  String get rankDisplay => rankPosition != null ? '#$rankPosition' : '';
  
  /// Prix formaté (ex: "$9.99")
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
  
  /// Indique si le contenu est premium (payant et publié)
  bool get isPremium => isPaid && isPublished && price > 0;

  /// ✅ Indique si ce média est un repost d'un autre média
  bool get isRepost => repostOf != null && repostOf!.isNotEmpty;

  /// ✅ Indique si ce média a été reposté au moins une fois
  bool get hasReposts => repostCount > 0;

  // ============================================================================
  // SANITIZATION (Anti-XSS & Sécurité)
  // ============================================================================
  
  /// Nettoie une chaîne de caractères pour prévenir les injections XSS
  static String _sanitize(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    
    return input
        .replaceAll(_htmlTagRegex, '')
        .replaceAll(_javascriptRegex, '')
        .replaceAll(_onEventRegex, '')
        .replaceAll(_controlCharRegex, '')
        .trim();
  }

  /// Valide et nettoie une URL
  static String _sanitizeUrl(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    
    final trimmed = input.trim();
    
    // Vérifie qu'il s'agit d'une URL HTTP/HTTPS valide
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '';
    }
    
    return trimmed
        .replaceAll(_controlCharRegex, '')
        .replaceAll(' ', '%20');
  }

  /// ✅ Valide et sanitise un UUID (pour repostOf)
  static String? _sanitizeUuid(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final trimmed = input.trim();
    if (!_uuidRegex.hasMatch(trimmed)) return null;
    return trimmed;
  }

  // ============================================================================
  // DÉSÉRIALISATION (JSON → Objet)
  // ============================================================================
  
  factory MediaContent.fromJson(Map<String, dynamic> json) {
    // ID et Titre sécurisés pour prévenir les plantages d'assertion en Debug
    final rawId = json['id']?.toString() ?? '';
    final parsedId = rawId.trim().isNotEmpty ? rawId : 'unknown_id';
    if (rawId.trim().isEmpty) {
      debugPrint('[MediaContent] Warning: Received empty ID from API payload');
    }

    final rawTitle = _sanitize(json['title']?.toString());
    final parsedTitle = rawTitle.isNotEmpty ? rawTitle : 'Sans titre';

    // Parsing sécurisé des dates (UTC)
    DateTime parsedCreatedAt;
    try {
      final createdAtStr = json['created_at']?.toString().trim();
      parsedCreatedAt = (createdAtStr != null && createdAtStr.isNotEmpty)
          ? DateTime.parse(createdAtStr).toUtc()
          : DateTime.now().toUtc();
    } catch (e) {
      debugPrint('[MediaContent] Invalid created_at: $e');
      parsedCreatedAt = DateTime.now().toUtc();
    }

    DateTime parsedUpdatedAt;
    try {
      final updatedAtStr = json['updated_at']?.toString().trim();
      parsedUpdatedAt = (updatedAtStr != null && updatedAtStr.isNotEmpty)
          ? DateTime.parse(updatedAtStr).toUtc()
          : parsedCreatedAt;
    } catch (e) {
      debugPrint('[MediaContent] Invalid updated_at: $e');
      parsedUpdatedAt = parsedCreatedAt;
    }

    // Parsing sécurisé des épisodes
    final episodesList = <String>[];
    final rawEpisodes = json['episodes_urls'];
    if (rawEpisodes is List) {
      for (final ep in rawEpisodes) {
        final sanitized = _sanitizeUrl(ep?.toString());
        if (sanitized.isNotEmpty) {
          episodesList.add(sanitized);
        }
      }
    }

    // Extraction optimisée du filtre appliqué
    final sanitizedFilter = _sanitize(json['filter_applied']?.toString());
    final parsedFilter = sanitizedFilter.isEmpty ? 'Normal' : sanitizedFilter;

    return MediaContent(
      id: parsedId,
      title: parsedTitle,
      subtitle: _sanitize(json['subtitle']?.toString()),
      type: _sanitize(json['type']?.toString()),
      year: json['year']?.toString(),
      coverUrl: _sanitizeUrl(json['cover_url']?.toString()),
      videoUrl: _sanitizeUrl(json['video_url']?.toString()),
      episodesUrls: episodesList,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      repostCount: ((json['repost_count'] as num?)?.toInt() ?? 0).clamp(0, 999999999), // ✅
      rankPosition: (json['rank_position'] as num?)?.toInt(),
      isTrending: json['is_trending'] == true,
      isNewRelease: json['is_new_release'] == true,
      isRecommended: json['is_recommended'] == true,
      isPublished: json['is_published'] != false,
      isFeedOnly: json['is_feed_only'] == true,
      userId: json['user_id']?.toString(),
      isPaid: json['is_paid'] == true,
      price: ((json['price'] as num?)?.toDouble() ?? 0.0).clamp(0.0, double.infinity),
      filterApplied: parsedFilter,
      repostOf: _sanitizeUuid(json['repost_of']?.toString()), // ✅
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  // ============================================================================
  // SÉRIALISATION (Objet → JSON)
  // ============================================================================
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'type': type,
    'year': year,
    'cover_url': coverUrl,
    'video_url': videoUrl,
    'episodes_urls': episodesUrls,
    'view_count': viewCount,
    'like_count': likeCount,
    'comment_count': commentCount,
    'repost_count': repostCount,       // ✅
    'rank_position': rankPosition,
    'is_trending': isTrending,
    'is_new_release': isNewRelease,
    'is_recommended': isRecommended,
    'is_published': isPublished,
    'is_feed_only': isFeedOnly,
    'user_id': userId,
    'is_paid': isPaid,
    'price': price,
    'filter_applied': filterApplied,
    'repost_of': repostOf,             // ✅
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  // ============================================================================
  // COPYWITH (Modification immutable)
  // ============================================================================
  
  MediaContent copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? type,
    String? year,
    String? coverUrl,
    String? videoUrl,
    List<String>? episodesUrls,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? repostCount,           // ✅
    int? rankPosition,
    bool? isTrending,
    bool? isNewRelease,
    bool? isRecommended,
    bool? isPublished,
    bool? isFeedOnly,
    String? userId,
    bool? isPaid,
    double? price,
    String? filterApplied,
    String? repostOf,           // ✅
    bool clearRepostOf = false, // ✅ Permet de supprimer le repost (utile si annulation)
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaContent(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      year: year ?? this.year,
      coverUrl: coverUrl ?? this.coverUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      episodesUrls: episodesUrls ?? this.episodesUrls,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,   // ✅
      rankPosition: rankPosition ?? this.rankPosition,
      isTrending: isTrending ?? this.isTrending,
      isNewRelease: isNewRelease ?? this.isNewRelease,
      isRecommended: isRecommended ?? this.isRecommended,
      isPublished: isPublished ?? this.isPublished,
      isFeedOnly: isFeedOnly ?? this.isFeedOnly,
      userId: userId ?? this.userId,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      filterApplied: filterApplied ?? this.filterApplied,
      repostOf: clearRepostOf ? null : (repostOf ?? this.repostOf), // ✅
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================================
  // ÉGALITÉ & HASHCODE
  // ============================================================================
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaContent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    final repostInfo = isRepost ? ', repostOf: $repostOf' : '';
    return 'MediaContent(id: $id, title: $title, type: $type, isSeries: $isSeries, isPaid: $isPaid, repostCount: $repostCount$repostInfo)';
  }
}
