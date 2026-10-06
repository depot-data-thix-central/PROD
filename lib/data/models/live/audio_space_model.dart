// lib/data/models/live/audio_space_model.dart
//
// ============================================================================
// 🎙️ AUDIO SPACE MODELS — Production
// ============================================================================
// Modèles de données pour les salons audio THIX ID :
//   ✅ AudioSpace (salon)
//   ✅ AudioSpaceParticipant (participant)
//   ✅ AudioSpaceChatMessage (message chat)
//   ✅ AudioSpaceInvite (invitation)
//   ✅ AudioSpaceReaction (réaction)
//   ✅ AgoraCredentials (token Agora)
//   ✅ AudioSpaceState (état UI legacy)
//   ✅ Extensions & helpers
// ============================================================================

// ════════════════════════════════════════════════════════════════════════
// ENUMS
// ════════════════════════════════════════════════════════════════════════

enum AudioSpaceStatus { scheduled, live, ended, cancelled }

enum AudioSpaceVisibility { public, followers, enterprise }

enum AudioSpaceRole { host, cohost, speaker, listener }

enum AudioSpaceScreenStatus { loading, ready, error, permissionDenied, banned }

// ════════════════════════════════════════════════════════════════════════
// EXTENSIONS — Helpers UI
// ════════════════════════════════════════════════════════════════════════

extension AudioSpaceStatusX on AudioSpaceStatus {
  String get label {
    switch (this) {
      case AudioSpaceStatus.scheduled:
        return 'Programmé';
      case AudioSpaceStatus.live:
        return 'En direct';
      case AudioSpaceStatus.ended:
        return 'Terminé';
      case AudioSpaceStatus.cancelled:
        return 'Annulé';
    }
  }

  String get emoji {
    switch (this) {
      case AudioSpaceStatus.scheduled:
        return '📅';
      case AudioSpaceStatus.live:
        return '🔴';
      case AudioSpaceStatus.ended:
        return '⏹️';
      case AudioSpaceStatus.cancelled:
        return '❌';
    }
  }

  bool get isActive => this == AudioSpaceStatus.live;
}

extension AudioSpaceRoleX on AudioSpaceRole {
  String get label {
    switch (this) {
      case AudioSpaceRole.host:
        return 'Hôte';
      case AudioSpaceRole.cohost:
        return 'Co-hôte';
      case AudioSpaceRole.speaker:
        return 'Intervenant';
      case AudioSpaceRole.listener:
        return 'Auditeur';
    }
  }

  String get emoji {
    switch (this) {
      case AudioSpaceRole.host:
        return '👑';
      case AudioSpaceRole.cohost:
        return '⭐';
      case AudioSpaceRole.speaker:
        return '🎙️';
      case AudioSpaceRole.listener:
        return '👂';
    }
  }

  bool get canSpeak =>
      this == AudioSpaceRole.host ||
      this == AudioSpaceRole.cohost ||
      this == AudioSpaceRole.speaker;

  bool get canModerate =>
      this == AudioSpaceRole.host || this == AudioSpaceRole.cohost;
}

extension AudioSpaceVisibilityX on AudioSpaceVisibility {
  String get label {
    switch (this) {
      case AudioSpaceVisibility.public:
        return 'Public';
      case AudioSpaceVisibility.followers:
        return 'Abonnés';
      case AudioSpaceVisibility.enterprise:
        return 'Entreprise';
    }
  }

  String get emoji {
    switch (this) {
      case AudioSpaceVisibility.public:
        return '🌍';
      case AudioSpaceVisibility.followers:
        return '👥';
      case AudioSpaceVisibility.enterprise:
        return '🏢';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// AGORA CREDENTIALS
// ════════════════════════════════════════════════════════════════════════

class AgoraCredentials {
  final String appId;
  final String token;
  final int? uid;
  final DateTime? expiresAt;

  const AgoraCredentials({
    required this.appId,
    required this.token,
    this.uid,
    this.expiresAt,
  });

  bool get isValid => appId.isNotEmpty && token.isNotEmpty;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory AgoraCredentials.fromMap(Map<String, dynamic> map) {
    return AgoraCredentials(
      appId: map['appId']?.toString() ?? map['app_id']?.toString() ?? '',
      token: map['token']?.toString() ?? '',
      uid: (map['uid'] as num?)?.toInt(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'appId': appId,
        'token': token,
        if (uid != null) 'uid': uid,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      };
}

// ════════════════════════════════════════════════════════════════════════
// AUDIO SPACE
// ════════════════════════════════════════════════════════════════════════

class AudioSpace {
  final String id;
  final String channelName;
  final String title;
  final String description;
  final String topic;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;
  final String? enterpriseId;
  final AudioSpaceStatus status;
  final AudioSpaceVisibility visibility;
  final bool requireVerifiedSpeakers;
  final bool recordingEnabled;
  final bool recordingConsent;
  final int maxSpeakers;
  final int listenerCount;
  final int speakerCount;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const AudioSpace({
    required this.id,
    required this.channelName,
    required this.title,
    required this.description,
    required this.topic,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    this.enterpriseId,
    this.status = AudioSpaceStatus.live,
    this.visibility = AudioSpaceVisibility.public,
    this.requireVerifiedSpeakers = false,
    this.recordingEnabled = false,
    this.recordingConsent = false,
    this.maxSpeakers = 12,
    this.listenerCount = 0,
    this.speakerCount = 1,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
  });

  // ─── Getters ───
  bool get isLive => status == AudioSpaceStatus.live;
  bool get isScheduled => status == AudioSpaceStatus.scheduled;
  bool get isEnded => status == AudioSpaceStatus.ended;
  bool get isCancelled => status == AudioSpaceStatus.cancelled;
  bool get isEnterprise => enterpriseId != null && enterpriseId!.isNotEmpty;
  bool get isPublic => visibility == AudioSpaceVisibility.public;

  int get totalParticipants => listenerCount + speakerCount;

  /// Durée écoulée depuis le début
  Duration get elapsed {
    if (startedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Durée formatée (HH:MM:SS ou MM:SS)
  String get elapsedFormatted {
    final d = elapsed;
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Lien de partage universel
  String get shareLink => 'https://thix.id/space/$id';

  /// Deep link (ouvre l'app)
  String get deepLink => 'thix://space/$id';

  // ─── Factories ───
  factory AudioSpace.fromMap(Map<String, dynamic> map) {
    return AudioSpace(
      id: map['id']?.toString() ?? '',
      channelName: map['channel_name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      topic: map['topic']?.toString() ?? 'general',
      hostId: map['host_id']?.toString() ?? '',
      hostName: map['host_name']?.toString() ?? 'Hôte THIX',
      hostAvatarUrl: map['host_avatar_url']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      status: _statusFrom(map['status']?.toString()),
      visibility: _visibilityFrom(map['visibility']?.toString()),
      requireVerifiedSpeakers: map['require_verified_speakers'] == true,
      recordingEnabled: map['recording_enabled'] == true,
      recordingConsent: map['recording_consent'] == true,
      maxSpeakers: (map['max_speakers'] as num?)?.toInt() ?? 12,
      listenerCount: (map['listener_count'] as num?)?.toInt() ?? 0,
      speakerCount: (map['speaker_count'] as num?)?.toInt() ?? 1,
      scheduledAt: _dt(map['scheduled_at']),
      startedAt: _dt(map['started_at']),
      endedAt: _dt(map['ended_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'channel_name': channelName,
        'title': title,
        'description': description,
        'topic': topic,
        'host_id': hostId,
        'host_name': hostName,
        if (hostAvatarUrl != null) 'host_avatar_url': hostAvatarUrl,
        if (enterpriseId != null) 'enterprise_id': enterpriseId,
        'status': status.name,
        'visibility': visibility.name,
        'require_verified_speakers': requireVerifiedSpeakers,
        'recording_enabled': recordingEnabled,
        'recording_consent': recordingConsent,
        'max_speakers': maxSpeakers,
        'listener_count': listenerCount,
        'speaker_count': speakerCount,
        if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      };

  AudioSpace copyWith({
    String? id,
    String? channelName,
    String? title,
    String? description,
    String? topic,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? enterpriseId,
    AudioSpaceStatus? status,
    AudioSpaceVisibility? visibility,
    bool? requireVerifiedSpeakers,
    bool? recordingEnabled,
    bool? recordingConsent,
    int? maxSpeakers,
    int? listenerCount,
    int? speakerCount,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return AudioSpace(
      id: id ?? this.id,
      channelName: channelName ?? this.channelName,
      title: title ?? this.title,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      requireVerifiedSpeakers:
          requireVerifiedSpeakers ?? this.requireVerifiedSpeakers,
      recordingEnabled: recordingEnabled ?? this.recordingEnabled,
      recordingConsent: recordingConsent ?? this.recordingConsent,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      listenerCount: listenerCount ?? this.listenerCount,
      speakerCount: speakerCount ?? this.speakerCount,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  // ─── Helpers ───
  static AudioSpaceStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'scheduled':
        return AudioSpaceStatus.scheduled;
      case 'ended':
        return AudioSpaceStatus.ended;
      case 'cancelled':
        return AudioSpaceStatus.cancelled;
      default:
        return AudioSpaceStatus.live;
    }
  }

  static AudioSpaceVisibility _visibilityFrom(String? raw) {
    switch (raw) {
      case 'followers':
        return AudioSpaceVisibility.followers;
      case 'enterprise':
        return AudioSpaceVisibility.enterprise;
      default:
        return AudioSpaceVisibility.public;
    }
  }

  static DateTime? _dt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AudioSpace && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AudioSpace($id, $title, ${status.label})';
}

// ════════════════════════════════════════════════════════════════════════
// PARTICIPANT
// ════════════════════════════════════════════════════════════════════════

class AudioSpaceParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final AudioSpaceRole role;
  final bool isMuted;
  final bool handRaised;
  final bool isBanned;
  final bool isVerified;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const AudioSpaceParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = AudioSpaceRole.listener,
    this.isMuted = true,
    this.handRaised = false,
    this.isBanned = false,
    this.isVerified = false,
    this.joinedAt,
    this.leftAt,
  });

  bool get canSpeak => !isBanned && role.canSpeak;
  bool get canModerate => role.canModerate;
  bool get isActive => leftAt == null && !isBanned;
  bool get isHost => role == AudioSpaceRole.host;
  bool get isSpeaker =>
      role == AudioSpaceRole.speaker ||
      role == AudioSpaceRole.cohost ||
      role == AudioSpaceRole.host;

  factory AudioSpaceParticipant.fromMap(Map<String, dynamic> map) {
    return AudioSpaceParticipant(
      userId: map['user_id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Membre',
      avatarUrl: map['avatar_url']?.toString(),
      role: roleFrom(map['role']?.toString()),
      isMuted: map['is_muted'] != false,
      handRaised: map['hand_raised'] == true,
      isBanned: map['is_banned'] == true,
      isVerified: map['is_verified'] == true,
      joinedAt: _dt(map['joined_at']),
      leftAt: _dt(map['left_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'role': role.name,
        'is_muted': isMuted,
        'hand_raised': handRaised,
        'is_banned': isBanned,
        'is_verified': isVerified,
        if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
        if (leftAt != null) 'left_at': leftAt!.toIso8601String(),
      };

  AudioSpaceParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    AudioSpaceRole? role,
    bool? isMuted,
    bool? handRaised,
    bool? isBanned,
    bool? isVerified,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return AudioSpaceParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      handRaised: handRaised ?? this.handRaised,
      isBanned: isBanned ?? this.isBanned,
      isVerified: isVerified ?? this.isVerified,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  static AudioSpaceRole roleFrom(String? raw) {
    switch (raw) {
      case 'host':
        return AudioSpaceRole.host;
      case 'cohost':
        return AudioSpaceRole.cohost;
      case 'speaker':
        return AudioSpaceRole.speaker;
      default:
        return AudioSpaceRole.listener;
    }
  }

  static DateTime? _dt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSpaceParticipant && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}

// ════════════════════════════════════════════════════════════════════════
// CHAT MESSAGE
// ════════════════════════════════════════════════════════════════════════

class AudioSpaceChatMessage {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String body;
  final DateTime sentAt;
  final bool isSystem; // message système (ex: "X a rejoint")

  const AudioSpaceChatMessage({
    this.id = '',
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.body,
    required this.sentAt,
    this.isSystem = false,
  });

  /// Temps relatif (ex: "il y a 2 min")
  String get timeAgo {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  factory AudioSpaceChatMessage.fromMap(Map<String, dynamic> map) {
    return AudioSpaceChatMessage(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Membre',
      avatarUrl: map['avatar_url']?.toString(),
      body: map['body']?.toString() ?? '',
      sentAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isSystem: map['is_system'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'user_id': userId,
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'body': body,
        'created_at': sentAt.toIso8601String(),
        'is_system': isSystem,
      };

  /// Message système helper
  factory AudioSpaceChatMessage.system(String body) {
    return AudioSpaceChatMessage(
      userId: 'system',
      displayName: 'Système',
      body: body,
      sentAt: DateTime.now(),
      isSystem: true,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// REACTION
// ════════════════════════════════════════════════════════════════════════

class AudioSpaceReaction {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String emoji;
  final DateTime sentAt;

  const AudioSpaceReaction({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.emoji,
    required this.sentAt,
  });

  factory AudioSpaceReaction.fromMap(Map<String, dynamic> map) {
    return AudioSpaceReaction(
      userId: map['userId']?.toString() ?? map['user_id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ??
          map['display_name']?.toString() ??
          'Membre',
      avatarUrl:
          map['avatarUrl']?.toString() ?? map['avatar_url']?.toString(),
      emoji: map['emoji']?.toString() ?? '❤️',
      sentAt: DateTime.tryParse(
              map['timestamp']?.toString() ?? map['sent_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'emoji': emoji,
        'timestamp': sentAt.toIso8601String(),
      };
}

// ════════════════════════════════════════════════════════════════════════
// INVITE
// ════════════════════════════════════════════════════════════════════════

enum AudioSpaceInviteStatus { pending, accepted, declined, expired }

class AudioSpaceInvite {
  final String id;
  final String spaceId;
  final String inviteeId;
  final String? inviteeName;
  final String? inviteeAvatar;
  final String invitedByName;
  final AudioSpaceInviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const AudioSpaceInvite({
    required this.id,
    required this.spaceId,
    required this.inviteeId,
    this.inviteeName,
    this.inviteeAvatar,
    required this.invitedByName,
    this.status = AudioSpaceInviteStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == AudioSpaceInviteStatus.pending;
  bool get isAccepted => status == AudioSpaceInviteStatus.accepted;
  bool get isDeclined => status == AudioSpaceInviteStatus.declined;

  factory AudioSpaceInvite.fromMap(Map<String, dynamic> map) {
    return AudioSpaceInvite(
      id: map['id']?.toString() ?? '',
      spaceId: map['space_id']?.toString() ?? '',
      inviteeId: map['invitee_id']?.toString() ?? '',
      inviteeName: map['invitee_name']?.toString(),
      inviteeAvatar: map['invitee_avatar']?.toString(),
      invitedByName: map['invited_by_name']?.toString() ?? 'Quelqu\'un',
      status: _statusFrom(map['status']?.toString()),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      respondedAt: map['responded_at'] != null
          ? DateTime.tryParse(map['responded_at'].toString())
          : null,
    );
  }

  static AudioSpaceInviteStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'accepted':
        return AudioSpaceInviteStatus.accepted;
      case 'declined':
        return AudioSpaceInviteStatus.declined;
      case 'expired':
        return AudioSpaceInviteStatus.expired;
      default:
        return AudioSpaceInviteStatus.pending;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// STATE (UI legacy — pour compatibilité avec l'ancien controller)
// ════════════════════════════════════════════════════════════════════════

class AudioSpaceState {
  final AudioSpace space;
  final AudioSpaceScreenStatus status;
  final String? errorMessage;
  final AudioSpaceParticipant? me;
  final List<AudioSpaceParticipant> participants;
  final List<AudioSpaceChatMessage> messages;
  final bool connected;
  final bool ended;
  final String? latestReactionEmoji;
  final int reactionTimestamp;

  const AudioSpaceState({
    required this.space,
    this.status = AudioSpaceScreenStatus.loading,
    this.errorMessage,
    this.me,
    this.participants = const [],
    this.messages = const [],
    this.connected = false,
    this.ended = false,
    this.latestReactionEmoji,
    this.reactionTimestamp = 0,
  });

  AudioSpaceRole get myRole => me?.role ?? AudioSpaceRole.listener;
  bool get isMuted => me?.isMuted ?? true;
  bool get handRaised => me?.handRaised ?? false;
  bool get isHost => me?.role == AudioSpaceRole.host;
  bool get canSpeak => me?.canSpeak ?? false;

  int get listenerCount =>
      participants.where((p) => p.role == AudioSpaceRole.listener).length;

  List<AudioSpaceParticipant> get speakers =>
      participants.where((p) => p.role != AudioSpaceRole.listener).toList();

  List<AudioSpaceParticipant> get handRaisedParticipants =>
      participants.where((p) => p.handRaised).toList();

  AudioSpaceState copyWith({
    AudioSpace? space,
    AudioSpaceScreenStatus? status,
    String? errorMessage,
    AudioSpaceParticipant? me,
    List<AudioSpaceParticipant>? participants,
    List<AudioSpaceChatMessage>? messages,
    bool? connected,
    bool? ended,
    bool? loading,
    String? error,
    String? latestReactionEmoji,
    int? reactionTimestamp,
  }) {
    AudioSpaceScreenStatus nextStatus = status ?? this.status;
    if (loading == true) nextStatus = AudioSpaceScreenStatus.loading;
    if (loading == false &&
        status == null &&
        this.status == AudioSpaceScreenStatus.loading) {
      nextStatus = AudioSpaceScreenStatus.ready;
    }

    return AudioSpaceState(
      space: space ?? this.space,
      status: nextStatus,
      errorMessage: errorMessage ?? error ?? this.errorMessage,
      me: me ?? this.me,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      connected: connected ?? this.connected,
      ended: ended ?? this.ended,
      latestReactionEmoji: latestReactionEmoji ?? this.latestReactionEmoji,
      reactionTimestamp: reactionTimestamp ?? this.reactionTimestamp,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HELPERS GLOBAUX
// ════════════════════════════════════════════════════════════════════════

/// Génère un UID Agora stable (int 32-bit) depuis un UUID Supabase
int generateAgoraUid(String userId) {
  final clean = userId.replaceAll('-', '');
  final head = clean.length >= 8 ? clean.substring(0, 8) : clean.padRight(8, '0');
  return int.parse(head, radix: 16) & 0x7FFFFFFF;
}

/// Formate un nombre (ex: 1234 → "1 234")
String formatCount(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}
