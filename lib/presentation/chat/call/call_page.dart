// lib/presentation/chat/call/call_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../../models/chat/call_status.dart';
import '../../../services/chat/call_service.dart';
import 'providers/call_provider.dart';
import '../providers/chat_providers.dart'; 

class CallPage extends ConsumerWidget {
  const CallPage({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callProvider);
    final notifier = ref.read(callProvider.notifier);
    final media = CallMediaService();

    final statusLabel = switch (state.status) {
      CallStatus.ringing => state.isCaller ? 'Appel…' : 'Connexion…',
      CallStatus.accepted => 'Connexion…',
      CallStatus.ongoing => _fmt(state.duration),
      CallStatus.busy => 'Occupé',
      CallStatus.failed => 'Échec',
      _ => state.status.label,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      body: SafeArea(
        child: Stack(
          children: [
            // Vidéo remote
            if (state.isVideo &&
                state.remoteUid != null &&
                media.engine != null)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: media.engine!,
                    canvas: VideoCanvas(uid: state.remoteUid),
                    connection: RtcConnection(channelId: state.channelName),
                  ),
                ),
              )
            else
              // Audio / waiting UI
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.white24,
                      backgroundImage: state.remoteAvatar != null
                          ? NetworkImage(state.remoteAvatar!)
                          : null,
                      child: state.remoteAvatar == null
                          ? const Icon(Icons.person,
                              size: 56, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      state.remoteName ?? 'Contact',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            // Preview locale (vidéo)
            if (state.isVideo &&
                !state.videoOff &&
                media.engine != null)
              Positioned(
                right: 16,
                top: 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: media.engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),

            // Header name en vidéo
            if (state.isVideo)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      state.remoteName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

            // Controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Btn(
                    icon: state.muted ? Icons.mic_off : Icons.mic,
                    label: state.muted ? 'Muet' : 'Micro',
                    onTap: notifier.toggleMute,
                    active: state.muted,
                  ),
                  if (state.isVideo)
                    _Btn(
                      icon: state.videoOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: 'Caméra',
                      onTap: notifier.toggleVideo,
                      active: state.videoOff,
                    ),
                  if (state.isVideo)
                    _Btn(
                      icon: Icons.cameraswitch,
                      label: 'Retourner',
                      onTap: notifier.switchCamera,
                    ),
                  _Btn(
                    icon: state.speakerOn
                        ? Icons.volume_up
                        : Icons.volume_off,
                    label: 'Haut-parleur',
                    onTap: notifier.toggleSpeaker,
                    active: !state.speakerOn,
                  ),
                  _Btn(
                    icon: Icons.call_end,
                    label: 'Raccrocher',
                    onTap: () async {
                      
                      try {
                        final isMissed = state.duration.inSeconds == 0;
                        final type = state.isVideo ? 'call_video' : 'call_audio';
                        final textType = state.isVideo ? 'Appel vidéo' : 'Appel audio';
                        final textDuration = isMissed ? 'manqué' : '(${_fmt(state.duration)})';
                        final content = '$textType $textDuration';

                        final chatSvc = ref.read(chatServiceProvider);
                        
                        
                        final convId = state.conversationId; 
                        
                        if (convId != null && convId.isNotEmpty) {
                          await chatSvc.sendMessage(
                            conversationId: convId,
                            content: content,
                            mediaType: type,
                          );
                        }
                      } catch (e) {
                        debugPrint('Erreur lors de la création de la bulle d\'historique : $e');
                      }

                      //  2. Fermeture normale de l'appel
                      await notifier.hangUp();
                      if (context.mounted) Navigator.pop(context);
                    },
                    bg: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? bg;

  const _Btn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bg ??
                  (active ? Colors.white : Colors.white24),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: bg != null
                  ? Colors.white
                  : (active ? const Color(0xFF0A1F44) : Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
