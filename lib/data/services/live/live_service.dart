// lib/data/services/live/live_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/data/models/live/live_model.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kCredentialsTimeout = Duration(seconds: 12);
const Duration _kDbTimeout = Duration(seconds: 10);
const int _kMaxCommentLength = 300;
const int _kMaxUserNameLength = 50;
const int _kMaxTitleLength = 80;
const int _kMaxDescriptionLength = 500;
const int _kMaxTagsLength = 120;
const int _kMaxRetries = 1;
const int _kMaxGuestsPerLive = 4;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _LiveServiceValidators {
  _LiveServiceValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String parseErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('unauthorized')) return 'Session expirée. Reconnectez-vous.';
    if (msg.contains('functions_http_error')) return 'Erreur serveur. Réessayez plus tard.';
    return e.toString().replaceFirst('Exception: ', '').split('\n').first;
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final liveServiceProvider = Provider<LiveService>((ref) => LiveService());

// ============================================================================
// SERVICE
// ============================================================================
class LiveService {
  final SupabaseClient _client = Supabase.instance.client;

  LiveService() {
    debugPrint('[LiveService] 🎬 Service initialized');
  }

  // ─── GETTERS ───

  String get currentUserId {
    final uid = _client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) {
      debugPrint('[LiveService] ⚠️ currentUserId called while not authenticated');
    }
    return uid;
  }

  bool get isAuthenticated => _client.auth.currentUser != null;

  // ════════════════════════════════════════════════════════════
  // AGORA CREDENTIALS (avec retry)
  // ════════════════════════════════════════════════════════════

  Future<AgoraCredentials> fetchAgoraCredentials(
    String channelName, {
    String role = 'audience',
    int attempt = 0,
  }) async {
    if (channelName.isEmpty) {
      throw Exception('Nom de canal invalide');
    }

    try {
      debugPrint('[LiveService] 🎟️ Fetching Agora credentials for "$channelName" (role=$role, attempt ${attempt + 1})');

      final response = await _client.functions
          .invoke(
            'thix-media-live-token',
            body: {
              'channelName': channelName,
              'uid': 0,
              'role': role,
            },
          )
          .timeout(_kCredentialsTimeout);

      if (response.data == null || response.data is! Map) {
        throw Exception('Réponse invalide de la fonction agora-token');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['appId'] == null || data['appId'].toString().isEmpty) {
        throw Exception('App ID manquant dans la réponse');
      }
      if (data['token'] == null || data['token'].toString().isEmpty) {
        throw Exception('Token manquant dans la réponse');
      }

      debugPrint('[LiveService] ✓ Credentials received (appId=${data['appId'].toString().substring(0, 8)}...)');
      return AgoraCredentials.fromMap(data);
    } on TimeoutException catch (e) {
      if (attempt < _kMaxRetries) {
        debugPrint('[LiveService] ⏱️ Timeout — retrying (${attempt + 1}/$_kMaxRetries)');
        await Future.delayed(const Duration(milliseconds: 500));
        return fetchAgoraCredentials(channelName, role: role, attempt: attempt + 1);
      }
      debugPrint('[LiveService] ❌ Timeout after ${attempt + 1} attempts');
      rethrow;
    } catch (e) {
      debugPrint('[LiveService] ❌ fetchAgoraCredentials error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 CREATE LIVE SESSION
  // ════════════════════════════════════════════════════════════

  Future<LiveSession> createLiveSession({
    required String title,
    String category = 'general',
    String? description,
    String? tags,
    String audience = 'public',
  }) async {
    if (currentUserId.isEmpty) {
      throw Exception('Utilisateur non authentifié');
    }

    final safeTitle = _LiveServiceValidators.sanitize(title, maxLength: _kMaxTitleLength);
    if (safeTitle.isEmpty) {
      throw Exception('Le titre ne peut pas être vide');
    }

    final safeCategory = _LiveServiceValidators.sanitize(category, maxLength: 40);
    final safeDescription = description != null
        ? _LiveServiceValidators.sanitize(description, maxLength: _kMaxDescriptionLength)
        : null;
    final safeTags = tags != null
        ? _LiveServiceValidators.sanitize(tags, maxLength: _kMaxTagsLength)
        : null;
    final safeAudience = ['public', 'followers', 'private'].contains(audience)
        ? audience
        : 'public';

    try {
      debugPrint('[LiveService] 🎬 Creating live session title=$safeTitle category=$safeCategory audience=$safeAudience');

      final existing = await _client
          .from('live_sessions')
          .select('id')
          .eq('host_id', currentUserId)
          .eq('status', 'live')
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (existing != null) {
        throw Exception('Vous avez déjà un live actif');
      }

      final channelName = _generateChannelName(currentUserId);

      final row = await _client
          .from('live_sessions')
          .insert({
            'host_id': currentUserId,
            'title': safeTitle,
            'category': safeCategory,
            'status': 'live',
            'channel_name': channelName,
            'started_at': DateTime.now().toUtc().toIso8601String(),
            if (safeDescription != null && safeDescription.isNotEmpty)
              'description': safeDescription,
            if (safeTags != null && safeTags.isNotEmpty)
              'tags': safeTags,
            'audience': safeAudience,
          })
          .select()
          .single()
          .timeout(_kDbTimeout);

      final session = LiveSession.fromMap(row);
      debugPrint('[LiveService] ✓ Live session created id=${session.id} channel=$channelName');

      return session;
    } catch (e) {
      debugPrint('[LiveService] ❌ createLiveSession error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  String _generateChannelName(String hostId) {
    final short = hostId.replaceAll('-', '').substring(0, 8);
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'thix_${short}_$suffix';
  }

  // ════════════════════════════════════════════════════════════
  // 📋 LIST ACTIVE LIVES
  // ════════════════════════════════════════════════════════════

  Future<List<LiveSession>> listActiveLives({int limit = 30}) async {
    try {
      debugPrint('[LiveService] 📋 Listing active lives (limit=$limit)');

      final rows = await _client
          .from('live_sessions')
          .select()
          .eq('status', 'live')
          .order('viewer_count', ascending: false)
          .order('started_at', ascending: false)
          .limit(limit)
          .timeout(_kDbTimeout);

      if (rows is! List) {
        debugPrint('[LiveService] ⚠️ listActiveLives: invalid response type');
        return [];
      }

      final sessions = <LiveSession>[];
      for (final row in rows) {
        try {
          if (row is Map) {
            sessions.add(LiveSession.fromMap(Map<String, dynamic>.from(row)));
          }
        } catch (e) {
          debugPrint('[LiveService] ⚠️ Invalid live skipped: $e');
        }
      }

      debugPrint('[LiveService] ✓ Active lives loaded count=${sessions.length}');
      return sessions;
    } catch (e) {
      debugPrint('[LiveService] ❌ listActiveLives error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // 🔍 GET LIVE SESSION BY ID
  // ════════════════════════════════════════════════════════════

  Future<LiveSession?> getLiveSession(String liveId) async {
    if (liveId.isEmpty) return null;

    try {
      final row = await _client
          .from('live_sessions')
          .select()
          .eq('id', liveId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (row == null) return null;
      return LiveSession.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[LiveService] ❌ getLiveSession error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  // SESSIONS
  // ════════════════════════════════════════════════════════════

  Future<void> endLiveSession(String liveId) async {
    if (liveId.isEmpty) {
      debugPrint('[LiveService] ⚠️ endLiveSession called with empty ID');
      return;
    }

    try {
      debugPrint('[LiveService] 🛑 Ending live session $liveId');

      await _client
          .from('live_sessions')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', liveId)
          .eq('host_id', currentUserId)
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Session $liveId marked as ended');
    } catch (e) {
      debugPrint('[LiveService] ❌ endLiveSession error: $e');
      rethrow;
    }
  }

  Future<void> cancelLiveSession(String liveId) async {
    if (liveId.isEmpty) return;

    try {
      await _client
          .from('live_sessions')
          .update({
            'status': 'cancelled',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', liveId)
          .eq('host_id', currentUserId)
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Session $liveId cancelled');
    } catch (e) {
      debugPrint('[LiveService] ⚠️ cancelLiveSession error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // ❤️ LIKES (avec RPC atomique)
  // ════════════════════════════════════════════════════════════

  Future<void> incrementLikes(String liveId, int count) async {
    if (liveId.isEmpty || count <= 0) return;

    try {
      await _client
          .rpc(
            'increment_live_likes',
            params: {
              'p_live_id': liveId,
              'p_count': count,
              'p_user_id': currentUserId,
            },
          )
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ❤️ Likes incremented liveId=$liveId count=$count');
    } catch (e) {
      debugPrint('[LiveService] ⚠️ incrementLikes error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // 👥 GUESTS / CO-HOSTS
  // ════════════════════════════════════════════════════════════

  Future<void> sendGuestInvite({
    required String liveId,
    required String guestUserId,
    required String guestUsername,
  }) async {
    if (liveId.isEmpty || guestUserId.isEmpty) {
      throw Exception('Paramètres invalides');
    }

    try {
      debugPrint('[LiveService] 👥 Sending guest invite liveId=$liveId guestId=$guestUserId');

      final existingGuests = await _client
          .from('live_guests')
          .select('user_id')
          .eq('live_id', liveId)
          .inFilter('status', ['invited', 'accepted', 'on_stage'])
          .timeout(_kDbTimeout);

      if (existingGuests is List && existingGuests.length >= _kMaxGuestsPerLive) {
        throw Exception('Limite d\'invités atteinte (max $_kMaxGuestsPerLive)');
      }

      if (existingGuests is List) {
        final alreadyInvited = existingGuests.any((g) => g['user_id'] == guestUserId);
        if (alreadyInvited) {
          throw Exception('Cette personne est déjà invitée ou sur scène');
        }
      }

      await _client
          .from('live_guests')
          .insert({
            'live_id': liveId,
            'user_id': guestUserId,
            'username': _LiveServiceValidators.sanitize(guestUsername, maxLength: _kMaxUserNameLength),
            'status': 'invited',
            'invited_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Guest invite sent');
    } catch (e) {
      debugPrint('[LiveService] ❌ sendGuestInvite error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  Future<void> acceptGuestInvite(String liveId) async {
    if (liveId.isEmpty || currentUserId.isEmpty) {
      throw Exception('Paramètres invalides');
    }

    try {
      await _client
          .from('live_guests')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('live_id', liveId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Guest invite accepted');
    } catch (e) {
      debugPrint('[LiveService] ❌ acceptGuestInvite error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  Future<void> rejectGuestInvite(String liveId) async {
    if (liveId.isEmpty || currentUserId.isEmpty) return;

    try {
      await _client
          .from('live_guests')
          .update({
            'status': 'rejected',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('live_id', liveId)
          .eq('user_id', currentUserId)
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Guest invite rejected');
    } catch (e) {
      debugPrint('[LiveService] ⚠️ rejectGuestInvite error: $e');
    }
  }

  Future<void> removeGuest(String liveId, String guestUserId) async {
    if (liveId.isEmpty || guestUserId.isEmpty) return;

    try {
      await _client
          .from('live_guests')
          .update({
            'status': 'removed',
            'removed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('live_id', liveId)
          .eq('user_id', guestUserId)
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Guest removed');
    } catch (e) {
      debugPrint('[LiveService] ❌ removeGuest error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  Future<List<Map<String, dynamic>>> getLiveGuests(String liveId) async {
    if (liveId.isEmpty) return [];

    try {
      final rows = await _client
          .from('live_guests')
          .select()
          .eq('live_id', liveId)
          .inFilter('status', ['invited', 'accepted', 'on_stage'])
          .order('invited_at', ascending: true)
          .timeout(_kDbTimeout);

      if (rows is! List) return [];
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('[LiveService] ❌ getLiveGuests error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // REALTIME CHANNEL
  // ════════════════════════════════════════════════════════════

  RealtimeChannel openRealtimeChannel({
    required String liveId,
    required void Function(LiveComment comment) onChat,
    required void Function() onHeart,
    required void Function(String userId, String userName) onCoHostRequest,
    required void Function(int viewerCount) onPresenceSync,
    bool isHost = false,
  }) {
    final channelName = 'live_$liveId';
    debugPrint('[LiveService] 📡 Opening Realtime channel: $channelName (isHost=$isHost)');

    final channel = _client.channel(channelName);

    channel
        .onBroadcast(
          event: 'chat',
          callback: (payload) {
            try {
              final comment = _safeParseComment(payload);
              if (comment != null) onChat(comment);
            } catch (e) {
              debugPrint('[LiveService] ⚠️ Chat handler error: $e');
            }
          },
        )
        .onBroadcast(
          event: 'heart',
          callback: (_) {
            try {
              onHeart();
            } catch (e) {
              debugPrint('[LiveService] ⚠️ Heart handler error: $e');
            }
          },
        )
        .onBroadcast(
          event: 'cohost_request',
          callback: (payload) {
            try {
              final userId = _LiveServiceValidators.sanitize(payload['userId']?.toString(), maxLength: 64);
              final userName = _LiveServiceValidators.sanitize(payload['userName']?.toString(), maxLength: _kMaxUserNameLength);
              if (userId.isNotEmpty) {
                onCoHostRequest(userId, userName);
              }
            } catch (e) {
              debugPrint('[LiveService] ⚠️ CoHost request handler error: $e');
            }
          },
        )
        .onBroadcast(
          event: 'cohost_response',
          callback: (payload) {
            debugPrint('[LiveService] 📨 CoHost response received: ${payload['accepted']}');
          },
        )
        .onPresenceSync((_) {
          try {
            final presences = channel.presenceState();
            int viewerCount = 0;

            for (final p in presences) {
              try {
                final dynamic dynP = p;
                Map<String, dynamic>? metadata;

                try {
                  metadata = dynP.payload as Map<String, dynamic>?;
                } catch (_) {
                  try {
                    metadata = dynP.state as Map<String, dynamic>?;
                  } catch (_) {
                    if (dynP is Map) {
                      metadata = Map<String, dynamic>.from(dynP);
                    }
                  }
                }

                if (metadata != null && metadata['is_host'] != true) {
                  viewerCount++;
                }
              } catch (e) {
                debugPrint('[LiveService] ⚠️ Presence entry parse error: $e');
              }
            }

            onPresenceSync(viewerCount);
          } catch (e) {
            debugPrint('[LiveService] ⚠️ Presence sync error: $e');
          }
        })
        .onPresenceJoin((payload) {
          debugPrint('[LiveService] 👤 Presence join: ${payload.key}');
        })
        .onPresenceLeave((payload) {
          debugPrint('[LiveService] 👋 Presence leave: ${payload.key}');
        })
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[LiveService] ❌ Subscribe error: $error');
            return;
          }

          if (status == RealtimeSubscribeStatus.subscribed) {
            try {
              channel.track({
                'user_id': currentUserId,
                'is_host': isHost,
                'joined_at': DateTime.now().toUtc().toIso8601String(),
              });
              debugPrint('[LiveService] ✓ Subscribed and tracked (isHost=$isHost)');
            } catch (e) {
              debugPrint('[LiveService] ⚠️ Track error: $e');
            }
          } else {
            debugPrint('[LiveService] 📡 Subscribe status: $status');
          }
        });

    return channel;
  }

  // ════════════════════════════════════════════════════════════
  // ENVOI DE MESSAGES
  // ════════════════════════════════════════════════════════════

  void sendChatMessage(RealtimeChannel channel, LiveComment comment) {
    try {
      final sanitizedComment = LiveComment(
        userId: comment.userId,
        userName: _LiveServiceValidators.sanitize(comment.userName, maxLength: _kMaxUserNameLength),
        text: _LiveServiceValidators.sanitize(comment.text, maxLength: _kMaxCommentLength),
      );

      if (sanitizedComment.text.isEmpty) {
        debugPrint('[LiveService] ⚠️ Empty comment after sanitization — rejected');
        return;
      }

      channel.sendBroadcastMessage(
        event: 'chat',
        payload: sanitizedComment.toPayload(),
      );
    } catch (e) {
      debugPrint('[LiveService] ❌ sendChatMessage error: $e');
      rethrow;
    }
  }

  void sendHeart(RealtimeChannel channel) {
    try {
      channel.sendBroadcastMessage(
        event: 'heart',
        payload: {
          'userId': currentUserId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[LiveService] ❌ sendHeart error: $e');
    }
  }

  void requestCoHost(RealtimeChannel channel, String userName) {
    try {
      if (currentUserId.isEmpty) {
        debugPrint('[LiveService] ⚠️ Cannot request co-host: not authenticated');
        return;
      }

      channel.sendBroadcastMessage(
        event: 'cohost_request',
        payload: {
          'userId': currentUserId,
          'userName': _LiveServiceValidators.sanitize(userName, maxLength: _kMaxUserNameLength),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint('[LiveService] 👥 CoHost request sent');
    } catch (e) {
      debugPrint('[LiveService] ❌ requestCoHost error: $e');
    }
  }

  void respondToCoHost(RealtimeChannel channel, String targetUserId, bool accepted) {
    try {
      if (targetUserId.isEmpty) {
        debugPrint('[LiveService] ⚠️ respondToCoHost: empty targetUserId');
        return;
      }

      channel.sendBroadcastMessage(
        event: 'cohost_response',
        payload: {
          'targetUserId': targetUserId,
          'accepted': accepted,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint('[LiveService] 👥 CoHost response sent: accepted=$accepted');
    } catch (e) {
      debugPrint('[LiveService] ❌ respondToCoHost error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // PARSING SÉCURISÉ
  // ════════════════════════════════════════════════════════════

  LiveComment? _safeParseComment(Map<String, dynamic> payload) {
    try {
      final userId = payload['userId']?.toString() ?? '';
      final userName = _LiveServiceValidators.sanitize(
        payload['userName']?.toString() ?? payload['user']?.toString(),
        maxLength: _kMaxUserNameLength,
      );
      final text = _LiveServiceValidators.sanitize(
        payload['text']?.toString(),
        maxLength: _kMaxCommentLength,
      );

      if (text.isEmpty) {
        debugPrint('[LiveService] ⚠️ Empty comment payload — ignored');
        return null;
      }

      return LiveComment(
        userId: userId.isEmpty ? 'anonymous' : userId,
        userName: userName.isEmpty ? 'Anonyme' : userName,
        text: text,
      );
    } catch (e) {
      debugPrint('[LiveService] ❌ _safeParseComment error: $e');
      return null;
    }
  }
}
