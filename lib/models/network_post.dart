// lib/models/network_post.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

// ============================================================================
// ENUMS POUR TYPE SAFETY
// ============================================================================
enum PostType {
  standard,
  poll,
  challenge,
  repost,
  audio;

  static PostType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'poll':
        return PostType.poll;
      case 'challenge':
        return PostType.challenge;
      case 'repost':
        return PostType.repost;
      case 'audio':
        return PostType.audio;
      default:
        return PostType.standard;
    }
  }

  String toJson() => name;
}

enum PostStatus {
  public,
  private,
  archived,
  deleted;

  static PostStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'private':
        return PostStatus.private;
      case 'archived':
        return PostStatus.archived;
      case 'deleted':
        return PostStatus.deleted;
      default:
        return PostStatus.public;
    }
  }

  String toJson() => name;
}

// ============================================================================
// VALIDATEURS CENTRALISÉS
// ============================================================================
class _PostValidators {
  _PostValidators._();

  static const int maxContentLength = 5000;
  static const int maxMediaCount = 10;
  static const int maxAudioDurationSeconds = 300; // 5 minutes

  /// Liste blanche des badges autorisés (sécurité : pas d'injection possible)
  static const Set<String> allowedBadges = {
    'urgent', 'flash', 'important', 'info', 'new',
    'alert', 'official', 'event', 'promo', 'reminder',
  };

  /// ✅ CORRECTIF PARAGRAPHES : conserve \n, normalise \n\n (espaces entre paragraphes).
  /// La version originale supprimait \n à cause de [\x00-\x1F\x7F].
  static String sanitizeText(String? input, {int maxLength = maxContentLength}) {
    if (input == null || input.trim().isEmpty) return '';
    
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '') // ⬅ préserve \n (0x0A)
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  /// Valide une URL (HTTP/HTTPS uniquement)
  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    
    final trimmed = url.trim();
    
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    
    return trimmed
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(' ', '%20');
  }

  /// Valide une liste d'URLs
  static List<String> sanitizeUrls(List<dynamic>? urls) {
    if (urls == null || urls.isEmpty) return [];
    
    return urls
        .where((u) => u is String && u.trim().isNotEmpty)
        .map((u) => sanitizeUrl(u as String))
        .where((u) => u != null)
        .cast<String>()
        .take(maxMediaCount)
        .toList();
  }

  /// 🏷️ Valide le badge : null si absent ou invalide (protection anti-injection).
  static String? sanitizeBadge(String? badge) {
    if (badge == null) return null;
    final b = badge.trim().toLowerCase();
    return allowedBadges.contains(b) ? b : null;
  }
}

// ============================================================================
// MODÈLE NETWORK POST
// ============================================================================
@immutable
class NetworkPost {
  // ─── Identifiants ───
  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String? authorTitle;

  // ─── Contenu ───
  final String content;
  final String? bgColor;

  // ─── 🏷️ BADGE SPÉCIAL (urgent, flash, important, etc.) ───
  final String? postBadge;

  // ─── Médias (unifiés) ───
  final List<String> mediaUrls;

  // ─── Nouveaux types (Sondages, Challenges & Audio) ───
  final PostType postType;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? challengeData;
  final int? audioDurationSeconds; // Durée audio en secondes

  // ─── Visibilité & Relations ───
  final PostStatus status;
  final bool isPublic;
  final String? communityId;
  final String? repostOfId;

  // ─── Fact-Checking ───
  final bool isFactChecked;
  final bool isMisinformation;
  final String? factCheckMessage;
  final String? factCheckSeverity;

  // ─── Dates ───
  final DateTime createdAt;
  final DateTime? updatedAt;

  // ─── Statistiques ───
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final int? views;

  // ─── États interactifs ───
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  final bool isPinned;

  // ─── Cache pour getters coûteux ───
  List<String>? _cachedImageUrls;
  List<String>? _cachedVideoUrls;
  List<String>? _cachedAudioUrls;
  String? _cachedFormattedDate;
  DateTime? _cachedFormattedDateCreatedAt;
  List<String>? _cachedParagraphs; // ➕ cache rendu paragraphes

  // ─── Constructeur ───
  NetworkPost({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    this.authorTitle,
    required this.content,
    this.bgColor,
    this.postBadge, // 🏷️
    required this.mediaUrls,
    this.postType = PostType.standard,
    this.pollData,
    this.challengeData,
    this.audioDurationSeconds,
    this.isFactChecked = false,
    this.isMisinformation = false,
    this.factCheckMessage,
    this.factCheckSeverity,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isReposted = false,
    this.isPinned = false,
    this.status = PostStatus.public,
    this.isPublic = true,
    this.communityId,
    this.views,
    this.repostOfId,
  }) : assert(id.isNotEmpty, 'NetworkPost.id cannot be empty'),
       assert(likesCount >= 0, 'NetworkPost.likesCount cannot be negative'),
       assert(commentsCount >= 0, 'NetworkPost.commentsCount cannot be negative'),
       assert(repostsCount >= 0, 'NetworkPost.repostsCount cannot be negative'),
       assert(postBadge == null || _PostValidators.allowedBadges.contains(postBadge),
              'NetworkPost.postBadge must be in allowed list');

  // ─── Logique de détection des médias (optimisée) ───

  static bool _hasExtension(String url, List<String> extensions) {
    final cleanUrl = url.split('?').first.split('#').first.toLowerCase();
    return extensions.any((ext) => cleanUrl.endsWith(ext));
  }

  static bool _isImage(String url) {
    if (_hasExtension(url, ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'])) {
      return true;
    }
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/images/') || 
           cleanUrl.contains('/image/') ||
           cleanUrl.contains('post_images');
  }

  static bool _isVideo(String url) {
    if (_hasExtension(url, ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'])) {
      return true;
    }
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/videos/') || 
           cleanUrl.contains('/video/') ||
           cleanUrl.contains('/videos');
  }

  static bool _isAudio(String url) {
    if (_hasExtension(url, ['.m4a', '.mp3', '.wav', '.aac', '.ogg', '.flac'])) {
      return true;
    }
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/audios/') || 
           cleanUrl.contains('/audio/') ||
           cleanUrl.contains('audio_uploads');
  }

  // ─── Getters avec cache ───

  List<String> get imageUrls {
    _cachedImageUrls ??= mediaUrls.where(_isImage).toList();
    return _cachedImageUrls!;
  }

  List<String> get videoUrls {
    _cachedVideoUrls ??= mediaUrls.where(_isVideo).toList();
    return _cachedVideoUrls!;
  }

  List<String> get audioUrls {
    _cachedAudioUrls ??= mediaUrls.where(_isAudio).toList();
    return _cachedAudioUrls!;
  }

  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasVideos => videoUrls.isNotEmpty;
  bool get hasAudio => audioUrls.isNotEmpty || postType == PostType.audio;
  bool get hasMedia => mediaUrls.isNotEmpty;
  bool get hasBadge => postBadge != null && postBadge!.isNotEmpty;

  // ─── 🔧 Helpers badges pour le rendu (feed) ───

  /// Badges "battants" qui doivent pulser (URGENT, ALERTE)
  bool get isPulsingBadge => postBadge == 'urgent' || postBadge == 'alert';

  /// Badges à fort impact visuel (encadré coloré)
  bool get isHighImpactBadge =>
      postBadge == 'urgent' || postBadge == 'alert' ||
      postBadge == 'important' || postBadge == 'flash';

  /// ¶ Contenu découpé en paragraphes (pour l'affichage aéré dans le feed)
  List<String> get paragraphs {
    _cachedParagraphs ??= content
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return _cachedParagraphs!;
  }

  bool get isRepostCard =>
      postType == PostType.repost || (repostOfId != null && repostOfId!.isNotEmpty);

  // ─── Factory depuis la Base de Données (avec validation robuste) ───
  factory NetworkPost.fromJson(Map<String, dynamic> json) {
    try {
      // Extraction et validation des URLs médias
      List<String> mediaUrls = [];
      if (json['media_urls'] != null) {
        mediaUrls = _PostValidators.sanitizeUrls(json['media_urls'] as List?);
      } else {
        final images = json['image_urls'] != null
            ? _PostValidators.sanitizeUrls(json['image_urls'] as List?)
            : <String>[];
        final videos = json['video_urls'] != null
            ? _PostValidators.sanitizeUrls(json['video_urls'] as List?)
            : <String>[];
        mediaUrls = [...images, ...videos].take(_PostValidators.maxMediaCount).toList();
      }

      // Parsing sécurisé des dates
      DateTime parsedCreatedAt;
      try {
        final createdAtStr = json['created_at']?.toString();
        parsedCreatedAt = createdAtStr != null && createdAtStr.isNotEmpty
            ? DateTime.parse(createdAtStr).toLocal()
            : DateTime.now();
      } catch (e) {
        debugPrint('[NetworkPost] Invalid created_at: $e');
        parsedCreatedAt = DateTime.now();
      }

      DateTime? parsedUpdatedAt;
      try {
        final updatedAtStr = json['updated_at']?.toString();
        parsedUpdatedAt = updatedAtStr != null && updatedAtStr.isNotEmpty
            ? DateTime.parse(updatedAtStr).toLocal()
            : null;
      } catch (e) {
        debugPrint('[NetworkPost] Invalid updated_at: $e');
        parsedUpdatedAt = null;
      }

      return NetworkPost(
        id: (json['id'] as String?) ?? '',
        userId: (json['user_id'] as String?) ?? '',
        authorName: _PostValidators.sanitizeText(
          json['author_name'] as String? ??
              (json['profiles']?['display_name'] as String?) ??
              'Utilisateur',
          maxLength: 200,
        ),
        authorAvatar: _PostValidators.sanitizeUrl(
          json['author_avatar'] as String? ??
              (json['profiles']?['avatar_url'] as String?),
        ),
        authorTitle: _PostValidators.sanitizeText(
          json['author_title'] as String? ??
              (json['profiles']?['profession'] as String?),
          maxLength: 100,
        ),
        content: _PostValidators.sanitizeText(json['content'] as String?),
        bgColor: json['bg_color'] as String?,
        postBadge: _PostValidators.sanitizeBadge(json['post_badge'] as String?), // 🏷️
        mediaUrls: mediaUrls,
        postType: PostType.fromString(json['post_type'] as String?),
        pollData: json['poll_data'] as Map<String, dynamic>?,
        challengeData: json['challenge_data'] as Map<String, dynamic>?,
        audioDurationSeconds: (json['audio_duration_seconds'] as num?)?.toInt(),
        isFactChecked: json['is_fact_checked'] == true,
        isMisinformation: json['is_misinformation'] == true,
        factCheckMessage: _PostValidators.sanitizeText(
          json['fact_check_message'] as String?,
          maxLength: 1000,
        ),
        factCheckSeverity: json['fact_check_severity'] as String?,
        createdAt: parsedCreatedAt,
        updatedAt: parsedUpdatedAt,
        likesCount: ((json['likes_count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
        commentsCount: ((json['comments_count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
        repostsCount: ((json['reposts_count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
        isLiked: json['is_liked'] == true,
        isSaved: json['is_saved'] == true,
        isReposted: json['is_reposted'] == true,
        isPinned: json['is_pinned'] == true,
        status: PostStatus.fromString(json['status'] as String?),
        isPublic: json['is_public'] != false,
        communityId: json['community_id'] as String?,
        views: (json['views'] as num?)?.toInt(),
        repostOfId: json['repost_of_id']?.toString(),
      );
    } catch (e, stack) {
      debugPrint('[NetworkPost] fromJson error: $e\n$stack');
      rethrow;
    }
  }

  // ─── Sérialisation JSON ───
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'author_title': authorTitle,
      'content': content,
      'bg_color': bgColor,
      'post_badge': postBadge, // 🏷️
      'media_urls': mediaUrls,
      'post_type': postType.toJson(),
      'poll_data': pollData,
      'challenge_data': challengeData,
      'audio_duration_seconds': audioDurationSeconds,
      'is_fact_checked': isFactChecked,
      'is_misinformation': isMisinformation,
      'fact_check_message': factCheckMessage,
      'fact_check_severity': factCheckSeverity,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'reposts_count': repostsCount,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'is_reposted': isReposted,
      'is_pinned': isPinned,
      'status': status.toJson(),
      'is_public': isPublic,
      'community_id': communityId,
      'views': views,
      'repost_of_id': repostOfId,
    };
  }

  // ─── Copie de l'objet (avec invalidation cache) ───
  NetworkPost copyWith({
    String? id,
    String? userId,
    String? authorName,
    String? authorAvatar,
    String? authorTitle,
    String? content,
    String? bgColor,
    String? postBadge, // 🏷️
    List<String>? mediaUrls,
    PostType? postType,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? challengeData,
    int? audioDurationSeconds,
    bool? isFactChecked,
    bool? isMisinformation,
    String? factCheckMessage,
    String? factCheckSeverity,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReposted,
    bool? isPinned,
    PostStatus? status,
    bool? isPublic,
    String? communityId,
    int? views,
    String? repostOfId,
  }) {
    final newPost = NetworkPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorTitle: authorTitle ?? this.authorTitle,
      content: content ?? this.content,
      bgColor: bgColor ?? this.bgColor,
      postBadge: postBadge ?? this.postBadge, // 🏷️
      mediaUrls: mediaUrls ?? this.mediaUrls,
      postType: postType ?? this.postType,
      pollData: pollData ?? this.pollData,
      challengeData: challengeData ?? this.challengeData,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      isFactChecked: isFactChecked ?? this.isFactChecked,
      isMisinformation: isMisinformation ?? this.isMisinformation,
      factCheckMessage: factCheckMessage ?? this.factCheckMessage,
      factCheckSeverity: factCheckSeverity ?? this.factCheckSeverity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReposted: isReposted ?? this.isReposted,
      isPinned: isPinned ?? this.isPinned,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      communityId: communityId ?? this.communityId,
      views: views ?? this.views,
      repostOfId: repostOfId ?? this.repostOfId,
    );

    if (createdAt != null && createdAt != this.createdAt) {
      newPost._cachedFormattedDate = null;
      newPost._cachedFormattedDateCreatedAt = null;
    }

    // ➕ Invalidate le cache paragraphes si le contenu change
    if (content != null && content != this.content) {
      newPost._cachedParagraphs = null;
    }

    return newPost;
  }

  // ─── Mise à jour atomique de l'engagement ───
  NetworkPost updateEngagement({
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReposted,
  }) {
    return copyWith(
      likesCount: likesCount,
      commentsCount: commentsCount,
      repostsCount: repostsCount,
      isLiked: isLiked,
      isSaved: isSaved,
      isReposted: isReposted,
    );
  }

  // ─── Formatage de la date (avec cache) ───
  String get formattedDate {
    if (_cachedFormattedDate != null && 
        _cachedFormattedDateCreatedAt == createdAt) {
      return _cachedFormattedDate!;
    }

    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    String result;
    if (difference.inDays > 7) {
      try {
        result = DateFormat('d MMM yyyy').format(createdAt);
      } catch (e) {
        debugPrint('[NetworkPost] DateFormat error: $e');
        result = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      }
    } else if (difference.inDays > 0) {
      result = 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      result = 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      result = 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      result = 'À l\'instant';
    }

    _cachedFormattedDate = result;
    _cachedFormattedDateCreatedAt = createdAt;
    
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkPost && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 
      'NetworkPost(id: $id, author: $authorName, type: ${postType.name}, '
      'badge: $postBadge, media: ${mediaUrls.length}, likes: $likesCount)';
}
