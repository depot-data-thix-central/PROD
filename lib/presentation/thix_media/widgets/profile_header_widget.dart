// lib/presentation/thix_media/widgets/profile_header_widget.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../thix_media_page.dart' show MediaLightPalette, MediaSanitizer, formatMediaNumber;

class ProfileHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, int>? stats;
  final bool isFollowing;
  final bool isMe;
  final String? certTier;
  final bool isCertified;
  final VoidCallback onEditProfile;

  const ProfileHeaderWidget({
    super.key,
    required this.profile,
    required this.stats,
    required this.isFollowing,
    required this.isMe,
    required this.certTier,
    required this.isCertified,
    required this.onEditProfile,
  });

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  // ✅ Couleur du badge selon le tier
  Color _getCertBadgeColor() {
    if (!isCertified) return MediaLightPalette.textMuted;
    switch (certTier?.toLowerCase()) {
      case 'official':
        return const Color(0xFF1E40AF); // Bleu officiel
      case 'enterprise':
        return const Color(0xFF7C3AED); // Violet
      case 'premium':
        return const Color(0xFFD4A017); // Or
      case 'standard':
        return const Color(0xFF0891B2); // Cyan
      default:
        return MediaLightPalette.textMuted;
    }
  }

  String _getCertLabel(AppLocalizations l10n) {
    if (!isCertified) return '';
    switch (certTier?.toLowerCase()) {
      case 'official':
        return _safeTr(l10n, 'certification_tier_official', 'Officiel');
      case 'enterprise':
        return _safeTr(l10n, 'certification_tier_enterprise', 'Entreprise');
      case 'premium':
        return _safeTr(l10n, 'certification_tier_premium', 'Premium');
      case 'standard':
        return _safeTr(l10n, 'certification_tier_standard', 'Standard');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = profile['avatar_url'] as String?;
    final fullName = MediaSanitizer.text(
        profile['full_name'] as String? ?? '',
        maxLength: 40);
    final username = MediaSanitizer.text(
        profile['username'] as String? ?? '',
        maxLength: 30);
    final bio = MediaSanitizer.text(
        profile['bio'] as String? ?? '',
        maxLength: 200);

    final followers = stats?['followers'] ?? 0;
    final following = stats?['following'] ?? 0;
    final posts = stats?['posts'] ?? 0;

    final displayName = fullName.isNotEmpty ? fullName : username;
    final certColor = _getCertBadgeColor();
    final certLabel = _getCertLabel(l10n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: MediaLightPalette.border, width: 3),
                  image: avatarUrl != null && avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 48, color: MediaLightPalette.textMuted)
                    : null,
              ),
              const SizedBox(width: 20),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                        count: posts,
                        label: _safeTr(l10n, 'profile_posts', 'Publications')),
                    _StatColumn(
                        count: followers,
                        label: _safeTr(l10n, 'network_followers', 'Abonnés')),
                    _StatColumn(
                        count: following,
                        label: _safeTr(l10n, 'network_following', 'Abonnements')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Nom + Badge de certification
          Row(
            children: [
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MediaLightPalette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (isCertified && certLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                _CertBadge(color: certColor, label: certLabel),
              ],
            ],
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@$username',
              style: const TextStyle(
                color: MediaLightPalette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              style: const TextStyle(
                color: MediaLightPalette.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // Boutons d'action
          Row(
            children: [
              if (isMe)
                Expanded(
                  child: _ActionButton(
                    label: _safeTr(l10n, 'profile_edit', 'Modifier le profil'),
                    icon: Icons.edit_rounded,
                    onTap: onEditProfile,
                    isPrimary: true,
                  ),
                )
              else ...[
                Expanded(
                  child: _ActionButton(
                    label: isFollowing
                        ? _safeTr(l10n, 'network_following', 'Abonné')
                        : _safeTr(l10n, 'network_follow', 'Suivre'),
                    icon: isFollowing
                        ? Icons.check_rounded
                        : Icons.person_add_rounded,
                    onTap: () {/* TODO: toggle follow */},
                    isPrimary: !isFollowing,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: _safeTr(l10n, 'common_chat', 'Message'),
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () {/* TODO: open chat */},
                    isPrimary: false,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;
  const _StatColumn({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatMediaNumber(count),
          style: const TextStyle(
            color: MediaLightPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: MediaLightPalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CertBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _CertBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? ThixPolicy.primary : MediaLightPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? ThixPolicy.primary
                : MediaLightPalette.border,
            width: 1.5,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: ThixPolicy.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isPrimary
                    ? Colors.white
                    : MediaLightPalette.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? Colors.white
                    : MediaLightPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
