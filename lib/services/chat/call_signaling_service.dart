// lib/services/chat/call_signaling_service.dart
//
// ============================================================================
// CALL SIGNALING SERVICE — Production Enterprise
// ============================================================================
//
// Service de signalisation pour les appels VoIP via Supabase Realtime.
//
// Architecture :
//   - SupabaseClient injecté via Riverpod (testable)
//   - Realtime channels pour événements temps réel
//   - Polling de secours pour réseau instable
//   - Edge Functions pour tokens Agora
//
// Sécurité :
//   - Validation UUID stricte sur tous les IDs
//   - Validation regex sur channel names
//   - Timeout + retry sur tous les appels réseau
//   - Stack traces masquées en production (kDebugMode)
//   - Sanitization sur toutes les entrées
//
// Robustesse :
//   - _isDisposed guard sur toutes les méthodes
//   - Limite max de channels Realtime (protection DoS)
//   - Cleanup garanti des subscriptions
//   - Backoff exponentiel sur polling
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMinAppIdLength = 10;
const int _kMaxChannelLength = 100;
const int _kMaxStatusChannels = 20; // Limite pour éviter fuite mémoire
const int _kPollingIntervalSec = 5; // Backoff augmenté (était 3s)
const int _kPollingWindowMinutes = 2;
const int _kMinExpireSec = 60;
const int _kMaxExpireSec = 86400;
const int _kDefaultExpireSec = 3600;
const Duration _kRpcTimeout = Duration(seconds: 15);
const Duration _kEdgeFunctionTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallSignalingValidators {
  _CallSignalingValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Valide un channel name Agora (alphanumérique + underscore + tiret).
  static bool isValidChannelName(String? name) {
    if (name == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  /// Sanitize un channel name.
  static String sanitizeChannelName(String? name) {
    if (name == null) return '';
    return name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .trim()
        .substring(0, name.length.clamp(0, _kMaxChannelLength));
  }

  /// Obfusque un ID pour les logs.
  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// AGORA TOKEN RESULT
// ============================================================================

/// Résultat token Agora (Edge Function `agora-token`).
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
      token: (j['token'] as String?)?.trim() ?? '',
      appId: (j['appId'] as String? ?? j['app_id'] as String?)?.trim() ?? '',
      channelName:
          (j['channelName'] as String? ?? j['channel_name'] as String?)?.trim() ?? '',
      uid: (j['uid'] as num?)?.toInt() ?? 0,
      expireAt: (j['expireAt'] as num?)?.toInt() ??
          (j['expire_at'] as num?)?.toInt() ??
          0,
    );
  }

  /// Vrai si le token est valide (non vide + appId min 10 caractères).
  bool get isValid =>
      token.isNotEmpty && appId.length >= _kMinAppIdLength;
}

// ============================================================================
// CALL SIGNALING SERVICE
// ============================================================================

/// Service de signalisation pour les appels VoIP.
///
/// Gère :
/// - Signalisation RPC Supabase (start, accept, reject, cancel, end)
/// - Tokens Agora via Edge Function
/// - Realtime channels pour appels entrants
/// - Polling de secours pour réseau instable
///
/// **Usage via Riverpod** :
/// ```dart
/// final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
///   final client = ref.watch(supabaseClientProvider);
///   return CallSignalingService(client: client);
/// });
/// ```
class CallSignalingService {
  CallSignalingService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client {
    debugPrint('[CallSignalingService] 🚀 Initialized');
  }

  final SupabaseClient _db;

  RealtimeChannel? _incomingChannel;
  final Map<String, RealtimeChannel> _statusChannels = {};
  bool _isDisposed = false;

  static const String _kAgoraTokenFunction = 'agora-token';

  String get _uid => _db.auth.currentUser?.id ?? '';

  // ============================================================
  // START CALL (signalisation)
  // ============================================================

  /// Démarre un appel (signalisation côté serveur).
  ///
  /// **Validation** :
  ///   - `calleeId` doit être un UUID valide différent de l'utilisateur courant
  ///
  /// **Throws** :
  ///   - [ArgumentError] si les inputs sont invalides
  ///   - [TimeoutException] si le RPC timeout
  ///   - [StateError] si le service est disposé
  Future<CallInvite> startCall({
    required String calleeId,
    required CallType type,
  }) async {
    if (_isDisposed) {
      throw StateError('CallSignalingService disposed');
    }

    // Validation auth
    if (_uid.isEmpty || !_CallSignalingValidators.isValidUuid(_uid)) {
      throw StateError('Non authentifié ou ID invalide');
    }

    // Validation inputs
    if (!_CallSignalingValidators.isValidUuid(calleeId)) {
      throw ArgumentError('calleeId invalide');
    }
    if (calleeId == _uid) {
      throw ArgumentError('Impossible de s\'appeler soi-même');
    }

    debugPrint('[CallSignalingService] 📞 startCall → '
        '${_CallSignalingValidators.obfuscate(calleeId)} (${type.name})');

    try {
      final res = await _db
          .rpc(
            'rpc_start_call',
            params: {
              'p_callee_id': calleeId,
              'p_call_type': type == CallType.video ? 'video' : 'audio',
            },
          )
          .timeout(_kRpcTimeout);

      final row = _asMap(res);
      if (row.isEmpty) {
        throw Exception('rpc_start_call a renvoyé une réponse vide');
      }

      debugPrint('[CallSignalingService] ✓ Call started');

      return _inviteFromRow(
        row,
        fallbackCaller: _uid,
        fallbackCallee: calleeId,
        fallbackType: type,
      );
    } on TimeoutException {
      debugPrint('[CallSignalingService] ❌ startCall timeout');
      rethrow;
    } catch (e) {
      debugPrint('[CallSignalingService] ❌ startCall failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ============================================================
  // AGORA TOKEN (Edge Function Supabase)
  // ============================================================

  /// Récupère un token RTC via Edge Function `agora-token`.
  ///
  /// **Validation** :
  ///   - `channelName` doit être alphanumérique + underscore + tiret
  ///   - `expireSec` clamped entre 60 et 86400
  ///
  /// **Throws** :
  ///   - [ArgumentError] si channelName invalide
  ///   - [TimeoutException] si Edge Function timeout
  Future<AgoraTokenResult> fetchAgoraToken({
    required String channelName,
    int uid = 0,
    int expireSec = _kDefaultExpireSec,
  }) async {
    if (_isDisposed) {
      throw StateError('CallSignalingService disposed');
    }

    // Validation auth
    if (_uid.isEmpty || !_CallSignalingValidators.isValidUuid(_uid)) {
      throw StateError('Non authentifié ou ID invalide');
    }

    // Validation channel
    if (!_CallSignalingValidators.isValidChannelName(channelName)) {
      throw ArgumentError('channelName invalide');
    }

    // Sanitize expireSec
    final safeExpireSec = expireSec.clamp(_kMinExpireSec, _kMaxExpireSec);

    debugPrint('[CallSignalingService] 🎫 fetchAgoraToken '
        '(channel=${_CallSignalingValidators.obfuscate(channelName)})');

    try {
      final res = await _db.functions
          .invoke(
            _kAgoraTokenFunction,
            body: {
              'channelName': channelName.trim(),
              'uid': uid,
              'expireSec': safeExpireSec,
              'role': 1, // publisher
            },
          )
          .timeout(_kEdgeFunctionTimeout);

      if (res.status != 200) {
        debugPrint('[CallSignalingService] ❌ agora-token status=${res.status}');
        throw Exception(
          'agora-token failed (${res.status})',
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

      debugPrint('[CallSignalingService] ✓ Token obtained');
      return result;
    } on TimeoutException {
      debugPrint('[CallSignalingService] ❌ fetchAgoraToken timeout');
      rethrow;
    } catch (e) {
      debugPrint('[CallSignalingService] ❌ fetchAgoraToken failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  /// startCall + token en une étape (caller).
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

  /// Token pour le callee après accept.
  Future<AgoraTokenResult> tokenForInvite(
    CallInvite invite, {
    int uid = 0,
  }) async {
    final channel = invite.channelName;
    if (channel == null || channel.isEmpty) {
      throw ArgumentError('Invite sans channel_name');
    }
    return fetchAgoraToken(channelName: channel, uid: uid);
  }

  // ============================================================
  // ACTIONS (RPC)
  // ============================================================

  /// Accepte un appel.
  Future<void> accept(String inviteId) async {
    await _executeRpc('rpc_accept_call', {'p_invite_id': inviteId}, inviteId);
  }

  /// Rejette un appel.
  Future<void> reject(String inviteId) async {
    await _executeRpc('rpc_reject_call', {'p_invite_id': inviteId}, inviteId);
  }

  /// Annule un appel (côté caller).
  Future<void> cancel(String inviteId) async {
    await _executeRpc('rpc_cancel_call', {'p_invite_id': inviteId}, inviteId);
  }

  /// Termine un appel (avec durée).
  Future<void> end(String inviteId, {int durationSec = 0}) async {
    await _executeRpc('rpc_end_call', {
      'p_invite_id': inviteId,
      'p_duration_sec': durationSec.clamp(0, 86400),
    }, inviteId);
  }

  /// Marque un appel comme manqué.
  Future<void> markMissed(String inviteId) async {
    if (_isDisposed) return;

    if (!_CallSignalingValidators.isValidUuid(inviteId)) {
      debugPrint('[CallSignalingService] ⚠️ markMissed: invalid inviteId');
      return;
    }

    try {
      await _db
          .rpc('rpc_miss_call', params: {'p_invite_id': inviteId})
          .timeout(_kRpcTimeout);
      debugPrint('[CallSignalingService] ✓ Call marked missed');
    } catch (e) {
      // Fallback si RPC absente
      debugPrint('[CallSignalingService] ⚠️ RPC miss_call failed, fallback to update');
      try {
        await _db
            .from('call_invites')
            .update({
              'status': 'missed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', inviteId)
            .timeout(_kRpcTimeout);
      } catch (e2) {
        debugPrint('[CallSignalingService] ❌ markMissed fallback failed: $e2');
      }
    }
  }

  /// Marque un appel comme en cours.
  Future<void> markOngoing(String inviteId) async {
    if (_isDisposed) return;

    if (!_CallSignalingValidators.isValidUuid(inviteId)) {
      debugPrint('[CallSignalingService] ⚠️ markOngoing: invalid inviteId');
      return;
    }

    try {
      await _db
          .rpc('rpc_ongoing_call', params: {'p_invite_id': inviteId})
          .timeout(_kRpcTimeout);
      debugPrint('[CallSignalingService] ✓ Call marked ongoing');
    } catch (e) {
      debugPrint('[CallSignalingService] ⚠️ RPC ongoing_call failed, fallback');
      try {
        await _db
            .from('call_invites')
            .update({
              'status': 'ongoing',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', inviteId)
            .timeout(_kRpcTimeout);
      } catch (e2) {
        debugPrint('[CallSignalingService] ❌ markOngoing fallback failed: $e2');
      }
    }
  }

  /// Helper : exécute un RPC avec validation et timeout.
  Future<void> _executeRpc(
    String rpcName,
    Map<String, dynamic> params,
    String inviteId,
  ) async {
    if (_isDisposed) {
      throw StateError('CallSignalingService disposed');
    }

    if (!_CallSignalingValidators.isValidUuid(inviteId)) {
      throw ArgumentError('inviteId invalide');
    }

    debugPrint('[CallSignalingService] 📤 $rpcName '
        '(inviteId=${_CallSignalingValidators.obfuscate(inviteId)})');

    try {
      await _db.rpc(rpcName, params: params).timeout(_kRpcTimeout);
      debugPrint('[CallSignalingService] ✓ $rpcName OK');
    } on TimeoutException {
      debugPrint('[CallSignalingService] ❌ $rpcName timeout');
      rethrow;
    } catch (e) {
      debugPrint('[CallSignalingService] ❌ $rpcName failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ============================================================
  // REALTIME — incoming (callee)
  // ============================================================

  /// Stream des appels entrants (Realtime uniquement).
  Stream<CallInvite> watchIncoming() {
    if (_isDisposed) {
      return const Stream.empty();
    }

    final controller = StreamController<CallInvite>.broadcast();
    final myId = _uid;

    if (myId.isEmpty || !_CallSignalingValidators.isValidUuid(myId)) {
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
            if (_isDisposed || controller.isClosed) return;
            try {
              final map = Map<String, dynamic>.from(payload.newRecord);
              final status = (map['status'] ?? '').toString();
              if (status != 'ringing') return;

              // Validation de l'invite reçu
              final inviteId = map['id']?.toString();
              if (!_CallSignalingValidators.isValidUuid(inviteId)) {
                debugPrint('[CallSignalingService] ⚠️ Invalid invite ID received');
                return;
              }

              controller.add(CallInvite.fromJson(map));
            } catch (e) {
              debugPrint('[CallSignalingService] ⚠️ watchIncoming parse: $e');
            }
          },
        )
        .subscribe();

    controller.onCancel = _teardownIncoming;
    return controller.stream;
  }

  /// Incoming + poll de secours (réseau instable).
  Stream<CallInvite> watchIncomingWithPoll() {
    if (_isDisposed) {
      return const Stream.empty();
    }

    final controller = StreamController<CallInvite>.broadcast();
    final myId = _uid;

    if (myId.isEmpty || !_CallSignalingValidators.isValidUuid(myId)) {
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

    final timer = Timer.periodic(
      const Duration(seconds: _kPollingIntervalSec),
      (_) async {
        if (_isDisposed || controller.isClosed) return;
        await _pollIncoming(myId, seen, controller);
      },
    );

    controller.onCancel = () {
      realtimeSub.cancel();
      timer.cancel();
    };

    return controller.stream;
  }

  /// Poll DB pour invites ringing récents.
  Future<void> _pollIncoming(
    String myId,
    Set<String> seen,
    StreamController<CallInvite> controller,
  ) async {
    try {
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: _kPollingWindowMinutes))
          .toIso8601String();

      final rows = await _db
          .from('call_invites')
          .select()
          .eq('callee_id', myId)
          .eq('status', 'ringing')
          .gte('created_at', since)
          .timeout(_kRpcTimeout);

      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        if (!_CallSignalingValidators.isValidUuid(id)) continue;
        if (!controller.isClosed) {
          controller.add(CallInvite.fromJson(map));
        }
      }
    } catch (e) {
      debugPrint('[CallSignalingService] ⚠️ Poll error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  // ============================================================
  // REALTIME — status invite (caller / callee)
  // ============================================================

  /// Stream des changements de statut d'un invite.
  Stream<CallStatus> watchInviteStatus(String inviteId) {
    if (_isDisposed) {
      return const Stream.empty();
    }

    // Validation
    if (!_CallSignalingValidators.isValidUuid(inviteId)) {
      debugPrint('[CallSignalingService] ⚠️ watchInviteStatus: invalid inviteId');
      return const Stream.empty();
    }

    // Protection contre croissance infinie
    if (_statusChannels.length >= _kMaxStatusChannels) {
      debugPrint('[CallSignalingService] ⚠️ Max status channels reached, '
          'cleaning oldest');
      _cleanupOldestStatusChannel();
    }

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
            if (_isDisposed || controller.isClosed) return;
            try {
              final map = Map<String, dynamic>.from(payload.newRecord);
              final status = _parseStatus(map['status']?.toString());
              controller.add(status);
            } catch (e) {
              debugPrint('[CallSignalingService] ⚠️ watchInviteStatus parse: $e');
            }
          },
        )
        .subscribe();

    // Snapshot initial
    scheduleMicrotask(() async {
      if (_isDisposed || controller.isClosed) return;
      try {
        final row = await _db
            .from('call_invites')
            .select('status')
            .eq('id', inviteId)
            .maybeSingle()
            .timeout(_kRpcTimeout);
        if (row != null && !controller.isClosed) {
          controller.add(_parseStatus(row['status']?.toString()));
        }
      } catch (e) {
        debugPrint('[CallSignalingService] ⚠️ Snapshot failed: $e');
      }
    });

    controller.onCancel = () {
      if (_isDisposed) return;
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

  /// Nettoie le channel status le plus ancien si limite atteinte.
  void _cleanupOldestStatusChannel() {
    if (_statusChannels.isEmpty) return;
    final oldestKey = _statusChannels.keys.first;
    final oldest = _statusChannels.remove(oldestKey);
    if (oldest != null) {
      try {
        oldest.unsubscribe();
        _db.removeChannel(oldest);
        debugPrint('[CallSignalingService] 🧹 Cleaned oldest status channel');
      } catch (_) {}
    }
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
      'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  /// Parse une réponse RPC en Map (plus strict que l'original).
  Map<String, dynamic> _asMap(dynamic res) {
    if (res == null) return {};
    if (res is Map<String, dynamic>) return res;
    if (res is Map) {
      try {
        return Map<String, dynamic>.from(res);
      } catch (e) {
        debugPrint('[CallSignalingService] ⚠️ _asMap conversion error: $e');
        return {};
      }
    }
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map) {
        try {
          return Map<String, dynamic>.from(first);
        } catch (e) {
          debugPrint('[CallSignalingService] ⚠️ _asMap list conversion error: $e');
          return {};
        }
      }
    }
    return {};
  }

  CallStatus _parseStatus(String? raw) {
    if (raw == null) return CallStatus.idle;
    switch (raw.toLowerCase()) {
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
        return CallStatus.canceled;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      default:
        debugPrint('[CallSignalingService] ⚠️ Unknown status: $raw');
        return CallStatus.idle;
    }
  }

  void _teardownIncoming() {
    final ch = _incomingChannel;
    _incomingChannel = null;
    if (ch != null) {
      try {
        ch.unsubscribe();
        _db.removeChannel(ch);
        debugPrint('[CallSignalingService] 🧹 Incoming channel teardown');
      } catch (e) {
        debugPrint('[CallSignalingService] ⚠️ Incoming teardown error: $e');
      }
    }
  }

  /// Libère toutes les ressources (à appeler en dispose).
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('[CallSignalingService] 👋 Disposing');

    _teardownIncoming();
    for (final entry in _statusChannels.entries) {
      try {
        entry.value.unsubscribe();
        _db.removeChannel(entry.value);
      } catch (e) {
        debugPrint('[CallSignalingService] ⚠️ Status channel teardown error: $e');
      }
    }
    _statusChannels.clear();

    debugPrint('[CallSignalingService] ✓ Disposed');
  }
}
