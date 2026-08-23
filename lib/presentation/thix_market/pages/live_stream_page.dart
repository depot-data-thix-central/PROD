// lib/presentation/thix_market/pages/live_stream_page.dart
import 'package:flutter/material.dart';
import '../widgets/live/live_stream_player.dart';

class LiveStreamPage extends StatelessWidget {
  final String liveId;
  final String? token;
  final String? channelName;
  final bool isHost; // Permet de savoir si c'est le diffuseur ou un spectateur

  const LiveStreamPage({
    super.key, 
    required this.liveId,
    this.token,
    this.channelName,
    this.isHost = false, // Spectateur par défaut
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
    
    // On passe TOUTES les informations au vrai lecteur vidéo
    return LiveStreamPlayer(
      liveId: liveId,
      channelName: channelName ?? liveId, 
      token: token,
      isHost: isHost, // C'est ici que la magie s'opère pour allumer ta caméra !
    );
  }
}
