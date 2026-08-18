// lib/models/network_message.dart
import 'package:flutter/material.dart';

class NetworkMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  NetworkMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  // Constructeur vide pour les tests
  NetworkMessage.empty()
      : id = '',
        conversationId = '',
        senderId = '',
        receiverId = '',
        content = '',
        isRead = false,
        createdAt = DateTime.now();

  // Getters
  bool get isSentByMe => senderId == _currentUserId;
  bool get isReceived => !isSentByMe;
  bool get isValid => id.isNotEmpty && content.isNotEmpty;
  
  String get shortContent => content.length > 50 
      ? '${content.substring(0, 47)}...' 
      : content;
  
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return 'le ${createdAt.day}/${createdAt.month}';
  }
  
  String get formattedTime {
    return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
  
  String get formattedDateTime {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} à ${formattedTime}';
  }

  static String? _currentUserId;
  static void setCurrentUserId(String userId) => _currentUserId = userId;
  static void clearCurrentUserId() => _currentUserId = null;

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'receiver_id': receiverId,
    'content': content,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  NetworkMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NetworkMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'NetworkMessage(id: $id, content: "${shortContent}", isRead: $isRead)';
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool lastMessageIsFromMe;

  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.lastMessageIsFromMe,
  });

  // Constructeur vide pour les tests
  Conversation.empty()
      : id = '',
        otherUserId = '',
        otherUserName = '',
        otherUserAvatar = null,
        lastMessage = null,
        lastMessageAt = DateTime.now(),
        unreadCount = 0,
        lastMessageIsFromMe = false;

  // Getters
  bool get hasUnread => unreadCount > 0;
  bool get hasLastMessage => lastMessage != null && lastMessage!.isNotEmpty;
  bool get hasAvatar => otherUserAvatar != null && otherUserAvatar!.isNotEmpty;
  
  String get avatarUrl => hasAvatar ? otherUserAvatar! : '';
  String get otherUserInitials => otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?';
  
  String get lastMessagePreview {
    if (!hasLastMessage) return 'Démarrer une conversation';
    if (lastMessage!.length > 30) {
      return '${lastMessage!.substring(0, 27)}...';
    }
    return lastMessage!;
  }
  
  String get lastMessageTime {
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt);
    if (diff.inDays > 7) return '${lastMessageAt.day}/${lastMessageAt.month}';
    if (diff.inDays > 0) return 'il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes}min';
    return 'maintenant';
  }
  
  String get lastMessageStatus {
    if (lastMessageIsFromMe) {
      return 'Vous: $lastMessagePreview';
    }
    return lastMessagePreview;
  }
  
  String get unreadBadge {
    if (unreadCount > 99) return '99+';
    return unreadCount.toString();
  }

  factory Conversation.fromJson(Map<String, dynamic> json, String currentUserId) {
    final isUser1 = json['user1_id'] == currentUserId;
    final otherUser = isUser1 ? json['user2'] : json['user1'];
    
    return Conversation(
      id: json['id']?.toString() ?? '',
      otherUserId: otherUser?['id']?.toString() ?? '',
      otherUserName: otherUser?['display_name']?.toString() ?? 'Utilisateur',
      otherUserAvatar: otherUser?['avatar_url']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.parse(json['last_message_at'] as String) 
          : DateTime.now(),
      unreadCount: (json['unread_count'] as int?) ?? 0,
      lastMessageIsFromMe: json['last_sender_id'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'other_user_id': otherUserId,
    'other_user_name': otherUserName,
    'other_user_avatar': otherUserAvatar,
    'last_message': lastMessage,
    'last_message_at': lastMessageAt.toIso8601String(),
    'unread_count': unreadCount,
  };

  Conversation copyWith({
    String? id,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? lastMessageIsFromMe,
  }) {
    return Conversation(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageIsFromMe: lastMessageIsFromMe ?? this.lastMessageIsFromMe,
    );
  }

  @override
  String toString() => 'Conversation(id: $id, with: $otherUserName, unread: $unreadCount)';
}

// Extension pour les messages
extension MessageStatusExtension on bool {
  String get readStatus => this ? 'Lu' : 'Non lu';
  Color get readColor => this ? Colors.green : Colors.orange;
}
