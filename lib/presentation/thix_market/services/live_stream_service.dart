// lib/presentation/thix_market/services/live_stream_service.dart
// ============================================================================
// LIVE STREAM SERVICE — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ App ID récupéré dynamiquement via Edge Function (plus de hardcode)
//  • ✅ Gestion erreurs robuste + retry automatique
//  • ✅ Token refresh automatique (avant expiration Agora ~1h)
//  • ✅ État thread-safe + guards mounted/disposed
//  • ✅ Tables unifiées live_sessions / live_comments / auction_bids
//  • ✅ Logging structuré pour debugging production
//  • ✅ Dispose sécurisé (double-call safe)
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 10);
const Duration _kTokenRefreshBuffer = Duration(minutes: 10); // Refresh 10min avant expiration
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

// ============================================================================
// EXCEPTIONS PERSONNALISÉES
// ============================================================================
class LiveStreamException implements Exception {
  final String message;
  final Object? cause;
  const LiveStreamException(this.message, [this.cause]);

  @override
  String toString() => 'LiveStreamException: $message${cause != null ? ' ($cause)' : ''}';
}

// ============================================================================
// SERVICE
// ============================================================================
class LiveStreamService {
  final SupabaseClient _supabase = Supabase.instance.client;

  RtcEngine? _engine;
  bool _isHost = false;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isDisposed = false;

  int _remoteUid = 0;
  String? _currentChannel;
  String? _currentLiveId;
  Timer? _tokenRefreshTimer;

  // Callbacks pour notifier le widget UI (sans couplage direct)
  VoidCallback? onJoinSuccess;
  VoidCallback? onUserJoined;
  VoidCallback? onUserOffline;
  ValueChanged<String>? onError;

  // ─── GETTERS ───
  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  int get remoteUid => _remoteUid;
  RtcEngine? get engine => _engine;

  // ══════════════════════════════════════════════════════════════════════
  // INIT ENGINE
  // ══════════════════════════════════════════════════════════════════════
  Future<void> initEngine({required bool isHost}) async {
    if (_isDisposed) throw const LiveStreamException('Service already disposed');

    _isHost = isHost;

    // Demander permissions
    final statuses = await [Permission.microphone, Permission.camera].request();
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted = statuses[Permission.camera]?.isGranted ?? false;

    if (!micGranted || !camGranted) {
      debugPrint('[LiveService] ⚠️ Permissions not fully granted: mic=$micGranted, cam=$camGranted');
    }

    // ✅ Récupérer App ID depuis Edge Function (plus de hardcode)
    final appId = await _fetchAppId();
    if (appId.isEmpty) {
      throw const LiveStreamException('Impossible de récupérer l\'App ID Agora');
    }

    _engine = createAgoraRtcEngine();

    await _engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine!.enableVideo();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[LiveService] ✓ Joined channel: ${connection.channelId}');
          _isJoined = true;
          onJoinSuccess?.call();
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          debugPrint('[LiveService] 👤 User joined: $uid');
          _remoteUid = uid;
          onUserJoined?.call();
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          debugPrint('[LiveService] 👤 User offline: $uid (reason: $reason)');
          _remoteUid = 0;
          onUserOffline?.call();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[LiveService] ❌ Agora error [$err]: $msg');
          onError?.call(msg);
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[LiveService] 🔗 State: $state (reason: $reason)');
        },
      ),
    );

    await _engine!.setClientRole(
      role: isHost
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    debugPrint('[LiveService] ✓ Engine initialized (host=$isHost)');
  }

  /// ✅ Récupère l'App ID Agora via Edge Function
  Future<String> _fetchAppId() async {
    try {
      final response = await _supabase.functions
          .invoke('generate-rtc-token', body: {'channelName': '_init_', 'role': 'subscriber'})
          .timeout(_kRequestTimeout);
      return response.data?['appId']?.toString() ?? '';
    } catch (e) {
      debugPrint('[LiveService] ❌ Fetch App ID error: $e');
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // JOIN CHANNEL (avec retry)
  // ══════════════════════════════════════════════════════════════════════
  Future<void> joinChannel({
    required String channelName,
    required String token,
    String? liveId,
  }) async {
    if (_engine == null || _isDisposed) {
      throw const LiveStreamException('Engine not initialized or disposed');
    }

    _currentChannel = channelName;
    _currentLiveId = liveId;

    await _withRetry(
      () async {
        await _engine!.joinChannel(
          token: token,
          channelId: channelName,
          uid: 0,
          options: ChannelMediaOptions(
            publishCameraTrack: _isHost && _isVideoEnabled,
            publishMicrophoneTrack: _isHost && !_isMuted,
            clientRoleType: _isHost
                ? ClientRoleType.clientRoleBroadcaster
                : ClientRoleType.clientRoleAudience,
          ),
        );
      },
      label: 'joinChannel($channelName)',
    );

    // ✅ Démarrer le refresh token automatique
    _startTokenRefresh(channelName);

    debugPrint('[LiveService] ✓ Join requested: $channelName');
  }

  // ══════════════════════════════════════════════════════════════════════
  // TOKEN REFRESH AUTOMATIQUE
  // ══════════════════════════════════════════════════════════════════════
  void _startTokenRefresh(String channelName) {
    _tokenRefreshTimer?.cancel();
    // Agora tokens expirent après ~1h, on refresh toutes les 50min
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
      if (_isDisposed || !_isJoined || _currentChannel == null) return;
      try {
        final newToken = await getAgoraToken(channelName);
        if (newToken != null && _engine != null) {
          await _engine!.renewToken(newToken);
          debugPrint('[LiveService] 🔄 Token refreshed for $channelName');
        }
      } catch (e) {
        debugPrint('[LiveService] ⚠️ Token refresh failed: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // LEAVE CHANNEL
  // ══════════════════════════════════════════════════════════════════════
  Future<void> leaveChannel() async {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;

    if (_engine != null && _isJoined) {
      try {
        await _engine!.leaveChannel();
        debugPrint('[LiveService] ✓ Left channel: $_currentChannel');
      } catch (e) {
        debugPrint('[LiveService] ⚠️ Leave error: $e');
      }
    }

    _isJoined = false;
    _remoteUid = 0;
    _currentChannel = null;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTRÔLES AUDIO / VIDÉO
  // ══════════════════════════════════════════════════════════════════════
  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    debugPrint('[LiveService] 🎤 Mute: $_isMuted');
  }

  Future<void> toggleVideo() async {
    if (_engine == null) return;
    _isVideoEnabled = !_isVideoEnabled;
    if (_isVideoEnabled) {
      await _engine!.enableVideo();
      if (_isHost) await _engine!.startPreview();
    } else {
      await _engine!.muteLocalVideoStream(true);
      await _engine!.disableVideo();
    }
    debugPrint('[LiveService] 📹 Video: $_isVideoEnabled');
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  Future<void> muteAllRemoteAudio(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteAllRemoteAudioStreams(muted);
  }

  // ══════════════════════════════════════════════════════════════════════
  // AGORA TOKEN VIA EDGE FUNCTION
  // ══════════════════════════════════════════════════════════════════════
  Future<String?> getAgoraToken(String channelName) async {
    try {
      final response = await _supabase.functions
          .invoke('generate-rtc-token', body: {
            'channelName': channelName,
            'role': _isHost ? 'publisher' : 'subscriber',
          })
          .timeout(_kRequestTimeout);
      return response.data?['token'] as String?;
    } catch (e) {
      debugPrint('[LiveService] ❌ Get token error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // SUPABASE : LIVE SESSIONS (TABLE UNIFIÉE)
  // ══════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> createLiveSession({
    required String shopId,
    required String title,
    String? description,
    required List<String> productIds,
    bool hasAuction = false,
    double? startingPrice,
    DateTime? auctionEndTime,
    DateTime? scheduledStart,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const LiveStreamException('Authentification requise');

    final channelName = 'live_${DateTime.now().millisecondsSinceEpoch}';

    final liveData = {
      'shop_id': shopId,
      'host_id': userId,
      'title': title,
      'description': description,
      'channel_name': channelName,
      'products': productIds,
      'has_auction': hasAuction,
      'starting_price': startingPrice,
      'auction_end_time': auctionEndTime?.toUtc().toIso8601String(),
      'scheduled_start': (scheduledStart ?? DateTime.now().add(const Duration(minutes: 5))).toUtc().toIso8601String(),
      'status': 'scheduled',
      'source': 'market',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await _supabase
          .from('live_sessions')
          .insert(liveData)
          .select()
          .single()
          .timeout(_kRequestTimeout);
      debugPrint('[LiveService] ✓ Live session created: ${res['id']}');
      return res;
    } catch (e) {
      throw LiveStreamException('Erreur création live', e);
    }
  }

  Future<void> startLive(String liveId) async {
    await _withRetry(
      () => _supabase.from('live_sessions').update({
        'status': 'live',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', liveId).timeout(_kRequestTimeout),
      label: 'startLive($liveId)',
    );
    debugPrint('[LiveService] ✓ Live started: $liveId');
  }

  Future<void> endLive(String liveId) async {
    try {
      await _supabase.from('live_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', liveId).timeout(_kRequestTimeout);
      debugPrint('[LiveService] ✓ Live ended: $liveId');
    } catch (e) {
      debugPrint('[LiveService] ⚠️ End live DB error: $e');
    }
    await leaveChannel();
  }

  // ══════════════════════════════════════════════════════════════════════
  // VIEWERS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> incrementViewers(String liveId) async {
    try {
      await _supabase.rpc('increment_live_viewers', params: {'live_id': liveId}).timeout(_kRequestTimeout);
    } catch (e) {
      debugPrint('[LiveService] ⚠️ Increment viewers error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // LIVE COMMENTS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> sendComment(String liveId, String comment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('live_comments').insert({
        'live_id': liveId,
        'user_id': userId,
        'comment': comment,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_kRequestTimeout);
    } catch (e) {
      // Fallback table alternative
      try {
        await _supabase.from('live_messages').insert({
          'live_id': liveId,
          'user_id': userId,
          'message': comment,
          'created_at': DateTime.now().toUtc().toiso8601String(),
        }).timeout(_kRequestTimeout);
      } catch (e2) {
        debugPrint('[LiveService] ❌ Send comment error: $e2');
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getLiveComments(String liveId) {
    return _supabase
        .from('live_comments')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ══════════════════════════════════════════════════════════════════════
  // AUCTIONS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> placeBid(String auctionId, double amount) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const LiveStreamException('Authentification requise');

    await _withRetry(
      () => _supabase.rpc('place_bid', params: {
        'auction_id': auctionId,
        'bid_amount': amount,
      }).timeout(_kRequestTimeout),
      label: 'placeBid($auctionId)',
    );
    debugPrint('[LiveService] ✓ Bid placed: $amount on $auctionId');
  }

  Stream<List<Map<String, dynamic>>> getAuctionBids(String auctionId) {
    return _supabase
        .from('auction_bids')
        .stream(primaryKey: ['id'])
        .eq('auction_id', auctionId)
        .order('amount', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<double> getCurrentBid(String auctionId) async {
    try {
      final response = await _supabase
          .from('auctions')
          .select('current_bid')
          .eq('id', auctionId)
          .maybeSingle()
          .timeout(_kRequestTimeout);
      return (response?['current_bid'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('[LiveService] ⚠️ Get current bid error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPER : RETRY
  // ══════════════════════════════════════════════════════════════════════
  Future<T> _withRetry<T>(Future<T> Function() fn, {required String label, int maxRetries = _kMaxRetries}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on TimeoutException {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[LiveService] ❌ $label: timeout after $attempt attempts');
          throw LiveStreamException('$label: délai dépassé');
        }
        debugPrint('[LiveService] ⏱️ $label timeout — retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        if (e is LiveStreamException) rethrow;
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[LiveService] ❌ $label error after $attempt attempts: $e');
          throw LiveStreamException('$label: $e');
        }
        debugPrint('[LiveService] ⚠️ $label error — retry $attempt/$maxRetries: $e');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DISPOSE (double-call safe)
  // ══════════════════════════════════════════════════════════════════════
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;

    if (_engine != null) {
      try {
        if (_isJoined) await _engine!.leaveChannel();
        await _engine!.release();
        debugPrint('[LiveService] ✓ Engine released');
      } catch (e) {
        debugPrint('[LiveService] ⚠️ Dispose error: $e');
      }
      _engine = null;
    }

    _isJoined = false;
    _remoteUid = 0;
    _currentChannel = null;
    _currentLiveId = null;

    // Nettoyer callbacks
    onJoinSuccess = null;
    onUserJoined = null;
    onUserOffline = null;
    onError = null;

    debugPrint('[LiveService] 👋 Disposed');
  }
}
