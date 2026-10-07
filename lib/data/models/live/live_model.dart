// lib/data/models/live/live_model.dart
//
// Modèles de données pour le système Live (TikTok/IG Live level)
// Version 2.0 avec support complet :
// - LiveSession avec tous les paramètres avancés
// - LiveComment avec types (chat/reaction/gift/invite/request_join/promote/demote)
// - AgoraCredentials complets (avec channelName, uid, role)
// - LiveState pour backward compatibility
//

// ============================================================================
// LIVE SESSION
// ============================================================================

class LiveSession {
  final String id;
  final String channelName;
  final String title;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;
  final String? hostDisplayName;

  // Paramètres avancés
  final String? description;
  final String? tags;
  final String audience; // 'public' | 'followers' | 'private'
  final String category;

  // État du live
  final String status; // 'live' | 'ended' | 'cancelled'
  final int viewerCount;
  final int likeCount;
  final DateTime startedAt;
  final DateTime? endedAt;

  // Certification du host
  final String? certificationTier;
  final String? certificationStatus;

  // Guests (co-hosts)
  final List<GuestInfo> guests;

  // ✅ CORRECTION : suppression de `const` + lignes vides
  // Raison : DateTime.now() et [] ne sont pas des expressions const
  LiveSession({
    required this.id,
    required this.channelName,
    required this.title,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    this.hostDisplayName,
    this.description,
    this.tags,
    this.audience = 'public',
    this.category = 'general',
    this.status = 'live',
    this.viewerCount = 0,
    this.likeCount = 0,
    DateTime? startedAt,
    this.endedAt,
    this.certificationTier,
    this.certificationStatus,
    List<GuestInfo>? guests,
  })  : startedAt = startedAt ?? DateTime.now(),
        guests = guests ?? [];

  factory LiveSession.fromMap(Map<String, dynamic> map) {
    return LiveSession(
      id: map['id']?.toString() ?? '',
      channelName: map['channel_name']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Live',
      hostId: map['host_id']?.toString() ?? '',
      hostName: map['host_name']?.toString() ?? 'Hôte THIX',
      hostAvatarUrl: map['host_avatar_url']?.toString(),
      hostDisplayName: map['host_display_name']?.toString(),
      description: map['description']?.toString(),
      tags: map['tags']?.toString(),
      audience: map['audience']?.toString() ?? 'public',
      category: map['category']?.toString() ?? 'general',
      status: map['status']?.toString() ?? 'live',
      viewerCount: (map['viewer_count'] as num?)?.toInt() ?? 0,
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: map['ended_at'] != null
          ? DateTime.tryParse(map['ended_at'].toString())
          : null,
      certificationTier: map['certification_tier']?.toString(),
      certificationStatus: map['certification_status']?.toString(),
      guests: map['guests'] is List
          ? (map['guests'] as List)
              .map((g) => g is Map
                  ? GuestInfo.fromMap(Map<String, dynamic>.from(g))
                  : null)
              .whereType<GuestInfo>()
              .toList()
          : [],
    );
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) =>
      LiveSession.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel_name': channelName,
      'title': title,
      'host_id': hostId,
      'host_name': hostName,
      if (hostAvatarUrl != null) 'host_avatar_url': hostAvatarUrl,
      if (hostDisplayName != null) 'host_display_name': hostDisplayName,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
      'audience': audience,
      'category': category,
      'status': status,
      'viewer_count': viewerCount,
      'like_count': likeCount,
      'started_at': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
      if (certificationTier != null) 'certification_tier': certificationTier,
      if (certificationStatus != null)
        'certification_status': certificationStatus,
    };
  }

  // Getters utilitaires
  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isCancelled => status == 'cancelled';
  bool get isPublic => audience == 'public';
  bool get isFollowersOnly => audience == 'followers';
  bool get isPrivate => audience == 'private';
  bool get hasGuests => guests.isNotEmpty;
  int get activeGuestsCount => guests.where((g) => g.isOnStage).length;

  LiveSession copyWith({
    String? id,
    String? channelName,
    String? title,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? hostDisplayName,
    String? description,
    String? tags,
    String? audience,
    String? category,
    String? status,
    int? viewerCount,
    int? likeCount,
    DateTime? startedAt,
    DateTime? endedAt,
    String? certificationTier,
    String? certificationStatus,
    List<GuestInfo>? guests,
  }) {
    return LiveSession(
      id: id ?? this.id,
      channelName: channelName ?? this.channelName,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      audience: audience ?? this.audience,
      category: category ?? this.category,
      status: status ?? this.status,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      certificationTier: certificationTier ?? this.certificationTier,
      certificationStatus: certificationStatus ?? this.certificationStatus,
      guests: guests ?? this.guests,
    );
  }

  @override
  String toString() =>
      'LiveSession(id: $id, title: $title, status: $status, viewers: $viewerCount, likes: $likeCount)';
}

// ============================================================================
// GUEST INFO
// ============================================================================

class GuestInfo {
  final String userId;
  final String username;
  final String status; // 'invited' | 'accepted' | 'on_stage' | 'rejected' | 'removed' | 'left'
  final int? agoraUid;
  final DateTime invitedAt;
  final DateTime? acceptedAt;
  final DateTime? promotedAt;
  final DateTime? removedAt;

  // ⚠️ Note : `invitedAt` est required, donc `const` est valide ici
  // (contrairement à LiveSession où DateTime.now() est utilisé par défaut)
  const GuestInfo({
    required this.userId,
    required this.username,
    required this.status,
    this.agoraUid,
    required this.invitedAt,
    this.acceptedAt,
    this.promotedAt,
    this.removedAt,
  });

  factory GuestInfo.fromMap(Map<String, dynamic> map) {
    return GuestInfo(
      userId: map['user_id']?.toString() ?? '',
      username: map['username']?.toString() ?? 'Guest',
      status: map['status']?.toString() ?? 'invited',
      agoraUid: (map['agora_uid'] as num?)?.toInt(),
      invitedAt: map['invited_at'] != null
          ? DateTime.tryParse(map['invited_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      acceptedAt: map['accepted_at'] != null
          ? DateTime.tryParse(map['accepted_at'].toString())
          : null,
      promotedAt: map['promoted_at'] != null
          ? DateTime.tryParse(map['promoted_at'].toString())
          : null,
      removedAt: map['removed_at'] != null
          ? DateTime.tryParse(map['removed_at'].toString())
          : null,
    );
  }

  bool get isOnStage => status == 'on_stage' || status == 'accepted';
  bool get isPending => status == 'invited';
  bool get isRemoved =>
      status == 'removed' || status == 'left' || status == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'status': status,
      if (agoraUid != null) 'agora_uid': agoraUid,
      'invited_at': invitedAt.toUtc().toIso8601String(),
      if (acceptedAt != null)
        'accepted_at': acceptedAt!.toUtc().toIso8601String(),
      if (promotedAt != null)
        'promoted_at': promotedAt!.toUtc().toIso8601String(),
      if (removedAt != null) 'removed_at': removedAt!.toUtc().toIso8601String(),
    };
  }
}

// ============================================================================
// LIVE COMMENT
// ============================================================================

class LiveComment {
  final String userId;
  final String userName;
  final String text;
  final String type; // 'chat' | 'reaction' | 'gift' | 'invite' | 'request_join' | 'promote' | 'demote'
  final DateTime sentAt;

  LiveComment({
    required this.userId,
    required this.userName,
    required this.text,
    this.type = 'chat',
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  factory LiveComment.fromPayload(Map<String, dynamic> payload) {
    DateTime? parsedSentAt;
    try {
      final sentAtStr = payload['sentAt']?.toString();
      if (sentAtStr != null && sentAtStr.isNotEmpty) {
        parsedSentAt = DateTime.parse(sentAtStr);
      }
    } catch (_) {
      parsedSentAt = null;
    }

    return LiveComment(
      userId: payload['userId']?.toString() ?? '',
      userName: payload['userName']?.toString() ??
          payload['user']?.toString() ??
          'Invité',
      text: payload['text']?.toString() ?? '',
      type: payload['type']?.toString() ?? 'chat',
      sentAt: parsedSentAt,
    );
  }

  Map<String, dynamic> toPayload() => {
        'userId': userId,
        'userName': userName,
        'text': text,
        'type': type,
        'sentAt': sentAt.toUtc().toIso8601String(),
      };

  bool get isSystemMessage =>
      ['invite', 'request_join', 'promote', 'demote'].contains(type);
  bool get isReaction => type == 'reaction';
  bool get isGift => type == 'gift';

  @override
  String toString() => 'LiveComment($userName: $text [$type])';
}

// ============================================================================
// AGORA CREDENTIALS
// ============================================================================

class AgoraCredentials {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String role; // 'host' | 'audience' | 'broadcaster'

  // ✅ `const` valide ici : tous les paramètres ont des valeurs par défaut const
  // ou sont required (pas de DateTime.now() ni [])
  const AgoraCredentials({
    required this.appId,
    required this.token,
    required this.channelName,
    this.uid = 0,
    this.role = 'audience',
  });

  factory AgoraCredentials.fromMap(Map<String, dynamic> map) {
    final appId = map['appId'];
    final token = map['token'];
    final channelName = map['channelName'] ?? map['channel_name'];

    if (appId == null ||
        token == null ||
        appId is! String ||
        token is! String ||
        appId.isEmpty ||
        token.isEmpty) {
      throw Exception('appId/token manquant ou invalide : $map');
    }

    if (channelName == null ||
        channelName is! String ||
        channelName.isEmpty) {
      throw Exception('channelName manquant ou invalide : $map');
    }

    return AgoraCredentials(
      appId: appId,
      token: token,
      channelName: channelName,
      uid: (map['uid'] as num?)?.toInt() ?? 0,
      role: map['role']?.toString() ?? 'audience',
    );
  }

  Map<String, dynamic> toMap() => {
        'appId': appId,
        'token': token,
        'channelName': channelName,
        'uid': uid,
        'role': role,
      };

  bool get isValid =>
      appId.isNotEmpty && token.isNotEmpty && channelName.isNotEmpty;
  bool get isHost => role == 'host';
  bool get isAudience => role == 'audience';
  bool get isBroadcaster => role == 'broadcaster';

  @override
  String toString() =>
      'AgoraCredentials(appId: ${appId.substring(0, 8)}..., channel: $channelName, role: $role)';
}

// ============================================================================
// LIVE SCREEN STATUS
// ============================================================================

enum LiveScreenStatus { loading, ready, error, permissionDenied }

// ============================================================================
// LIVE STATE (pour backward compatibility avec anciens écrans)
// ============================================================================

/// État complet de l'écran de live, exposé par le Notifier Riverpod.
/// ⚠️ DEPRECATED: Utilisez GoLiveState dans go_live_provider.dart à la place.
/// Gardé pour compatibilité avec les anciens écrans.
@Deprecated('Utilisez GoLiveState dans go_live_provider.dart')
class LiveState {
  final LiveScreenStatus status;
  final String? errorMessage;
  final bool isMuted;
  final bool isVideoOff;
  final bool isEnding;
  final bool isFrontCamera;
  final bool isBeautyEnabled;
  final int viewerCount;
  final int likeCount;
  final List<int> coHostUids;
  final List<LiveComment> comments;

  // ✅ `const` valide ici : toutes les valeurs par défaut sont const
  // (pas de DateTime.now(), listes sont `const []`)
  const LiveState({
    this.status = LiveScreenStatus.loading,
    this.errorMessage,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isEnding = false,
    this.isFrontCamera = true,
    this.isBeautyEnabled = false,
    this.viewerCount = 0,
    this.likeCount = 0,
    this.coHostUids = const [],
    this.comments = const [],
  });

  LiveState copyWith({
    LiveScreenStatus? status,
    String? errorMessage,
    bool? isMuted,
    bool? isVideoOff,
    bool? isEnding,
    bool? isFrontCamera,
    bool? isBeautyEnabled,
    int? viewerCount,
    int? likeCount,
    List<int>? coHostUids,
    List<LiveComment>? comments,
  }) {
    return LiveState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      isEnding: isEnding ?? this.isEnding,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isBeautyEnabled: isBeautyEnabled ?? this.isBeautyEnabled,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      coHostUids: coHostUids ?? this.coHostUids,
      comments: comments ?? this.comments,
    );
  }
}

// ============================================================================
// GUEST INVITE (pour les invitations en temps réel)
// ============================================================================

class GuestInvite {
  final String liveId;
  final String hostId;
  final String hostUsername;
  final DateTime receivedAt;

  // ⚠️ Note : `receivedAt` est required, donc `const` est techniquement valide
  // mais les factory utilisent DateTime.now() → utiliser sans const en pratique
  const GuestInvite({
    required this.liveId,
    required this.hostId,
    required this.hostUsername,
    required this.receivedAt,
  });

  factory GuestInvite.fromPayload(Map<String, dynamic> payload) {
    return GuestInvite(
      liveId: payload['live_id']?.toString() ?? '',
      hostId: payload['host_id']?.toString() ?? '',
      hostUsername: payload['host_username']?.toString() ?? 'Hôte',
      receivedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toPayload() => {
        'live_id': liveId,
        'host_id': hostId,
        'host_username': hostUsername,
        'timestamp': receivedAt.toUtc().toIso8601String(),
      };
}
