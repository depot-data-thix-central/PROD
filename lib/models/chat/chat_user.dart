// ============================================================
// 📁 lib/models/chat/chat_user.dart
// ============================================================

class ChatUser {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? status;
  final DateTime? lastSeenAt;
  final bool isOnline;

  ChatUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.status,
    this.lastSeenAt,
    this.isOnline = false,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? '',
      displayName: json['chat_display_name'] ?? json['display_name'] ?? 'Inconnu',
      username: json['username'],
      avatarUrl: json['chat_avatar'] ?? json['avatar_url'],
      status: json['chat_status'] ?? 'En ligne',
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_display_name': displayName,
      'username': username,
      'chat_avatar': avatarUrl,
      'chat_status': status,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'is_online': isOnline,
    };
  }

  ChatUser copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? status,
    DateTime? lastSeenAt,
    bool? isOnline,
  }) {
    return ChatUser(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
