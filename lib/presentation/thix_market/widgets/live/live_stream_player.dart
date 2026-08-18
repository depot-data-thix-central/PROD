import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LiveStreamPlayer extends StatefulWidget {
  final String channelName;
  final String liveId;
  final String? token;

  const LiveStreamPlayer({
    super.key,
    required this.channelName,
    required this.liveId,
    this.token,
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
  List<Map<String, dynamic>> _messages = [];

  int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release(); // ✅ Agora 6.5.1 correct
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initAgora() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();

    // ✅ Agora 6.x correct init
    _engine = createAgoraRtcEngine();

    await _engine.initialize(
      RtcEngineContext(
        appId: 'YOUR_AGORA_APP_ID',
        channelProfile:
            ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine.enableVideo();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _isJoined = true);
        },
        onUserJoined:
            (RtcConnection connection, int uid, int elapsed) {
          setState(() => _remoteUid = uid);
        },
        onUserOffline: (
          RtcConnection connection,
          int uid,
          UserOfflineReasonType reason,
        ) {
          setState(() => _remoteUid = 0);
        },
      ),
    );

    // viewer only
    await _engine.setClientRole(
      role: ClientRoleType.clientRoleAudience,
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
      body: Stack(
        children: [
          // 🎥 VIDEO
          if (_isJoined && _remoteUid != 0)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(
                  channelId: widget.channelName,
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // 🔴 LIVE badge
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "LIVE",
                style: TextStyle(color: Colors.white),
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
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),

          // 🔊 mute button
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                setState(() => _isMuted = !_isMuted);
                _engine.muteLocalAudioStream(_isMuted);
              },
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
