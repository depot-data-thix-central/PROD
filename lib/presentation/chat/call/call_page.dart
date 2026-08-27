// lib/presentation/chat/call/call_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../../models/chat/call_status.dart';
import '../../../services/chat/call_service.dart';
import 'providers/call_provider.dart';
import '../providers/chat_providers.dart';

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _errorHandled = false;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callProvider);
    final notifier = ref.read(callProvider.notifier);
    final media = CallMediaService();

    // Affiche l'erreur et ferme la page après 4 secondes
    ref.listen(callProvider, (previous, next) {
      if (next.status == CallStatus.failed && !_errorHandled) {
        _errorHandled = true;
        final message = next.error ?? "L'appel a échoué.";
        debugPrint('❌ CALL UI error: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 10),
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (context.mounted) Navigator.of(context).pop();
        });
      }
    });

    final statusLabel = switch (state.status) {
      CallStatus.ringing => state.isCaller ? 'Appel…' : 'Connexion…',
      CallStatus.accepted => 'Connexion…',
      CallStatus.ongoing => _fmt(state.duration),
      CallStatus.busy => 'Occupé',
      CallStatus.failed => 'Échec',
      _ => state.status.label,
    };

    final channelId = state.channelName;
    final engineReady = media.engine != null;

    // ── États d'affichage vidéo ──────────────────────────────
    // 1. Vidéo distante plein écran : appel connecté + remote uid
    final showRemote = state.isVideo &&
        state.remoteUid != null &&
        engineReady &&
        channelId != null &&
        channelId.isNotEmpty;

    // 2. Préview locale plein écran : pendant sonnerie / connexion
    final showLocalFull =
        state.isVideo && !state.videoOff && engineReady && !showRemote;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      body: SafeArea(
        child: Stack(
          children: [
            // ── FOND ─────────────────────────────────────────
            // Priorité : distant plein écran > préview locale > avatar
            if (showRemote)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: media.engine!,
                    canvas: VideoCanvas(uid: state.remoteUid),
                    connection: RtcConnection(channelId: channelId),
                  ),
                ),
              )
            else if (showLocalFull)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: media.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              )
            else
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
                    if (state.status == CallStatus.failed &&
                        state.error != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (state.isVideo &&
                        state.status == CallStatus.ongoing &&
                        !engineReady) ...[
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Initialisation de la caméra...',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Voile sombre sur la préview locale (lisibilité) ──
            if (showLocalFull)
              Positioned.fill(
                child: Container(color: Colors.black26),
              ),

            // ── En-tête nom + statut (par-dessus la vidéo) ──────
            if (showRemote || showLocalFull)
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
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── PiP locale (coin haut droit quand le distant est connecté) ──
            if (showRemote && !state.videoOff)
              Positioned(
                right: 16,
                top: 56,
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

            // ── Boutons de contrôle ─────────────────────────────
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
              color: bg ?? (active ? Colors.white : Colors.white24),
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
