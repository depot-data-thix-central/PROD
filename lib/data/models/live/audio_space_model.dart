enum AudioSpaceStatus { scheduled, live, ended, cancelled }
enum AudioSpaceVisibility { public, followers, enterprise }
enum AudioSpaceRole { host, cohost, speaker, listener }

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
  });

  bool get isLive => status == AudioSpaceStatus.live;
  bool get isEnterprise => enterpriseId != null && enterpriseId!.isNotEmpty;

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
    );
  }

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
}

class AudioSpaceParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final AudioSpaceRole role;
  final bool isMuted;
  final bool handRaised;
  final bool isBanned;
  final bool isVerified;

  const AudioSpaceParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = AudioSpaceRole.listener,
    this.isMuted = true,
    this.handRaised = false,
    this.isBanned = false,
    this.isVerified = false,
  });

  bool get canSpeak =>
      !isBanned &&
      !isMuted &&
      (role == AudioSpaceRole.host ||
          role == AudioSpaceRole.cohost ||
          role == AudioSpaceRole.speaker);

  bool get canModerate =>
      role == AudioSpaceRole.host || role == AudioSpaceRole.cohost;

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
}

class AudioSpaceChatMessage {
  final String userId;
  final String displayName;
  final String body;
  final DateTime sentAt;

  const AudioSpaceChatMessage({
    required this.userId,
    required this.displayName,
    required this.body,
    required this.sentAt,
  });
}

enum AudioSpaceScreenStatus { loading, ready, error, permissionDenied, banned }

class AudioSpaceState {
  final AudioSpaceScreenStatus status;
  final String? errorMessage;
  final bool isMuted;
  final bool handRaised;
  final int listenerCount;
  final AudioSpaceRole myRole;
  final List<AudioSpaceParticipant> participants;
  final List<AudioSpaceChatMessage> messages;

  const AudioSpaceState({
    this.status = AudioSpaceScreenStatus.loading,
    this.errorMessage,
    this.isMuted = true,
    this.handRaised = false,
    this.listenerCount = 0,
    this.myRole = AudioSpaceRole.listener,
    this.participants = const [],
    this.messages = const [],
  });

  AudioSpaceState copyWith({
    AudioSpaceScreenStatus? status,
    String? errorMessage,
    bool? isMuted,
    bool? handRaised,
    int? listenerCount,
    AudioSpaceRole? myRole,
    List<AudioSpaceParticipant>? participants,
    List<AudioSpaceChatMessage>? messages,
  }) {
    return AudioSpaceState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      isMuted: isMuted ?? this.isMuted,
      handRaised: handRaised ?? this.handRaised,
      listenerCount: listenerCount ?? this.listenerCount,
      myRole: myRole ?? this.myRole,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
    );
  }
}
