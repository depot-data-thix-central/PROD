// lib/services/chat/chat_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_conversation.dart';
import '../../models/chat/user_status.dart';
import '../../models/chat/group_info.dart';

class ChatService {
  final SupabaseClient _supabase;
  Timer? _presenceHeartbeat;

  ChatService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUserId.isNotEmpty;

  // ============================================================
  // HELPERS
  // ============================================================

  static String _resolveDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Utilisateur inconnu';
    final displayName = profile['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName;
    }
    final fullName = profile['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName;
    }
    return 'Utilisateur inconnu';
  }

  Future<void> _assertParticipant(String conversationId) async {
    if (currentUserId.isEmpty) {
      throw Exception('Non authentifié');
    }
    final row = await _supabase
        .from('conversation_participants')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    if (row == null) {
      throw Exception('Accès refusé à cette conversation');
    }
  }

  // ============================================================
  // PRÉSENCE
  // ============================================================

  Future<void> startPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    await updatePresence('online');

    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) async {
      await updatePresence('online');
    });
  }

  Future<void> stopPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    await updatePresence('offline');
  }

  Future<void> updatePresence(String status, {String? customStatus}) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    try {
      await _supabase.from('user_presence').upsert({
        'user_id': uid,
        'status': status,
        'custom_status': customStatus,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ updatePresence: $e');
    }
  }

  Future<List<UserStatus>> getUsersPresence(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];
      final response = await _supabase
          .from('user_presence')
          .select('*, profiles!user_id(display_name, full_name, avatar_url)')
          .inFilter('user_id', userIds);
      return (response as List).map((e) => UserStatus.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getUsersPresence: $e');
      return [];
    }
  }

  Future<UserStatus?> getUserPresence(String userId) async {
    try {
      final list = await getUsersPresence([userId]);
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      debugPrint('❌ getUserPresence: $e');
      return null;
    }
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Future<List<ChatConversation>> getConversations({
    int limit = 20,
    int offset = 0,
    String filter = 'all',
  }) async {
    try {
      if (currentUserId.isEmpty) return [];

      final response = await _supabase.rpc(
        'rpc_get_user_conversations',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_filter': filter,
        },
      );

      if (response == null) return [];

      final List data = response as List;

      List<ChatConversation> conversations = data.map((row) {
        final map = Map<String, dynamic>.from(row as Map);

        // ── Last message + 3 lights ──
        ChatMessage? lastMessage;
        final preview = map['last_message_preview'] as String?;
        if (preview != null && preview.isNotEmpty) {
          lastMessage = ChatMessage(
            id: map['last_message_id']?.toString() ?? '',
            conversationId: map['id']?.toString() ?? '',
            senderId: map['last_message_sender_id']?.toString() ?? '',
            senderName: '',
            content: preview,
            createdAt: map['last_message_at'] != null
                ? DateTime.parse(map['last_message_at'].toString())
                : DateTime.now().toUtc(),
            isDelivered: map['last_message_is_delivered'] == true,
            isRead: map['last_message_is_read'] == true,
          );
        }

        // ── Escalade ──
        final isEscalation = map['is_escalation'] == true ||
            map['is_escalated'] == true ||
            map['escalation_status']?.toString() == 'escalated';

        return ChatConversation(
          id: map['id']?.toString() ?? '',
          isGroup: map['is_group'] == true,
          groupName: map['group_name'] as String?,
          groupAvatar: map['group_avatar'] as String?,
          participantIds: (map['participant_ids'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          otherParticipantName:
              map['other_display_name'] as String? ?? 'Utilisateur inconnu',
          otherParticipantAvatar: map['other_avatar_url'] as String?,
          lastMessage: lastMessage,
          unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
          updatedAt: map['updated_at'] != null
              ? DateTime.parse(map['updated_at'].toString())
              : DateTime.now().toUtc(),
          isPinned: map['is_pinned'] == true,
          isEscalation: isEscalation,
          clientName: map['client_display_name'] as String? ??
              map['client_name'] as String?,
          clientAvatar: map['client_avatar_url'] as String? ??
              map['client_avatar'] as String?,
          escalatedByName: map['escalated_by_name'] as String? ??
              map['agent_display_name'] as String? ??
              map['from_agent_name'] as String?,
          agentAvatar: map['agent_avatar_url'] as String? ??
              map['escalated_by_avatar'] as String? ??
              map['agent_avatar'] as String?,
        );
      }).toList();

      // ── Correction profils (sans perdre l'escalade) ──
      final otherUserIds = <String>{};
      for (final conv in conversations) {
        if (!conv.isGroup) {
          final otherId = conv.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          if (otherId.isNotEmpty) otherUserIds.add(otherId);
        }
      }

      if (otherUserIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase
              .from('profiles')
              .select('id, display_name, full_name, avatar_url')
              .inFilter('id', otherUserIds.toList());

          final profilesMap = {
            for (var p in (profilesResponse as List)) p['id'].toString(): p
          };

          conversations = conversations.map((conv) {
            if (!conv.isGroup) {
              final otherId = conv.participantIds.firstWhere(
                (id) => id != currentUserId,
                orElse: () => '',
              );
              final correctProfile = profilesMap[otherId];

              if (correctProfile != null) {
                return ChatConversation(
                  id: conv.id,
                  isGroup: conv.isGroup,
                  groupName: conv.groupName,
                  groupAvatar: conv.groupAvatar,
                  participantIds: conv.participantIds,
                  otherParticipantName: _resolveDisplayName(correctProfile),
                  otherParticipantAvatar:
                      correctProfile['avatar_url'] as String?,
                  lastMessage: conv.lastMessage,
                  unreadCount: conv.unreadCount,
                  updatedAt: conv.updatedAt,
                  isPinned: conv.isPinned,
                  // ✅ conserver escalade
                  isEscalation: conv.isEscalation,
                  clientName: conv.clientName,
                  clientAvatar: conv.clientAvatar,
                  escalatedByName: conv.escalatedByName,
                  agentAvatar: conv.agentAvatar,
                );
              }
            }
            return conv;
          }).toList();
        } catch (e) {
          debugPrint('❌ Erreur correction profils: $e');
        }
      }

      return conversations;
    } catch (e, st) {
      debugPrint('❌ getConversations: $e\n$st');
      return [];
    }
  }

  Future<int> getTotalUnreadCount() async {
    try {
      final result = await _supabase.rpc('rpc_get_total_unread');
      return (result as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('❌ getTotalUnreadCount: $e');
      return 0;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _supabase.rpc(
        'rpc_mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('❌ markConversationAsRead: $e');
      rethrow;
    }
  }

  Future<ChatConversation?> getConversation(String conversationId) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return null;

      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              profiles!user_id (
                display_name,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('id', conversationId)
          .maybeSingle();

      if (response == null) return null;

      final participants = response['conversation_participants'] as List? ?? [];
      final participantIds =
          participants.map((p) => p['user_id'].toString()).toList();

      String? otherName;
      String? otherAvatar;

      if (!(response['is_group'] ?? false) && participants.isNotEmpty) {
        final other = participants.firstWhere(
          (p) => p['user_id'] != uid,
          orElse: () => participants.first,
        );
        final profile = other['profiles'] as Map<String, dynamic>?;
        otherName = _resolveDisplayName(profile);
        otherAvatar = profile?['avatar_url'] as String?;
      }

      final isEscalation = response['is_escalated'] == true ||
          response['is_escalation'] == true ||
          response['escalation_status']?.toString() == 'escalated';

      return ChatConversation(
        id: response['id'].toString(),
        isGroup: response['is_group'] ?? false,
        groupName: response['group_name'],
        groupAvatar: response['group_avatar'],
        participantIds: participantIds,
        otherParticipantName: otherName,
        otherParticipantAvatar: otherAvatar,
        unreadCount: 0,
        updatedAt: DateTime.parse(response['updated_at'].toString()),
        isPinned: response['is_pinned'] ?? false,
        isEscalation: isEscalation,
        clientName: response['client_display_name'] as String? ??
            response['client_name'] as String?,
        clientAvatar: response['client_avatar_url'] as String? ??
            response['client_avatar'] as String?,
        escalatedByName: response['escalated_by_name'] as String? ??
            response['from_agent_name'] as String?,
        agentAvatar: response['agent_avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('❌ getConversation: $e');
      return null;
    }
  }

  // ============================================================
  // CRÉATION DE CONVERSATIONS
  // ============================================================

  Future<ChatConversation> createDirectConversation(String otherUserId) async {
    if (currentUserId.isEmpty) throw Exception('Not logged in');
    if (otherUserId.isEmpty || otherUserId == currentUserId) {
      throw Exception('Cible invalide');
    }

    final convId = await _supabase.rpc(
      'create_direct_conversation',
      params: {'p_other_user_id': otherUserId},
    );

    final id = convId?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Impossible de créer la conversation');
    }

    return (await getConversation(id)) ??
        ChatConversation(
          id: id,
          isGroup: false,
          participantIds: [currentUserId, otherUserId],
          updatedAt: DateTime.now().toUtc(),
        );
  }

  Future<ChatConversation> createConversation({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupAvatar,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    final conversationId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.from('conversations').insert({
      'id': conversationId,
      'is_group': isGroup,
      'group_name': groupName,
      'group_avatar': groupAvatar,
      'created_at': now,
      'updated_at': now,
    });

    final allParticipants = {...participantIds, uid};

    await _supabase.from('conversation_participants').insert({
      'conversation_id': conversationId,
      'user_id': uid,
      'role': 'admin',
      'last_read_at': now,
    });

    return ChatConversation(
      id: conversationId,
      isGroup: isGroup,
      groupName: groupName,
      groupAvatar: groupAvatar,
      participantIds: allParticipants.toList(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> togglePinned(String conversationId, bool isPinned) async {
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_pinned': isPinned})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('❌ togglePinned: $e');
    }
  }

  Future<void> toggleMute(String conversationId, bool isMuted) async {
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_muted': isMuted})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('❌ toggleMute: $e');
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_archived': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('❌ archiveConversation: $e');
    }
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await _assertParticipant(conversationId);

      final response = await _supabase
          .from('messages')
          .select('''
            *,
            profiles!sender_id (
              display_name,
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        final profile = map['profiles'] as Map<String, dynamic>?;
        map['sender_name'] = _resolveDisplayName(profile);
        map['sender_avatar'] = profile?['avatar_url'];
        return ChatMessage.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('❌ getMessages: $e');
      return [];
    }
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? mediaSize,
    String? replyToId,
    bool isEphemeral = false,
    int? ephemeralDuration,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    await _assertParticipant(conversationId);

    final now = DateTime.now().toUtc();
    final deleteAt = isEphemeral && ephemeralDuration != null
        ? now.add(Duration(seconds: ephemeralDuration))
        : null;

    final response = await _supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': uid,
          'content': content,
          'created_at': now.toIso8601String(),
          'media_url': mediaUrl,
          'media_type': mediaType,
          'media_name': mediaName,
          'media_size': mediaSize,
          'reply_to_id': replyToId,
          'is_ephemeral': isEphemeral,
          'ephemeral_duration': ephemeralDuration,
          'delete_at': deleteAt?.toIso8601String(),
        })
        .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
        .single();

    final profile = response['profiles'] as Map<String, dynamic>?;
    response['sender_name'] = _resolveDisplayName(profile);
    response['sender_avatar'] = profile?['avatar_url'];

    return ChatMessage.fromJson(response);
  }

  Future<void> updateMessage(String messageId, String newContent) async {
    if (currentUserId.isEmpty) throw Exception('Not logged in');
    try {
      await _supabase.from('messages').update({
        'content': newContent,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', currentUserId);
    } catch (e) {
      debugPrint('❌ updateMessage: $e');
      rethrow;
    }
  }

  Future<void> toggleReaction(String messageId, String reaction) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final existing = await _supabase
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', uid);
    } else {
      await _supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': uid,
        'reaction': reaction,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    final controller = StreamController<List<ChatMessage>>();
    final channel = _supabase.channel('messages:$conversationId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            try {
              final raw = payload.newRecord;
              if (raw != null && raw.isNotEmpty) {
                final map = Map<String, dynamic>.from(raw);

                if (map['sender_id'] != null) {
                  try {
                    final p = await _supabase
                        .from('profiles')
                        .select('display_name, full_name, avatar_url')
                        .eq('id', map['sender_id'])
                        .maybeSingle();
                    map['sender_name'] = _resolveDisplayName(p);
                    map['sender_avatar'] = p?['avatar_url'];
                  } catch (_) {
                    map['sender_name'] ??= 'Utilisateur';
                  }
                }

                final msg = ChatMessage.fromJson(map);
                if (!controller.isClosed) {
                  controller.add([msg]);
                }
                return;
              }
            } catch (e) {
              debugPrint('⚠️ payload parse error: $e');
            }

            final messages = await getMessages(conversationId);
            if (!controller.isClosed) {
              controller.add(messages);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ============================================================
  // ALIAS + GROUPES + PRESENCE + DELETE + UPLOAD
  // ============================================================

  Future<void> markAsRead(String conversationId) {
    return markConversationAsRead(conversationId);
  }

  Future<List<GroupMember>> getGroupMembers(String conversationId) async {
    try {
      final response = await _supabase
          .from('conversation_participants')
          .select('''
            user_id,
            role,
            profiles!user_id (
              display_name,
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId);

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final profile = map['profiles'] as Map<String, dynamic>?;

        return GroupMember(
          userId: map['user_id']?.toString() ?? '',
          displayName: profile?['display_name']?.toString() ??
              profile?['full_name']?.toString() ??
              'Utilisateur',
          avatarUrl: profile?['avatar_url']?.toString(),
          role: map['role']?.toString() ?? 'member',
          isOnline: false,
          joinedAt: DateTime.now().toUtc(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ getGroupMembers: $e');
      return [];
    }
  }

  Stream<List<UserStatus>> subscribeToPresence(List<String> userIds) {
    final controller = StreamController<List<UserStatus>>();

    getUsersPresence(userIds).then((list) {
      if (!controller.isClosed) controller.add(list);
    });

    final channel = _supabase.channel('presence-${userIds.join('-')}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          callback: (_) async {
            final list = await getUsersPresence(userIds);
            if (!controller.isClosed) controller.add(list);
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  Future<void> deleteMessage(String messageId) async {
    if (currentUserId.isEmpty) throw Exception('Not logged in');
    try {
      await _supabase.from('messages').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', currentUserId);
    } catch (e) {
      debugPrint('❌ deleteMessage: $e');
      rethrow;
    }
  }

  Future<String?> uploadFileWithUniqueName(
    String bucket,
    String folder,
    Uint8List data,
    String extension,
  ) async {
    try {
      final uniqueName = '${const Uuid().v4()}.$extension';
      final path = '$folder/$uniqueName';
      await _supabase.storage.from(bucket).uploadBinary(path, data);
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ uploadFileWithUniqueName: $e');
      return null;
    }
  }

  Future<ChatMessage> sendAudioMessage({
    required String conversationId,
    required Uint8List audioData,
    required int duration,
    String? fileName,
    bool isEphemeral = false,
    int? ephemeralDuration,
    String? replyToId,
  }) async {
    final extension = fileName?.split('.').last ?? 'm4a';
    final uniqueName = '${const Uuid().v4()}.$extension';
    final path = 'messages/$conversationId/$uniqueName';

    await _supabase.storage.from('audio_uploads').uploadBinary(path, audioData);
    final audioUrl = _supabase.storage.from('audio_uploads').getPublicUrl(path);

    return sendMessage(
      conversationId: conversationId,
      content: '🎤 Message audio (${duration}s)',
      mediaUrl: audioUrl,
      mediaType: 'audio',
      isEphemeral: isEphemeral,
      ephemeralDuration: ephemeralDuration,
      replyToId: replyToId,
    );
  }
}
