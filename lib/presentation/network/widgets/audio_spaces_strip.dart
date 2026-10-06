// lib/presentation/network/widgets/audio_spaces_strip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/network/live/audio_space_room_screen.dart';
import 'package:thix_id/presentation/network/live/create_audio_space_sheet.dart';

final activeAudioSpacesProvider = StreamProvider.autoDispose<List<AudioSpace>>((ref) {
  try {
    return Supabase.instance.client
        .from('audio_spaces')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(12)
        .map((rows) => rows
            .map(AudioSpace.fromMap)
            .where((s) => s.isLive && s.id.isNotEmpty)
            .toList());
  } catch (e) {
    debugPrint('[AudioSpaces] stream error: $e');
    return Stream.value(const <AudioSpace>[]);
  }
});

class AudioSpacesStrip extends ConsumerWidget {
  const AudioSpacesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(activeAudioSpacesProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (spaces) {
        if (spaces.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── HEADER COMPACT ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LiveDot(),
                        const SizedBox(width: 5),
                        Text(
                          l10n.t('audio_space_live_title'),
                          style: ThixPolicy.captionStyle.copyWith(
                            color: const Color(0xFF7C4DFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CreateAudioSpaceSheet(),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 13, color: Color(0xFF7C4DFF)),
                          const SizedBox(width: 3),
                          Text(
                            l10n.t('audio_space_create_short'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C4DFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ─── LISTE COMPACTE ───
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: spaces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _CompactLiveSpaceCard(
                    space: spaces[i],
                    cta: l10n.t('audio_space_join'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CARTE COMPACTE
// ════════════════════════════════════════════════════════════════════════
class _CompactLiveSpaceCard extends StatelessWidget {
  final AudioSpace space;
  final String cta;

  const _CompactLiveSpaceCard({required this.space, required this.cta});

  @override
  Widget build(BuildContext context) {
    final count = space.listenerCount + space.speakerCount;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AudioSpaceRoomScreen(space: space)),
      ),
      child: Container(
        width: 210,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E0FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ─── ICÔNE LIVE ───
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF5E35B1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),

            // ─── TEXTE ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    space.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: ThixPolicy.inkDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 11, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.mic_rounded, size: 10, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        space.hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // ─── BOUTON JOIN ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                cta,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// LIVE DOT (animation)
// ════════════════════════════════════════════════════════════════════════
class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF7C4DFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.5 * _ctrl.value),
              blurRadius: 4,
              spreadRadius: 1.5 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}
