// lib/models/network_post.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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

  // ─── Médias (unifiés) ───
  final List<String> mediaUrls;

  // ─── Nouveaux types (Sondages, Challenges & Audio) ───
  final String postType; // 'standard', 'poll', 'challenge', 'repost', 'audio'
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? challengeData;

  // ─── Visibilité & Relations ───
  final String status;
  final bool isPublic;
  final String? communityId;
  final String? repostOfId; // (post original si c'est un repost)
  
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

  // ─── Constructeur ───
  const NetworkPost({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    this.authorTitle,
    required this.content,
    this.bgColor,
    required this.mediaUrls,
    this.postType = 'standard',
    this.pollData,
    this.challengeData,
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
    this.status = 'public',
    this.isPublic = true,
    this.communityId,
    this.views,
    this.repostOfId,
  });

  // ─── Logique de détection des médias améliorée ───

  static bool _hasExtension(String url, List<String> extensions) {
    final cleanUrl = url.split('?').first.split('#').first.toLowerCase();
    return extensions.any((ext) => cleanUrl.endsWith(ext));
  }

  static bool _isImage(String url) {
    if (_hasExtension(url, ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'])) {
      return true;
    }
    // Fallback de sécurité si l'URL cloud n'a pas d'extension
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/images/') || cleanUrl.contains('/image/');
  }

  static bool _isVideo(String url) {
    if (_hasExtension(url, ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'])) {
      return true;
    }
    // Fallback de sécurité pour les vidéos cloud
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/videos/') || cleanUrl.contains('/video/');
  }

  static bool _isAudio(String url) {
    if (_hasExtension(url, ['.m4a', '.mp3', '.wav', '.aac', '.ogg', '.flac'])) {
      return true;
    }
    // Fallback de sécurité pour les audios cloud
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('/audios/') || cleanUrl.contains('/audio/');
  }

  // ─── Getters ───

  List<String> get imageUrls => mediaUrls.where(_isImage).toList();
  List<String> get videoUrls => mediaUrls.where(_isVideo).toList();
  List<String> get audioUrls => mediaUrls.where(_isAudio).toList(); 

  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasVideos => videoUrls.isNotEmpty;
  bool get hasAudio => audioUrls.isNotEmpty || postType == 'audio'; 
  bool get hasMedia => mediaUrls.isNotEmpty;

  bool get isRepostCard =>
      postType == 'repost' || (repostOfId != null && repostOfId!.isNotEmpty);

  // ─── Factory depuis la Base de Données ───
  factory NetworkPost.fromJson(Map<String, dynamic> json) {
    List<String> mediaUrls = [];
    if (json['media_urls'] != null) {
      mediaUrls = List<String>.from(json['media_urls'] as List? ?? []);
    } else {
      final images = json['image_urls'] != null
          ? List<String>.from(json['image_urls'] as List? ?? [])
          : <String>[];
      final videos = json['video_urls'] != null
          ? List<String>.from(json['video_urls'] as List? ?? [])
          : <String>[];
      mediaUrls = [...images, ...videos];
    }

    return NetworkPost(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      authorName: json['author_name'] as String? ??
          json['profiles']?['display_name'] as String? ??
          'Utilisateur',
      authorAvatar: json['author_avatar'] as String? ??
          json['profiles']?['avatar_url'] as String?,
      authorTitle: json['author_title'] as String? ??
          json['profiles']?['profession'] as String?,
      content: json['content'] as String? ?? '',
      bgColor: json['bg_color'] as String?,
      mediaUrls: mediaUrls,
      postType: json['post_type'] as String? ?? 'standard',
      pollData: json['poll_data'] as Map<String, dynamic>?,
      challengeData: json['challenge_data'] as Map<String, dynamic>?,
      isFactChecked: json['is_fact_checked'] as bool? ?? false,
      isMisinformation: json['is_misinformation'] as bool? ?? false,
      factCheckMessage: json['fact_check_message'] as String?,
      factCheckSeverity: json['fact_check_severity'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      repostsCount: (json['reposts_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] == true,
      isSaved: json['is_saved'] == true,
      isReposted: json['is_reposted'] == true,
      isPinned: json['is_pinned'] == true,
      status: json['status'] as String? ?? 'public',
      isPublic: json['is_public'] as bool? ?? true,
      communityId: json['community_id'] as String?,
      views: (json['views'] as num?)?.toInt(),
      repostOfId: json['repost_of_id']?.toString(),
    );
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
      'media_urls': mediaUrls,
      'post_type': postType,
      'poll_data': pollData,
      'challenge_data': challengeData,
      'is_fact_checked': isFactChecked,
      'is_misinformation': isMisinformation,
      'fact_check_message': factCheckMessage,
      'fact_check_severity': factCheckSeverity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'reposts_count': repostsCount,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'is_reposted': isReposted,
      'is_pinned': isPinned,
      'status': status,
      'is_public': isPublic,
      'community_id': communityId,
      'views': views,
      'repost_of_id': repostOfId,
    };
  }

  // ─── Copie de l'objet ───
  NetworkPost copyWith({
    String? id,
    String? userId,
    String? authorName,
    String? authorAvatar,
    String? authorTitle,
    String? content,
    String? bgColor,
    List<String>? mediaUrls,
    String? postType,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? challengeData,
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
    String? status,
    bool? isPublic,
    String? communityId,
    int? views,
    String? repostOfId,
  }) {
    return NetworkPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorTitle: authorTitle ?? this.authorTitle,
      content: content ?? this.content,
      bgColor: bgColor ?? this.bgColor,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      postType: postType ?? this.postType,
      pollData: pollData ?? this.pollData,
      challengeData: challengeData ?? this.challengeData,
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
  }

  // ─── Formatage de la date ───
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays > 7) {
      return DateFormat('d MMM yyyy').format(createdAt);
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkPost && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NetworkPost(id: $id, author: $authorName, type: $postType)';
}
