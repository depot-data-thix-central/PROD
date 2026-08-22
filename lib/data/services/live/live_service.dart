// lib/data/services/live/live_service.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🌟 Import standard
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/data/models/live/live_model.dart';

// 🌟 REMPLACEMENT : Déclaration manuelle du Provider au lieu de @riverpod
final liveServiceProvider = Provider<LiveService>((ref) {
  return LiveService();
});

class LiveService {
  final SupabaseClient _client = Supabase.instance.client;

  String get currentUserId => _client.auth.currentUser?.id ?? 'host';

  Future<AgoraCredentials> fetchAgoraCredentials(String channelName) async {
    final response = await _client.functions
        // ✅ CORRECTION ICI : 'channelName' au lieu de 'channel'
        .invoke('agora-token', body: {'channelName': channelName, 'uid': 0})
        .timeout(const Duration(seconds: 12));

    if (response.data == null || response.data is! Map) {
      throw Exception('Réponse invalide de la fonction agora-token');
    }
    return AgoraCredentials.fromMap(response.data as Map<String, dynamic>);
  }

  Future<void> endLiveSession(String liveId) async {
    await _client.from('live_sessions').delete().eq('id', liveId);
  }

  RealtimeChannel openRealtimeChannel({
    required String liveId,
    required void Function(LiveComment comment) onChat,
    required void Function() onHeart,
    required void Function(String userId, String userName) onCoHostRequest,
    required void Function(int viewerCount) onPresenceSync,
  }) {
    final channel = _client.channel('live_$liveId');

    channel
        .onBroadcast(
          event: 'chat',
          callback: (payload) => onChat(LiveComment.fromPayload(payload)),
        )
        .onBroadcast(event: 'heart', callback: (_) => onHeart())
        .onBroadcast(
          event: 'cohost_request',
          callback: (payload) => onCoHostRequest(
            payload['userId']?.toString() ?? '',
            payload['userName']?.toString() ?? '',
          ),
        )
        .onPresenceSync((_) {
          final state = channel.presenceState();
          final count = state.length;
          onPresenceSync(count > 0 ? count - 1 : 0);
        })
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            channel.track({'user_id': currentUserId, 'is_host': true});
          }
        });

    return channel;
  }

  void sendChatMessage(RealtimeChannel channel, LiveComment comment) {
    channel.sendBroadcastMessage(event: 'chat', payload: comment.toPayload());
  }

  void respondToCoHost(RealtimeChannel channel, String targetUserId, bool accepted) {
    channel.sendBroadcastMessage(
      event: 'cohost_response',
      payload: {'targetUserId': targetUserId, 'accepted': accepted},
    );
  }
}
