// lib/presentation/network/live/live_viewer_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';

class LiveViewerScreen extends StatefulWidget {
  final String liveId;
  final String channelName;
  final String hostName;
  final String? hostAvatarUrl;

  const LiveViewerScreen({
    super.key,
    required this.liveId,
    required this.channelName,
    this.hostName = 'Hôte THIX',
    this.hostAvatarUrl,
  });

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> with TickerProviderStateMixin {
  late RtcEngine _engine;
  RealtimeChannel? _realtimeChannel;
  
  bool _isInitialized = false;
  int? _remoteUid;
  
  bool _isCoHost = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isRequesting = false;
  int _viewerCount = 0;
  
  String? _errorMessage;

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _comments = [];
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();

  final List<Color> _heartColors = [
    ThixPolicy.danger,
    ThixPolicy.primary,
    ThixPolicy.gold,
    Colors.white,
  ];

  String get _myUserId => Supabase.instance.client.auth.currentUser?.id ?? 'spectator';
  String get _myUserName => 'Membre THIX';

  @override
  void initState() {
    super.initState();
    _initAgora();
    _initRealtime();
  }

  Future<void> _initAgora() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'agora-token',
        body: {
          'channel': widget.channelName,
          'uid': 0,
        },
      );
      final data = response.data as Map<String, dynamic>;

      if (data['token'] == null || data['appId'] == null) {
        throw Exception('Token Agora invalide: $data');
      }

      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: data['appId'],
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (_remoteUid == null) setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (_remoteUid == remoteUid) {
              setState(() => _remoteUid = null);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le direct est terminé.'), backgroundColor: ThixPolicy.inkDeep));
              Navigator.pop(context);
            }
          },
        ),
      );

      await _engine.joinChannel(
        token: data['token'],
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Erreur Agora Spectateur: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString()); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Live : $e'),
            backgroundColor: ThixPolicy.danger,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _initRealtime() {
    _realtimeChannel = Supabase.instance.client.channel('live_${widget.liveId}');

    _realtimeChannel!
      .onBroadcast(event: 'chat', callback: (payload) {
        setState(() => _comments.add({"user": payload['user'], "text": payload['text']}));
      })
      .onBroadcast(event: 'heart', callback: (payload) {
        _triggerHeartAnimation();
      })
      .onBroadcast(event: 'cohost_response', callback: (payload) {
        if (payload['targetUserId'] == _myUserId) {
          if (payload['accepted'] == true) {
            _becomeCoHost();
          } else {
            setState(() => _isRequesting = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande refusée par l\'hôte.'), backgroundColor: ThixPolicy.danger));
          }
        }
      })
      .onPresenceSync((_) {
        final state = _realtimeChannel!.presenceState();
        final int count = state.length;
        setState(() => _viewerCount = count > 0 ? count - 1 : 0);
      })
      .subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _realtimeChannel!.track({'user_id': _myUserId, 'is_host': false});
        }
      });
  }

  void _requestToJoin() {
    setState(() => _isRequesting = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée à l\'hôte...')));
    _realtimeChannel!.sendBroadcastMessage(
      event: 'cohost_request',
      payload: {'userId': _myUserId, 'userName': _myUserName},
    );
  }

  Future<void> _becomeCoHost() async {
    if (!kIsWeb) await [Permission.camera, Permission.microphone].request();
    
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.startPreview();
    
    if (mounted) {
      setState(() {
        _isCoHost = true;
        _isRequesting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous êtes maintenant en direct !'), backgroundColor: ThixPolicy.success));
    }
  }

  void _sendComment() {
    if (_chatController.text.trim().isEmpty) return;
    final text = _chatController.text.trim();
    
    _realtimeChannel!.sendBroadcastMessage(
      event: 'chat',
      payload: {'user': _myUserName, 'text': text},
    );
    
    setState(() {
      _comments.add({"user": _myUserName, "text": text});
      _chatController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _sendHeart() {
    _triggerHeartAnimation();
    _realtimeChannel!.sendBroadcastMessage(event: 'heart', payload: {});
  }

  void _triggerHeartAnimation() {
    final key = UniqueKey();
    setState(() {
      _floatingHearts.add(_AnimatedHeart(
        key: key,
        color: _heartColors[_random.nextInt(_heartColors.length)],
        onComplete: () => setState(() => _floatingHearts.removeWhere((w) => w.key == key)),
      ));
    });
  }

  Future<void> _leaveBroadcast() async {
    _realtimeChannel?.unsubscribe();
    if (_isInitialized) {
      await _engine.leaveChannel();
      await _engine.release();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _leaveBroadcast(); 
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _leaveBroadcast();
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Le fond est noir en permanence
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // 1. VIDEO / LOADING / ERROR
            Positioned.fill(
              child: _isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: _remoteUid != null
                              ? AgoraVideoView(
                                  controller: VideoViewController.remote(
                                    rtcEngine: _engine,
                                    canvas: VideoCanvas(uid: _remoteUid),
                                    connection: RtcConnection(channelId: widget.channelName),
                                    useFlutterTexture: kIsWeb,
                                  ),
                                )
                              : Container(
                                  color: ThixPolicy.inkDeep,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(color: ThixPolicy.primary),
                                        const SizedBox(height: 16),
                                        Text('En attente de la vidéo de l\'hôte...', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    )
                  : Container(
                      color: ThixPolicy.inkDeep,
                      child: Center(
                        child: _errorMessage != null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  "Impossible de rejoindre le direct :\n$_errorMessage",
                                  textAlign: TextAlign.center,
                                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: ThixPolicy.primary),
                                  const SizedBox(height: 16),
                                  Text("Connexion en cours...", style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70)),
                                ],
                              ),
                      ),
                    ),
            ),

            // 2. DÉGRADÉS LISIBILITÉ
            Positioned(
              top: 0, left: 0, right: 0, height: 160, 
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])))
            ),
            Positioned(
              bottom: 0, left: 0, right: 0, height: 350, 
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent])))
            ),

            // 3. PIÈCE EN INCRUSTATION CO-HÔTE (MOI)
            if (_isCoHost && !_isVideoOff)
              Positioned(
                top: 110, right: 16, width: 110, height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd), 
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1), 
                    color: ThixPolicy.inkDeep,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd - 1),
                    child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0), useFlutterTexture: kIsWeb)),
                  ),
                ),
              ),

            // 4. TOP BAR
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── HOST INFO (Glassmorphism) ───
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1))),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18, 
                                backgroundColor: ThixPolicy.primary, 
                                backgroundImage: widget.hostAvatarUrl != null && widget.hostAvatarUrl!.isNotEmpty ? CachedNetworkImageProvider(widget.hostAvatarUrl!) : null,
                                child: widget.hostAvatarUrl == null || widget.hostAvatarUrl!.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                              ), 
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start, 
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  Text(widget.hostName, style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold)), 
                                  Row(
                                    children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle)), 
                                      const SizedBox(width: 4), 
                                      Text('EN DIRECT', style: ThixPolicy.microStyle.copyWith(color: Colors.white70, fontSize: 9, fontWeight: ThixPolicy.bold, letterSpacing: 0.5))
                                    ]
                                  )
                                ]
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    
                    // ─── VIEWER COUNT ───
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: Colors.white.withOpacity(0.1))),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility_rounded, color: Colors.white, size: 14), 
                              const SizedBox(width: 6), 
                              Text('$_viewerCount', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold))
                            ]
                          )
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // ─── CLOSE BUTTON ───
                    GestureDetector(
                      onTap: _leaveBroadcast, 
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10), 
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))), 
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)
                          ),
                        ),
                      )
                    ),
                  ],
                ),
              ),
            ),

            // 5. CHAT
            Positioned(
              left: 16, bottom: 90, width: MediaQuery.of(context).size.width * 0.75, height: 280,
              child: ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.15, 1.0]).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[_comments.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: '${comment["user"]}  ', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.bold)),
                                    TextSpan(text: comment["text"], style: ThixPolicy.bodyStyle.copyWith(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 6. BOTTOM DOCK (Chat Input & Controls)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Input de Chat
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15), 
                                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: TextField(
                                controller: _chatController, 
                                style: ThixPolicy.bodyStyle.copyWith(color: Colors.white), 
                                textInputAction: TextInputAction.send, 
                                onSubmitted: (_) => _sendComment(),
                                decoration: InputDecoration(
                                  hintText: 'Commenter...', 
                                  hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white54), 
                                  border: InputBorder.none, 
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Boutons d'actions
                      if (_isCoHost)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionDockButton(icon: Icons.flip_camera_ios_rounded, onTap: () => _engine.switchCamera()),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, isDanger: _isMuted, onTap: () { setState(() => _isMuted = !_isMuted); _engine.muteLocalAudioStream(_isMuted); }),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, isDanger: _isVideoOff, onTap: () { setState(() => _isVideoOff = !_isVideoOff); _engine.muteLocalVideoStream(_isVideoOff); }),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: Icons.favorite_rounded, color: ThixPolicy.primary, isPulse: true, onTap: _sendHeart),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionDockButton(
                              icon: Icons.video_call_rounded,
                              active: _isRequesting,
                              isLoading: _isRequesting,
                              onTap: _isRequesting ? () {} : _requestToJoin,
                            ),
                            const SizedBox(width: 10),
                            _ActionDockButton(
                              icon: Icons.favorite_rounded,
                              color: ThixPolicy.primary,
                              isPulse: true,
                              onTap: _sendHeart,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            ..._floatingHearts,
          ],
        ),
      ),
    );
  }
}

// ─── COMPOSANTS ANNEXES ───

class _ActionDockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool isLoading;
  final bool isDanger;
  final Color? color;
  final bool isPulse;

  const _ActionDockButton({
    required this.icon, 
    required this.onTap, 
    this.active = false, 
    this.isLoading = false,
    this.isDanger = false, 
    this.color, 
    this.isPulse = false
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDanger ? ThixPolicy.danger : (active && !isLoading ? ThixPolicy.primary : Colors.white.withOpacity(0.15));
    final iconColor = (isDanger || (active && !isLoading)) ? Colors.white : (color ?? Colors.white);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: isPulse ? [BoxShadow(color: (color ?? ThixPolicy.primary).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : null,
            ),
            child: isLoading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _AnimatedHeart extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;
  const _AnimatedHeart({super.key, required this.color, required this.onComplete});
  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _pos, _op, _sc;
  final _r = Random();
  late double _x;

  @override
  void initState() {
    super.initState();
    _x = (_r.nextDouble() * 60) - 30;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _pos = Tween<double>(begin: 0, end: 500).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _op = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _sc = Tween<double>(begin: 0.6, end: 1.6).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
    _c.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (c, _) => Positioned(
        bottom: 80 + _pos.value,
        right: 40 + _x + (sin(_pos.value / 40) * 30),
        child: Opacity(
          opacity: _op.value, 
          child: Transform.scale(
            scale: _sc.value, 
            child: Icon(Icons.favorite_rounded, color: widget.color, size: 28, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))])
          )
        ),
      ),
    );
  }
}
