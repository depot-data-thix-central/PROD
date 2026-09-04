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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFEDE7FF),
                    child: Icon(Icons.mic_none_rounded, size: 16, color: Color(0xFF7C4DFF)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('audio_space_live_title'),
                      style: ThixPolicy.h2Style.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CreateAudioSpaceSheet(),
                    ),
                    child: Text(l10n.t('audio_space_create_short')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: spaces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final s = spaces[i];
                    return _LiveSpaceCard(
                      title: s.title,
                      subtitle: '${s.hostName} · ${s.listenerCount + s.speakerCount}',
                      cta: l10n.t('audio_space_join'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AudioSpaceRoomScreen(space: s)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveSpaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  const _LiveSpaceCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.graphic_eq_rounded, size: 16, color: Color(0xFF7C4DFF)),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(cta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
