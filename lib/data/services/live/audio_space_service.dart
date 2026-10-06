// lib/data/services/live/audio_space_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/models/live/live_model.dart' hide AgoraCredentials;
import 'package:thix_id/data/services/live/live_service.dart';

const int _kMaxTitle = 100;
const int _kMaxDesc = 500;
const int _kMaxTopic = 40;
const int _kMaxName = 50;
const int _kMaxChat = 300;
const Duration _kDbTimeout = Duration(seconds: 10);
const Duration _kFnTimeout = Duration(seconds: 12);

// ============================================================================
// SANITIZER
// ============================================================================
class AudioSpaceSanitizer {
  AudioSpaceSanitizer._();

  static String sanitize(String? input, {int maxLength = 300}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:', caseSensitive: false), '')
        .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? validateTitle(String title) {
    final clean = title.trim();
    if (clean.length < 3) return 'Titre trop court (min 3 caractères)';
    if (clean.length > _kMaxTitle) return 'Titre trop long';
    return null;
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final audioSpaceServiceProvider = Provider<AudioSpaceService>((ref) {
  return AudioSpaceService(ref.read(liveServiceProvider));
});

// ============================================================================
// SERVICE
// ============================================================================
class AudioSpaceService {
  final LiveService _live;
  final SupabaseClient _client = Supabase.instance.client;

  AudioSpaceService(this._live);

  String get currentUserId => _live.currentUserId;
  bool get isAuthenticated => _live.isAuthenticated;

  String _newChannel(String userId) {
    final raw = userId.replaceAll('-', '');
    final head = raw.length >= 12 ? raw.substring(0, 12) : raw.padRight(12, '0');
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'space_${head}_$ts';
  }

  bool _isDuplicateChannel(Object e) {
    final msg = e.toString();
    return msg.contains('23505') || msg.contains('audio_spaces_channel_name_key');
  }

  // ═════════════════════════════════════════════════════════════════════
  // AGORA CREDENTIALS
  // ═════════════════════════════════════════════════════════════════════
  Future<AgoraCredentials> fetchCredentials(
    String channelName, {
    required int uid,
    required bool isPublisher,
  }) async {
    if (channelName.trim().isEmpty) {
      throw Exception('Canal salon audio manquant.');
    }
    if (_client.auth.currentSession == null) {
      throw Exception('Session expirée. Reconnectez-vous.');
    }

    try {
      final res = await _client.functions
          .invoke(
            'agora-token-space',
            body: {
              'channelName': channelName,
              'uid': uid,
              'role': isPublisher ? 'publisher' : 'subscriber',
            },
          )
          .timeout(_kFnTimeout);

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'Token salon audio refusé (${res.status}) channel=$channelName',
        );
      }

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final token = data['token']?.toString() ?? '';
      final appId = data['appId']?.toString() ?? '';
      if (token.isEmpty || appId.isEmpty) {
        throw Exception('Réponse token salon invalide.');
      }
      return AgoraCredentials(appId: appId, token: token);
    } catch (e) {
      debugPrint('[AudioSpace] token-space error: $e');
      rethrow;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // CRUD SPACES
  // ═════════════════════════════════════════════════════════════════════
  Future<AudioSpace> createSpace({
    required String title,
    String description = '',
    String topic = 'general',
    String hostName = 'Hôte THIX',
    String? hostAvatarUrl,
    String? enterpriseId,
    AudioSpaceVisibility visibility = AudioSpaceVisibility.public,
    bool requireVerifiedSpeakers = false,
    bool recordingEnabled = false,
    bool recordingConsent = false,
    int maxSpeakers = 12,
  }) async {
    if (!isAuthenticated) throw Exception('Session expirée. Reconnectez-vous.');

    final cleanTitle = AudioSpaceSanitizer.sanitize(title, maxLength: _kMaxTitle);
    final titleErr = AudioSpaceSanitizer.validateTitle(cleanTitle);
    if (titleErr != null) throw Exception(titleErr);
    if (recordingEnabled && !recordingConsent) {
      throw Exception('Le consentement d\'enregistrement est obligatoire.');
    }

    final cleanDesc = AudioSpaceSanitizer.sanitize(description, maxLength: _kMaxDesc);
    final cleanTopicRaw = AudioSpaceSanitizer.sanitize(topic, maxLength: _kMaxTopic);
    final cleanTopic = cleanTopicRaw.isEmpty ? 'general' : cleanTopicRaw;
    final cleanHostName = AudioSpaceSanitizer.sanitize(hostName, maxLength: _kMaxName);

    final uid = currentUserId;
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      final channel = _newChannel(uid);
      debugPrint('[AudioSpace] channel=$channel');
      try {
        final row = await _client
            .from('audio_spaces')
            .insert({
              'channel_name': channel,
              'title': cleanTitle,
              'description': cleanDesc,
              'topic': cleanTopic,
              'host_id': uid,
              'host_name': cleanHostName,
              'host_avatar_url': hostAvatarUrl,
              'enterprise_id': enterpriseId,
              'status': 'live',
              'visibility': visibility.name,
              'require_verified_speakers': requireVerifiedSpeakers,
              'recording_enabled': recordingEnabled,
              'recording_consent': recordingConsent,
              'max_speakers': maxSpeakers.clamp(1, 16),
              'speaker_count': 1,
              'started_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .single()
            .timeout(_kDbTimeout);

        final space = AudioSpace.fromMap(Map<String, dynamic>.from(row));
        await joinSpace(
          space,
          displayName: cleanHostName,
          avatarUrl: hostAvatarUrl,
          role: AudioSpaceRole.host,
          isMuted: false,
        );
        return space;
      } catch (e) {
        lastError = e;
        debugPrint('[AudioSpace] create attempt failed: $e');
        if (!_isDuplicateChannel(e)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }

    throw Exception(lastError.toString());
  }

  Future<void> endSpace(String spaceId) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;
    await _client
        .from('audio_spaces')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', spaceId)
        .eq('host_id', currentUserId)
        .timeout(_kDbTimeout);
  }

  Future<AudioSpace?> getSpaceById(String spaceId) async {
    if (spaceId.isEmpty) return null;
    try {
      final row = await _client
          .from('audio_spaces')
          .select()
          .eq('id', spaceId)
          .maybeSingle()
          .timeout(_kDbTimeout);
      if (row == null) return null;
      return AudioSpace.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[AudioSpace] getSpaceById error: $e');
      return null;
    }
  }

  Future<AudioSpace?> getMyActiveSpace() async {
    if (currentUserId.isEmpty) return null;
    try {
      final asHost = await _client
          .from('audio_spaces')
          .select()
          .eq('host_id', currentUserId)
          .eq('status', 'live')
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (asHost != null) {
        return AudioSpace.fromMap(Map<String, dynamic>.from(asHost));
      }

      final participation = await _client
          .from('audio_space_participants')
          .select('space_id, audio_spaces!inner(*)')
          .eq('user_id', currentUserId)
          .isFilter('left_at', null)
          .eq('is_banned', false)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (participation != null && participation['audio_spaces'] != null) {
        final spaceData = participation['audio_spaces'];
        if (spaceData is Map) {
          final spaceMap = Map<String, dynamic>.from(spaceData);
          if (spaceMap['status'] == 'live') {
            return AudioSpace.fromMap(spaceMap);
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[AudioSpace] getMyActiveSpace error: $e');
      return null;
    }
  }

  Future<List<AudioSpace>> listActiveSpaces({
  int limit = 12,
  String? topic,
  String? enterpriseId,
}) async {
  try {
    // ✅ Construction progressive de la requête AVANT .select()
    var query = _client.from('audio_spaces');

    // Appliquer les filtres avant de sélectionner
    PostgrestFilterBuilder<List<Map<String, dynamic>>> filteredQuery =
        query.select().eq('status', 'live');

    if (topic != null && topic.isNotEmpty) {
      filteredQuery = filteredQuery.eq('topic', topic);
    }
    if (enterpriseId != null && enterpriseId.isNotEmpty) {
      filteredQuery = filteredQuery.eq('enterprise_id', enterpriseId);
    }

    final rows = await filteredQuery
        .order('started_at', ascending: false)
        .limit(limit)
        .timeout(_kDbTimeout);

    return (rows as List)
        .map((e) => AudioSpace.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((s) => s.isLive && s.id.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('[AudioSpace] listActiveSpaces error: ' + e.toString());
    return [];
  }
}

  Future<void> updateSpaceMetadata({
    required String spaceId,
    String? title,
    String? description,
    String? topic,
  }) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;

    final updates = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      final clean = AudioSpaceSanitizer.sanitize(title, maxLength: _kMaxTitle);
      final err = AudioSpaceSanitizer.validateTitle(clean);
      if (err != null) throw Exception(err);
      updates['title'] = clean;
    }
    if (description != null) {
      updates['description'] = AudioSpaceSanitizer.sanitize(description, maxLength: _kMaxDesc);
    }
    if (topic != null) {
      updates['topic'] = AudioSpaceSanitizer.sanitize(topic, maxLength: _kMaxTopic);
    }

    if (updates.isEmpty) return;

    await _client
        .from('audio_spaces')
        .update(updates)
        .eq('id', spaceId)
        .eq('host_id', currentUserId)
        .timeout(_kDbTimeout);
  }

  Future<void> deleteSpace(String spaceId) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;
    await _client
        .from('audio_spaces')
        .delete()
        .eq('id', spaceId)
        .eq('host_id', currentUserId)
        .timeout(_kDbTimeout);
  }

  // ═════════════════════════════════════════════════════════════════════
  // PARTICIPANTS
  // ═════════════════════════════════════════════════════════════════════
  Future<AudioSpaceParticipant> joinSpace(
    AudioSpace space, {
    required String displayName,
    String? avatarUrl,
    AudioSpaceRole role = AudioSpaceRole.listener,
    bool isMuted = true,
    bool isVerified = false,
  }) async {
    if (currentUserId.isEmpty) throw Exception('Session expirée. Reconnectez-vous.');

    final existing = await _client
        .from('audio_space_participants')
        .select()
        .eq('space_id', space.id)
        .eq('user_id', currentUserId)
        .maybeSingle()
        .timeout(_kDbTimeout);

    if (existing != null && existing['is_banned'] == true) {
      throw Exception('Vous avez été exclu de ce salon.');
    }

    final payload = {
      'space_id': space.id,
      'user_id': currentUserId,
      'display_name': AudioSpaceSanitizer.sanitize(displayName, maxLength: _kMaxName),
      'avatar_url': avatarUrl,
      'role': existing != null ? existing['role'] : role.name,
      'is_muted': existing != null ? existing['is_muted'] : isMuted,
      'hand_raised': false,
      'is_banned': false,
      'is_verified': isVerified,
      'left_at': null,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _client
        .from('audio_space_participants')
        .upsert(payload, onConflict: 'space_id,user_id')
        .select()
        .single()
        .timeout(_kDbTimeout);

    await _incrementParticipantCount(space.id);

    return AudioSpaceParticipant.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> leaveSpace(String spaceId) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;
    await _client
        .from('audio_space_participants')
        .update({
          'left_at': DateTime.now().toUtc().toIso8601String(),
          'hand_raised': false,
        })
        .eq('space_id', spaceId)
        .eq('user_id', currentUserId)
        .timeout(_kDbTimeout);

    await _decrementParticipantCount(spaceId);
  }

  Future<List<AudioSpaceParticipant>> listActiveParticipants(String spaceId) async {
    final rows = await _client
        .from('audio_space_participants')
        .select()
        .eq('space_id', spaceId)
        .isFilter('left_at', null)
        .eq('is_banned', false)
        .timeout(_kDbTimeout);
    return (rows as List)
        .map((e) => AudioSpaceParticipant.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> getParticipantsCount(String spaceId) async {
    try {
      final rows = await _client
          .from('audio_space_participants')
          .select('id')
          .eq('space_id', spaceId)
          .isFilter('left_at', null)
          .eq('is_banned', false)
          .timeout(_kDbTimeout);
      return (rows as List).length;
    } catch (e) {
      debugPrint('[AudioSpace] getParticipantsCount error: $e');
      return 0;
    }
  }

  Future<void> _incrementParticipantCount(String spaceId) async {
    try {
      await _client.rpc('increment_space_participant_count', params: {'p_space_id': spaceId});
    } catch (e) {
      debugPrint('[AudioSpace] RPC increment failed, fallback manual: $e');
    }
  }

  Future<void> _decrementParticipantCount(String spaceId) async {
    try {
      await _client.rpc('decrement_space_participant_count', params: {'p_space_id': spaceId});
    } catch (e) {
      debugPrint('[AudioSpace] RPC decrement failed: $e');
    }
  }

  Future<void> setHandRaised(String spaceId, bool raised) async {
    await _client
        .from('audio_space_participants')
        .update({'hand_raised': raised})
        .eq('space_id', spaceId)
        .eq('user_id', currentUserId)
        .timeout(_kDbTimeout);
  }

  Future<void> setMuted({
    required String spaceId,
    required String targetUserId,
    required bool muted,
  }) async {
    final payload = <String, dynamic>{'is_muted': muted};
    if (muted) payload['hand_raised'] = false;
    await _client
        .from('audio_space_participants')
        .update(payload)
        .eq('space_id', spaceId)
        .eq('user_id', targetUserId)
        .timeout(_kDbTimeout);
  }

  Future<void> promoteToSpeaker({
    required AudioSpace space,
    required String targetUserId,
    required bool targetVerified,
  }) async {
    if (space.requireVerifiedSpeakers && !targetVerified) {
      throw Exception('Seuls les profils vérifiés peuvent parler dans ce salon.');
    }
    final speakers = (await listActiveParticipants(space.id))
        .where((p) =>
            p.role == AudioSpaceRole.host ||
            p.role == AudioSpaceRole.cohost ||
            p.role == AudioSpaceRole.speaker)
        .length;
    if (speakers >= space.maxSpeakers) {
      throw Exception(
        'Nombre maximum d\'intervenants atteint (${space.maxSpeakers}).',
      );
    }
    await _client
        .from('audio_space_participants')
        .update({'role': 'speaker', 'is_muted': false, 'hand_raised': false})
        .eq('space_id', space.id)
        .eq('user_id', targetUserId)
        .timeout(_kDbTimeout);
  }

  Future<void> demoteToListener({
    required String spaceId,
    required String targetUserId,
  }) async {
    await _client
        .from('audio_space_participants')
        .update({'role': 'listener', 'is_muted': true, 'hand_raised': false})
        .eq('space_id', spaceId)
        .eq('user_id', targetUserId)
        .timeout(_kDbTimeout);
  }

  Future<void> banUser({
    required String spaceId,
    required String targetUserId,
  }) async {
    await _client
        .from('audio_space_participants')
        .update({
          'is_banned': true,
          'role': 'listener',
          'is_muted': true,
          'hand_raised': false,
          'left_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('space_id', spaceId)
        .eq('user_id', targetUserId)
        .timeout(_kDbTimeout);
  }

  Future<bool> canModerate(String spaceId) async {
    if (currentUserId.isEmpty) return false;
    try {
      final row = await _client
          .from('audio_space_participants')
          .select('role')
          .eq('space_id', spaceId)
          .eq('user_id', currentUserId)
          .isFilter('left_at', null)
          .maybeSingle()
          .timeout(_kDbTimeout);
      if (row == null) return false;
      final role = row['role']?.toString();
      return role == 'host' || role == 'cohost';
    } catch (e) {
      debugPrint('[AudioSpace] canModerate error: $e');
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // CHAT
  // ═════════════════════════════════════════════════════════════════════
  Future<void> persistChat({
    required String spaceId,
    required String displayName,
    required String body,
  }) async {
    final clean = AudioSpaceSanitizer.sanitize(body, maxLength: _kMaxChat);
    if (clean.isEmpty) return;
    await _client.from('audio_space_messages').insert({
      'space_id': spaceId,
      'user_id': currentUserId,
      'display_name': AudioSpaceSanitizer.sanitize(displayName, maxLength: _kMaxName),
      'body': clean,
    }).timeout(_kDbTimeout);
  }

  Future<List<AudioSpaceChatMessage>> getChatHistory(
  String spaceId, {
  int limit = 50,
  DateTime? before,
}) async {
  try {
    // ✅ Construction progressive
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
        _client.from('audio_space_messages')
            .select()
            .eq('space_id', spaceId);

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(_kDbTimeout);

    final messages = (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return AudioSpaceChatMessage(
        userId: m['user_id']?.toString() ?? '',
        displayName: m['display_name']?.toString() ?? 'Membre',
        body: m['body']?.toString() ?? '',
        sentAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();

    return messages.reversed.toList();
  } catch (e) {
    debugPrint('[AudioSpace] getChatHistory error: ' + e.toString());
    return [];
  }
}


  Future<void> deleteMessage({
    required String spaceId,
    required String messageId,
  }) async {
    if (spaceId.isEmpty || messageId.isEmpty) return;
    try {
      await _client
          .from('audio_space_messages')
          .delete()
          .eq('id', messageId)
          .eq('space_id', spaceId)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[AudioSpace] deleteMessage error: $e');
      rethrow;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // REACTIONS
  // ═════════════════════════════════════════════════════════════════════
  Future<void> sendReaction(RealtimeChannel channel, String emoji) async {
    if (emoji.isEmpty || currentUserId.isEmpty) return;
    await broadcast(channel, 'reaction', {
      'emoji': emoji,
      'userId': currentUserId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ═════════════════════════════════════════════════════════════════════
  Future<void> recordAnalytics({
    required String spaceId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    if (spaceId.isEmpty) return;
    try {
      await _client.from('audio_space_analytics').insert({
        'space_id': spaceId,
        'user_id': currentUserId.isEmpty ? null : currentUserId,
        'event_type': eventType,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[AudioSpace] recordAnalytics error: $e');
    }
  }

  Future<Map<String, int>> getSpaceStats(String spaceId) async {
    try {
      final rows = await _client
          .from('audio_space_analytics')
          .select('event_type')
          .eq('space_id', spaceId)
          .timeout(_kDbTimeout);

      final stats = <String, int>{
        'views': 0,
        'joins': 0,
        'shares': 0,
        'reactions': 0,
      };

      for (final row in rows.whereType<Map>()) {
        final type = row['event_type']?.toString() ?? '';
        if (stats.containsKey(type)) {
          stats[type] = stats[type]! + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('[AudioSpace] getSpaceStats error: $e');
      return {'views': 0, 'joins': 0, 'shares': 0, 'reactions': 0};
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // REALTIME
  // ═════════════════════════════════════════════════════════════════════
  RealtimeChannel openChannel({
    required String spaceId,
    required void Function(AudioSpaceChatMessage message) onChat,
    required void Function() onEnded,
    required void Function() onRosterChanged,
    required void Function(String targetUserId, bool muted) onForceMute,
    required void Function(String targetUserId, String role) onRoleChanged,
    required void Function(String targetUserId) onBanned,
    void Function(String userId, String emoji)? onReaction,
  }) {
    final channel = _client.channel('audio_space_$spaceId');
    channel
        .onBroadcast(
          event: 'chat',
          callback: (payload) {
            try {
              final body = AudioSpaceSanitizer.sanitize(
                payload['body']?.toString(),
                maxLength: _kMaxChat,
              );
              if (body.isEmpty) return;
              final name = AudioSpaceSanitizer.sanitize(
                payload['displayName']?.toString(),
                maxLength: _kMaxName,
              );
              onChat(AudioSpaceChatMessage(
                userId: payload['userId']?.toString() ?? '',
                displayName: name.isEmpty ? 'Membre' : name,
                body: body,
                sentAt: DateTime.tryParse(payload['sentAt']?.toString() ?? '') ??
                    DateTime.now(),
              ));
            } catch (e) {
              debugPrint('[AudioSpace] chat parse error: $e');
            }
          },
        )
        .onBroadcast(
          event: 'reaction',
          callback: (payload) {
            final emoji = payload['emoji']?.toString() ?? '';
            final userId = payload['userId']?.toString() ?? '';
            if (emoji.isNotEmpty && userId.isNotEmpty) {
              onReaction?.call(userId, emoji);
            }
          },
        )
        .onBroadcast(event: 'ended', callback: (_) => onEnded())
        .onBroadcast(event: 'roster', callback: (_) => onRosterChanged())
        .onBroadcast(
          event: 'force_mute',
          callback: (payload) {
            final target = payload['targetUserId']?.toString() ?? '';
            if (target.isEmpty) return;
            onForceMute(target, payload['muted'] != false);
          },
        )
        .onBroadcast(
          event: 'role',
          callback: (payload) {
            final target = payload['targetUserId']?.toString() ?? '';
            final role = payload['role']?.toString() ?? 'listener';
            if (target.isEmpty) return;
            onRoleChanged(target, role);
          },
        )
        .onBroadcast(
          event: 'banned',
          callback: (payload) {
            final target = payload['targetUserId']?.toString() ?? '';
            if (target.isNotEmpty) onBanned(target);
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> broadcast(
    RealtimeChannel channel,
    String event,
    Map<String, dynamic> payload,
  ) {
    return channel.sendBroadcastMessage(event: event, payload: payload);
  }

  Future<void> closeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } catch (e) {
      debugPrint('[AudioSpace] closeChannel error: $e');
    }
  }
}
