// lib/presentation/network/live/live_viewer_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class _C {
  static const primary = ThixPolicy.primary;
  static const red = ThixPolicy.danger; 
  static const bgDark = ThixPolicy.inkDeep;
  static const textMain = Colors.white; 
  static const textMuted = Colors.white70;
}

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
  
  String? _errorMessage; // ✅ AJOUT : Pour gérer l'erreur visuelle du spectateur

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _comments = [];
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();

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
      // ✅ APPEL DE LA FUNCTION SUPABASE
      final response = await Supabase.instance.client.functions.invoke(
        'agora-token',
        body: {
          'channel': widget.channelName,
          'uid': 0,
        },
      );
      final data = response.data as Map<String, dynamic>;

      // ✅ VÉRIFICATION DU TOKEN
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le direct est terminé.'), backgroundColor: _C.bgDark));
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
        // ✅ On enregistre l'erreur pour arrêter le chargement infini
        setState(() => _errorMessage = e.toString()); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Live : $e'),
            backgroundColor: Colors.red,
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande refusée par l\'hôte.'), backgroundColor: _C.red));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous êtes maintenant en direct !'), backgroundColor: Colors.green));
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
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
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
        backgroundColor: _C.bgDark,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ✅ CORRECTION ICI : Gestion de l'erreur vs Chargement infini
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
                                  color: _C.bgDark,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: _C.primary),
                                        SizedBox(height: 16),
                                        Text('En attente de la vidéo de l\'hôte...', style: TextStyle(color: _C.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    )
                  : Container(
                      color: _C.bgDark,
                      child: Center(
                        child: _errorMessage != null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  "Impossible de rejoindre le direct :\n$_errorMessage",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: _C.red, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: _C.primary),
                                  SizedBox(height: 16),
                                  Text("Connexion en cours...", style: TextStyle(color: _C.textMuted)),
                                ],
                              ),
                      ),
                    ),
            ),

            // 2. DÉGRADÉS LISIBILITÉ
            Positioned(top: 0, left: 0, right: 0, height: 140, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),
            Positioned(bottom: 0, left: 0, right: 0, height: 300, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),

            // 3. PIÈCE EN INCINÉRATION CO-HÔTE (MOI)
            if (_isCoHost && !_isVideoOff)
              Positioned(
                top: 100, right: 16, width: 100, height: 140,
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.primary, width: 2), color: Colors.black),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0), useFlutterTexture: kIsWeb)),
                  ),
                ),
              ),

            // 4. TOP BAR
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(30)),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16, 
                          backgroundColor: _C.primary, 
                          backgroundImage: widget.hostAvatarUrl != null && widget.hostAvatarUrl!.isNotEmpty ? CachedNetworkImageProvider(widget.hostAvatarUrl!) : null,
                          child: widget.hostAvatarUrl == null || widget.hostAvatarUrl!.isEmpty ? const Icon(Icons.person, size: 20, color: _C.textMain) : null,
                        ), 
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(widget.hostName, style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold)), Row(children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle)), const SizedBox(width: 4), const Text('EN DIRECT', style: TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.bold))])]),
                        const SizedBox(width: 12),
                      ]),
                    ),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)), child: Row(children: [const Icon(Icons.visibility_rounded, color: _C.textMain, size: 14), const SizedBox(width: 4), Text('$_viewerCount', style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold))])),
                    const SizedBox(width: 12),
                    GestureDetector(onTap: _leaveBroadcast, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: _C.textMain, size: 20))),
                  ],
                ),
              ),
            ),

            // 5. ACTIONS CO-HÔTE
            if (_isCoHost)
              Positioned(
                right: 16, bottom: 140,
                child: Column(
                  children: [
                    _SideActionButton(icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, label: 'Micro', onTap: () { setState(() => _isMuted = !_isMuted); _engine.muteLocalAudioStream(_isMuted); }),
                    _SideActionButton(icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, label: 'Caméra', onTap: () { setState(() => _isVideoOff = !_isVideoOff); _engine.muteLocalVideoStream(_isVideoOff); }),
                    _SideActionButton(icon: Icons.flip_camera_ios_rounded, label: 'Tourner', onTap: () => _engine.switchCamera()),
                  ],
                ),
              ),

            // 6. CHAT
            Positioned(
              left: 16, bottom: 80, width: MediaQuery.of(context).size.width * 0.7, height: 250,
              child: ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.2, 1.0]).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  reverse: true,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[_comments.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                        child: RichText(text: TextSpan(children: [TextSpan(text: '${comment["user"]}   ', style: TextStyle(color: _C.textMain.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)), TextSpan(text: comment["text"], style: const TextStyle(color: _C.textMain, fontSize: 14))])),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 7. INPUT CHAT ET ACTIONS
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                        child: TextField(
                          controller: _chatController, style: const TextStyle(color: _C.textMain, fontSize: 14), textInputAction: TextInputAction.send, onSubmitted: (_) => _sendComment(),
                          decoration: const InputDecoration(hintText: 'Ajouter un commentaire...', hintStyle: TextStyle(color: _C.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        ),
                      ),
                    ),
                    if (!_isCoHost) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isRequesting ? null : _requestToJoin,
                        child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: _isRequesting ? Colors.grey : _C.primary), child: _isRequesting ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.video_call_rounded, color: _C.textMain, size: 22)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendHeart,
                      child: Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_C.red, Colors.orange])), child: const Icon(Icons.favorite_rounded, color: _C.textMain, size: 24)),
                    ),
                  ],
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

class _SideActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SideActionButton({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.only(bottom: 16), child: GestureDetector(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: _C.textMain, size: 22)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: _C.textMain, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]))]))); }
}

class _AnimatedHeart extends StatefulWidget {
  final Color color; final VoidCallback onComplete;
  const _AnimatedHeart({super.key, required this.color, required this.onComplete});
  @override State<_AnimatedHeart> createState() => _AnimatedHeartState();
}
class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _pos, _op, _sc; final _r = Random(); late double _x;
  @override void initState() { super.initState(); _x = (_r.nextDouble() * 60) - 30; _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000)); _pos = Tween<double>(begin: 0, end: 400).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)); _op = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut))); _sc = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut)); _c.forward().then((_) => widget.onComplete()); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _c, builder: (c, _) => Positioned(bottom: 70 + _pos.value, right: 25 + _x + (sin(_pos.value / 30) * 20), child: Opacity(opacity: _op.value, child: Transform.scale(scale: _sc.value, child: Icon(Icons.favorite_rounded, color: widget.color, size: 28))))); }
}
