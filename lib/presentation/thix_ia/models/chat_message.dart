// lib/presentation/thix_ia/models/chat_message.dart
import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant, system }

extension ChatRoleX on ChatRole {
  String get value {
    switch (this) {
      case ChatRole.user: return 'user';
      case ChatRole.assistant: return 'assistant';
      case ChatRole.system: return 'system';
    }
  }
  static ChatRole fromString(String v) {
    switch (v.toLowerCase()) {
      case 'assistant': return ChatRole.assistant;
      case 'system': return ChatRole.system;
      default: return ChatRole.user;
    }
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.projectCode,
    this.userId,
    required this.role,
    required this.content,
    this.metadata = const {},
    this.isStreaming = false,
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String? userId;
  final ChatRole role;
  final String content;
  final Map<String, dynamic> metadata;
  final bool isStreaming;
  final DateTime? createdAt;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
  bool get isSystem => role == ChatRole.system;

  // Pour UI streaming
  bool get isEmpty => content.trim().isEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      projectCode: (json['project_code'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      role: ChatRoleX.fromString((json['role'] ?? 'user').toString()),
      content: (json['content'] ?? '').toString(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      isStreaming: json['is_streaming'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_code': projectCode,
      if (userId != null) 'user_id': userId,
      'role': role.value,
      'content': content,
      'metadata': metadata,
      'is_streaming': isStreaming,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    // Pour Supabase insert (id auto)
    return {
      'project_code': projectCode,
      if (userId != null) 'user_id': userId,
      'role': role.value,
      'content': content,
      'metadata': metadata,
      'is_streaming': isStreaming,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? projectCode,
    String? userId,
    ChatRole? role,
    String? content,
    Map<String, dynamic>? metadata,
    bool? isStreaming,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      isStreaming: isStreaming ?? this.isStreaming,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Factories helpers pour UI
  factory ChatMessage.user({required String projectCode, required String content, String? userId}) {
    return ChatMessage(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      projectCode: projectCode,
      userId: userId,
      role: ChatRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant({required String projectCode, required String content, bool streaming = false, Map<String, dynamic>? metadata}) {
    return ChatMessage(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      projectCode: projectCode,
      role: ChatRole.assistant,
      content: content,
      metadata: metadata ?? const {},
      isStreaming: streaming,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.system({required String projectCode, required String content}) {
    return ChatMessage(
      id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
      projectCode: projectCode,
      role: ChatRole.system,
      content: content,
      createdAt: DateTime.now(),
    );
  }
}
