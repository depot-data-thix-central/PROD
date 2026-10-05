// lib/models/chat/chat_message.dart
import 'sentiment.dart';

// ============================================================================
// MESSAGE REACTION
// ============================================================================
class MessageReaction {
  final String reaction;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final DateTime createdAt;

  const MessageReaction({
    required this.reaction,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> j) {
    return MessageReaction(
      reaction: '${j['reaction'] ?? ''}',
      userId: '${j['user_id'] ?? ''}',
      userName: j['user_name']?.toString(),
      userAvatar: j['user_avatar']?.toString(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'reaction': reaction,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'created_at': createdAt.toIso8601String(),
      };
}

// ============================================================================
// CHAT MESSAGE — P0/P1 Enterprise
// ============================================================================
class ChatMessage {
  // ── Identité ──
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;

  // ── Contenu ──
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deleteAt;

  // ── Média ──
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  final int? mediaSize;
  final String? mimeType;

  // ── État ──
  final bool isRead;
  final bool isDelivered;
  final bool isDeleted;
  final bool isEphemeral;
  final int? ephemeralDuration;

  // ── Réponse ──
  final String? replyToId;

  // ── Code ──
  final bool isCodeSnippet;
  final String? codeLanguage;
  final String? codeContent;

  // ── Réactions & Notes ──
  final List<MessageReaction> reactions;
  final bool isInternalNote;
  final SentimentResult? sentiment;

  // ══════════════════════════════════════════════════════════
  // ✅ NOUVEAUX CHAMPS P0/P1
  // ══════════════════════════════════════════════════════════

  /// Édition : true si le message a été modifié après envoi
  final bool isEdited;

  /// Suppression pour tous (pas juste locale)
  final bool isDeletedForAll;

  /// Forward : true si transféré depuis une autre conversation
  final bool isForwarded;
  final String? forwardedFromConversationId;
  final String? forwardedFromSenderName;

  /// Mentions @utilisateur (liste des user_ids mentionnés)
  final List<String> mentionedUserIds;

  /// Épinglé dans la conversation
  final bool isPinned;

  /// Favori ⭐ (marqué par l'utilisateur courant)
  final bool isStarred;

  /// View Once : média qui disparaît après première vue
  final bool isViewOnce;
  final bool hasBeenViewed; // true si déjà vu par le destinataire

  /// Chiffrement mot de passe : préfixe ENCv1: détecté automatiquement
  /// Le contenu brut est stocké dans [content], le déchiffrement est fait côté UI

  /// Rappels sur message
  final DateTime? reminderAt;

  /// Threads : ID du message parent si ce message est dans un fil
  final String? threadParentId;

  /// Transcription audio auto-générée
  final String? transcription;

  /// Annotation sur image (JSON: {x, y, type, color, text})
  final String? annotations;

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
    // ✅ Nouveaux champs P0/P1
    this.isEdited = false,
    this.isDeletedForAll = false,
    this.isForwarded = false,
    this.forwardedFromConversationId,
    this.forwardedFromSenderName,
    this.mentionedUserIds = const [],
    this.isPinned = false,
    this.isStarred = false,
    this.isViewOnce = false,
    this.hasBeenViewed = false,
    this.reminderAt,
    this.threadParentId,
    this.transcription,
    this.annotations,
  });

  // ================================================================
  // HELPERS PRIVÉS
  // ================================================================

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

  static List<String> _pStringList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  // ================================================================
  // DÉTECTION AUTO DU CHIFFREMENT
  // ================================================================

  /// Détecte si le contenu est chiffré avec mot de passe
  bool get isEncrypted =>
      content.startsWith('ENCv1:') || content.startsWith('🔒');

  /// Extrait le payload chiffré (sans le préfixe)
  String get encryptedPayload {
    if (content.startsWith('ENCv1:')) return content.substring(6);
    if (content.startsWith('🔒')) return content.substring(2).trim();
    return content;
  }

  // ================================================================
  // AUTO-DESTRUCTION : vérifie si le message a expiré
  // ================================================================

  /// True si le message est éphémère ET que son timer est écoulé
  bool get isExpired {
    if (!isEphemeral || ephemeralDuration == null || ephemeralDuration! <= 0) {
      return false;
    }
    final expiresAt = createdAt.add(Duration(seconds: ephemeralDuration!));
    return DateTime.now().toUtc().isAfter(expiresAt);
  }

  /// Temps restant avant auto-destruction (null si pas éphémère ou déjà expiré)
  Duration? get timeUntilExpiry {
    if (!isEphemeral || ephemeralDuration == null || ephemeralDuration! <= 0) {
      return null;
    }
    final expiresAt = createdAt.add(Duration(seconds: ephemeralDuration!));
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? null : remaining;
  }

  /// True si le message doit être affiché (pas supprimé, pas expiré, pas viewOnce déjà vu)
  bool get shouldDisplay {
    if (isDeleted || isDeletedForAll) return false;
    if (isExpired) return false;
    if (isViewOnce && hasBeenViewed) return false;
    return true;
  }

  // ================================================================
  // FROM JSON
  // ================================================================

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final p = j['profiles'] as Map<String, dynamic>?;

    return ChatMessage(
      id: '${j['id'] ?? ''}',
      conversationId: '${j['conversation_id'] ?? ''}',
      senderId: '${j['sender_id'] ?? ''}',
      senderName:
          '${p?['full_name'] ?? p?['display_name'] ?? p?['username'] ?? 'Utilisateur'}',
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
      // ✅ Nouveaux champs P0/P1
      isEdited: j['is_edited'] == true,
      isDeletedForAll: j['is_deleted_for_all'] == true,
      isForwarded: j['is_forwarded'] == true,
      forwardedFromConversationId:
          j['forwarded_from_conversation_id']?.toString(),
      forwardedFromSenderName: j['forwarded_from_sender_name']?.toString(),
      mentionedUserIds: _pStringList(j['mentioned_user_ids']),
      isPinned: j['is_pinned'] == true,
      isStarred: j['is_starred'] == true,
      isViewOnce: j['is_view_once'] == true,
      hasBeenViewed: j['has_been_viewed'] == true,
      reminderAt: _pDate(j['reminder_at']),
      threadParentId: j['thread_parent_id']?.toString(),
      transcription: j['transcription']?.toString(),
      annotations: j['annotations']?.toString(),
    );
  }

  // ================================================================
  // TO JSON
  // ================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'delete_at': deleteAt?.toIso8601String(),
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_name': mediaName,
      'media_size': mediaSize,
      'mime_type': mimeType,
      'is_read': isRead,
      'is_delivered': isDelivered,
      'is_deleted': isDeleted,
      'is_ephemeral': isEphemeral,
      'ephemeral_duration': ephemeralDuration,
      'reply_to_id': replyToId,
      'is_code_snippet': isCodeSnippet,
      'code_language': codeLanguage,
      'code_content': codeContent,
      'is_internal_note': isInternalNote,
      'is_edited': isEdited,
      'is_deleted_for_all': isDeletedForAll,
      'is_forwarded': isForwarded,
      'forwarded_from_conversation_id': forwardedFromConversationId,
      'forwarded_from_sender_name': forwardedFromSenderName,
      'mentioned_user_ids': mentionedUserIds,
      'is_pinned': isPinned,
      'is_starred': isStarred,
      'is_view_once': isViewOnce,
      'has_been_viewed': hasBeenViewed,
      'reminder_at': reminderAt?.toIso8601String(),
      'thread_parent_id': threadParentId,
      'transcription': transcription,
      'annotations': annotations,
      'profiles': {
        'full_name': senderName,
        'avatar_url': senderAvatar,
      },
    };
  }

  // ================================================================
  // COPY WITH
  // ================================================================

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
    // ✅ Nouveaux champs P0/P1
    bool? isEdited,
    bool? isDeletedForAll,
    bool? isForwarded,
    String? forwardedFromConversationId,
    String? forwardedFromSenderName,
    List<String>? mentionedUserIds,
    bool? isPinned,
    bool? isStarred,
    bool? isViewOnce,
    bool? hasBeenViewed,
    DateTime? reminderAt,
    bool clearReminder = false,
    String? threadParentId,
    String? transcription,
    String? annotations,
    bool clearAnnotations = false,
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
      // ✅ Nouveaux champs P0/P1
      isEdited: isEdited ?? this.isEdited,
      isDeletedForAll: isDeletedForAll ?? this.isDeletedForAll,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFromConversationId:
          forwardedFromConversationId ?? this.forwardedFromConversationId,
      forwardedFromSenderName:
          forwardedFromSenderName ?? this.forwardedFromSenderName,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      hasBeenViewed: hasBeenViewed ?? this.hasBeenViewed,
      reminderAt: clearReminder ? null : reminderAt ?? this.reminderAt,
      threadParentId: threadParentId ?? this.threadParentId,
      transcription: transcription ?? this.transcription,
      annotations: clearAnnotations ? null : annotations ?? this.annotations,
    );
  }

  // ================================================================
  // GETTERS UTILES
  // ================================================================

  /// Message actif (pas supprimé, pas expiré)
  bool get isActive => !isDeleted && !isDeletedForAll && !isExpired;

  /// A du média attaché
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  /// Est un message audio
  bool get isAudio =>
      mediaType == 'audio' ||
      (mediaName?.toLowerCase().endsWith('.m4a') ?? false) ||
      (mediaName?.toLowerCase().endsWith('.mp3') ?? false);

  /// Est un message vidéo
  bool get isVideo =>
      mediaType == 'video' ||
      (mediaName?.toLowerCase().endsWith('.mp4') ?? false) ||
      (mediaName?.toLowerCase().endsWith('.mov') ?? false);

  /// Est une image
  bool get isImage =>
      mediaType == 'image' ||
      (mediaName?.toLowerCase().endsWith('.jpg') ?? false) ||
      (mediaName?.toLowerCase().endsWith('.jpeg') ?? false) ||
      (mediaName?.toLowerCase().endsWith('.png') ?? false) ||
      (mediaName?.toLowerCase().endsWith('.webp') ?? false);

  /// Peut être édité (15 min max, pas de média, pas éphémère)
  bool canBeEdited(String currentUserId) {
    if (senderId != currentUserId) return false;
    if (isDeleted || isDeletedForAll) return false;
    if (isEphemeral) return false;
    if (hasMedia) return false;
    final elapsed = DateTime.now().toUtc().difference(createdAt);
    return elapsed.inMinutes <= 15;
  }

  /// Peut être supprimé pour tous (15 min max, own message)
  bool canBeDeletedForAll(String currentUserId) {
    if (senderId != currentUserId) return false;
    if (isDeleted || isDeletedForAll) return false;
    final elapsed = DateTime.now().toUtc().difference(createdAt);
    return elapsed.inMinutes <= 15;
  }

  /// Texte d'aperçu pour la liste des conversations
  String get previewText {
    if (isDeleted || isDeletedForAll) return '🚫 Message supprimé';
    if (isExpired) return '⏱️ Message expiré';
    if (isEncrypted) return '🔒 Message protégé';
    if (isViewOnce && hasBeenViewed) return '👁️ Message vu une fois';
    if (isForwarded) return '↪️ ${content.isNotEmpty ? content : "Transféré"}';
    if (hasMedia) {
      switch (mediaType) {
        case 'image':
          return '📷 Photo';
        case 'video':
          return '🎥 Vidéo';
        case 'audio':
          return '🎤 Audio';
        case 'document':
          return '📄 ${mediaName ?? "Document"}';
        case 'location':
          return '📍 Localisation';
        case 'contact':
          return '👤 Contact';
        default:
          return '📎 Fichier';
      }
    }
    return content.isNotEmpty ? content : '—';
  }
}
