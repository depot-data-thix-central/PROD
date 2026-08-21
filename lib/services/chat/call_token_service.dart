// lib/services/chat/call_token_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallTokenResult {
  final String token;
  final String appId;
  final String channel;
  final int uid;

  const CallTokenResult({
    required this.token,
    required this.appId,
    required this.channel,
    required this.uid,
  });
}

class CallTokenService {
  final _client = Supabase.instance.client;

  Future<CallTokenResult> getToken({
    required String channel,
    required int uid,
  }) async {
    final res = await _client.functions.invoke(
      'agora-token',
      body: {'channelName': channel, 'uid': uid},
    );

    if (res.status != 200) {
      throw Exception('Token error: ${res.data}');
    }

    final data = Map<String, dynamic>.from(res.data as Map);
    final returnedChannel = (data['channelName'] as String?) ?? channel;

    return CallTokenResult(
      token: '${data['token']}',
      appId: '${data['appId']}',
      channel: returnedChannel,
      uid: (data['uid'] as num?)?.toInt() ?? uid,
    );
  }
}
