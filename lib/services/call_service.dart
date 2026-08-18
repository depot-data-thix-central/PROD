import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class ThixCall {
  final String id;
  final String? chatId;
  final String kind;
  final String status;
  final String callerId;
  final String receiverId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const ThixCall({
    required this.id,
    required this.chatId,
    required this.kind,
    required this.status,
    required this.callerId,
    required this.receiverId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  static ThixCall fromRow(Map<String, dynamic> row) {
    DateTime parseDt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    DateTime? parseDtOrNull(Object? v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ThixCall(
      id: (row['id'] as String?) ?? '',
      chatId: (row['chat_id'] as String?),
      kind: (row['kind'] as String?) ?? 'audio',
      status: (row['status'] as String?) ?? 'ongoing',
      callerId: (row['caller_id'] as String?) ?? '',
      receiverId: (row['receiver_id'] as String?) ?? '',
      startedAt: parseDt(row['started_at']),
      endedAt: parseDtOrNull(row['ended_at']),
      durationSeconds: (row['duration_seconds'] as int?) ?? 0,
    );
  }
}

class CallService {
  static const String table = 'call_history';
  static const String signalsTable = 'thix_call_signals';
  static const String agoraTokenFunction = 'agora-token';

  final SupabaseClient _client;
  final List<RealtimeChannel> _activeChannels = [];

  CallService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  int agoraUidFor(String userId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in userId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }

  String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }

  Future<Map<String, dynamic>> fetchAgoraToken({required String channel, required int uid, required String role}) async {
    try {
      final res = await _client.functions.invoke(
        agoraTokenFunction,
        body: {'channel': channel, 'uid': uid, 'role': role},
      );
      final data = res.data;
      if (data is Map) return data.cast<String, dynamic>();
      throw Exception('Unexpected token response');
    } catch (e) {
      debugPrint('CallService: fetchAgoraToken failed channel=$channel uid=$uid err=$e');
      rethrow;
    }
  }

  bool _isUuidLike(String v) => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v.trim());

  Future<String> startCall({required String chatId, required String kind, required String receiverId}) async {
    final caller = _client.auth.currentUser;
    if (caller == null) throw Exception('Not authenticated');
    final safeKind = (kind == 'video') ? 'video' : 'audio';
    final safeChatId = _isUuidLike(chatId) ? chatId : null;

    final inserted = await _client
        .from(table)
        .insert({
          'chat_id': safeChatId,
          'kind': safeKind,
          'status': 'ongoing',
          'caller_id': caller.id,
          'receiver_id': receiverId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return (inserted['id'] as String?) ?? '';
  }

  Future<void> sendSignal({
    required String callId,
    required String toUserId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw Exception('Not authenticated');
    final safeType = switch (type) {
      'offer' || 'answer' || 'candidate' || 'hangup' || 'decline' => type,
      _ => 'candidate',
    };
    try {
      await _client.from(signalsTable).insert({
        'call_id': callId,
        'from_user_id': me.id,
        'to_user_id': toUserId,
        'type': safeType,
        'payload': payload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('CallService: sendSignal failed call=$callId type=$safeType err=$e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamSignals({required String callId, required String forUserId}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    
    // Écouter les changements en temps réel via un stream simple
    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(signalsTable)
            .select('*')
            .eq('call_id', callId)
            .eq('to_user_id', forUserId)
            .order('created_at', ascending: false)
            .limit(50);
        final list = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        debugPrint('CallService: streamSignals emitLatest failed call=$callId for=$forUserId err=$e');
        if (!controller.isClosed) controller.add(const <Map<String, dynamic>>[]);
      }
    }

    // Polling toutes les 2 secondes (fallback si Realtime ne fonctionne pas)
    Timer? pollTimer;

    controller.onListen = () {
      unawaited(emitLatest());
      pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(emitLatest()));
    };

    controller.onCancel = () {
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> completeCall({required String callId, required DateTime startedAt, required DateTime endedAt}) async {
    final seconds = endedAt.difference(startedAt).inSeconds.clamp(0, 24 * 60 * 60);
    try {
      await _client.from(table).update({
        'status': 'completed',
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_seconds': seconds,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (e) {
      debugPrint('CallService: completeCall failed id=$callId err=$e');
      rethrow;
    }
  }

  Future<void> setCallStatus({required String callId, required String status}) async {
    final safe = switch (status) {
      'ongoing' || 'completed' || 'missed' || 'declined' => status,
      _ => 'declined',
    };
    final updateData = {
      'status': safe,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (safe == 'completed' || safe == 'missed' || safe == 'declined') {
      updateData['ended_at'] = DateTime.now().toUtc().toIso8601String();
    }
    try {
      await _client.from(table).update(updateData).eq('id', callId);
    } catch (e) {
      debugPrint('CallService: setCallStatus failed id=$callId status=$safe err=$e');
      rethrow;
    }
  }

  /// Back-compat helper for older UI code.
  Future<void> updateCallStatus(String callId, String status) => setCallStatus(callId: callId, status: status);

  Stream<List<ThixCall>> streamIncomingOngoingCalls({required String receiverId}) {
    final controller = StreamController<List<ThixCall>>.broadcast();
    Timer? pollTimer;

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(table)
            .select('*')
            .eq('receiver_id', receiverId)
            .eq('status', 'ongoing')
            .order('started_at', ascending: false)
            .limit(5);
        final list = (rows is List)
            ? rows.map((r) => ThixCall.fromRow((r as Map).cast<String, dynamic>())).toList(growable: false)
            : const <ThixCall>[];
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        debugPrint('CallService: emitLatest incoming failed receiver=$receiverId err=$e');
        if (!controller.isClosed) controller.add(const <ThixCall>[]);
      }
    }

    controller.onListen = () {
      unawaited(emitLatest());
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    };

    controller.onCancel = () {
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> disposeAllChannels() async {
    for (final channel in _activeChannels) {
      await _client.removeChannel(channel);
    }
    _activeChannels.clear();
  }
}
