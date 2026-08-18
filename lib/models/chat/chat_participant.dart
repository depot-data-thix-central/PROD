import 'user_status.dart';

class ChatParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? role; // 'admin', 'member' (pour groupes)
  final String status; // valeurs de UserStatus
  final String? customStatus;
  final DateTime? lastSeen;

  ChatParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role,
    this.status = UserStatus.offline,
    this.customStatus,
    this.lastSeen,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userId: json['user_id'] ?? '',
      displayName: json['display_name'] ?? 'Utilisateur',
      avatarUrl: json['avatar_url'],
      role: json['role'],
      status: json['status'] ?? UserStatus.offline,
      customStatus: json['custom_status'],
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'role': role,
    'status': status,
    'custom_status': customStatus,
    'last_seen': lastSeen?.toIso8601String(),
  };

  ChatParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    String? status,
    String? customStatus,
    DateTime? lastSeen,
  }) {
    return ChatParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      customStatus: customStatus ?? this.customStatus,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isOnline => status == UserStatus.online;
  bool get isBusy => status == UserStatus.busy;
  bool get isAway => status == UserStatus.away;
  bool get isDoNotDisturb => status == UserStatus.doNotDisturb;
  bool get isOffline => status == UserStatus.offline;
}
