// lib/presentation/thix_market/widgets/live/live_stream_player.dart
// ============================================================================
// LIVE STREAM PLAYER — Production Enterprise v6
// ----------------------------------------------------------------------------
//  • ✅ Erreurs de connexion visibles (écran + Réessayer) — plus de spinner infini
//  • ✅ Token toujours frais, retry auto sur erreur de token, timeout de join 20 s
//  • ✅ Heartbeat hôte (last_heartbeat_at) toutes les 25 s
//  • ✅ Fin de live vérifiée (0 ligne mise à jour = alerte visible)
//  • ✅ Agora libéré proprement (stopPreview + leave + release attendus)
//  • ✅ Spectateurs éjectés quand le live passe à ended (realtime + polling)
//  • ✅ Navigation via go_router (plus de Navigator.pop)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'package:thix_id/presentation/thix_market/widgets/live/live_host_control_panel.dart';
import 'package:thix_id/presentation/thix_market/widgets/live/live_viewer_carousel.dart';
import 'package:thix_id/presentation/thix_market/widgets/live/live_voting_panel.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart';
import 'package:thix_id/services/live_shopping_service.dart';

// ============================================================================
// PROVIDER LOCAL — Nombre de produits épinglés (pour badge bouton hôte)
// ============================================================================
final _pinnedCountProvider = StreamProvider.family<int, String>((ref, sessionId) {
  return Supabase.instance.client
      .from('live_pinned_products')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .isFilter('unpinned_at', null)
      .map((rows) => rows.length);
});

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class LiveStreamPlayer extends ConsumerStatefulWidget {
  final String channelName;
  final String liveId;

  /// Conservé pour compatibilité avec la route, mais ignoré :
  /// un token frais est toujours demandé à generate-rtc-token.
  final String? token;
  final bool isHost;

  const LiveStreamPlayer({
    super.key,
    required this.channelName,
    required this.liveId,
    this.token,
    this.isHost = false,
  });

  @override
  ConsumerState<LiveStreamPlayer> createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends ConsumerState<LiveStreamPlayer> with WidgetsBindingObserver {
  RtcEngine? _engine;
  bool _isJoined = false;
  int _remoteUid = 0;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  bool _isEnding = false;
  bool _isLoadingToken = true;
  bool _hostEnded = false;
  bool _recovering = false;
  int _tokenRetries = 0;
  String? _error;
  String? _fetchedToken;
  int _viewerCount = 0;

  /// Valeurs résolues (extra route OU table live_sessions)
  late String _channelName;
  late bool _isHost;

  final TextEditingController _messageController = TextEditingController();

  Timer? _tokenRefreshTimer;
  Timer? _heartbeatTimer;
  Timer? _statusPollTimer;
  Timer? _joinTimeout;
  RealtimeChannel? _statusChannel;

  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Duration _kTokenRefreshInterval = Duration(minutes: 45);
  static const Duration _kHeartbeatInterval = Duration(seconds: 25);
  static const Duration _kStatusPollInterval = Duration(seconds: 10);
  static const Duration _kJoinTimeout = Duration(seconds: 20);

  // ══════════════════════════════════════════════════════════════════════
  // CYCLE DE VIE
  // ══════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _channelName = widget.channelName.trim();
    _isHost = widget.isHost;
    WidgetsBinding.instance.addObserver(this);
    _initializeLive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    _joinTimeout?.cancel();
    try {
      _statusChannel?.unsubscribe();
    } catch (_) {}
    _messageController.dispose();

    // Best-effort : l'hôte quitte sans passer par "Terminer" → couper le live en DB
    if (_isHost && !_isEnding && !_hostEnded) {
      unawaited(_markEndedInDb());
    }
    unawaited(_shutdownEngine());

    debugPrint('[LivePlayer] 👋 Disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (_isHost && _engine != null) {
          _engine?.muteLocalAudioStream(true);
          _engine?.muteLocalVideoStream(true);
        }
        break;
      case AppLifecycleState.resumed:
        if (_isHost && _engine != null) {
          if (!_isMuted) _engine?.muteLocalAudioStream(false);
          if (!_isVideoOff) _engine?.muteLocalVideoStream(false);
        }
        if (!_isEnding && !_hostEnded) unawaited(_checkStillLive());
        break;
      case AppLifecycleState.detached:
        if (_isHost && !_isEnding) unawaited(_markEndedInDb());
        break;
      default:
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════
  /// Traduction avec repli (les clés l10n manquantes renvoient la clé brute)
  String _t(String key, String fallback) {
    final s = AppLocalizations.of(context).t(key);
    return s == key ? fallback : s;
  }

  String _friendly(Object e) {
    var m = e.toString().replaceFirst('Exception: ', '');
    m = m.split('\n').first.trim();
    if (m.length > 220) m = m.substring(0, 220);
    return m;
  }

  bool _looksLikeTokenError(String s) => s.toLowerCase().contains('token');

  void _setError(String msg) {
    if (!mounted) return;
    _joinTimeout?.cancel();
    debugPrint('[LivePlayer] ❌ $msg');
    setState(() {
      _error = msg;
      _isLoadingToken = false;
    });
  }

  void _leavePage() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/market/live');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DB : fin de live / heartbeat / statut
  // ══════════════════════════════════════════════════════════════════════
  /// Retourne true si la base a bien enregistré la fin du live
  Future<bool> _markEndedInDb() async {
    try {
      final rows = await Supabase.instance.client
          .from('live_sessions')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.liveId)
          .select('id');
      final ok = (rows as List).isNotEmpty;
      debugPrint(ok
          ? '[LivePlayer] ✓ Live marqué ended en DB'
          : '[LivePlayer] ⚠️ 0 ligne mise à jour (RLS ?) — live toujours actif en DB');
      return ok;
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ markEnded: $e');
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    unawaited(_sendHeartbeat());
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) => _sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    try {
      await Supabase.instance.client.from('live_sessions').update({
        'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.liveId);
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ heartbeat: $e');
    }
  }

  void _startStatusWatch() {
    try {
      _statusChannel?.unsubscribe();
      _statusChannel = Supabase.instance.client
          .channel('live_status_${widget.liveId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'live_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.liveId,
            ),
            callback: (payload) {
              if (payload.newRecord['status']?.toString() == 'ended') {
                unawaited(_onRemoteEnded());
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ status realtime: $e');
    }
    // Filet de sécurité si le realtime n'est pas activé sur la table
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(_kStatusPollInterval, (_) => _checkStillLive());
  }

  Future<void> _checkStillLive() async {
    if (!mounted || _isEnding || _hostEnded) return;
    try {
      final s = await Supabase.instance.client
          .from('live_sessions')
          .select('status')
          .eq('id', widget.liveId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (s != null && s['status']?.toString() == 'ended') {
        await _onRemoteEnded();
      }
    } catch (_) {}
  }

  Future<void> _onRemoteEnded() async {
    if (!mounted || _isEnding || _hostEnded) return;
    debugPrint('[LivePlayer] 🛑 Live terminé (statut DB)');
    _tokenRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    await _shutdownEngine();
    if (mounted) {
      setState(() {
        _hostEnded = true;
        _isJoined = false;
        _remoteUid = 0;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // RÉSOLUTION SESSION (channel + rôle hôte)
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _resolveSession() async {
    final me = Supabase.instance.client.auth.currentUser?.id;

    final session = await Supabase.instance.client
        .from('live_sessions')
        .select('channel_name, host_id, status')
        .eq('id', widget.liveId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));

    if (session == null) {
      throw Exception('Live introuvable');
    }

    final status = session['status']?.toString() ?? '';
    if (status == 'ended') {
      throw Exception('Ce live est terminé');
    }

    final dbChannel = session['channel_name']?.toString().trim() ?? '';
    if (dbChannel.isNotEmpty) {
      _channelName = dbChannel;
    }

    if (_channelName.isEmpty) {
      throw Exception('channel_name manquant pour ce live');
    }

    final hostId = session['host_id']?.toString();
    if (me != null && hostId != null && hostId == me) {
      _isHost = true;
    }

    debugPrint('[LivePlayer] Resolved channel=$_channelName isHost=$_isHost status=$status');
  }

  // ══════════════════════════════════════════════════════════════════════
  // TOKEN
  // ══════════════════════════════════════════════════════════════════════
  Future<Map<String, String>> _fetchToken() async {
    final response = await Supabase.instance.client.functions
        .invoke(
          'generate-rtc-token',
          body: {
            'channelName': _channelName,
            'role': _isHost ? 'publisher' : 'subscriber',
          },
        )
        .timeout(const Duration(seconds: 15));

    final data = response.data;
    if (data is! Map) {
      throw Exception('Réponse token invalide (generate-rtc-token)');
    }
    final appId = data['appId']?.toString() ?? '';
    final token = data['token']?.toString() ?? '';
    if (appId.isEmpty) throw Exception('App ID Agora manquant');
    if (token.isEmpty) throw Exception('Token Agora vide');
    if (token.startsWith('test_token_')) {
      throw Exception('Token de test invalide — vérifiez generate-rtc-token');
    }
    return {'appId': appId, 'token': token};
  }

  /// Renouvellement pendant le live (hôte et spectateur)
  Future<void> _refreshToken() async {
    try {
      final creds = await _fetchToken();
      final eng = _engine;
      if (eng != null) {
        await eng.renewToken(creds['token']!);
        _fetchedToken = creds['token'];
        debugPrint('[LivePlayer] 🔄 Token refreshed');
      }
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ Token refresh failed: $e');
    }
  }

  /// Token refusé par Agora : on en redemande un frais (2 essais max)
  Future<void> _recoverFromTokenError() async {
    if (_recovering || !mounted) return;
    _recovering = true;
    try {
      if (_tokenRetries >= 2) {
        _setError('Token Agora refusé après 2 essais. Vérifiez le déploiement de '
            'generate-rtc-token et le certificat Agora.');
        return;
      }
      _tokenRetries++;
      debugPrint('[LivePlayer] 🔁 Token refusé — nouvel essai $_tokenRetries/2');
      final creds = await _fetchToken();
      _fetchedToken = creds['token'];
      final eng = _engine;
      if (eng == null) return;
      if (_isJoined) {
        await eng.renewToken(creds['token']!);
      } else {
        await eng.leaveChannel();
        await _joinChannel(creds['token']!);
      }
    } catch (e) {
      _setError(_friendly(e));
    } finally {
      _recovering = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // AGORA : init / join / shutdown
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _initializeLive() async {
    if (mounted) {
      setState(() {
        _isLoadingToken = true;
        _error = null;
      });
    }
    try {
      await _resolveSession();
      if (mounted) setState(() {}); // rafraîchir l'UI avec _isHost réel

      await [Permission.microphone, Permission.camera].request();

      final creds = await _fetchToken();
      _fetchedToken = creds['token'];

      await _setupEngineAndJoin(creds['appId']!, creds['token']!);

      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = Timer.periodic(_kTokenRefreshInterval, (_) => _refreshToken());
      _startStatusWatch();

      if (_isHost) {
        _startHeartbeat();
        await _applyPrePinned();
      }
    } catch (e) {
      debugPrint('[LivePlayer] ❌ Init error: $e');
      await _shutdownEngine();
      _setError(_friendly(e));
    } finally {
      if (mounted) setState(() => _isLoadingToken = false);
    }
  }

  Future<void> _setupEngineAndJoin(String appId, String token) async {
    final eng = createAgoraRtcEngine();
    _engine = eng;

    await eng.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await eng.enableVideo();

    eng.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _joinTimeout?.cancel();
          if (mounted) {
            setState(() {
              _isJoined = true;
              _error = null;
            });
          }
          debugPrint('[LivePlayer] ✓ Joined channel: ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          if (mounted) setState(() => _remoteUid = uid);
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          if (mounted) setState(() => _remoteUid = 0);
        },
        onRtcStats: (RtcConnection connection, RtcStats stats) {
          if (mounted && _isHost) {
            final n = (stats.userCount ?? 1) - 1; // sans l'hôte
            setState(() => _viewerCount = n < 0 ? 0 : n);
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          unawaited(_refreshToken());
        },
        onRequestToken: (RtcConnection connection) {
          unawaited(_refreshToken());
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[LivePlayer] ❌ Agora error [$err]: $msg');
          if (!_isJoined && _looksLikeTokenError('$err $msg')) {
            unawaited(_recoverFromTokenError());
          }
        },
        onConnectionStateChanged:
            (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[LivePlayer] 🔗 Connection state: $state (reason: $reason)');
          if (state == ConnectionStateType.connectionStateFailed) {
            if (_looksLikeTokenError('$reason')) {
              unawaited(_recoverFromTokenError());
            } else {
              _setError('Connexion au direct impossible ($reason)');
            }
          } else if (state == ConnectionStateType.connectionStateDisconnected) {
            if (mounted && _isJoined) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('live_connection_lost', 'Connexion perdue, reconnexion…')),
                  backgroundColor: danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else if (state == ConnectionStateType.connectionStateConnected) {
            if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        },
      ),
    );

    await eng.setClientRole(
      role: _isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
    );

    if (_isHost) {
      await eng.startPreview();
    }

    await _joinChannel(token);
  }

  Future<void> _joinChannel(String token) async {
    final eng = _engine;
    if (eng == null) return;

    _joinTimeout?.cancel();
    _joinTimeout = Timer(_kJoinTimeout, () {
      if (!_isJoined && mounted && _error == null && !_recovering) {
        _setError('Connexion au direct impossible (délai dépassé). '
            'Vérifiez votre réseau puis réessayez.');
      }
    });

    await eng.joinChannel(
      token: token,
      channelId: _channelName,
      uid: 0,
      options: ChannelMediaOptions(
        publishCameraTrack: _isHost && !_isVideoOff,
        publishMicrophoneTrack: _isHost && !_isMuted,
        clientRoleType:
            _isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      ),
    );
  }

  /// Libération complète d'Agora (caméra / micro coupés)
  Future<void> _shutdownEngine() async {
    final eng = _engine;
    _engine = null;
    _joinTimeout?.cancel();
    if (eng == null) return;
    try {
      if (_isHost) await eng.stopPreview();
    } catch (_) {}
    try {
      await eng.leaveChannel();
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ leaveChannel: $e');
    }
    try {
      await eng.release();
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ release: $e');
    }
    _isJoined = false;
    debugPrint('[LivePlayer] ✓ Engine released');
  }

  Future<void> _retry() async {
    HapticFeedback.selectionClick();
    _tokenRetries = 0;
    _recovering = false;
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    _tokenRefreshTimer?.cancel();
    await _shutdownEngine();
    if (mounted) {
      setState(() {
        _isJoined = false;
        _remoteUid = 0;
      });
    }
    await _initializeLive();
  }

  Future<void> _applyPrePinned() async {
    try {
      final session = await Supabase.instance.client
          .from('live_sessions')
          .select('pre_pinned_products, allow_voting, allow_dynamic_control')
          .eq('id', widget.liveId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final prePinned = List<String>.from((session?['pre_pinned_products'] as List?) ?? []);
      if (prePinned.isNotEmpty) {
        await LiveShoppingService().applyPrePinned(widget.liveId, prePinned);
        debugPrint('[LiveShopping] Pre-pinned ${prePinned.length} products');
      }
    } catch (e) {
      debugPrint('[LiveShopping] Pre-pin apply failed (non-critical): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTRÔLES HOST
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoOff = !_isVideoOff);
    if (_isVideoOff) {
      await _engine?.muteLocalVideoStream(true);
      await _engine?.disableVideo();
    } else {
      await _engine?.enableVideo();
      await _engine?.muteLocalVideoStream(false);
      if (_isHost) await _engine?.startPreview();
    }
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _endLive() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _tokenRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();

    final ok = await _markEndedInDb();
    await _shutdownEngine();

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'live_end_not_confirmed',
            'Diffusion arrêtée, mais le serveur n\'a pas confirmé la fin du live (droits de mise à jour).',
          )),
          backgroundColor: danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _leavePage();
  }

  Future<void> _confirmEndLive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('live_end_confirm_title', 'Terminer le live ?'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          _t('live_end_confirm_desc', 'La diffusion sera arrêtée pour tous les spectateurs.'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('common_cancel', 'Annuler'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('live_end_confirm_btn', 'Terminer'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await _endLive();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('live_comments').insert({
        'live_id': widget.liveId,
        'user_id': userId,
        'comment': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      try {
        await Supabase.instance.client.from('live_messages').insert({
          'live_id': widget.liveId,
          'user_id': userId,
          'message': text,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[LivePlayer] ❌ Send message error: $e');
      }
    }

    _messageController.clear();
  }

  Future<void> _openHostControlPanel() async {
    List<String> productIds = [];
    try {
      final session = await Supabase.instance.client
          .from('live_sessions')
          .select('products')
          .eq('id', widget.liveId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      productIds = List<String>.from((session?['products'] as List?) ?? []);
    } catch (e) {
      debugPrint('[LivePlayer] ❌ Load products failed: $e');
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LiveHostControlPanel(
        sessionId: widget.liveId,
        availableProductIds: productIds,
      ),
    );
  }

  Future<void> _openVotingPanel() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LiveVotingPanel(sessionId: widget.liveId),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildVideo() {
    if (!_isJoined || _engine == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_isHost) {
      if (_isVideoOff) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              Text(
                _t('live_camera_off', 'Caméra désactivée'),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      }
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    if (_remoteUid != 0) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channelName),
        ),
      );
    }

    return Center(
      child: Text(
        _t('live_waiting_host', 'En attente de l\'hôte…'),
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B1F44),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: Color(0xFF1D2333), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline_rounded, color: danger, size: 56),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('live_connection_error_title', 'Erreur de connexion'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF5350), fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(_t('live_retry', 'Réessayer'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6BDE),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isHost ? _endLive : _leavePage,
                  child: Text(
                    _isHost
                        ? _t('live_end_and_leave', 'Terminer le live et quitter')
                        : _t('live_back', 'Retour'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndedView() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B1F44),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv_rounded, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  _t('live_ended_title', 'Le live est terminé'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _leavePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(_t('live_back', 'Retour'),
                      style: const TextStyle(color: Color(0xFF1B2A4A), fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hostControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDanger = false,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDanger ? danger : Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinnedCountAsync = _isHost ? ref.watch(_pinnedCountProvider(widget.liveId)) : null;
    final pinnedCount = pinnedCountAsync?.valueOrNull ?? 0;

    return PopScope(
      canPop: !_isHost || _hostEnded,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isHost && _error != null) {
          await _endLive();
          return;
        }
        if (_isHost) await _confirmEndLive();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoadingToken
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: gold),
                    const SizedBox(height: 12),
                    Text(_t('live_connecting', 'Connexion au direct…'),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : _error != null
                ? _buildErrorView()
                : _hostEnded
                    ? _buildEndedView()
                    : Stack(
                        children: [
                          Positioned.fill(child: _buildVideo()),

                          Positioned(
                            top: 0, left: 0, right: 0, height: 140,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 0, left: 0, right: 0, height: 220,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: MediaQuery.of(context).padding.top + 12,
                            left: 16,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: danger,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                                      SizedBox(width: 4),
                                      Text('LIVE',
                                          style: TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (_isHost) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.visibility_rounded, color: Colors.white70, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_viewerCount',
                                          style: const TextStyle(
                                              color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          Positioned(
                            top: MediaQuery.of(context).padding.top + 8,
                            right: 12,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              onPressed: _isHost ? (_isEnding ? null : _confirmEndLive) : _leavePage,
                            ),
                          ),

                          if (_isHost)
                            Positioned(
                              bottom: 90,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _hostControlButton(
                                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                    isDanger: _isMuted,
                                    onTap: _toggleMute,
                                  ),
                                  const SizedBox(width: 14),
                                  _hostControlButton(
                                    icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                    isDanger: _isVideoOff,
                                    onTap: _toggleVideo,
                                  ),
                                  const SizedBox(width: 14),
                                  _hostControlButton(
                                    icon: Icons.flip_camera_ios_rounded,
                                    onTap: _switchCamera,
                                  ),
                                  const SizedBox(width: 14),
                                  _hostControlButton(
                                    icon: Icons.call_end_rounded,
                                    isDanger: true,
                                    onTap: _isEnding ? () {} : _confirmEndLive,
                                  ),
                                ],
                              ),
                            ),

                          if (!_isHost)
                            Positioned(
                              bottom: 90,
                              right: 16,
                              child: FloatingActionButton(
                                mini: true,
                                backgroundColor: Colors.black54,
                                elevation: 0,
                                onPressed: () {
                                  setState(() => _isMuted = !_isMuted);
                                  _engine?.muteAllRemoteAudioStreams(_isMuted);
                                },
                                child: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                          Positioned(
                            bottom: 20,
                            left: 16,
                            right: 16,
                            child: SafeArea(
                              top: false,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      style: const TextStyle(color: Colors.black87),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      decoration: InputDecoration(
                                        hintText: _t('live_message_hint', 'Écrire un message…'),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: gold,
                                    child: IconButton(
                                      onPressed: _sendMessage,
                                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_isHost && _isJoined)
                            Positioned(
                              bottom: 160,
                              right: 16,
                              child: GestureDetector(
                                onTap: _openHostControlPanel,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: gold,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: gold.withOpacity(0.55), blurRadius: 14, spreadRadius: 1),
                                          BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3)),
                                        ],
                                      ),
                                      child: const Icon(Icons.shopping_bag_rounded,
                                          color: Color(0xFF1B2A4A), size: 24),
                                    ),
                                    if (pinnedCount > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                          decoration: BoxDecoration(
                                            color: danger,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 2),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            pinnedCount > 99 ? '99+' : '$pinnedCount',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                          if (!_isHost && _isJoined)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 80,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 260),
                                child: LiveViewerCarousel(
                                  sessionId: widget.liveId,
                                  onOpenVoting: _openVotingPanel,
                                ),
                              ),
                            ),

                          if (_isEnding)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: Colors.white),
                                    const SizedBox(height: 12),
                                    Text(_t('live_ending', 'Fermeture du live…'),
                                        style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}
