// lib/services/chat/call_signaling_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat/call_invite.dart';
import '../../models/chat/call_status.dart';

/// Résultat token Agora (Edge Function `agora-token`)
class AgoraTokenResult {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final int expireAt;

  const AgoraTokenResult({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.expireAt,
  });

  factory AgoraTokenResult.fromJson(Map<String, dynamic> j) {
    return AgoraTokenResult(
      token: j['token'] as String? ?? '',
      appId: j['appId'] as String? ?? j['app_id'] as String? ?? '',
      channelName:
          j['channelName'] as String? ?? j['channel_name'] as String? ?? '',
      uid: (j['uid'] as num?)?.toInt() ?? 0,
      expireAt: (j['expireAt'] as num?)?.toInt() ??
          (j['expire_at'] as num?)?.toInt() ??
          0,
    );
  }

  bool get isValid => token.isNotEmpty && appId.isNotEmpty;
}

class CallSignalingService {
  CallSignalingService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  RealtimeChannel? _incomingChannel;
  final Map<String, RealtimeChannel> _statusChannels = {};

  static const String agoraTokenFunction = 'agora-token';

  String get _uid => _db.auth.currentUser?.id ?? '';

  // ============================================================
  // START CALL (signalisation)
  // ============================================================

  Future<CallInvite> startCall({
    required String calleeId,
    required CallType type,
  }) async {
    if (_uid.isEmpty) throw Exception('Non authentifié');
    if (calleeId.isEmpty) throw Exception('calleeId vide');
    if (calleeId == _uid) {
      throw Exception('Impossible de s’appeler soi-même');
    }

    final res = await _db.rpc(
      'rpc_start_call',
      params: {
        'p_callee_id': calleeId,
        'p_call_type': type == CallType.video ? 'video' : 'audio',
      },
    );

    debugPrint('📞 rpc_start_call: $res');

    final row = _asMap(res);
    if (row.isEmpty) {
      throw Exception('rpc_start_call a renvoyé une réponse vide');
    }

    return _inviteFromRow(
      row,
      fallbackCaller: _uid,
      fallbackCallee: calleeId,
      fallbackType: type,
    );
  }

  // ============================================================
  // AGORA TOKEN (Edge Function Supabase)
  // ============================================================

  /// Récupère un token RTC via Edge Function `agora-token`.
  /// À appeler après startCall / accept, avant joinChannel.
  Future<AgoraTokenResult> fetchAgoraToken({
    required String channelName,
    int uid = 0,
    int expireSec = 3600,
  }) async {
    if (_uid.isEmpty) throw Exception('Non authentifié');
    if (channelName.trim().isEmpty) {
      throw Exception('channelName vide');
    }

    final res = await _db.functions.invoke(
      agoraTokenFunction,
      body: {
        'channelName': channelName.trim(),
        'uid': uid,
        'expireSec': expireSec.clamp(60, 86400),
        'role': 1, // publisher
      },
    );

    if (res.status != 200) {
      debugPrint('agora-token error status=\( {res.status} data= \){res.data}');
      throw Exception(
        'agora-token failed (${res.status}): ${res.data}',
      );
    }

    final map = _asMap(res.data);
    if (map.isEmpty) {
      throw Exception('agora-token: réponse vide');
    }

    final result = AgoraTokenResult.fromJson(map);
    if (!result.isValid) {
      throw Exception('agora-token: token ou appId manquant');
    }
    return result;
  }

  /// startCall + token en une étape (caller)
  Future<({CallInvite invite, AgoraTokenResult agora})> startCallWithToken({
    required String calleeId,
    required CallType type,
    int uid = 0,
  }) async {
    final invite = await startCall(calleeId: calleeId, type: type);
    final channel = invite.channelName;
    if (channel == null || channel.isEmpty) {
      throw Exception('Invite sans channel_name');
    }
    final agora = await fetchAgoraToken(channelName: channel, uid: uid);
    return (invite: invite, agora: agora);
  }

  /// Après accept : token pour le callee
  Future<AgoraTokenResult> tokenForInvite(
    CallInvite invite, {
    int uid = 0,
  }) async {
    final channel = invite.channelName;
    if (channel == null || channel.isEmpty) {
      throw Exception('Invite sans channel_name');
    }
    return fetchAgoraToken(channelName: channel, uid: uid);
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> accept(String inviteId) async {
    await _db.rpc('rpc_accept_call', params: {'p_invite_id': inviteId});
  }

  Future<void> reject(String inviteId) async {
    await _db.rpc('rpc_reject_call', params: {'p_invite_id': inviteId});
  }

  Future<void> cancel(String inviteId) async {
    await _db.rpc('rpc_cancel_call', params: {'p_invite_id': inviteId});
  }

  Future<void> end(String inviteId, {int durationSec = 0}) async {
    await _db.rpc('rpc_end_call', params: {
      'p_invite_id': inviteId,
      'p_duration_sec': durationSec,
    });
  }

  Future<void> markMissed(String inviteId) async {
    try {
      await _db.rpc('rpc_miss_call', params: {'p_invite_id': inviteId});
    } catch (_) {
      // fallback si RPC absente
      await _db.from('call_invites').update({
        'status': 'missed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', inviteId);
    }
  }

  Future<void> markOngoing(String inviteId) async {
    try {
      await _db.rpc('rpc_ongoing_call', params: {'p_invite_id': inviteId});
    } catch (_) {
      await _db.from('call_invites').update({
        'status': 'ongoing',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', inviteId);
    }
  }
  // ============================================================
  // REALTIME — incoming (callee)
  // ============================================================

  Stream<CallInvite> watchIncoming() {
    final controller = StreamController<CallInvite>.broadcast();
    final myId = _uid;

    if (myId.isEmpty) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.close();
      });
      return controller.stream;
    }

    _teardownIncoming();

    final ch = _db.channel('call_incoming_$myId');
    _incomingChannel = ch;

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: myId,
          ),
          callback: (payload) {
            try {
              final map = Map<String, dynamic>.from(payload.newRecord);
              final status = (map['status'] ?? '').toString();
              if (status != 'ringing') return;
              if (!controller.isClosed) {
                controller.add(CallInvite.fromJson(map));
              }
            } catch (e) {
              debugPrint('watchIncoming parse: $e');
            }
          },
        )
        .subscribe();

    controller.onCancel = _teardownIncoming;
    return controller.stream;
  }

  /// Incoming + poll de secours (réseau instable)
  Stream<CallInvite> watchIncomingWithPoll() {
    final controller = StreamController<CallInvite>.broadcast();
    final myId = _uid;

    if (myId.isEmpty) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.close();
      });
      return controller.stream;
    }

    final seen = <String>{};

    final realtimeSub = watchIncoming().listen(
      (invite) {
        if (seen.add(invite.id)) {
          if (!controller.isClosed) controller.add(invite);
        }
      },
      onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      },
    );

    final timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final since = DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 2))
            .toIso8601String();

        final rows = await _db
            .from('call_invites')
            .select()
            .eq('callee_id', myId)
            .eq('status', 'ringing')
            .gte('created_at', since);

        for (final row in (rows as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['id']?.toString() ?? '';
          if (id.isEmpty || !seen.add(id)) continue;
          if (!controller.isClosed) {
            controller.add(CallInvite.fromJson(map));
          }
        }
      } catch (e) {
        debugPrint('📞 poll error: $e');
      }
    });

    controller.onCancel = () {
      realtimeSub.cancel();
      timer.cancel();
    };

    return controller.stream;
  }

  // ============================================================
  // REALTIME — status invite (caller / callee)
  // ============================================================

  Stream<CallStatus> watchInviteStatus(String inviteId) {
    final controller = StreamController<CallStatus>.broadcast();

    final old = _statusChannels.remove(inviteId);
    if (old != null) {
      try {
        old.unsubscribe();
        _db.removeChannel(old);
      } catch (_) {}
    }

    final ch = _db.channel('call_status_$inviteId');
    _statusChannels[inviteId] = ch;

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: inviteId,
          ),
          callback: (payload) {
            try {
              final map = Map<String, dynamic>.from(payload.newRecord);
              final status = _parseStatus(map['status']?.toString());
              if (!controller.isClosed) controller.add(status);
            } catch (e) {
              debugPrint('watchInviteStatus: $e');
            }
          },
        )
        .subscribe();

    // Snapshot initial
    scheduleMicrotask(() async {
      try {
        final row = await _db
            .from('call_invites')
            .select('status')
            .eq('id', inviteId)
            .maybeSingle();
        if (row != null && !controller.isClosed) {
          controller.add(_parseStatus(row['status']?.toString()));
        }
      } catch (_) {}
    });

    controller.onCancel = () {
      final c = _statusChannels.remove(inviteId);
      if (c != null) {
        try {
          c.unsubscribe();
          _db.removeChannel(c);
        } catch (_) {}
      }
    };

    return controller.stream;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  CallInvite _inviteFromRow(
    Map<String, dynamic> row, {
    required String fallbackCaller,
    required String fallbackCallee,
    required CallType fallbackType,
  }) {
    return CallInvite.fromJson({
      ...row,
      'id': row['id'] ?? row['invite_id'],
      'channel_name': row['channel_name'] ?? row['channel'],
      'caller_id': row['caller_id'] ?? fallbackCaller,
      'callee_id': row['callee_id'] ?? fallbackCallee,
      'call_type': row['call_type'] ??
          (fallbackType == CallType.video ? 'video' : 'audio'),
      'status': row['status'] ?? 'ringing',
      'created_at':
          row['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return {};
  }

  CallStatus _parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
      case 'ongoing':
      case 'active':
        return CallStatus.accepted;
      case 'rejected':
        return CallStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return CallStatus.cancelled;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      default:
        return CallStatus.ringing;
    }
  }

  void _teardownIncoming() {
    final ch = _incomingChannel;
    _incomingChannel = null;
    if (ch != null) {
      try {
        ch.unsubscribe();
        _db.removeChannel(ch);
      } catch (_) {}
    }
  }

  void dispose() {
    _teardownIncoming();
    for (final ch in _statusChannels.values) {
      try {
        ch.unsubscribe();
        _db.removeChannel(ch);
      } catch (_) {}
    }
    _statusChannels.clear();
  }
}
