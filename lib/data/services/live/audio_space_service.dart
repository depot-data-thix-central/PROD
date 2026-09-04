import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';

const int _kMaxTitle = 100;
const int _kMaxDesc = 500;
const int _kMaxTopic = 40;
const int _kMaxName = 50;
const int _kMaxChat = 300;
const Duration _kDbTimeout = Duration(seconds: 10);
const Duration _kFnTimeout = Duration(seconds: 12);

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

final audioSpaceServiceProvider = Provider<AudioSpaceService>((ref) {
  return AudioSpaceService(ref.read(liveServiceProvider));
});

class AudioSpaceService {
  final LiveService _live;
  final SupabaseClient _client = Supabase.instance.client;

  AudioSpaceService(this._live);

  String get currentUserId => _live.currentUserId;
  bool get isAuthenticated => _live.isAuthenticated;

  String _newChannel(String userId) {
    final short = userId.replaceAll('-', '');
    final head = short.length >= 12 ? short.substring(0, 12) : short.padRight(12, '0');
    return 'space_\( {head}_ \){DateTime.now().millisecondsSinceEpoch}';
  }

  bool _isDuplicateChannel(Object e) {
    final msg = e.toString();
    return msg.contains('23505') || msg.contains('audio_spaces_channel_name_key');
  }

  Future<AgoraCredentials> fetchCredentials(String channelName) async {
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
              'uid': 0,
              'role': 'publisher',
            },
          )
          .timeout(_kFnTimeout);

      if (res.status != 200 || res.data == null) {
        throw Exception('Token salon audio refusé (${res.status}).');
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
    } on FunctionException catch (e) {
      debugPrint('[AudioSpace] token-space ${e.status} ${e.details}');
      throw Exception('Token salon audio refusé (${e.status}).');
    }
  }

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

    final uid = currentUserId;
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      final channel = _newChannel(uid);
      try {
        final row = await _client
            .from('audio_spaces')
            .insert({
              'channel_name': channel,
              'title': cleanTitle,
              'description': AudioSpaceSanitizer.sanitize(description, maxLength: _kMaxDesc),
              'topic': AudioSpaceSanitizer.sanitize(topic, maxLength: _kMaxTopic).isEmpty
                  ? 'general'
                  : AudioSpaceSanitizer.sanitize(topic, maxLength: _kMaxTopic),
              'host_id': uid,
              'host_name': AudioSpaceSanitizer.sanitize(hostName, maxLength: _kMaxName),
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
          displayName: hostName,
          avatarUrl: hostAvatarUrl,
          role: AudioSpaceRole.host,
          isMuted: false,
        );
        return space;
      } catch (e) {
        lastError = e;
        debugPrint('[AudioSpace] create attempt ${attempt + 1} failed: $e');
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
      throw Exception('Nombre maximum d\'intervenants atteint (${space.maxSpeakers}).');
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

  RealtimeChannel openChannel({
    required String spaceId,
    required void Function(AudioSpaceChatMessage message) onChat,
    required void Function() onEnded,
    required void Function() onRosterChanged,
    required void Function(String targetUserId, bool muted) onForceMute,
    required void Function(String targetUserId, String role) onRoleChanged,
    required void Function(String targetUserId) onBanned,
  }) {
    final channel = _client.channel('audio_space_$spaceId');
    channel
        .onBroadcast(
          event: 'chat',
          callback: (payload) {
            try {
              final body = AudioSpaceSanitizer.sanitize(payload['body']?.toString(), maxLength: _kMaxChat);
              if (body.isEmpty) return;
              final name = AudioSpaceSanitizer.sanitize(payload['displayName']?.toString(), maxLength: _kMaxName);
              onChat(AudioSpaceChatMessage(
                userId: payload['userId']?.toString() ?? '',
                displayName: name.isEmpty ? 'Membre' : name,
                body: body,
                sentAt: DateTime.tryParse(payload['sentAt']?.toString() ?? '') ?? DateTime.now(),
              ));
            } catch (e) {
              debugPrint('[AudioSpace] chat parse error: $e');
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

  Future<void> broadcast(RealtimeChannel channel, String event, Map<String, dynamic> payload) {
    return channel.sendBroadcastMessage(event: event, payload: payload);
  }
}
