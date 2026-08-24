import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamPlayer extends StatefulWidget {
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
  State<LiveStreamPlayer> createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends State<LiveStreamPlayer> {
  RtcEngine? _engine;
  bool _isJoined = false;
  int _remoteUid = 0;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  bool _isEnding = false;
  bool _isLoadingToken = true;
  String? _fetchedToken;

  final TextEditingController _messageController = TextEditingController();

  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _initializeLive();
  }

  @override
  void dispose() {
    _messageController.dispose();
    // Ne pas endLive ici : déjà géré par _endLive / PopScope
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

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
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            if (mounted) setState(() => _remoteUid = uid);
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
            if (mounted) setState(() => _remoteUid = 0);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('Agora error [$err]: $msg');
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
    } catch (e) {
      debugPrint('Erreur init live: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur connexion live: $e'), backgroundColor: danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingToken = false);
    }
  }

  // ─── CONTRÔLES HOST ───────────────────────────────────────────

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

  /// Termine le live en DB + quitte Agora + ferme l'écran
  Future<void> _endLive({bool pop = true}) async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    try {
      // ✅ Table unifiée
      await Supabase.instance.client.from('live_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.liveId);
    } catch (e) {
      debugPrint('Erreur endLive DB: $e');
    }

    try {
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
    } catch (e) {
      debugPrint('Erreur leave Agora: $e');
    }

    if (pop && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmEndLive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer le live ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'La diffusion sera coupée pour tous les spectateurs.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Couper', style: TextStyle(color: Colors.white)),
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
      // fallback ancienne table si besoin
      try {
        await Supabase.instance.client.from('live_messages').insert({
          'live_id': widget.liveId,
          'user_id': userId,
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Erreur envoi message: $e');
      }
    }

    _messageController.clear();
  }

  // ─── UI ───────────────────────────────────────────────────────

  Widget _buildVideo() {
    if (!_isJoined || _engine == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (widget.isHost) {
      if (_isVideoOff) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
              SizedBox(height: 12),
              Text('Caméra désactivée', style: TextStyle(color: Colors.white70)),
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

    // Spectateur
    if (_remoteUid != 0) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return const Center(
      child: Text('En attente du diffuseur...', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
    return PopScope(
      canPop: !widget.isHost, // host ne peut pas sortir sans terminer
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (widget.isHost) {
          await _confirmEndLive();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoadingToken
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: gold),
                    SizedBox(height: 12),
                    Text('Connexion au serveur sécurisé...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Stack(
                children: [
                  // Vidéo plein écran
                  Positioned.fill(child: _buildVideo()),

                  // Gradients
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

                  // Badge LIVE
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    child: Container(
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
                  ),

                  // Bouton fermer / Couper
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 12,
                    child: widget.isHost
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: _isEnding ? null : _confirmEndLive,
                          )
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                  ),

                  // Barre de contrôles HOST
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
                          // Bouton COUPER
                          _hostControlButton(
                            icon: Icons.call_end_rounded,
                            isDanger: true,
                            onTap: _isEnding ? () {} : _confirmEndLive,
                          ),
                        ],
                      ),
                    ),

                  // Mute seul pour spectateur (optionnel)
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

                  // Champ message
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
                                hintText: 'Message...',
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

                  // Overlay "fin en cours"
                  if (_isEnding)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Fin du live...', style: TextStyle(color: Colors.white)),
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
