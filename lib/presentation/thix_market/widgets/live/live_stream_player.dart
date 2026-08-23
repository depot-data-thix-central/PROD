import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamPlayer extends StatefulWidget {
  final String channelName;
  final String liveId;
  final String? token;
  final bool isHost; // 🟢 NOUVEAU : Permet de savoir si on est le vendeur (true) ou un client (false)

  const LiveStreamPlayer({
    super.key,
    required this.channelName,
    required this.liveId,
    this.token,
    this.isHost = false, // Par défaut, on considère que c'est un spectateur
  });

  @override
  State<LiveStreamPlayer> createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends State<LiveStreamPlayer> {
  late RtcEngine _engine;

  bool _isJoined = false;
  int _remoteUid = 0;
  bool _isMuted = false;

  final TextEditingController _messageController = TextEditingController();
  // List<Map<String, dynamic>> _messages = []; // À utiliser plus tard pour afficher le chat

  // int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release(); 
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initAgora() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();

    _engine = createAgoraRtcEngine();

    await _engine.initialize(
      const RtcEngineContext(
        appId: 'YOUR_AGORA_APP_ID', // ⚠️ N'oublie pas de mettre ton vrai App ID Agora ici !
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine.enableVideo();
    
    // Si c'est le vendeur, on démarre l'aperçu de la caméra locale
    if (widget.isHost) {
      await _engine.startPreview();
    }

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _isJoined = true);
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          setState(() => _remoteUid = uid);
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          setState(() => _remoteUid = 0);
        },
      ),
    );

    // 🟢 DÉFINITION DYNAMIQUE DU RÔLE
    await _engine.setClientRole(
      role: widget.isHost 
          ? ClientRoleType.clientRoleBroadcaster // Le vendeur diffuse
          : ClientRoleType.clientRoleAudience,   // Le client regarde
    );

    await _engine.joinChannel(
      token: widget.token ?? '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
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
      body: Stack(
        children: [
          // 🎥 GESTION DE L'AFFICHAGE VIDÉO
          if (_isJoined)
            if (widget.isHost)
              // 🔴 Vue du Vendeur (Caméra locale)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else if (_remoteUid != 0)
              // 🔵 Vue du Client (Caméra distante du vendeur)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: widget.channelName),
                ),
              )
            else
              // ⏳ Client en attente de l'image du vendeur
              const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            // ⏳ Chargement initial
            const Center(child: CircularProgressIndicator(color: Colors.white)),

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
                _engine.muteLocalAudioStream(_isMuted);
              },
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
          
          // ❌ Bouton pour quitter le live (Très utile en phase de test !)
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
