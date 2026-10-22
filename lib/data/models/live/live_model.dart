// lib/data/models/live/live_model.dart
//
// Modèles de données pour le système Live (TikTok/IG Live level)
// Version 3.0 avec support complet :
// - LiveRole enum (host, coHost, guest, viewer)
// - GuestStatus enum (invited, accepted, onStage, rejected, removed)
// - LiveGuest (remplace GuestInfo) avec avatarUrl, isEmpty, empty()
// - LiveSession avec hostUsername, hostAvatarUrl, coverUrl
// - LiveComment avec types (chat/reaction/gift/invite/request_join/promote/demote/kick/system)
// - AgoraCredentials complets (avec channelName, uid, role)
// - LiveState pour backward compatibility
//

// ============================================================================
// ROLES (v3.0)
// ============================================================================

/// Rôle d'un participant dans un live
enum LiveRole {
  host,       // Créateur du live
  coHost,     // Co-animateur (guest promu avec privilèges)
  guest,      // Invité sur scène
  viewer;     // Spectateur (audience)

  bool get isBroadcaster => this == host || this == coHost || this == guest;
  bool get isHostLike => this == host || this == coHost;
  bool get isOnStage => isBroadcaster;

  String get label {
    switch (this) {
      case LiveRole.host: return 'Host';
      case LiveRole.coHost: return 'Co-Host';
      case LiveRole.guest: return 'Guest';
      case LiveRole.viewer: return 'Viewer';
    }
  }

  static LiveRole fromString(String? value, {LiveRole fallback = LiveRole.viewer}) {
    switch (value?.toLowerCase()) {
      case 'host': return LiveRole.host;
      case 'co_host':
      case 'cohost':
      case 'co-host': return LiveRole.coHost;
      case 'guest': return LiveRole.guest;
      case 'viewer':
      case 'audience': return LiveRole.viewer;
      default: return fallback;
    }
  }
}

// ============================================================================
// GUEST STATUS (v3.0)
// ============================================================================

/// Statut d'un guest dans un live
enum GuestStatus {
  invited,    // Invitation envoyée, en attente de réponse
  accepted,   // Invitation acceptée, pas encore promu sur scène
  onStage,    // Sur scène (broadcaster actif)
  rejected,   // Invitation refusée
  removed,    // Retiré par le host
  left;       // Quitté volontairement

  bool get isActive => this == accepted || this == onStage;
  bool get isPending => this == invited;
  bool get isFinal => this == rejected || this == removed || this == left;

  String get dbValue {
    switch (this) {
      case GuestStatus.invited: return 'invited';
      case GuestStatus.accepted: return 'accepted';
      case GuestStatus.onStage: return 'on_stage';
      case GuestStatus.rejected: return 'rejected';
      case GuestStatus.removed: return 'removed';
      case GuestStatus.left: return 'left';
    }
  }

  static GuestStatus fromString(String? value, {GuestStatus fallback = GuestStatus.invited}) {
    switch (value?.toLowerCase()) {
      case 'invited': return GuestStatus.invited;
      case 'accepted': return GuestStatus.accepted;
      case 'on_stage':
      case 'onstage': return GuestStatus.onStage;
      case 'rejected': return GuestStatus.rejected;
      case 'removed': return GuestStatus.removed;
      case 'left': return GuestStatus.left;
      default: return fallback;
    }
  }
}

// ============================================================================
// LIVE GUEST (v3.0 — remplace GuestInfo)
// ============================================================================

/// Guest complet dans un live (host + viewer l'utilisent)
class LiveGuest {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int? agoraUid;
  final bool isOnStage;
  final LiveRole role;
  final GuestStatus status;
  final DateTime? joinedAt;

  const LiveGuest({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.agoraUid,
    this.isOnStage = false,
    this.role = LiveRole.viewer,
    this.status = GuestStatus.invited,
    this.joinedAt,
  });

  /// Constructeur "vide" pour usage avec firstWhere/orElse
  /// Utilisé par live_viewer_page v3.0 pour identifier les remote broadcasters
  const LiveGuest.empty()
      : userId = '',
        username = '',
        avatarUrl = null,
        agoraUid = null,
        isOnStage = false,
        role = LiveRole.viewer,
        status = GuestStatus.invited,
        joinedAt = null;

  /// Retourne true si c'est un instance "vide" (pas de userId)
  bool get isEmpty => userId.isEmpty;
  bool get isNotEmpty => userId.isNotEmpty;

  /// Depuis un Map Supabase (avec JOIN profiles pour avatar/username)
  factory LiveGuest.fromMap(Map<String, dynamic> m) {
    final statusStr = (m['status'] ?? 'invited').toString();
    final status = GuestStatus.fromString(statusStr);

    // Rôle : déduit du champ `role` ou du status
    LiveRole role;
    if (m['role'] != null) {
      role = LiveRole.fromString(m['role']?.toString());
    } else {
      role = status == GuestStatus.onStage ? LiveRole.guest : LiveRole.viewer;
    }

    final isOnStage = status == GuestStatus.onStage ||
        m['is_on_stage'] == true ||
        role.isBroadcaster;

    return LiveGuest(
      userId: (m['user_id'] ?? '').toString(),
      username: (m['username'] ?? m['display_name'] ?? 'User').toString(),
      avatarUrl: m['avatar_url']?.toString(),
      agoraUid: (m['agora_uid'] as num?)?.toInt(),
      isOnStage: isOnStage,
      role: role,
      status: status,
      joinedAt: _parseDateTime(m['promoted_at'] ?? m['accepted_at'] ?? m['joined_at']),
    );
  }

  factory LiveGuest.fromJson(Map<String, dynamic> json) =>
      LiveGuest.fromMap(json);

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'username': username,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (agoraUid != null) 'agora_uid': agoraUid,
        'is_on_stage': isOnStage,
        'role': role.name == 'coHost' ? 'co_host' : role.name,
        'status': status.dbValue,
        if (joinedAt != null) 'joined_at': joinedAt!.toUtc().toIso8601String(),
      };

  LiveGuest copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    int? agoraUid,
    bool? isOnStage,
    LiveRole? role,
    GuestStatus? status,
    DateTime? joinedAt,
  }) {
    return LiveGuest(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      agoraUid: agoraUid ?? this.agoraUid,
      isOnStage: isOnStage ?? this.isOnStage,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  String toString() =>
      'LiveGuest(userId: $userId, username: $username, role: ${role.name}, '
      'status: ${status.dbValue}, agoraUid: $agoraUid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveGuest &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          agoraUid == other.agoraUid;

  @override
  int get hashCode => userId.hashCode ^ (agoraUid ?? 0).hashCode;
}

// ============================================================================
// LIVE SESSION
// ============================================================================

class LiveSession {
  final String id;
  final String channelName;
  final String title;
  final String hostId;

  /// ⚠️ DEPRECATED: Utilisez `hostUsername` à la place (gardé pour compat)
  final String hostName;

  /// Nom d'utilisateur du host (v3.0 — utilisé par viewer/host pages)
  final String hostUsername;

  final String? hostAvatarUrl;
  final String? hostDisplayName;
  final String? coverUrl;

  // Paramètres avancés
  final String? description;
  final String? tags;
  final String audience;
  final String category;

  // État du live
  final String status;
  final int viewerCount;
  final int likeCount;
  final DateTime startedAt;
  final DateTime? endedAt;

  // Certification du host
  final String? certificationTier;
  final String? certificationStatus;

  // Guests (v3.0 : LiveGuest au lieu de GuestInfo)
  final List<LiveGuest> guests;

  LiveSession({
    required this.id,
    required this.channelName,
    required this.title,
    required this.hostId,
    String? hostName,
    String? hostUsername,
    this.hostAvatarUrl,
    this.hostDisplayName,
    this.coverUrl,
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
    List<LiveGuest>? guests,
  })  : startedAt = startedAt ?? DateTime.now(),
        hostUsername = hostUsername ?? hostName ?? 'Host',
        hostName = hostName ?? hostUsername ?? 'Host',
        guests = guests ?? [];

  factory LiveSession.fromMap(Map<String, dynamic> map) {
    final hostUsername = (map['host_username'] ??
            map['host_name'] ??
            map['hostName'] ??
            'Host')
        .toString();

    final hostName = (map['host_name'] ??
            map['host_username'] ??
            map['hostName'] ??
            'Host')
        .toString();

    return LiveSession(
      id: map['id']?.toString() ?? '',
      channelName: map['channel_name']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Live',
      hostId: map['host_id']?.toString() ?? '',
      hostName: hostName,
      hostUsername: hostUsername,
      hostAvatarUrl: map['host_avatar_url']?.toString(),
      hostDisplayName: map['host_display_name']?.toString(),
      coverUrl: map['cover_url']?.toString(),
      description: map['description']?.toString(),
      tags: map['tags']?.toString(),
      audience: map['audience']?.toString() ?? 'public',
      category: map['category']?.toString() ?? 'general',
      status: map['status']?.toString() ?? 'live',
      viewerCount: (map['viewer_count'] as num?)?.toInt() ?? 0,
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      startedAt: _parseDateTime(map['started_at']) ?? DateTime.now(),
      endedAt: _parseDateTime(map['ended_at']),
      certificationTier: map['certification_tier']?.toString(),
      certificationStatus: map['certification_status']?.toString(),
      guests: map['guests'] is List
          ? (map['guests'] as List)
              .map((g) => g is Map
                  ? LiveGuest.fromMap(Map<String, dynamic>.from(g))
                  : null)
              .whereType<LiveGuest>()
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
      'host_username': hostUsername,
      if (hostAvatarUrl != null) 'host_avatar_url': hostAvatarUrl,
      if (hostDisplayName != null) 'host_display_name': hostDisplayName,
      if (coverUrl != null) 'cover_url': coverUrl,
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
      'guests': guests.map((g) => g.toMap()).toList(),
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
  int get coHostsCount => guests.where((g) => g.role == LiveRole.coHost).length;

  LiveSession copyWith({
    String? id,
    String? channelName,
    String? title,
    String? hostId,
    String? hostName,
    String? hostUsername,
    String? hostAvatarUrl,
    String? hostDisplayName,
    String? coverUrl,
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
    List<LiveGuest>? guests,
  }) {
    return LiveSession(
      id: id ?? this.id,
      channelName: channelName ?? this.channelName,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostUsername: hostUsername ?? this.hostUsername,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      coverUrl: coverUrl ?? this.coverUrl,
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
      'LiveSession(id: $id, title: $title, host: $hostUsername, '
      'status: $status, viewers: $viewerCount, likes: $likeCount, '
      'guests: ${guests.length})';
}

// ============================================================================
// GUEST INFO (v2.0 — DEPRECATED, utilisez LiveGuest)
// ============================================================================

@Deprecated('Utilisez LiveGuest à la place (v3.0)')
class GuestInfo {
  final String userId;
  final String username;
  final String status;
  final int? agoraUid;
  final DateTime invitedAt;
  final DateTime? acceptedAt;
  final DateTime? promotedAt;
  final DateTime? removedAt;

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
      invitedAt: _parseDateTime(map['invited_at']) ?? DateTime.now(),
      acceptedAt: _parseDateTime(map['accepted_at']),
      promotedAt: _parseDateTime(map['promoted_at']),
      removedAt: _parseDateTime(map['removed_at']),
    );
  }

  /// Conversion vers LiveGuest (v3.0)
  LiveGuest toLiveGuest() {
    final guestStatus = GuestStatus.fromString(status);
    return LiveGuest(
      userId: userId,
      username: username,
      agoraUid: agoraUid,
      isOnStage: guestStatus == GuestStatus.onStage,
      role: guestStatus == GuestStatus.onStage ? LiveRole.guest : LiveRole.viewer,
      status: guestStatus,
      joinedAt: promotedAt ?? acceptedAt,
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
  final String? targetUserId; // v3.0 : pour messages ciblés (invite/promote/kick)
  final String userName;
  final String text;
  final String type; // 'chat' | 'reaction' | 'gift' | 'invite' | 'request_join' | 'promote' | 'demote' | 'kick' | 'system'
  final DateTime sentAt;

  LiveComment({
    required this.userId,
    this.targetUserId,
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
      userId: payload['userId']?.toString() ?? payload['user_id']?.toString() ?? '',
      targetUserId: payload['targetUserId']?.toString() ?? payload['target_user_id']?.toString(),
      userName: payload['userName']?.toString() ??
          payload['user_name']?.toString() ??
          payload['user']?.toString() ??
          'Invité',
      text: payload['text']?.toString() ?? '',
      type: payload['type']?.toString() ?? 'chat',
      sentAt: parsedSentAt,
    );
  }

  factory LiveComment.fromMap(Map<String, dynamic> map) =>
      LiveComment.fromPayload(map);

  Map<String, dynamic> toPayload() => {
        'userId': userId,
        if (targetUserId != null) 'targetUserId': targetUserId,
        'userName': userName,
        'text': text,
        'type': type,
        'sentAt': sentAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toMap() => toPayload();

  bool get isSystemMessage =>
      ['invite', 'request_join', 'promote', 'demote', 'kick', 'system'].contains(type);
  bool get isReaction => type == 'reaction';
  bool get isGift => type == 'gift';
  bool get isRequest => type == 'request_join';
  bool get isTargeted => targetUserId != null;

  @override
  String toString() => 'LiveComment($userName: $text [$type]'
      '${targetUserId != null ? ' -> $targetUserId' : ''})';
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

  const AgoraCredentials({
    required this.appId,
    required this.token,
    required this.channelName,
    this.uid = 0,
    this.role = 'audience',
  });

  factory AgoraCredentials.fromMap(Map<String, dynamic> map) {
    final appId = map['appId'] ?? map['app_id'];
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

  factory AgoraCredentials.fromJson(Map<String, dynamic> json) =>
      AgoraCredentials.fromMap(json);

  Map<String, dynamic> toMap() => {
        'appId': appId,
        'token': token,
        'channelName': channelName,
        'uid': uid,
        'role': role,
      };

  bool get isValid =>
      appId.isNotEmpty &&
      token.isNotEmpty &&
      channelName.isNotEmpty &&
      appId.length >= 10;
  bool get isHost => role == 'host';
  bool get isAudience => role == 'audience';
  bool get isBroadcaster => role == 'broadcaster' || role == 'host';

  AgoraCredentials copyWith({
    String? appId,
    String? token,
    String? channelName,
    int? uid,
    String? role,
  }) {
    return AgoraCredentials(
      appId: appId ?? this.appId,
      token: token ?? this.token,
      channelName: channelName ?? this.channelName,
      uid: uid ?? this.uid,
      role: role ?? this.role,
    );
  }

  @override
  String toString() =>
      'AgoraCredentials(appId: ${appId.length >= 8 ? '${appId.substring(0, 8)}...' : appId}, '
      'channel: $channelName, uid: $uid, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgoraCredentials &&
          runtimeType == other.runtimeType &&
          appId == other.appId &&
          token == other.token &&
          channelName == other.channelName &&
          uid == other.uid;

  @override
  int get hashCode =>
      appId.hashCode ^ token.hashCode ^ channelName.hashCode ^ uid.hashCode;
}

// ============================================================================
// LIVE SCREEN STATUS
// ============================================================================

enum LiveScreenStatus { loading, ready, error, permissionDenied }

// ============================================================================
// LIVE STATE (backward compatibility)
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
  final String? channelName; // v3.0 : pour reconnecter directement
  final String? liveTitle;   // v3.0 : affichage dans dialog
  final DateTime receivedAt;

  const GuestInvite({
    required this.liveId,
    required this.hostId,
    required this.hostUsername,
    this.channelName,
    this.liveTitle,
    required this.receivedAt,
  });

  factory GuestInvite.fromPayload(Map<String, dynamic> payload) {
    return GuestInvite(
      liveId: payload['live_id']?.toString() ?? '',
      hostId: payload['host_id']?.toString() ?? '',
      hostUsername: payload['host_username']?.toString() ?? 'Hôte',
      channelName: payload['channel_name']?.toString(),
      liveTitle: payload['live_title']?.toString(),
      receivedAt: payload['invited_at'] != null
          ? (_parseDateTime(payload['invited_at']) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  factory GuestInvite.fromMap(Map<String, dynamic> map) =>
      GuestInvite.fromPayload(map);

  Map<String, dynamic> toPayload() => {
        'live_id': liveId,
        'host_id': hostId,
        'host_username': hostUsername,
        if (channelName != null) 'channel_name': channelName,
        if (liveTitle != null) 'live_title': liveTitle,
        'invited_at': receivedAt.toUtc().toIso8601String(),
        'timestamp': receivedAt.toUtc().toIso8601String(),
      };

  /// Durée restante avant expiration (30s par défaut)
  Duration remainingUntilExpire({Duration timeout = const Duration(seconds: 30)}) {
    final elapsed = DateTime.now().difference(receivedAt);
    final remaining = timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isExpired({Duration timeout = const Duration(seconds: 30)}) =>
      remainingUntilExpire(timeout: timeout) == Duration.zero;
}

// ============================================================================
// HELPERS PRIVÉS
// ============================================================================

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is! String || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}
