// lib/data/models/live/live_model.dart
class LiveSession {
  final String id;
  final String channelName;
  final String title;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;

  // ✅ AJOUT : Certification du host (optionnelle, pour backward compat)
  final String? certificationTier;
  final String? certificationStatus;

  const LiveSession({
    required this.id,
    required this.channelName,
    required this.title,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    this.certificationTier,
    this.certificationStatus,
  });

  factory LiveSession.fromMap(Map<String, dynamic> map) {
    return LiveSession(
      id: map['id']?.toString() ?? '',
      channelName: map['channel_name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      hostId: map['host_id']?.toString() ?? '',
      hostName: map['host_name']?.toString() ?? 'Hôte THIX',
      hostAvatarUrl: map['host_avatar_url']?.toString(),
      certificationTier: map['certification_tier']?.toString(),
      certificationStatus: map['certification_status']?.toString(),
    );
  }

  // ✅ Alias pour compatibilité avec les écrans qui utilisent fromJson
  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession.fromMap(json);
}

class LiveComment {
  final String userId;
  final String userName;
  final String text;
  final DateTime sentAt;

  LiveComment({
    required this.userId,
    required this.userName,
    required this.text,
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
      // ✅ Supporte les deux clés pour backward compat
      userName: payload['userName']?.toString() ?? payload['user']?.toString() ?? 'Invité',
      text: payload['text']?.toString() ?? '',
      sentAt: parsedSentAt,
    );
  }

  Map<String, dynamic> toPayload() => {
        'userId': userId,
        'userName': userName,  // ✅ Aligné avec live_service.dart qui attend 'userName'
        'text': text,
        'sentAt': sentAt.toUtc().toIso8601String(),  // ✅ Timestamp UTC
      };
}

class AgoraCredentials {
  final String appId;
  final String token;

  const AgoraCredentials({required this.appId, required this.token});

  factory AgoraCredentials.fromMap(Map<String, dynamic> map) {
    final appId = map['appId'];
    final token = map['token'];
    if (appId == null || token == null || appId is! String || token is! String || appId.isEmpty || token.isEmpty) {
      throw Exception('appId/token manquant ou invalide : $map');
    }
    return AgoraCredentials(appId: appId, token: token);
  }
}

enum LiveScreenStatus { loading, ready, error, permissionDenied }

/// État complet de l'écran de live, exposé par le Notifier Riverpod.
class LiveState {
  final LiveScreenStatus status;
  final String? errorMessage;
  final bool isMuted;
  final bool isVideoOff;
  final bool isEnding;
  final bool isFrontCamera;
  final bool isBeautyEnabled;
  final int viewerCount;
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
      coHostUids: coHostUids ?? this.coHostUids,
      comments: comments ?? this.comments,
    );
  }
}
