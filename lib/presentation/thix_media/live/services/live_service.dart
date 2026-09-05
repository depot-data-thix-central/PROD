import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgoraCredentials {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final String role;

  AgoraCredentials({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.role,
  });

  factory AgoraCredentials.fromJson(Map<String, dynamic> j) => AgoraCredentials(
        token: j['token'] as String,
        appId: j['appId'] as String,
        channelName: j['channelName'] as String,
        uid: j['uid'] as int,
        role: j['role'] as String,
      );
}

class LiveSession {
  final String id;
  final String hostId;
  final String title;
  final String category;
  final String status;
  final String channelName;
  final int viewerCount;
  final int likeCount;

  LiveSession({
    required this.id,
    required this.hostId,
    required this.title,
    required this.category,
    required this.status,
    required this.channelName,
    this.viewerCount = 0,
    this.likeCount = 0,
  });

  factory LiveSession.fromJson(Map<String, dynamic> j) => LiveSession(
        id: j['id'] as String,
        hostId: j['host_id'] as String,
        title: (j['title'] ?? 'Live') as String,
        category: (j['category'] ?? 'Général') as String,
        status: (j['status'] ?? 'live') as String,
        channelName: j['channel_name'] as String,
        viewerCount: (j['viewer_count'] as num?)?.toInt() ?? 0,
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      );
}

class LiveService {
  final _client = Supabase.instance.client;

  String _newChannelName(String hostId) {
    final short = hostId.replaceAll('-', '').substring(0, 8);
    final r = Random().nextInt(99999);
    return 'thix_$short$r';
  }

  /// Crée un live + récupère le token Agora (host)
  Future<({LiveSession session, AgoraCredentials creds})> startLive({
    required String title,
    String category = 'Général',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final channel = _newChannelName(user.id);

    final row = await _client
        .from('lives')
        .insert({
          'host_id': user.id,
          'title': title.trim().isEmpty ? 'Live' : title.trim(),
          'category': category,
          'status': 'live',
          'channel_name': channel,
        })
        .select()
        .single();

    final creds = await fetchAgoraToken(
      channelName: channel,
      role: 'host',
    );

    return (session: LiveSession.fromJson(row), creds: creds);
  }

  /// Rejoindre un live existant (audience)
  Future<({LiveSession session, AgoraCredentials creds})> joinLive(
    String liveId,
  ) async {
    final row =
        await _client.from('lives').select().eq('id', liveId).single();
    final session = LiveSession.fromJson(row);
    if (session.status != 'live') {
      throw Exception('Live terminé');
    }

    final creds = await fetchAgoraToken(
      channelName: session.channelName,
      role: 'audience',
    );
    return (session: session, creds: creds);
  }

  Future<AgoraCredentials> fetchAgoraToken({
  required String channelName,
  required String role, // host | audience
}) async {
  final res = await _client.functions.invoke(
    'thix-media-live-token',
    body: {
      'channelName': channelName,
      'role': role,
    },
  );
  if (res.status != 200) {
    throw Exception('Token error: ${res.data}');
  }
  return AgoraCredentials.fromJson(
    Map<String, dynamic>.from(res.data as Map),
  );
}

  Future<void> endLive(String liveId) async {
    await _client.from('lives').update({
      'status': 'ended',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', liveId);
  }

  Future<List<LiveSession>> listActiveLives({int limit = 30}) async {
    final rows = await _client
        .from('lives')
        .select()
        .eq('status', 'live')
        .order('started_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => LiveSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> sendMessage({
    required String liveId,
    required String text,
    required String username,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('live_messages').insert({
      'live_id': liveId,
      'user_id': user.id,
      'username': username,
      'text': text.trim(),
      'type': 'chat',
    });
  }
}
