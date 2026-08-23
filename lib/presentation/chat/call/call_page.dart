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

    // ── Surface les échecs silencieux (permission refusée, token
    // invalide, etc.) au lieu de laisser l'écran figé sans explication.
    ref.listen(callProvider, (previous, next) {
      if (next.status == CallStatus.failed && !_errorHandled) {
        _errorHandled = true;
        final message = next.error ?? "L'appel a échoué.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_humanizeCallError(message)),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
        Future.delayed(const Duration(milliseconds: 800), () {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      body: SafeArea(
        child: Stack(
          children: [
            // Vidéo remote — garde-fou sur channelId nullable
            if (state.isVideo &&
                state.remoteUid != null &&
                media.engine != null &&
                channelId != null &&
                channelId.isNotEmpty)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: media.engine!,
                    canvas: VideoCanvas(uid: state.remoteUid),
                    connection: RtcConnection(channelId: channelId),
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
                    // ── Indicateur explicite si la vidéo est prévue mais
                    // le moteur/caméra pas encore prêt, au lieu de rien
                    // afficher et laisser croire à un bug.
                    if (state.isVideo &&
                        state.status == CallStatus.ongoing &&
                        media.engine == null) ...[
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
                        "Initialisation de la caméra...",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

            // Preview locale (vidéo)
            if (state.isVideo && !state.videoOff && media.engine != null)
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

  /// Traduit les exceptions techniques en messages compréhensibles.
  String _humanizeCallError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('caméra refusée') || lower.contains('camera')) {
      return "Accès à la caméra refusé. Activez-le dans les réglages de votre téléphone.";
    }
    if (lower.contains('micro refusé') || lower.contains('microphone')) {
      return "Accès au microphone refusé. Activez-le dans les réglages de votre téléphone.";
    }
    if (lower.contains('token')) {
      return "Erreur de connexion au serveur d'appel. Réessayez.";
    }
    if (lower.contains('non authentifié')) {
      return "Session expirée. Reconnectez-vous.";
    }
    return "L'appel n'a pas pu aboutir.";
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
