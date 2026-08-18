import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat/group_info.dart';
import '../../models/chat/chat_conversation.dart';
import '../../models/chat/chat_participant.dart';

/// Service pour la gestion avancée des groupes.
class GroupService {
  final SupabaseClient _supabase;
  final String _currentUserId;

  GroupService(this._supabase)
      : _currentUserId = _supabase.auth.currentUser?.id ?? '';

  // ============================================================
  // CRÉATION DE GROUPE
  // ============================================================

  Future<ChatConversation> createGroup({
    required String name,
    String? description,
    String? avatarUrl,
    required List<String> memberIds,
    bool isPublic = false,
  }) async {
    if (_currentUserId.isEmpty) throw Exception('Non connecté');

    final allMemberIds = {...memberIds, _currentUserId}.toList();
    final conversationId = const Uuid().v4();

    await _supabase.from('conversations').insert({
      'id': conversationId,
      'is_group': true,
      'group_name': name,
      'group_avatar': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
      'is_pinned': false,
    });

    for (var uid in allMemberIds) {
      await _supabase.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': uid,
        'role': uid == _currentUserId ? 'admin' : 'member',
        'last_read_at': DateTime.now().toIso8601String(),
      });
    }

    await _supabase.from('group_info').upsert({
      'group_id': conversationId,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'is_public': isPublic,
      'invite_code': _generateInviteCode(),
      'created_at': DateTime.now().toIso8601String(),
    });

    return await getGroupInfo(conversationId);
  }

  // ============================================================
  // LECTURE DES INFORMATIONS DU GROUPE (CORRIGÉ)
  // ============================================================

  Future<ChatConversation> getGroupInfo(String groupId) async {
    try {
      final convData = await _supabase
          .from('conversations')
          .select('*')
          .eq('id', groupId)
          .single();

      final participantsData = await _supabase
          .from('conversation_participants')
          .select('''
            user_id,
            role,
            last_read_at,
            profiles!user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', groupId);

      final members = <GroupMember>[];
      final adminIds = <String>[];

      for (var p in participantsData as List) {
        final profile = p['profiles'] as Map<String, dynamic>?;
        final userId = p['user_id'] as String;
        final role = p['role'] as String? ?? 'member';
        if (role == 'admin') adminIds.add(userId);

        final presence = await _supabase
            .from('user_presence')
            .select('status')
            .eq('user_id', userId)
            .maybeSingle();
        final isOnline = presence != null && presence['status'] == 'online';

        members.add(GroupMember(
          userId: userId,
          displayName: profile?['full_name'] ?? profile?['username'] ?? 'Utilisateur',
          avatarUrl: profile?['avatar_url'],
          role: role,
          isOnline: isOnline,
          joinedAt: DateTime.parse(p['last_read_at'] ?? DateTime.now().toIso8601String()),
        ));
      }

      final groupInfoData = await _supabase
          .from('group_info')
          .select('*')
          .eq('group_id', groupId)
          .maybeSingle();

      // ✅ LIGNE 138 CORRIGÉE – évite les ? imbriqués dans le ternaire
      bool isGroup = convData['is_group'] == true;
      String displayName = '';

      if (isGroup) {
        displayName = convData['group_name'] as String? ?? 'Groupe';
        if (groupInfoData != null && groupInfoData['name'] != null) {
          displayName = groupInfoData['name'] as String;
        }
      }

      return ChatConversation(
        id: groupId,
        isGroup: true,
        groupName: displayName,
        groupAvatar: convData['group_avatar'] ?? groupInfoData?['avatar_url'],
        participantIds: members.map((m) => m.userId).toList(),
        otherParticipantName: null,
        otherParticipantAvatar: null,
        lastMessage: null,
        unreadCount: 0,
        updatedAt: DateTime.parse(convData['updated_at']),
        isPinned: convData['is_pinned'] ?? false,
      );
    } catch (e) {
      debugPrint('❌ getGroupInfo: $e');
      rethrow;
    }
  }

  // ============================================================
  // GESTION DES MEMBRES
  // ============================================================

  Future<void> addMember(String groupId, String userId) async {
    await _supabase.from('conversation_participants').insert({
      'conversation_id': groupId,
      'user_id': userId,
      'role': 'member',
      'last_read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _supabase
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> promoteToAdmin(String groupId, String userId) async {
    await _supabase
        .from('conversation_participants')
        .update({'role': 'admin'})
        .eq('conversation_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> demoteFromAdmin(String groupId, String userId) async {
    await _supabase
        .from('conversation_participants')
        .update({'role': 'member'})
        .eq('conversation_id', groupId)
        .eq('user_id', userId);
  }

  // ============================================================
  // PARAMÈTRES DU GROUPE
  // ============================================================

  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isPublic != null) updates['is_public'] = isPublic;

    if (updates.isNotEmpty) {
      await _supabase
          .from('group_info')
          .update(updates)
          .eq('group_id', groupId);
    }

    if (name != null) {
      await _supabase
          .from('conversations')
          .update({'group_name': name})
          .eq('id', groupId);
    }
  }

  // ============================================================
  // CODE D'INVITATION
  // ============================================================

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random % chars.length)),
    );
  }

  Future<String> regenerateInviteCode(String groupId) async {
    final newCode = _generateInviteCode();
    await _supabase
        .from('group_info')
        .update({'invite_code': newCode})
        .eq('group_id', groupId);
    return newCode;
  }

  Future<void> joinGroupByInviteCode(String inviteCode) async {
    final groupInfo = await _supabase
        .from('group_info')
        .select('group_id')
        .eq('invite_code', inviteCode)
        .maybeSingle();

    if (groupInfo == null) {
      throw Exception('Code d\'invitation invalide');
    }

    final groupId = groupInfo['group_id'] as String;
    await addMember(groupId, _currentUserId);
  }

  // ============================================================
  // QUITTER / SUPPRIMER UN GROUPE
  // ============================================================

  Future<void> leaveGroup(String groupId) async {
    final participant = await _supabase
        .from('conversation_participants')
        .select('role')
        .eq('conversation_id', groupId)
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (participant != null && participant['role'] == 'admin') {
      throw Exception('Les admins doivent nommer un remplaçant avant de quitter');
    }

    await removeMember(groupId, _currentUserId);
  }

  Future<void> deleteGroup(String groupId) async {
    final participant = await _supabase
        .from('conversation_participants')
        .select('role')
        .eq('conversation_id', groupId)
        .eq('user_id', _currentUserId)
        .single();

    if (participant['role'] != 'admin') {
      throw Exception('Seul un admin peut supprimer le groupe');
    }

    await _supabase.from('conversations').delete().eq('id', groupId);
    await _supabase.from('group_info').delete().eq('group_id', groupId);
  }

  // ============================================================
  // LISTE DES GROUPES DE L'UTILISATEUR
  // ============================================================

  Future<List<String>> getUserGroupIds() async {
    final response = await _supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', _currentUserId);

    final List<dynamic> data = response as List;
    final ids = data.map((e) => e['conversation_id'] as String).toList();

    final List<String> groupIds = [];
    for (var id in ids) {
      final conv = await _supabase
          .from('conversations')
          .select('is_group')
          .eq('id', id)
          .maybeSingle();
      if (conv != null && conv['is_group'] == true) {
        groupIds.add(id);
      }
    }
    return groupIds;
  }

  Future<List<ChatConversation>> getUserGroups() async {
    final ids = await getUserGroupIds();
    final groups = <ChatConversation>[];
    for (var id in ids) {
      try {
        final group = await getGroupInfo(id);
        groups.add(group);
      } catch (e) {
        debugPrint('Erreur lors du chargement du groupe $id: $e');
      }
    }
    return groups;
  }
}
