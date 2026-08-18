// lib/presentation/chat/widgets/status_story_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/status/create_status_page.dart';
import 'package:thix_id/presentation/chat/status/status_viewer_page.dart';

class StatusStoryRow extends ConsumerWidget {
  final String currentUserId;
  final String? currentUserAvatar;
  final String currentUserName;

  const StatusStoryRow({
    super.key,
    required this.currentUserId,
    this.currentUserAvatar,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statusProvider);

    if (state.isLoading && state.items.isEmpty) {
      return const SizedBox(
        height: 98,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary), // Corrigé pour fond clair
          ),
        ),
      );
    }

    final byUser = state.byUser;
    final ordered = state.orderedUserIds;
    final hasMine = ordered.any((id) => byUser[id]?.any((s) => s.isMine) == true);

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: ordered.length + (hasMine ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, i) {
          // Bouton "Mon statut" toujours en premier si pas encore de statut
          if (!hasMine && i == 0) {
            return _StatusAvatar(
              label: 'Mon statut',
              avatarUrl: currentUserAvatar,
              isAdd: true,
              hasUnseen: false,
              onTap: () => _openCreate(context),
            );
          }

          final idx = hasMine ? i : i - 1;
          final userId = ordered[idx];
          final stories = byUser[userId] ?? [];
          if (stories.isEmpty) return const SizedBox.shrink();

          final first = stories.first;
          final isMine = first.isMine;
          final hasUnseen = stories.any((s) => !s.hasViewed && !s.isMine);

          return _StatusAvatar(
            label: isMine ? 'Mon statut' : first.displayName.split(' ').first,
            avatarUrl: first.avatarUrl,
            isAdd: isMine && stories.isEmpty,
            hasUnseen: hasUnseen,
            isMine: isMine,
            onTap: () {
              if (isMine && stories.isEmpty) {
                _openCreate(context);
              } else {
                _openViewer(context, ref, stories);
              }
            },
            onLongPress: isMine
                ? () => _openCreate(context)
                : null,
          );
        },
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStatusPage()),
    );
  }

  void _openViewer(
    BuildContext context,
    WidgetRef ref,
    List<UserStatusStory> stories,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerPage(stories: stories),
      ),
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final bool isAdd;
  final bool hasUnseen;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StatusAvatar({
    required this.label,
    this.avatarUrl,
    this.isAdd = false,
    this.hasUnseen = false,
    this.isMine = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = hasUnseen
        ? ThixPolicy.gold // non vu
        : (isMine
            ? ThixPolicy.primary
            : ThixPolicy.borderStrong); // Corrigé pour lisibilité sur fond clair

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasUnseen || isMine
                      ? LinearGradient(
                          colors: hasUnseen
                              ? const [Color(0xFFE3B23C), Color(0xFFF3D999)]
                              : const [Color(0xFF2D6CDF), Color(0xFF60A5FA)],
                        )
                      : null,
                  color: hasUnseen || isMine ? null : ringColor,
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: ThixPolicy.tint, // Corrigé pour fond clair
                  backgroundImage:
                      avatarUrl != null && avatarUrl!.isNotEmpty
                          ? NetworkImage(avatarUrl!)
                          : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Icon(
                          isAdd ? Icons.add : Icons.person_rounded,
                          color: ThixPolicy.primaryDeep, // Corrigé pour lisibilité
                          size: isAdd ? 26 : 22,
                        )
                      : null,
                ),
              ),
              if (isAdd || isMine)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary,
                      shape: BoxShape.circle,
                      // La bordure prend la couleur du fond (ThixPolicy.card = blanc) pour bien détacher le bouton
                      border: Border.all(color: ThixPolicy.card, width: 2), 
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ThixPolicy.textMain, // 🌟 Corrigé : le texte est noir/foncé maintenant !
              ),
            ),
          ),
        ],
      ),
    );
  }
}
