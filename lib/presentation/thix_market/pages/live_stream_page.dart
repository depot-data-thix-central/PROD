// lib/presentation/thix_market/pages/live_stream_page.dart
import 'package:flutter/material.dart';

import '../widgets/live/live_stream_player.dart';

class LiveStreamPage extends StatelessWidget {
  final String liveId;

  const LiveStreamPage({super.key, required this.liveId});

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
    return LiveStreamPlayer(channelName: liveId, liveId: liveId);
  }
}
