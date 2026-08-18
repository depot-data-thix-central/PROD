// lib/models/chat/chat_message.dart
import 'sentiment.dart';

class MessageReaction {
  final String reaction;
  final String userId;

  const MessageReaction({
    required this.reaction,
    required this.userId,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> j) {
    return MessageReaction(
      reaction: '${j['reaction'] ?? ''}',
      userId: '${j['user_id'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'reaction': reaction,
        'user_id': userId,
      };
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deleteAt;

  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  final int? mediaSize;
  final String? mimeType;

  final bool isRead;
  final bool isDelivered;
  final bool isDeleted;
  final bool isEphemeral;
  final int? ephemeralDuration;

  final String? replyToId;

  final bool isCodeSnippet;
  final String? codeLanguage;
  final String? codeContent;

  final List<MessageReaction> reactions;
  final bool isInternalNote;
  final SentimentResult? sentiment;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.deleteAt,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    this.mediaSize,
    this.mimeType,
    this.isRead = false,
    this.isDelivered = false,
    this.isDeleted = false,
    this.isEphemeral = false,
    this.ephemeralDuration,
    this.replyToId,
    this.isCodeSnippet = false,
    this.codeLanguage,
    this.codeContent,
    this.reactions = const [],
    this.isInternalNote = false,
    this.sentiment,
  });

  // ----------------------------------------------------------
  // Helpers privés
  // ----------------------------------------------------------

  static DateTime? _pDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static SentimentResult? _pSent(dynamic v) {
    if (v == null) return null;
    if (v is SentimentResult) return v;
    if (v is Map<String, dynamic>) {
      try {
        return SentimentResult.fromJson(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<MessageReaction> _pReact(dynamic v) {
    if (v is! List) return [];
    return v
        .whereType<Map<String, dynamic>>()
        .map((e) {
          try {
            return MessageReaction.fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<MessageReaction>()
        .toList();
  }

  // ----------------------------------------------------------
  // fromJson
  // ----------------------------------------------------------

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final p = j['profiles'] as Map<String, dynamic>?;

    return ChatMessage(
      id: '${j['id'] ?? ''}',
      conversationId: '${j['conversation_id'] ?? ''}',
      senderId: '${j['sender_id'] ?? ''}',
      senderName: '${p?['full_name'] ?? p?['display_name'] ?? p?['username'] ?? 'Utilisateur'}',
      senderAvatar: p?['avatar_url']?.toString(),
      content: '${j['content'] ?? ''}',
      createdAt: _pDate(j['created_at']) ?? DateTime.now(),
      updatedAt: _pDate(j['updated_at']),
      deleteAt: _pDate(j['delete_at']),
      mediaUrl: (j['media_url'] ?? j['file_url'] ?? j['url'])?.toString(),
      mediaType: (j['media_type'] ?? '').toString(),
      mediaName: (j['media_name'] ?? j['file_name'])?.toString(),
      mediaSize: j['media_size'] is int
          ? j['media_size']
          : int.tryParse('${j['media_size'] ?? ''}'),
      mimeType: j['mime_type']?.toString(),
      isRead: j['is_read'] == true,
      isDelivered: j['is_delivered'] == true,
      isDeleted: j['is_deleted'] == true,
      isEphemeral: j['is_ephemeral'] == true,
      ephemeralDuration: j['ephemeral_duration'] is int
          ? j['ephemeral_duration']
          : int.tryParse('${j['ephemeral_duration'] ?? ''}'),
      replyToId: j['reply_to_id']?.toString(),
      isCodeSnippet: j['is_code_snippet'] == true,
      codeLanguage: j['code_language']?.toString(),
      codeContent: j['code_content']?.toString(),
      reactions: _pReact(j['reactions']),
      isInternalNote: j['is_internal_note'] == true,
      sentiment: _pSent(j['sentiment']),
    );
  }

  // ----------------------------------------------------------
  // toJson
  // ----------------------------------------------------------

  Map<String, dynamic> toJson() {
    dynamic s;
    try {
      s = (sentiment as dynamic).toJson();
    } catch (_) {
      s = null;
    }

    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_name': mediaName,
      'media_size': mediaSize,
      'is_ephemeral': isEphemeral,
      'ephemeral_duration': ephemeralDuration,
      'is_internal_note': isInternalNote,
      'sentiment': s,
    };
  }

  // ----------------------------------------------------------
  // copyWith
  // ----------------------------------------------------------

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deleteAt,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? mediaSize,
    String? mimeType,
    bool? isRead,
    bool? isDelivered,
    bool? isDeleted,
    bool? isEphemeral,
    int? ephemeralDuration,
    String? replyToId,
    bool? isCodeSnippet,
    String? codeLanguage,
    String? codeContent,
    List<MessageReaction>? reactions,
    bool? isInternalNote,
    SentimentResult? sentiment,
    bool clearSentiment = false,
    bool clearMedia = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleteAt: deleteAt ?? this.deleteAt,
      mediaUrl: clearMedia ? null : mediaUrl ?? this.mediaUrl,
      mediaType: clearMedia ? null : mediaType ?? this.mediaType,
      mediaName: clearMedia ? null : mediaName ?? this.mediaName,
      mediaSize: clearMedia ? null : mediaSize ?? this.mediaSize,
      mimeType: clearMedia ? null : mimeType ?? this.mimeType,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      isDeleted: isDeleted ?? this.isDeleted,
      isEphemeral: isEphemeral ?? this.isEphemeral,
      ephemeralDuration: ephemeralDuration ?? this.ephemeralDuration,
      replyToId: replyToId ?? this.replyToId,
      isCodeSnippet: isCodeSnippet ?? this.isCodeSnippet,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      codeContent: codeContent ?? this.codeContent,
      reactions: reactions ?? this.reactions,
      isInternalNote: isInternalNote ?? this.isInternalNote,
      sentiment: clearSentiment ? null : sentiment ?? this.sentiment,
    );
  }

  // ----------------------------------------------------------
  // Getters utiles
  // ----------------------------------------------------------

  bool get isActive =>
      !isDeleted && (deleteAt == null || deleteAt!.isAfter(DateTime.now()));

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
}
