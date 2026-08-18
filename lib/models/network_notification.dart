// lib/models/network_notification.dart
import 'package:flutter/material.dart';

class NetworkNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? actorId;
  final String? actorName;
  final String? actorAvatar;
  final String? postId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NetworkNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.actorId,
    this.actorName,
    this.actorAvatar,
    this.postId,
    this.data = const {},
    required this.isRead,
    required this.createdAt,
  });

  // Constructeur vide pour les tests
  NetworkNotification.empty()
      : id = '',
        type = 'generic',
        title = '',
        body = '',
        actorId = null,
        actorName = null,
        actorAvatar = null,
        postId = null,
        data = const {},
        isRead = false,
        createdAt = DateTime.now();

  // Getters
  bool get isUnread => !isRead;
  bool get isValid => id.isNotEmpty && type.isNotEmpty;
  bool get hasActor => actorId != null && actorId!.isNotEmpty;
  bool get hasPost => postId != null && postId!.isNotEmpty;
  bool get hasAvatar => actorAvatar != null && actorAvatar!.isNotEmpty;
  
  String get actorDisplayName => actorName ?? 'Quelqu\'un';
  String get avatarUrl => hasAvatar ? actorAvatar! : '';
  
  String get formattedTitle {
    if (actorName != null && actorName!.isNotEmpty) {
      return title.replaceFirst('Quelqu\'un', actorName!);
    }
    return title;
  }
  
  String get formattedBody {
    if (actorName != null && actorName!.isNotEmpty) {
      return body.replaceFirst('Quelqu\'un', actorName!);
    }
    return body;
  }
  
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return 'le ${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
  
  String get shortBody => body.length > 100 ? '${body.substring(0, 97)}...' : body;
  
  String get formattedDateTime {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} à ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
  
  // Type checks
  bool get isLike => type == 'like';
  bool get isComment => type == 'comment';
  bool get isConnectionRequest => type == 'connection_request';
  bool get isConnectionAccepted => type == 'connection_accepted';
  bool get isGeneric => type == 'generic';
  
  IconData get icon {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'connection_request':
        return Icons.person_add;
      case 'connection_accepted':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }
  
  Color get iconColor {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'connection_request':
        return Colors.orange;
      case 'connection_accepted':
        return Colors.green;
      default:
        return const Color(0xFFD4AF37);
    }
  }
  
  Color get backgroundColor {
    if (isUnread) {
      return const Color(0xFFD4AF37).withOpacity(0.05);
    }
    return Colors.white;
  }

  factory NetworkNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    
    return NetworkNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'generic',
      title: json['title']?.toString() ?? _getDefaultTitle(json['type']),
      body: json['body']?.toString() ?? _getDefaultBody(json['type']),
      actorId: actor?['id']?.toString() ?? json['actor_id']?.toString(),
      actorName: actor?['display_name']?.toString() ?? json['actor_name']?.toString(),
      actorAvatar: actor?['avatar_url']?.toString() ?? json['actor_avatar']?.toString(),
      postId: json['post_id']?.toString(),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: (json['read'] as bool?) ?? (json['is_read'] as bool?) ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  static String _getDefaultTitle(String? type) {
    switch (type) {
      case 'like': return 'Nouveau like';
      case 'comment': return 'Nouveau commentaire';
      case 'connection_request': return 'Demande de connexion';
      case 'connection_accepted': return 'Connexion acceptée';
      default: return 'Notification';
    }
  }

  static String _getDefaultBody(String? type) {
    switch (type) {
      case 'like': return 'Quelqu\'un a aimé votre publication';
      case 'comment': return 'Quelqu\'un a commenté votre publication';
      case 'connection_request': return 'Quelqu\'un souhaite se connecter avec vous';
      case 'connection_accepted': return 'Votre demande a été acceptée';
      default: return 'Nouvelle notification';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'actor_id': actorId,
    'actor_name': actorName,
    'actor_avatar': actorAvatar,
    'post_id': postId,
    'data': data,
    'read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  NetworkNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? actorId,
    String? actorName,
    String? actorAvatar,
    String? postId,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NetworkNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
      postId: postId ?? this.postId,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  NetworkNotification markAsRead() => copyWith(isRead: true);

  @override
  String toString() => 'NetworkNotification(id: $id, type: $type, isRead: $isRead)';
}

// Extension pour les types de notification
extension NotificationTypeExtension on String {
  bool get isLikeType => this == 'like';
  bool get isCommentType => this == 'comment';
  bool get isConnectionRequestType => this == 'connection_request';
  bool get isConnectionAcceptedType => this == 'connection_accepted';
  bool get isGenericType => this == 'generic';
  
  String get displayName {
    switch (this) {
      case 'like': return 'Like';
      case 'comment': return 'Commentaire';
      case 'connection_request': return 'Demande de connexion';
      case 'connection_accepted': return 'Connexion acceptée';
      default: return 'Notification';
    }
  }
  
  IconData get icon {
    switch (this) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.comment;
      case 'connection_request': return Icons.person_add;
      case 'connection_accepted': return Icons.check_circle;
      default: return Icons.notifications;
    }
  }
  
  Color get color {
    switch (this) {
      case 'like': return Colors.red;
      case 'comment': return Colors.blue;
      case 'connection_request': return Colors.orange;
      case 'connection_accepted': return Colors.green;
      default: return const Color(0xFFD4AF37);
    }
  }
}

// Extension pour les notifications groupées
extension NotificationListExtension on List<NetworkNotification> {
  List<NetworkNotification> get unread => where((n) => n.isUnread).toList();
  List<NetworkNotification> get read => where((n) => n.isRead).toList();
  
  Map<String, List<NetworkNotification>> groupByDate() {
    final map = <String, List<NetworkNotification>>{};
    for (final notification in this) {
      final key = _getDateKey(notification.createdAt);
      map.putIfAbsent(key, () => []).add(notification);
    }
    return map;
  }
  
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return "Aujourd'hui";
    if (difference.inDays == 1) return 'Hier';
    if (difference.inDays < 7) return 'Cette semaine';
    if (difference.inDays < 30) return 'Ce mois';
    return 'Plus ancien';
  }
}
