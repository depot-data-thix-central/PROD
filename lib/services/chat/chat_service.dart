// lib/services/chat/chat_service.dart
//
// Service principal de messagerie : conversations, messages, présence, médias.
// Les notifications de message sont créées par le trigger SQL
// trg_notify_new_message (+ webhook push). Aucune insertion côté Dart.
//
// ✅ P0/P1 Enterprise : edit, deleteForAll, forward, pin, star, search,
//    viewOnce, mentions, reminders, threads, transcription, annotations
// ✅ P2 : typing broadcast, getUserRole, markMessagesDelivered

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/models/chat/user_status.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kDefaultLimit = 20;
const int _kMaxLimit = 100;
const int _kMaxMessageLength = 10000;
const int _kMaxPreviewLength = 120;
const int _kMaxProfileNameLength = 100;
const int _kMaxInFilterSize = 100;
const int _kMaxFileBytes = 50 * 1024 * 1024; // 50MB
const int _kProfileCacheTtlMinutes = 5;
const int _kMaxCacheSize = 500;
const int _kEditWindowMinutes = 15;
const int _kDeleteForAllWindowMinutes = 15;
const int _kMaxForwardRecipients = 5;
const int _kMaxPinnedMessages = 3;
const Duration _kPresenceHeartbeat = Duration(seconds: 45);
const Duration _kDbTimeout = Duration(seconds: 15);
const Duration _kStorageTimeout = Duration(seconds: 60);
const Duration _kMessageSyncInterval = Duration(seconds: 20);
const Duration _kPresenceDebounce = Duration(seconds: 1);

const Set<String> _kAllowedBuckets = {
  'audio_uploads',
  'chat-media',
  'images',
  'videos',
  'documents',
  'avatars',
};

const Set<String> _kAllowedMediaTypes = {
  'image',
  'video',
  'audio',
  'document',
  'location',
  'contact',
  'call_audio',
  'call_video',
  'sticker',
  'gif',
};

// ============================================================================
// VALIDATORS
// ============================================================================
class _ChatValidators {
  _ChatValidators._();

  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  static String sanitizeContent(String? input, {int maxLength = _kMaxMessageLength}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String sanitizeName(String? input, {int maxLength = _kMaxProfileNameLength}) {
    return sanitizeContent(input, maxLength: maxLength);
  }

  static bool isValidMediaType(String? type) {
    if (type == null || type.isEmpty) return false;
    return _kAllowedMediaTypes.contains(type.toLowerCase());
  }

  static bool isValidBucket(String? bucket) {
    if (bucket == null || bucket.isEmpty) return false;
    return _kAllowedBuckets.contains(bucket);
  }

  static bool isValidExtension(String? ext) {
    if (ext == null || ext.isEmpty) return false;
    final clean = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean.isNotEmpty && clean.length <= 10;
  }

  static String truncatePreview(String? text, {int maxLength = _kMaxPreviewLength}) {
    if (text == null) return '';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxLength) return trimmed;
    final truncated = trimmed.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    return (lastSpace > maxLength ~/ 2 ? truncated.substring(0, lastSpace) : truncated) + '…';
  }

  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROFILE CACHE (TTL)
// ============================================================================
class _ProfileCacheEntry {
  final Map<String, dynamic> profile;
  final DateTime expiresAt;

  _ProfileCacheEntry(this.profile, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _ProfileCache {
  final Map<String, _ProfileCacheEntry> _cache = {};

  Map<String, dynamic>? get(String userId) {
    final entry = _cache[userId];
    if (entry == null || entry.isExpired) {
      _cache.remove(userId);
      return null;
    }
    return entry.profile;
  }

  void put(String userId, Map<String, dynamic> profile) {
    if (_cache.length >= _kMaxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[userId] = _ProfileCacheEntry(
      profile,
      DateTime.now().add(const Duration(minutes: _kProfileCacheTtlMinutes)),
    );
  }

  void invalidate(String userId) => _cache.remove(userId);
  void clear() => _cache.clear();
}

// ============================================================================
// CHAT SERVICE — P0/P1/P2 Enterprise
// ============================================================================
class ChatService {
  final SupabaseClient _supabase;
  Timer? _presenceHeartbeat;
  final _ProfileCache _profileCache = _ProfileCache();
  bool _isDisposed = false;
  
  // ✅ P2: Channels pour typing broadcast
  final Map<String, RealtimeChannel> _typingChannels = <String, RealtimeChannel>{};

  ChatService(this._supabase) {
    debugPrint('[ChatService] 🚀 Initialized');
  }

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUserId.isNotEmpty;

  // ============================================================
  // HELPERS
  // ============================================================

  static String _resolveDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Utilisateur inconnu';
    final displayName = _ChatValidators.sanitizeName(profile['display_name'] as String?);
    if (displayName.isNotEmpty) return displayName;
    final fullName = _ChatValidators.sanitizeName(profile['full_name'] as String?);
    if (fullName.isNotEmpty) return fullName;
    return 'Utilisateur inconnu';
  }

  Future<void> _assertParticipant(String conversationId) async {
    if (!_ChatValidators.isValidUuid(conversationId)) {
      throw ArgumentError('conversationId invalide');
    }
    if (currentUserId.isEmpty || !_ChatValidators.isValidUuid(currentUserId)) {
      throw StateError('Non authentifié');
    }

    final row = await _supabase
        .from('conversation_participants')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .eq('user_id', currentUserId)
        .maybeSingle()
        .timeout(_kDbTimeout);

    if (row == null) {
      throw StateError('Accès refusé à cette conversation');
    }
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    if (!_ChatValidators.isValidUuid(userId)) return null;

    final cached = _profileCache.get(userId);
    if (cached != null) return cached;

    try {
      final row = await _supabase
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (row != null) {
        final map = Map<String, dynamic>.from(row);
        _profileCache.put(userId, map);
        return map;
      }
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getProfile ${_ChatValidators.obfuscate(userId)}: $e');
    }
    return null;
  }

  Future<void> _warmProfiles(String conversationId) async {
    try {
      final rows = await _supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .timeout(_kDbTimeout);

      final ids = (rows as List)
          .map((r) => (r['user_id'] ?? '').toString())
          .where((id) =>
              _ChatValidators.isValidUuid(id) && _profileCache.get(id) == null)
          .toList();
      if (ids.isEmpty) return;

      for (final chunk in _chunkIds(ids)) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, display_name, full_name, avatar_url')
            .inFilter('id', chunk)
            .timeout(_kDbTimeout);
        for (final p in (profiles as List)) {
          final map = Map<String, dynamic>.from(p as Map);
          _profileCache.put(map['id'].toString(), map);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] ⚠️ warmProfiles: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  List<List<String>> _chunkIds(List<String> ids) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += _kMaxInFilterSize) {
      chunks.add(ids.skip(i).take(_kMaxInFilterSize).toList());
    }
    return chunks;
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    final profile = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;
    map['sender_name'] = _resolveDisplayName(profile);
    map['sender_avatar'] = profile?['avatar_url'];
    map['content'] = _ChatValidators.sanitizeContent(map['content'] as String?);
    return ChatMessage.fromJson(map);
  }

  // ============================================================
  // PRÉSENCE
  // ============================================================

  Future<void> startPresenceHeartbeat() async {
    if (_isDisposed) return;

    _presenceHeartbeat?.cancel();
    await updatePresence('online');

    _presenceHeartbeat = Timer.periodic(_kPresenceHeartbeat, (_) async {
      if (!_isDisposed) await updatePresence('online');
    });
    debugPrint('[ChatService] ⏱️ Presence heartbeat started');
  }

  Future<void> stopPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    await updatePresence('offline');
    debugPrint('[ChatService] ⏹️ Presence heartbeat stopped');
  }

  Future<void> updatePresence(String status, {String? customStatus}) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('user_presence').upsert({
        'user_id': uid,
        'status': status,
        'custom_status': customStatus != null
            ? _ChatValidators.sanitizeContent(customStatus, maxLength: 200)
            : null,
        'last_seen_at': now,
        'updated_at': now,
      }).timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ updatePresence: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<List<UserStatus>> getUsersPresence(List<String> userIds) async {
    if (_isDisposed) return [];
    final validIds = userIds.where(_ChatValidators.isValidUuid).toList();
    if (validIds.isEmpty) return [];

    try {
      final allResults = <UserStatus>[];
      for (final chunk in _chunkIds(validIds)) {
        final response = await _supabase
            .from('user_presence')
            .select('*, profiles!user_id(display_name, full_name, avatar_url)')
            .inFilter('user_id', chunk)
            .timeout(_kDbTimeout);
        allResults.addAll(
          (response as List).map((e) => UserStatus.fromJson(e)),
        );
      }
      return allResults;
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getUsersPresence: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  Future<UserStatus?> getUserPresence(String userId) async {
    final list = await getUsersPresence([userId]);
    return list.isNotEmpty ? list.first : null;
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Future<List<ChatConversation>> getConversations({
    int limit = _kDefaultLimit,
    int offset = 0,
    String filter = 'all',
  }) async {
    if (_isDisposed) return [];

    try {
      if (!_ChatValidators.isValidUuid(currentUserId)) return [];

      final safeLimit = limit.clamp(1, _kMaxLimit);
      final safeOffset = offset.clamp(0, 10000);

      final response = await _supabase
          .rpc(
            'rpc_get_user_conversations',
            params: {
              'p_limit': safeLimit,
              'p_offset': safeOffset,
              'p_filter': filter,
            },
          )
          .timeout(_kDbTimeout);

      if (response == null) return [];

      final data = response as List;
      final conversations = data.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return _conversationFromRpcRow(map);
      }).toList();

      final otherUserIds = <String>{};
      for (final conv in conversations) {
        if (!conv.isGroup) {
          final otherId = conv.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          if (_ChatValidators.isValidUuid(otherId)) otherUserIds.add(otherId);
        }
      }

      if (otherUserIds.isNotEmpty) {
        await _enrichConversationsWithProfiles(conversations, otherUserIds.toList());
      }

      return conversations;
    } catch (e) {
      debugPrint('[ChatService] ❌ getConversations: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  ChatConversation _conversationFromRpcRow(Map<String, dynamic> map) {
    ChatMessage? lastMessage;
    final preview = map['last_message_preview'] as String?;
    if (preview != null && preview.isNotEmpty) {
      lastMessage = ChatMessage(
        id: map['last_message_id']?.toString() ?? '',
        conversationId: map['id']?.toString() ?? '',
        senderId: map['last_message_sender_id']?.toString() ?? '',
        senderName: '',
        content: _ChatValidators.sanitizeContent(preview),
        createdAt: map['last_message_at'] != null
            ? DateTime.parse(map['last_message_at'].toString())
            : DateTime.now().toUtc(),
        isDelivered: map['last_message_is_delivered'] == true,
        isRead: map['last_message_is_read'] == true,
      );
    }

    final isEscalation = map['is_escalation'] == true ||
        map['is_escalated'] == true ||
        map['escalation_status']?.toString() == 'escalated';

    return ChatConversation(
      id: map['id']?.toString() ?? '',
      isGroup: map['is_group'] == true,
      groupName: _ChatValidators.sanitizeName(map['group_name'] as String?),
      groupAvatar: map['group_avatar'] as String?,
      participantIds: (map['participant_ids'] as List?)
              ?.map((e) => e.toString())
              .where(_ChatValidators.isValidUuid)
              .toList() ??
          [],
      otherParticipantName:
          _ChatValidators.sanitizeName(map['other_display_name'] as String?) ??
              'Utilisateur inconnu',
      otherParticipantAvatar: map['other_avatar_url'] as String?,
      lastMessage: lastMessage,
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now().toUtc(),
      isPinned: map['is_pinned'] == true,
      pinnedAt: map['pinned_at'] != null
          ? DateTime.tryParse(map['pinned_at'].toString())
          : null,
      isArchived: map['is_archived'] == true,
      isMuted: map['is_muted'] == true,
      muteUntil: map['mute_until'] != null
          ? DateTime.tryParse(map['mute_until'].toString())
          : null,
      isLocked: map['is_locked'] == true,
      draft: map['draft'] as String?,
      isEscalation: isEscalation,
      clientName: _ChatValidators.sanitizeName(map['client_display_name'] as String?),
      clientAvatar: map['client_avatar_url'] as String?,
      escalatedByName: _ChatValidators.sanitizeName(
        map['escalated_by_name'] as String? ??
            map['agent_display_name'] as String? ??
            map['from_agent_name'] as String?,
      ),
      agentAvatar: map['agent_avatar_url'] as String? ??
          map['escalated_by_avatar'] as String? ??
          map['agent_avatar'] as String?,
    );
  }

  Future<void> _enrichConversationsWithProfiles(
    List<ChatConversation> conversations,
    List<String> otherUserIds,
  ) async {
    try {
      final toFetch = <String>[];
      for (final id in otherUserIds) {
        if (_profileCache.get(id) == null) toFetch.add(id);
      }

      for (final chunk in _chunkIds(toFetch)) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, display_name, full_name, avatar_url')
            .inFilter('id', chunk)
            .timeout(_kDbTimeout);

        for (final p in (profilesResponse as List)) {
          final map = Map<String, dynamic>.from(p as Map);
          final id = map['id'].toString();
          _profileCache.put(id, map);
        }
      }

      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        if (!conv.isGroup) {
          final otherId = conv.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          final profile = _profileCache.get(otherId);
          if (profile != null) {
            conversations[i] = conv.copyWith(
              otherParticipantName: _resolveDisplayName(profile),
              otherParticipantAvatar: profile['avatar_url'] as String?,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatService] ⚠️ Enrich profiles: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  // ── Conversation actions (P0/P1) ─────────────────────────────

  Future<int> getTotalUnreadCount() async {
    if (_isDisposed) return 0;
    try {
      final result = await _supabase
          .rpc('rpc_get_total_unread')
          .timeout(_kDbTimeout);
      return (result as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getTotalUnreadCount: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return 0;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) {
      throw ArgumentError('conversationId invalide');
    }
    try {
      await _supabase
          .rpc('rpc_mark_conversation_read',
              params: {'p_conversation_id': conversationId})
          .timeout(_kDbTimeout);
      debugPrint('[ChatService] ✓ Marked read: ${_ChatValidators.obfuscate(conversationId)}');
    } catch (e) {
      debugPrint('[ChatService] ❌ markConversationAsRead: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  Future<void> markAsUnread(String conversationId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({'unread_count': 1})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ markAsUnread: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> togglePinned(String conversationId, bool isPinned) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({
            'is_pinned': isPinned,
            'pinned_at': isPinned ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ togglePinned: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> toggleMute(String conversationId, bool isMuted) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_muted': isMuted, 'mute_until': null})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ toggleMute: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> muteConversationWithDuration(String conversationId, Duration? duration) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      final muteUntil = duration != null ? DateTime.now().add(duration) : null;
      await _supabase
          .from('conversation_participants')
          .update({
            'is_muted': duration != null,
            'mute_until': muteUntil?.toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ muteConversationWithDuration: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_archived': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ archiveConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> unarchiveConversation(String conversationId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_archived': false})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ unarchiveConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> toggleLockConversation(String conversationId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      final current = await _supabase
          .from('conversation_participants')
          .select('is_locked')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      final isLocked = current?['is_locked'] == true;
      await _supabase
          .from('conversation_participants')
          .update({'is_locked': !isLocked})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ toggleLockConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> saveDraft(String conversationId, String? draft) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(conversationId)) return;
    try {
      await _supabase
          .from('conversation_participants')
          .update({'draft': draft})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ saveDraft: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<ChatConversation?> getConversation(String conversationId) async {
    if (_isDisposed) return null;
    if (!_ChatValidators.isValidUuid(conversationId)) return null;

    try {
      final uid = currentUserId;
      if (!_ChatValidators.isValidUuid(uid)) return null;

      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              profiles!user_id (display_name, full_name, avatar_url)
            )
          ''')
          .eq('id', conversationId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (response == null) return null;

      final participants = response['conversation_participants'] as List? ?? [];
      final participantIds = participants
          .map((p) => p['user_id'].toString())
          .where(_ChatValidators.isValidUuid)
          .toList();

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
        groupName: _ChatValidators.sanitizeName(response['group_name'] as String?),
        groupAvatar: response['group_avatar'] as String?,
        participantIds: participantIds,
        otherParticipantName: otherName,
        otherParticipantAvatar: otherAvatar,
        unreadCount: 0,
        updatedAt: DateTime.parse(response['updated_at'].toString()),
        isPinned: response['is_pinned'] ?? false,
        isEscalation: isEscalation,
        clientName: _ChatValidators.sanitizeName(response['client_display_name'] as String?),
        clientAvatar: response['client_avatar_url'] as String?,
        escalatedByName: _ChatValidators.sanitizeName(
          response['escalated_by_name'] as String? ??
              response['from_agent_name'] as String?,
        ),
        agentAvatar: response['agent_avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return null;
    }
  }

  // ============================================================
  // CRÉATION DE CONVERSATIONS
  // ============================================================

  Future<ChatConversation> createDirectConversation(String otherUserId) async {
    if (_isDisposed) throw StateError('ChatService disposed');
    if (!_ChatValidators.isValidUuid(currentUserId)) {
      throw StateError('Non authentifié');
    }
    if (!_ChatValidators.isValidUuid(otherUserId)) {
      throw ArgumentError('otherUserId invalide');
    }
    if (otherUserId == currentUserId) {
      throw ArgumentError('Impossible de créer une conversation avec soi-même');
    }

    final convId = await _supabase
        .rpc('create_direct_conversation',
            params: {'p_other_user_id': otherUserId})
        .timeout(_kDbTimeout);

    final id = convId?.toString();
    if (!_ChatValidators.isValidUuid(id)) {
      throw StateError('Impossible de créer la conversation');
    }

    debugPrint('[ChatService] ✓ Created direct conv: ${_ChatValidators.obfuscate(id)}');
    return (await getConversation(id!)) ??
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
    if (_isDisposed) throw StateError('ChatService disposed');
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) {
      throw StateError('Non authentifié');
    }

    final validParticipants =
        participantIds.where(_ChatValidators.isValidUuid).toList();
    if (validParticipants.isEmpty) {
      throw ArgumentError('Aucun participant valide');
    }

    final conversationId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final safeGroupName = isGroup
        ? _ChatValidators.sanitizeName(groupName, maxLength: 80)
        : null;

    await _supabase.from('conversations').insert({
      'id': conversationId,
      'is_group': isGroup,
      'group_name': safeGroupName,
      'group_avatar': groupAvatar,
      'created_at': now,
      'updated_at': now,
    }).timeout(_kDbTimeout);

    final allParticipants = {...validParticipants, uid}.toList();

    await _supabase.from('conversation_participants').insert(
      allParticipants.map((userId) => {
        'conversation_id': conversationId,
        'user_id': userId,
        'role': userId == uid ? 'admin' : 'member',
        'last_read_at': now,
      }).toList(),
    ).timeout(_kDbTimeout);

    debugPrint('[ChatService] ✓ Created conversation: '
        '${_ChatValidators.obfuscate(conversationId)} '
        '(participants=${allParticipants.length})');

    return ChatConversation(
      id: conversationId,
      isGroup: isGroup,
      groupName: safeGroupName,
      groupAvatar: groupAvatar,
      participantIds: allParticipants,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  // ============================================================
  // MESSAGES — CRUD + P0/P1
  // ============================================================

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (_isDisposed) return [];
    if (!_ChatValidators.isValidUuid(conversationId)) return [];

    try {
      await _assertParticipant(conversationId);

      final safeLimit = limit.clamp(1, _kMaxLimit);
      final safeOffset = offset.clamp(0, 10000);

      final response = await _supabase
          .from('messages')
          .select('''
            *,
            profiles!sender_id (display_name, full_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .eq('is_deleted_for_all', false)
          .order('created_at', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1)
          .timeout(_kDbTimeout);

      return (response as List)
          .map((e) => _messageFromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getMessages: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  Future<List<ChatMessage>> _getMessagesSince(
    String conversationId,
    DateTime since,
  ) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('''
            *,
            profiles!sender_id (display_name, full_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .eq('is_deleted_for_all', false)
          .gt('created_at', since.toUtc().toIso8601String())
          .order('created_at', ascending: true)
          .limit(50)
          .timeout(_kDbTimeout);

      return (response as List)
          .map((e) => _messageFromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getMessagesSince: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  /// ✅ P0: Envoyer un message avec tous les nouveaux champs
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
    bool isViewOnce = false,
    List<String> mentionedUserIds = const [],
    bool isForwarded = false,
    String? forwardedFromConversationId,
    String? forwardedFromSenderName,
    String? threadParentId,
    String? annotations,
  }) async {
    if (_isDisposed) throw StateError('ChatService disposed');

    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) {
      throw StateError('Non authentifié');
    }
    if (!_ChatValidators.isValidUuid(conversationId)) {
      throw ArgumentError('conversationId invalide');
    }
    if (mediaType != null && !_ChatValidators.isValidMediaType(mediaType)) {
      throw ArgumentError('mediaType invalide');
    }
    if (replyToId != null && !_ChatValidators.isValidUuid(replyToId)) {
      throw ArgumentError('replyToId invalide');
    }

    await _assertParticipant(conversationId);

    final sanitizedContent = _ChatValidators.sanitizeContent(content);
    if (sanitizedContent.isEmpty && mediaUrl == null) {
      throw ArgumentError('Message vide');
    }

    final now = DateTime.now().toUtc();
    final deleteAt = isEphemeral && ephemeralDuration != null && ephemeralDuration > 0
        ? now.add(Duration(seconds: ephemeralDuration))
        : null;

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': sanitizedContent,
      'created_at': now.toIso8601String(),
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_name': mediaName != null
          ? _ChatValidators.sanitizeContent(mediaName, maxLength: 255)
          : null,
      'media_size': mediaSize,
      'reply_to_id': replyToId,
      'is_ephemeral': isEphemeral,
      'ephemeral_duration': ephemeralDuration,
      'delete_at': deleteAt?.toIso8601String(),
      // ✅ Nouveaux champs P0/P1
      'is_view_once': isViewOnce,
      'mentioned_user_ids': mentionedUserIds.isEmpty ? null : mentionedUserIds,
      'is_forwarded': isForwarded,
      'forwarded_from_conversation_id': forwardedFromConversationId,
      'forwarded_from_sender_name': forwardedFromSenderName,
      'thread_parent_id': threadParentId,
      'annotations': annotations,
    };

    // Nettoyer les nulls pour éviter les erreurs Supabase
    payload.removeWhere((key, value) => value == null);

    final response = await _supabase
        .from('messages')
        .insert(payload)
        .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
        .single()
        .timeout(_kDbTimeout);

    final profile = response['profiles'] as Map<String, dynamic>?;
    response['sender_name'] = _resolveDisplayName(profile);
    response['sender_avatar'] = profile?['avatar_url'];
    response['content'] = sanitizedContent;

    debugPrint('[ChatService] ✓ Message sent '
        '(conv=${_ChatValidators.obfuscate(conversationId)})');

    return ChatMessage.fromJson(response);
  }

  /// ✅ P0: Éditer un message (fenêtre 15 min)
  Future<ChatMessage?> editMessage(String messageId, String newContent) async {
    if (_isDisposed) return null;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) throw StateError('Non authentifié');
    if (!_ChatValidators.isValidUuid(messageId)) throw ArgumentError('messageId invalide');

    final sanitized = _ChatValidators.sanitizeContent(newContent);
    if (sanitized.isEmpty) throw ArgumentError('Contenu vide');

    try {
      // Vérifier la fenêtre d'édition côté serveur via RPC
      final response = await _supabase
          .rpc('rpc_edit_message', params: {
            'p_message_id': messageId,
            'p_user_id': uid,
            'p_new_content': sanitized,
            'p_window_minutes': _kEditWindowMinutes,
          })
          .timeout(_kDbTimeout);

      if (response is Map) {
        debugPrint('[ChatService] ✓ Message edited: ${_ChatValidators.obfuscate(messageId)}');
        return ChatMessage.fromJson(Map<String, dynamic>.from(response));
      }
      // Fallback si RPC n'existe pas encore
      await _supabase.from('messages').update({
        'content': sanitized,
        'is_edited': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', uid).timeout(_kDbTimeout);

      debugPrint('[ChatService] ✓ Message edited (fallback): ${_ChatValidators.obfuscate(messageId)}');
      return null;
    } catch (e) {
      debugPrint('[ChatService] ❌ editMessage: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  /// ✅ P0: Supprimer pour tous (fenêtre 15 min)
  Future<void> deleteMessageForAll(String messageId) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) throw StateError('Non authentifié');
    if (!_ChatValidators.isValidUuid(messageId)) throw ArgumentError('messageId invalide');

    try {
      await _supabase.from('messages').update({
        'is_deleted_for_all': true,
        'is_deleted': true,
        'content': '',
        'media_url': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', uid).timeout(_kDbTimeout);

      debugPrint('[ChatService] ✓ Message deleted for all: ${_ChatValidators.obfuscate(messageId)}');
    } catch (e) {
      debugPrint('[ChatService] ❌ deleteMessageForAll: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  /// Supprimer pour soi uniquement
  Future<void> deleteMessage(String messageId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(currentUserId)) {
      throw StateError('Non authentifié');
    }
    if (!_ChatValidators.isValidUuid(messageId)) {
      throw ArgumentError('messageId invalide');
    }

    try {
      await _supabase.from('messages').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', currentUserId).timeout(_kDbTimeout);
      debugPrint('[ChatService] ✓ Message deleted: ${_ChatValidators.obfuscate(messageId)}');
    } catch (e) {
      debugPrint('[ChatService] ❌ deleteMessage: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  /// ✅ P0: Transférer un message (max 5 destinataires)
  Future<List<ChatMessage>> forwardMessage({
    required String originalMessageId,
    required List<String> targetConversationIds,
  }) async {
    if (_isDisposed) throw StateError('ChatService disposed');
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) throw StateError('Non authentifié');
    if (!_ChatValidators.isValidUuid(originalMessageId)) throw ArgumentError('originalMessageId invalide');
    if (targetConversationIds.isEmpty || targetConversationIds.length > _kMaxForwardRecipients) {
      throw ArgumentError('Forward: 1 à $_kMaxForwardRecipients conversations max');
    }

    // Récupérer le message original
    final originalRows = await _supabase
        .from('messages')
        .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
        .eq('id', originalMessageId)
        .maybeSingle()
        .timeout(_kDbTimeout);

    if (originalRows == null) throw StateError('Message original introuvable');

    final original = ChatMessage.fromJson(Map<String, dynamic>.from(originalRows));
    final forwardedMessages = <ChatMessage>[];

    for (final targetConvId in targetConversationIds) {
      if (!_ChatValidators.isValidUuid(targetConvId)) continue;

      try {
        final msg = await sendMessage(
          conversationId: targetConvId,
          content: original.content,
          mediaUrl: original.mediaUrl,
          mediaType: original.mediaType,
          mediaName: original.mediaName,
          mediaSize: original.mediaSize,
          isForwarded: true,
          forwardedFromConversationId: original.conversationId,
          forwardedFromSenderName: original.senderName,
        );
        forwardedMessages.add(msg);
      } catch (e) {
        debugPrint('[ChatService] ⚠️ Forward to ${_ChatValidators.obfuscate(targetConvId)} failed: $e');
      }
    }

    debugPrint('[ChatService] ✓ Forwarded ${forwardedMessages.length}/${targetConversationIds.length}');
    return forwardedMessages;
  }

  /// ✅ P0: Épingler un message (max 3 par conversation)
  Future<void> pinMessage(String messageId, String conversationId) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      // Vérifier le nombre de messages épinglés
      final pinnedCount = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_pinned', true)
          .timeout(_kDbTimeout);

      if ((pinnedCount as List).length >= _kMaxPinnedMessages) {
        throw StateError('Maximum $_kMaxPinnedMessages messages épinglés atteint');
      }

      await _supabase
          .from('messages')
          .update({'is_pinned': true})
          .eq('id', messageId)
          .timeout(_kDbTimeout);

      debugPrint('[ChatService] ✓ Message pinned: ${_ChatValidators.obfuscate(messageId)}');
    } catch (e) {
      debugPrint('[ChatService] ❌ pinMessage: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  /// ✅ P0: Désépingler un message
  Future<void> unpinMessage(String messageId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      await _supabase
          .from('messages')
          .update({'is_pinned': false})
          .eq('id', messageId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ unpinMessage: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// ✅ P0: Marquer/unmarquer comme favori ⭐
  Future<void> toggleStarMessage(String messageId) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      final existing = await _supabase
          .from('starred_messages')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (existing != null) {
        await _supabase
            .from('starred_messages')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', uid)
            .timeout(_kDbTimeout);
        debugPrint('[ChatService] ✓ Message unstarred: ${_ChatValidators.obfuscate(messageId)}');
      } else {
        await _supabase.from('starred_messages').insert({
          'message_id': messageId,
          'user_id': uid,
          'starred_at': DateTime.now().toUtc().toIso8601String(),
        }).timeout(_kDbTimeout);
        debugPrint('[ChatService] ✓ Message starred: ${_ChatValidators.obfuscate(messageId)}');
      }
    } catch (e) {
      debugPrint('[ChatService] ⚠️ toggleStarMessage: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// ✅ P0: Récupérer les messages favoris
  Future<List<ChatMessage>> getStarredMessages({int limit = 50}) async {
    if (_isDisposed) return [];
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) return [];

    try {
      final response = await _supabase
          .from('starred_messages')
          .select('messages(*, profiles!sender_id(display_name, full_name, avatar_url))')
          .eq('user_id', uid)
          .order('starred_at', ascending: false)
          .limit(limit)
          .timeout(_kDbTimeout);

      return (response as List)
          .where((e) => e['messages'] != null)
          .map((e) => _messageFromRow(Map<String, dynamic>.from(e['messages'] as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getStarredMessages: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  /// ✅ P0: Récupérer les messages épinglés d'une conversation
  Future<List<ChatMessage>> getPinnedMessages(String conversationId) async {
    if (_isDisposed) return [];
    if (!_ChatValidators.isValidUuid(conversationId)) return [];

    try {
      final response = await _supabase
          .from('messages')
          .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
          .eq('conversation_id', conversationId)
          .eq('is_pinned', true)
          .order('created_at', ascending: false)
          .limit(_kMaxPinnedMessages)
          .timeout(_kDbTimeout);

      return (response as List)
          .map((e) => _messageFromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getPinnedMessages: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  /// ✅ P0: Recherche in-chat
  Future<List<ChatMessage>> searchInConversation(
    String conversationId,
    String query, {
    int limit = 30,
  }) async {
    if (_isDisposed) return [];
    if (!_ChatValidators.isValidUuid(conversationId)) return [];
    final sanitizedQuery = _ChatValidators.sanitizeContent(query, maxLength: 200);
    if (sanitizedQuery.isEmpty) return [];

    try {
      final response = await _supabase
          .from('messages')
          .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
          .eq('conversation_id', conversationId)
          .eq('is_deleted_for_all', false)
          .ilike('content', '%$sanitizedQuery%')
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(_kDbTimeout);

      return (response as List)
          .map((e) => _messageFromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ searchInConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  /// ✅ P1: Marquer un message View Once comme vu
  Future<void> markViewOnceAsSeen(String messageId) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      await _supabase
          .from('messages')
          .update({'has_been_viewed': true})
          .eq('id', messageId)
          .eq('has_been_viewed', false)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ markViewOnceAsSeen: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// ✅ P1: Ajouter un rappel sur un message
  Future<void> setMessageReminder(String messageId, DateTime reminderAt) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      await _supabase
          .from('messages')
          .update({'reminder_at': reminderAt.toUtc().toIso8601String()})
          .eq('id', messageId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ setMessageReminder: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// ✅ P1: Sauvegarder la transcription d'un audio
  Future<void> saveTranscription(String messageId, String transcription) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      await _supabase
          .from('messages')
          .update({'transcription': _ChatValidators.sanitizeContent(transcription, maxLength: 5000)})
          .eq('id', messageId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ saveTranscription: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// ✅ P1: Sauvegarder des annotations sur une image
  Future<void> saveAnnotations(String messageId, String annotationsJson) async {
    if (_isDisposed) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;

    try {
      await _supabase
          .from('messages')
          .update({'annotations': annotationsJson})
          .eq('id', messageId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ saveAnnotations: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<void> toggleReaction(String messageId, String reaction) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid)) return;
    if (!_ChatValidators.isValidUuid(messageId)) return;
    if (reaction.isEmpty || reaction.length > 10) return;

    try {
      final existing = await _supabase
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (existing != null) {
        await _supabase
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', uid)
            .timeout(_kDbTimeout);
      } else {
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': uid,
          'reaction': reaction,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).timeout(_kDbTimeout);
      }
    } catch (e) {
      debugPrint('[ChatService] ⚠️ toggleReaction: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    final controller = StreamController<List<ChatMessage>>();

    if (!_ChatValidators.isValidUuid(conversationId)) {
      scheduleMicrotask(() => controller.close());
      return controller.stream;
    }

    unawaited(_warmProfiles(conversationId));

    var lastSeen = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
    var syncing = false;
    Timer? syncTimer;

    void track(ChatMessage m) {
      if (m.createdAt.isAfter(lastSeen)) lastSeen = m.createdAt;
    }

    Future<void> catchUp() async {
      if (_isDisposed || controller.isClosed || syncing) return;
      syncing = true;
      try {
        final fresh = await _getMessagesSince(conversationId, lastSeen);
        if (fresh.isNotEmpty && !controller.isClosed) {
          for (final m in fresh) {
            track(m);
          }
          controller.add(fresh);
        }
      } finally {
        syncing = false;
      }
    }

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
            if (_isDisposed || controller.isClosed) return;

            try {
              final raw = payload.newRecord;
              if (raw != null && raw.isNotEmpty) {
                final map = Map<String, dynamic>.from(raw);
                final senderId = map['sender_id']?.toString();

                if (senderId != null && _ChatValidators.isValidUuid(senderId)) {
                  final profile = _profileCache.get(senderId) ??
                      await _getProfile(senderId)
                          .timeout(const Duration(seconds: 2), onTimeout: () => null);
                  map['sender_name'] = _resolveDisplayName(profile);
                  map['sender_avatar'] = profile?['avatar_url'];
                } else {
                  map['sender_name'] ??= 'Utilisateur';
                }

                map['content'] = _ChatValidators.sanitizeContent(map['content'] as String?);

                if (!controller.isClosed) {
                  final msg = ChatMessage.fromJson(map);
                  track(msg);
                  controller.add([msg]);
                }
                return;
              }
            } catch (e) {
              debugPrint('[ChatService] ⚠️ Realtime payload parse: '
                  '${kDebugMode ? e : "error"}');
            }

            if (!controller.isClosed) {
              final messages = await getMessages(conversationId);
              if (!controller.isClosed) controller.add(messages);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(catchUp());
          }
        });

    syncTimer = Timer.periodic(_kMessageSyncInterval, (_) => unawaited(catchUp()));

    controller.onCancel = () {
      syncTimer?.cancel();
      try {
        _supabase.removeChannel(channel);
      } catch (_) {}
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  // ============================================================
  // GROUPES + PRESENCE + UPLOAD
  // ============================================================

  Future<void> markAsRead(String conversationId) =>
      markConversationAsRead(conversationId);

  Future<List<GroupMember>> getGroupMembers(String conversationId) async {
    if (_isDisposed) return [];
    if (!_ChatValidators.isValidUuid(conversationId)) return [];

    try {
      final response = await _supabase
          .from('conversation_participants')
          .select('''
            user_id,
            role,
            profiles!user_id (display_name, full_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .timeout(_kDbTimeout);

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final profile = map['profiles'] as Map<String, dynamic>?;
        final userId = map['user_id']?.toString() ?? '';

        return GroupMember(
          userId: userId,
          displayName: _resolveDisplayName(profile),
          avatarUrl: profile?['avatar_url']?.toString(),
          role: GroupRoleX.fromString(map['role']?.toString()),
          isOnline: false,
          joinedAt: DateTime.now().toUtc(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getGroupMembers: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  Stream<List<UserStatus>> subscribeToPresence(List<String> userIds) {
    final controller = StreamController<List<UserStatus>>();
    final validIds = userIds
        .where(_ChatValidators.isValidUuid)
        .take(_kMaxInFilterSize)
        .toList();

    if (validIds.isEmpty) {
      scheduleMicrotask(() => controller.close());
      return controller.stream;
    }

    getUsersPresence(validIds).then((list) {
      if (!controller.isClosed) controller.add(list);
    });

    final sorted = [...validIds]..sort();
    final channelName = 'presence-${sorted.take(5).join('-')}';
    Timer? debounce;
    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'user_id',
            value: validIds,
          ),
          callback: (_) {
            if (_isDisposed || controller.isClosed) return;
            debounce?.cancel();
            debounce = Timer(_kPresenceDebounce, () async {
              if (_isDisposed || controller.isClosed) return;
              final list = await getUsersPresence(validIds);
              if (!controller.isClosed) controller.add(list);
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      debounce?.cancel();
      try {
        _supabase.removeChannel(channel);
      } catch (_) {}
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Future<String?> uploadFileWithUniqueName(
    String bucket,
    String folder,
    Uint8List data,
    String extension,
  ) async {
    if (_isDisposed) return null;

    if (!_ChatValidators.isValidBucket(bucket)) {
      debugPrint('[ChatService] ❌ Invalid bucket: $bucket');
      return null;
    }
    if (!_ChatValidators.isValidExtension(extension)) {
      debugPrint('[ChatService] ❌ Invalid extension: $extension');
      return null;
    }
    if (data.length > _kMaxFileBytes) {
      debugPrint('[ChatService] ❌ File too large: ${data.length} bytes');
      return null;
    }
    if (folder.contains('..') || folder.startsWith('/')) {
      debugPrint('[ChatService] ❌ Invalid folder path: $folder');
      return null;
    }

    try {
      final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_/-]'), '');
      final uniqueName = '${const Uuid().v4()}.$extension';
      final path = '$safeFolder/$uniqueName';

      await _supabase.storage
          .from(bucket)
          .uploadBinary(path, data)
          .timeout(_kStorageTimeout);

      debugPrint('[ChatService] ✓ File uploaded: $bucket/$path');
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('[ChatService] ❌ uploadFileWithUniqueName: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return null;
    }
  }

  // ============================================================
  // ✅ P2: TYPING BROADCAST + RÔLE + DELIVERED
  // ============================================================

  /// Envoie le statut "typing" via Realtime broadcast
  Future<void> sendTypingStatus(String conversationId, {required bool isTyping}) async {
    if (_isDisposed) return;
    final uid = currentUserId;
    if (!_ChatValidators.isValidUuid(uid) || !_ChatValidators.isValidUuid(conversationId)) return;
    
    try {
      final key = 'send:$conversationId';
      RealtimeChannel channel;
      
      if (_typingChannels.containsKey(key)) {
        channel = _typingChannels[key]!;
      } else {
        channel = _supabase.channel('typing:$conversationId');
        _typingChannels[key] = channel;
      }
      
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: <String, dynamic>{'senderId': uid, 'isTyping': isTyping},
      );
    } catch (e) {
      debugPrint('[ChatService] ⚠️ sendTypingStatus: $e');
    }
  }

  /// Démarre l'écoute des événements typing d'une conversation
  void startTypingListener(
    String conversationId,
    void Function(String senderId, bool isTyping) onEvent,
  ) {
    if (_isDisposed || !_ChatValidators.isValidUuid(conversationId)) return;
    
    stopTypingListener(conversationId);
    
    final channel = _supabase.channel('typing:$conversationId');
    _typingChannels['listen:$conversationId'] = channel;
    
    channel.onBroadcast(
      event: 'typing',
      callback: (Map<String, dynamic> payload) {
        final sid = (payload['senderId'] ?? '').toString();
        final typing = payload['isTyping'] == true;
        if (sid.isNotEmpty) onEvent(sid, typing);
      },
    ).subscribe();
  }

  /// Arrête l'écoute des événements typing d'une conversation
  void stopTypingListener(String conversationId) {
    final channel = _typingChannels.remove('listen:$conversationId');
    if (channel == null) return;
    
    try {
      _supabase.removeChannel(channel);
    } catch (_) {}
  }

  /// Récupère le rôle d'un utilisateur (agent, admin, support, enterprise, user)
  Future<String> getUserRole(String userId) async {
    if (_isDisposed || !_ChatValidators.isValidUuid(userId)) return '';
    
    try {
      final row = await _supabase
          .from('profiles')
          .select('role, account_type')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_kDbTimeout);
      
      if (row == null) return '';
      
      return (row['role'] ?? row['account_type'] ?? '').toString();
    } catch (e) {
      debugPrint('[ChatService] ⚠️ getUserRole: $e');
      return '';
    }
  }

  /// Marque une liste de messages comme distribués (is_delivered = true)
  Future<void> markMessagesDelivered(List<String> messageIds) async {
    if (_isDisposed || messageIds.isEmpty) return;
    
    try {
      final chunk = messageIds.take(_kMaxInFilterSize).toList();
      
      await _supabase
          .from('messages')
          .update(<String, dynamic>{'is_delivered': true})
          .inFilter('id', chunk)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatService] ⚠️ markMessagesDelivered: $e');
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
    if (_isDisposed) throw StateError('ChatService disposed');
    if (!_ChatValidators.isValidUuid(conversationId)) {
      throw ArgumentError('conversationId invalide');
    }
    if (audioData.length > _kMaxFileBytes) {
      throw ArgumentError('Audio trop volumineux');
    }
    if (duration < 0 || duration > 3600) {
      throw ArgumentError('Durée audio invalide');
    }

    const extension = 'm4a';
    final uniqueName = '${const Uuid().v4()}.$extension';
    final path = 'messages/$conversationId/$uniqueName';

    await _supabase.storage
        .from('audio_uploads')
        .uploadBinary(path, audioData)
        .timeout(_kStorageTimeout);
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

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    
    // ✅ Nettoyer tous les channels typing
    for (final channel in _typingChannels.values) {
      try {
        _supabase.removeChannel(channel);
      } catch (_) {}
    }
    _typingChannels.clear();
    
    _profileCache.clear();
    debugPrint('[ChatService] 👋 Disposed');
  }
}
