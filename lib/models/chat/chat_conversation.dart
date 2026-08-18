// lib/models/chat/chat_conversation.dart
import 'chat_message.dart';

class ChatConversation {
  final String id;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final List<String> participantIds;
  final String? otherParticipantName;
  final String? otherParticipantAvatar;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isPinned;

  /// Escalade
  final bool isEscalation;
  final String? clientName;
  final String? clientAvatar;
  final String? escalatedByName; // nom de l'agent qui a escaladé
  final String? agentAvatar;     // photo de l'agent

  ChatConversation({
    required this.id,
    required this.isGroup,
    this.groupName,
    this.groupAvatar,
    required this.participantIds,
    this.otherParticipantName,
    this.otherParticipantAvatar,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.isPinned = false,
    this.isEscalation = false,
    this.clientName,
    this.clientAvatar,
    this.escalatedByName,
    this.agentAvatar,
  });

  /// Titre liste : client si escalade, sinon groupe / autre participant
  String get displayName {
    if (isEscalation && (clientName?.isNotEmpty ?? false)) {
      return clientName!;
    }
    if (isGroup) return groupName ?? 'Groupe';
    return otherParticipantName ?? 'Utilisateur inconnu';
  }

  String? get displayAvatar {
    if (isEscalation && (clientAvatar?.isNotEmpty ?? false)) {
      return clientAvatar;
    }
    if (isGroup) return groupAvatar;
    return otherParticipantAvatar;
  }

  /// Alias pratiques pour l'UI escalade
  String get agentName => escalatedByName ?? 'Agent';
  String? get escalationClientName => clientName;
  String? get escalationClientAvatar => clientAvatar;
  String? get escalationAgentName => escalatedByName;
  String? get escalationAgentAvatar => agentAvatar;

  ChatConversation copyWith({
    String? id,
    bool? isGroup,
    String? groupName,
    String? groupAvatar,
    List<String>? participantIds,
    String? otherParticipantName,
    String? otherParticipantAvatar,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isEscalation,
    String? clientName,
    String? clientAvatar,
    String? escalatedByName,
    String? agentAvatar,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      participantIds: participantIds ?? this.participantIds,
      otherParticipantName: otherParticipantName ?? this.otherParticipantName,
      otherParticipantAvatar:
          otherParticipantAvatar ?? this.otherParticipantAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isEscalation: isEscalation ?? this.isEscalation,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      escalatedByName: escalatedByName ?? this.escalatedByName,
      agentAvatar: agentAvatar ?? this.agentAvatar,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    ChatMessage? lastMsg;
    if (json['last_message'] != null && json['last_message'] is Map) {
      lastMsg = ChatMessage.fromJson(
        Map<String, dynamic>.from(json['last_message'] as Map),
      );
    } else if (json['last_message_preview'] != null &&
        (json['last_message_preview'] as String).isNotEmpty) {
      // Fallback RPC qui renvoie un aperçu plat
      lastMsg = ChatMessage(
        id: json['last_message_id']?.toString() ?? '',
        conversationId: json['id']?.toString() ?? '',
        senderId: json['last_message_sender_id']?.toString() ?? '',
        senderName: '',
        content: json['last_message_preview']?.toString() ?? '',
        createdAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'].toString())
            : DateTime.now().toUtc(),
        isRead: json['last_message_is_read'] == true,
        isDelivered: json['last_message_is_delivered'] == true,
      );
    }

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      isGroup: json['is_group'] == true,
      groupName: json['group_name'] as String?,
      groupAvatar: json['group_avatar'] as String?,
      participantIds: (json['participant_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      otherParticipantName: json['other_participant_name'] as String? ??
          json['other_display_name'] as String?,
      otherParticipantAvatar: json['other_participant_avatar'] as String? ??
          json['other_avatar_url'] as String?,
      lastMessage: lastMsg,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now().toUtc(),
      isPinned: json['is_pinned'] == true,
      isEscalation: json['is_escalation'] == true,
      clientName: json['client_display_name'] as String? ??
          json['client_name'] as String?,
      clientAvatar: json['client_avatar_url'] as String? ??
          json['client_avatar'] as String?,
      escalatedByName: json['escalated_by_name'] as String? ??
          json['agent_display_name'] as String? ??
          json['agent_name'] as String?,
      agentAvatar: json['agent_avatar_url'] as String? ??
          json['escalated_by_avatar'] as String? ??
          json['agent_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'is_group': isGroup,
        'group_name': groupName,
        'group_avatar': groupAvatar,
        'participant_ids': participantIds,
        'other_participant_name': otherParticipantName,
        'other_participant_avatar': otherParticipantAvatar,
        'unread_count': unreadCount,
        'updated_at': updatedAt.toIso8601String(),
        'is_pinned': isPinned,
        'is_escalation': isEscalation,
        'client_display_name': clientName,
        'client_avatar_url': clientAvatar,
        'escalated_by_name': escalatedByName,
        'agent_avatar_url': agentAvatar,
      };
}
