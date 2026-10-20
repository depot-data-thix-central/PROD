// lib/presentation/thix_market/widgets/live/live_stream_player.dart
// ============================================================================
// LIVE STREAM PLAYER — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Pré-pin produits au démarrage du live (hôte)
//  • ✅ Overlay bouton "Produits" flottant avec badge compteur (hôte)
//  • ✅ Overlay carousel produits + bouton vote (spectateur)
//  • ✅ Positionnement corrigé (plus de chevauchement)
//  • ✅ Support FR / EN / SW via AppLocalizations
//  • ✅ Compteur spectateurs temps réel
//  • ✅ Gestion reconnexion réseau
//  • ✅ Zéro impact sur le flux vidéo Agora
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String? _fetchedToken;
  int _viewerCount = 0;

  final TextEditingController _messageController = TextEditingController();

  // Timer pour refresh token (Agora tokens expirent après ~1h)
  Timer? _tokenRefreshTimer;

  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Duration _kTokenRefreshInterval = Duration(minutes: 50);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshTimer?.cancel();
    _messageController.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    debugPrint('[LivePlayer] 👋 Disposed');
    super.dispose();
  }

  // ✅ Gestion cycle de vie app (pause/reprise)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isHost || _engine == null) return;
    switch (state) {
      case AppLifecycleState.paused:
        _engine?.muteLocalAudioStream(true);
        _engine?.muteLocalVideoStream(true);
        break;
      case AppLifecycleState.resumed:
        if (!_isMuted) _engine?.muteLocalAudioStream(false);
        if (!_isVideoOff) _engine?.muteLocalVideoStream(false);
        break;
      default:
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // INITIALISATION AGORA + PRÉ-PIN
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _initializeLive() async {
    try {
      await [Permission.microphone, Permission.camera].request();

      final response = await Supabase.instance.client.functions.invoke(
        'generate-rtc-token',
        body: {
          'channelName': widget.channelName,
          'role': widget.isHost ? 'publisher' : 'subscriber',
        },
      );

      final data = response.data;
      final String appId = data['appId']?.toString() ?? '';
      _fetchedToken = data['token']?.toString() ?? widget.token;

      if (appId.isEmpty) {
        throw Exception('Impossible de récupérer l\'App ID du serveur');
      }

      _engine = createAgoraRtcEngine();

      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      await _engine!.enableVideo();

      if (widget.isHost) {
        await _engine!.startPreview();
      }

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) setState(() => _isJoined = true);
            debugPrint('[LivePlayer] ✓ Joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            if (mounted) setState(() => _remoteUid = uid);
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
            if (mounted) setState(() => _remoteUid = 0);
          },
          // ✅ Compteur spectateurs temps réel
          onRtcStats: (RtcConnection connection, RtcStats stats) {
            if (mounted && widget.isHost) {
              setState(() => _viewerCount = stats.userCount);
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[LivePlayer] ❌ Agora error [$err]: $msg');
          },
          // ✅ Gestion reconnexion réseau
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[LivePlayer] 🔗 Connection state: $state (reason: $reason)');
            if (state == ConnectionStateType.connectionStateDisconnected) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).t('live_connection_lost')),
                    backgroundColor: danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else if (state == ConnectionStateType.connectionStateConnected) {
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }
            }
          },
        ),
      );

      await _engine!.setClientRole(
        role: widget.isHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );

      await _engine!.joinChannel(
        token: _fetchedToken ?? '',
        channelId: widget.channelName,
        uid: 0,
        options: ChannelMediaOptions(
          publishCameraTrack: widget.isHost && !_isVideoOff,
          publishMicrophoneTrack: widget.isHost && !_isMuted,
          clientRoleType: widget.isHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
        ),
      );

      // ✅ Refresh token périodique (avant expiration Agora ~1h)
      if (widget.isHost) {
        _tokenRefreshTimer = Timer.periodic(_kTokenRefreshInterval, (_) => _refreshToken());
      }

      // ✅ PRÉ-PIN produits au démarrage (hôte uniquement)
      if (widget.isHost) {
        try {
          final session = await Supabase.instance.client
              .from('live_sessions')
              .select('pre_pinned_products, allow_voting, allow_dynamic_control')
              .eq('id', widget.liveId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));
          final prePinned = List<String>.from(
              (session?['pre_pinned_products'] as List?) ?? []);
          if (prePinned.isNotEmpty) {
            await LiveShoppingService().applyPrePinned(widget.liveId, prePinned);
            debugPrint('[LiveShopping] Pre-pinned ${prePinned.length} products');
          }
        } catch (e) {
          debugPrint('[LiveShopping] Pre-pin apply failed (non-critical): $e');
        }
      }
    } catch (e) {
      debugPrint('[LivePlayer] ❌ Init error: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.t("live_connection_error")}: $e'),
            backgroundColor: danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingToken = false);
    }
  }

  /// ✅ Rafraîchir le token Agora sans interrompre le stream
  Future<void> _refreshToken() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-rtc-token',
        body: {
          'channelName': widget.channelName,
          'role': widget.isHost ? 'publisher' : 'subscriber',
        },
      );
      final newToken = response.data?['token']?.toString();
      if (newToken != null && _engine != null) {
        await _engine!.renewToken(newToken);
        debugPrint('[LivePlayer] 🔄 Token refreshed');
      }
    } catch (e) {
      debugPrint('[LivePlayer] ⚠️ Token refresh failed: $e');
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
      if (widget.isHost) await _engine?.startPreview();
    }
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _endLive({bool pop = true}) async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _tokenRefreshTimer?.cancel();

    try {
      await Supabase.instance.client.from('live_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.liveId);
    } catch (e) {
      debugPrint('[LivePlayer] ❌ EndLive DB error: $e');
    }

    try {
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
    } catch (e) {
      debugPrint('[LivePlayer] ❌ Leave Agora error: $e');
    }

    if (pop && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmEndLive() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.t('live_end_confirm_title'), style: const TextStyle(color: Colors.white)),
        content: Text(l10n.t('live_end_confirm_desc'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('live_end_confirm_btn'), style: const TextStyle(color: Colors.white)),
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
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      try {
        await Supabase.instance.client.from('live_messages').insert({
          'live_id': widget.liveId,
          'user_id': userId,
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[LivePlayer] ❌ Send message error: $e');
      }
    }

    _messageController.clear();
  }

  // ══════════════════════════════════════════════════════════════════════
  // OUVERTURE PANNEAUX LIVE SHOPPING
  // ══════════════════════════════════════════════════════════════════════
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
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildVideo() {
    if (!_isJoined || _engine == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (widget.isHost) {
      if (_isVideoOff) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).t('live_camera_off'),
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
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }

    return Center(
      child: Text(
        AppLocalizations.of(context).t('live_waiting_host'),
        style: const TextStyle(color: Colors.white70, fontSize: 16),
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

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ✅ Badge compteur produits épinglés (hôte)
    final pinnedCountAsync = widget.isHost
        ? ref.watch(_pinnedCountProvider(widget.liveId))
        : null;
    final pinnedCount = pinnedCountAsync?.valueOrNull ?? 0;

    return PopScope(
      canPop: !widget.isHost,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (widget.isHost) await _confirmEndLive();
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
                    Text(l10n.t('live_connecting'), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Stack(
                children: [
                  // ── Vidéo plein écran ──
                  Positioned.fill(child: _buildVideo()),

                  // ── Gradient haut ──
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

                  // ── Gradient bas ──
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

                  // ── Badge LIVE + Compteur spectateurs ──
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
                              Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        // ✅ Compteur spectateurs (hôte uniquement)
                        if (widget.isHost) ...[
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
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Bouton fermer / Couper ──
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: widget.isHost
                          ? (_isEnding ? null : _confirmEndLive)
                          : () => Navigator.pop(context),
                    ),
                  ),

                  // ── Contrôles HOST ──
                  if (widget.isHost)
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

                  // ── Mute spectateur ──
                  if (!widget.isHost)
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

                  // ── Champ message ──
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
                                hintText: l10n.t('live_message_hint'),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

                  // ════════════════════════════════════════════════════════
                  // ✅ OVERLAY HÔTE — Bouton flottant "Produits" + BADGE
                  // Positionné AU-DESSUS des contrôles (bottom: 160)
                  // ════════════════════════════════════════════════════════
                  if (widget.isHost && _isJoined)
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
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF1B2A4A), size: 24),
                            ),
                            // ✅ Badge compteur produits épinglés
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
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // ════════════════════════════════════════════════════════
                  // ✅ OVERLAY SPECTATEUR — Carousel + vote
                  // Positionné AU-DESSUS de la barre de message (bottom: 80)
                  // Hauteur contrainte pour éviter débordement
                  // ════════════════════════════════════════════════════════
                  if (!widget.isHost && _isJoined)
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

                  // ── Overlay "fin en cours" ──
                  if (_isEnding)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 12),
                            Text(l10n.t('live_ending'), style: const TextStyle(color: Colors.white)),
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
