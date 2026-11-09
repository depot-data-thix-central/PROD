// lib/presentation/thix_media/live/widgets/live_mini_bar.dart
//
// Barre « Live en cours » (live réduit). Masquée quand l'écran du live est
// ouvert. Un tap rouvre le live.

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/nav.dart';

import '../pages/live_room_view.dart';
import '../services/live_room_manager.dart';

class LiveMiniBar extends StatelessWidget {
  const LiveMiniBar({super.key});

  @override
  Widget build(BuildContext context) {
    final m = LiveRoomManager.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: m.roomOpen,
      builder: (context, open, _) {
        return ListenableBuilder(
          listenable: m,
          builder: (context, _) {
            final s = m.session;
            if (!m.isActive || open || s == null) {
              return const SizedBox.shrink();
            }

            return Material(
              color: const Color(0xFF111111),
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: () {
                    rootNavigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            LiveRoomView(isHost: m.isHost, liveId: s.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.title,
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
                                builder: (_, __) {
                                  final d = m.elapsed;
                                  String two(int v) =>
                                      v.toString().padLeft(2, '0');
                                  final t = d.inHours > 0
                                      ? '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}'
                                      : '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
                                  return Text(
                                    '${m.isHost ? 'Vous êtes en direct' : 'Vous regardez'} · $t · ${m.viewerCount} spectateurs',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        fontSize: 11.5),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (m.isHost || m.isOnStage)
                          IconButton(
                            icon: Icon(
                              m.muted ? Icons.mic_off : Icons.mic,
                              color: Colors.white,
                            ),
                            onPressed: m.toggleMute,
                          ),
                        IconButton(
                          tooltip: m.isHost ? 'Terminer' : 'Quitter',
                          icon: const Icon(Icons.close_rounded,
                              color: ThixPolicy.danger),
                          onPressed: () async {
                            if (m.isHost) {
                              await m.endLive();
                            } else {
                              await m.leave();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
