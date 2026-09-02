/// MediaInfoBand — bande d'info du feed vidéo
/// - Absorbe les taps (n'ouvre PAS la vidéo)
/// - Affiche le compte auteur (avatar + @username) → profil
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';

class MediaInfoBand extends StatelessWidget {
  final MediaContent item;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final String? creatorId;
  final int likes;
  final int comments;
  final int views;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onOpenComments;
  final VoidCallback onFullscreen;
  final VoidCallback onOpenProfile;

  const MediaInfoBand({
    super.key,
    required this.item,
    required this.likes,
    required this.comments,
    required this.views,
    required this.isLiked,
    required this.onLike,
    required this.onOpenComments,
    required this.onFullscreen,
    required this.onOpenProfile,
    this.creatorName,
    this.creatorAvatarUrl,
    this.creatorId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // FIX BUG 1 : GestureDetector opaque = le tap reste DANS la bande.
    // Le recognizer le plus profond gagne l'arène de gestes :
    // le handler "tap vidéo" (ancêtre) ne se déclenche JAMAIS ici.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // absorbe volontairement le tap
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + catégorie
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // FIX BUG 2 : compte auteur (avatar + @username) → profil
            Semantics(
              button: true,
              label: '${l10n.t("band_open_profile")} ${creatorName ?? ""}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenProfile();
                },
                child: Row(
                  children: [
                    _CreatorAvatar(url: creatorAvatarUrl),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        creatorName?.isNotEmpty == true
                            ? '@${creatorName!}'
                            : l10n.t('band_unknown_creator'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: Colors.white.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            const SizedBox(height: 10),

            // Actions (chaque bouton = recognizer propre, gagne l'arène)
            Row(
              children: [
                _actionButton(
                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? ThixPolicy.danger : Colors.white70,
                  count: likes,
                  label: l10n.t('band_like'),
                  onTap: onLike,
                ),
                const Spacer(),
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white70,
                  count: comments,
                  label: l10n.t('band_comments'),
                  onTap: onOpenComments, // ouvre UNIQUEMENT la sheet commentaires
                ),
                const Spacer(),
                _actionButton(
                  icon: Icons.visibility_outlined,
                  color: Colors.white70,
                  count: views,
                  label: l10n.t('band_views'),
                  onTap: () {}, // compteur, pas d'action
                ),
                const Spacer(),
                _actionButton(
                  icon: Icons.fullscreen_rounded,
                  color: Colors.white70,
                  label: l10n.t('band_fullscreen'),
                  onTap: onFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    int? count,
  }) {
    return Semantics(
      button: true,
      label: count != null ? '$label $count' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String? url;
  const _CreatorAvatar({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, size: 16, color: Colors.white54),
              )
            : const Icon(Icons.person, size: 16, color: Colors.white54),
      ),
    );
  }
}
