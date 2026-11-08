// lib/models/chat/user_status_story.dart

class UserStatusStory {
  final String statusId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? content;
  final String? mediaUrl;
  final String mediaType; // text | image | video
  final String background;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isMine;
  final bool hasViewed;
  /// ✅ NOUVEAU : compteur de vues (fallback 0 si absent)
  final int viewsCount;

  const UserStatusStory({
    required this.statusId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.content,
    this.mediaUrl,
    required this.mediaType,
    required this.background,
    required this.createdAt,
    required this.expiresAt,
    required this.isMine,
    required this.hasViewed,
    this.viewsCount = 0,
  });

  factory UserStatusStory.fromJson(Map<String, dynamic> j) {
    return UserStatusStory(
      statusId: '${j['status_id'] ?? ''}',
      userId: '${j['user_id'] ?? ''}',
      displayName: '${j['display_name'] ?? 'Utilisateur'}',
      avatarUrl: j['avatar_url']?.toString(),
      content: j['content']?.toString(),
      mediaUrl: j['media_url']?.toString(),
      mediaType: '${j['media_type'] ?? 'text'}',
      background: '${j['background'] ?? '#1D4ED8'}',
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      expiresAt: DateTime.tryParse('${j['expires_at']}') ??
          DateTime.now().add(const Duration(hours: 24)),
      isMine: j['is_mine'] == true,
      hasViewed: j['has_viewed'] == true,
      viewsCount: (j['views_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isImage => mediaType == 'image';
  bool get isText => mediaType == 'text';

  /// ✅ NOUVEAU : détecte si c'est une vidéo (par type OU par URL)
  bool get isVideo {
    if (mediaType == 'video') return true;
    final url = mediaUrl?.toLowerCase() ?? '';
    return url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.m4v') ||
        url.endsWith('.webm') ||
        url.endsWith('.avi') ||
        url.contains('/videos/') ||
        url.contains('/video/');
  }

  UserStatusStory copyWith({
    bool? hasViewed,
    int? viewsCount,
  }) {
    return UserStatusStory(
      statusId: statusId,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      background: background,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isMine: isMine,
      hasViewed: hasViewed ?? this.hasViewed,
      viewsCount: viewsCount ?? this.viewsCount,
    );
  }
}
