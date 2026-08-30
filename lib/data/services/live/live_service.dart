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
const int _kMaxRetries = 1;

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

  /// ID de l'utilisateur courant, ou empty string si non authentifié.
  /// ⚠️ Ne jamais utiliser 'host' comme fallback : cela crée de faux users en DB.
  String get currentUserId {
    final uid = _client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) {
      debugPrint('[LiveService] ⚠️ currentUserId called while not authenticated');
    }
    return uid;
  }

  bool get isAuthenticated => _client.auth.currentUser != null;

  // ─── AGORA CREDENTIALS (avec retry) ───

  Future<AgoraCredentials> fetchAgoraCredentials(String channelName, {int attempt = 0}) async {
    if (channelName.isEmpty) {
      throw Exception('Nom de canal invalide');
    }

    try {
      debugPrint('[LiveService] 🎟️ Fetching Agora credentials for "$channelName" (attempt ${attempt + 1})');

      final response = await _client.functions
          .invoke(
            'agora-token',
            body: {'channelName': channelName, 'uid': 0},
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
      // Retry une seule fois sur timeout
      if (attempt < _kMaxRetries) {
        debugPrint('[LiveService] ⏱️ Timeout — retrying (${attempt + 1}/$_kMaxRetries)');
        await Future.delayed(const Duration(milliseconds: 500));
        return fetchAgoraCredentials(channelName, attempt: attempt + 1);
      }
      debugPrint('[LiveService] ❌ Timeout after ${attempt + 1} attempts');
      rethrow;
    } catch (e) {
      debugPrint('[LiveService] ❌ fetchAgoraCredentials error: $e');
      throw Exception(_LiveServiceValidators.parseErrorMessage(e));
    }
  }

  // ─── SESSIONS ───

  /// Termine une session live en mettant à jour son statut.
  /// ⚠️ On ne SUPPRIME pas la session : on la marque 'ended' pour conserver
  /// l'historique (analytics, replay, modération).
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
          .eq('host_id', currentUserId) // Sécurité : seul l'hôte peut terminer
          .timeout(_kDbTimeout);

      debugPrint('[LiveService] ✓ Session $liveId marked as ended');
    } catch (e) {
      debugPrint('[LiveService] ❌ endLiveSession error: $e');
      rethrow;
    }
  }

  /// Annule une session live qui n'a jamais vraiment démarré (rollback).
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

  // ─── REALTIME CHANNEL ───

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

    // ─── Handlers broadcast avec try/catch ───
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
        // ✅ FIX AGNOSTIQUE : utilise cast dynamique pour contourner les variations
        // d'API de SinglePresenceState entre les versions de realtime_client
        .onPresenceSync((_) {
          try {
            final presences = channel.presenceState();
            int viewerCount = 0;

            for (final p in presences) {
              try {
                // Cast dynamique : contourne le typage statique strict
                // qui varie selon les versions de realtime_client
                final dynamic dynP = p;

                Map<String, dynamic>? metadata;

                // Essaie les différentes propriétés possibles
                try {
                  metadata = dynP.payload as Map<String, dynamic>?;
                } catch (_) {
                  try {
                    metadata = dynP.state as Map<String, dynamic>?;
                  } catch (_) {
                    // En dernier recours : si p est directement un Map
                    if (dynP is Map) {
                      metadata = Map<String, dynamic>.from(dynP);
                    }
                  }
                }

                // Compte seulement les viewers (exclut l'hôte)
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

  // ─── ENVOI DE MESSAGES ───

  void sendChatMessage(RealtimeChannel channel, LiveComment comment) {
    try {
      // Validation avant envoi
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

  // ─── PARSING SÉCURISÉ ───

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
