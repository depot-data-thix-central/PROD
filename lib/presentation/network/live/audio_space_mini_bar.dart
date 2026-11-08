// lib/presentation/network/live/audio_space_mini_bar.dart
//
// Barre « Space en cours » (salon réduit). Se masque quand l'écran du salon
// est ouvert. Un tap rouvre le salon.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_controller.dart';
import 'package:thix_id/data/services/live/audio_space_manager.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/network/live/audio_space_room_screen.dart';

class AudioSpaceMiniBar extends ConsumerWidget {
  const AudioSpaceMiniBar({super.key});

  void _open(AudioSpace space) {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AudioSpaceRoomScreen(space: space),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioSpaceControllerProvider);
    final ctrl = ref.read(audioSpaceControllerProvider.notifier);

    return ValueListenableBuilder<bool>(
      valueListenable: AudioSpaceManager.instance.roomOpen,
      builder: (context, open, _) {
        final space = s.space;
        if (!s.isActive || open || space == null) {
          return const SizedBox.shrink();
        }

        final me = s.me;
        final canTalk = me?.role.canSpeak ?? false;

        return Material(
          color: ThixPolicy.inkDeep,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => _open(space),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            space.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                          StreamBuilder<int>(
                            stream: Stream<int>.periodic(
                                const Duration(seconds: 1), (i) => i),
                            builder: (_, __) => Text(
                              '${s.elapsedFormatted} · ${s.participants.length} à l\'écoute',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canTalk)
                      IconButton(
                        icon: Icon(
                          (me?.isMuted ?? true)
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                        onPressed: ctrl.toggleMute,
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded,
                          color: ThixPolicy.danger),
                      tooltip: 'Quitter',
                      onPressed: ctrl.leave,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
