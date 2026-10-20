// lib/presentation/thix_market/pages/live_stream_page.dart
import 'package:flutter/material.dart';
import '../widgets/live/live_stream_player.dart';

class LiveStreamPage extends StatelessWidget {
  final String liveId;
  final String? token;
  final String? channelName;
  final bool isHost;

  const LiveStreamPage({
    super.key,
    required this.liveId,
    this.token,
    this.channelName,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    if (liveId.trim().isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Live introuvable',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }

    // Ne plus fallback channelName sur liveId (UUID ≠ channel Agora).
    // Si channelName/isHost absents (ouverture depuis la liste),
    // LiveStreamPlayer les résout depuis live_sessions.
    return LiveStreamPlayer(
      liveId: liveId,
      channelName: channelName?.trim() ?? '',
      token: token,
      isHost: isHost,
    );
  }
}
