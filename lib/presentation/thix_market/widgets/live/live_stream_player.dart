import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamPlayer extends StatefulWidget {
  final String channelName;
  final String liveId;
  final String? token; // Optionnel si on le récupère à la volée
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
  bool _isLoadingToken = true; // Pour afficher un chargement propre pendant l'appel réseau
  String? _fetchedToken;

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLive();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    _messageController.dispose();
    super.dispose();
  }

  /// 🟢 Étape clé : Récupérer l'App ID et le Token depuis la Edge Function
  Future<void> _initializeLive() async {
    try {
      await [
        Permission.microphone,
        Permission.camera,
      ].request();

      // Appel de la Edge Function pour obtenir l'App ID et le Token de manière dynamique
      final response = await Supabase.instance.client.functions.invoke(
        'generate-rtc-token',
        body: {
          'channelName': widget.channelName,
          'role': widget.isHost ? 'publisher' : 'subscriber',
        },
      );

      final data = response.data;
      final String appId = data['appId']; // Récupéré dynamiquement !
      _fetchedToken = data['token'] ?? widget.token;

      if (appId.isEmpty) {
        throw Exception('Impossible de récupérer l\'App ID du serveur');
      }

      // Initialisation du moteur Agora avec l'App ID dynamique
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
            print('✅ Connecté au canal Agora : ${connection.channelId}');
            if (mounted) setState(() => _isJoined = true);
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            print('👤 Utilisateur distant joint : $uid');
            if (mounted) setState(() => _remoteUid = uid);
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
            print('❌ Utilisateur parti : $uid');
            if (mounted) setState(() => _remoteUid = 0);
          },
          onError: (ErrorCodeType err, String msg) {
            print('⚠️ Erreur Agora [$err] : $msg');
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
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      print('❌ Erreur d\'initialisation du live : $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingToken = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('live_messages').insert({
      'live_id': widget.liveId,
      'user_id': userId,
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoadingToken
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFC9962C)),
                  SizedBox(height: 12),
                  Text("Connexion au serveur sécurisé...", style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Stack(
              children: [
                // 🎥 GESTION DE L'AFFICHAGE VIDÉO
                Positioned.fill(
                  child: _isJoined && _engine != null
                      ? (widget.isHost
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : (_remoteUid != 0
                              ? AgoraVideoView(
                                  controller: VideoViewController.remote(
                                    rtcEngine: _engine!,
                                    canvas: VideoCanvas(uid: _remoteUid),
                                    connection: RtcConnection(channelId: widget.channelName),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    "En attente du diffuseur...",
                                    style: TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                )))
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),

                // 🔴 Badge LIVE
                Positioned(
                  top: 50,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 💬 CHAT INPUT
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: "Message...",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFFC9962C),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔊 Bouton Mute
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black54,
                    elevation: 0,
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _engine?.muteLocalAudioStream(_isMuted);
                    },
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),

                // ❌ Bouton pour quitter
                Positioned(
                  top: 50,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
    );
  }
}
