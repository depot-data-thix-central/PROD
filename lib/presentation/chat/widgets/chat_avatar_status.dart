// lib/presentation/chat/widgets/chat_avatar_status.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/user_status.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kDefaultRadius = 24.0;
const double _kBorderWidth = 2.0;
const double _kIndicatorPadding = 2.0;
const double _kIndicatorOffset = -1.0;
const double _kFallbackIconRatio = 0.9;
const double _kIndicatorRatio = 0.55;
const double _kShadowBlur = 8.0;
const double _kShadowOffsetY = 2.0;
const double _kMaxInitialsLength = 2;

// ============================================================================
// VALIDATORS
// ============================================================================
class _AvatarValidators {
  _AvatarValidators._();

  /// Valide et sanitise une URL d'image (http/https uniquement)
  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    // Retirer caractères de contrôle
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Valide le statut (fallback sur offline si inconnu)
  static String validateStatus(String? status) {
    if (status == null || status.trim().isEmpty) return UserStatus.offline;
    const validStatuses = [
      UserStatus.online,
      UserStatus.offline,
      UserStatus.busy,
      UserStatus.away,
      UserStatus.doNotDisturb,
    ];
    return validStatuses.contains(status) ? status : UserStatus.offline;
  }

  /// Extrait les initiales d'un nom (max 2 caractères)
  static String extractInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ============================================================================
// CHAT AVATAR STATUS
// ============================================================================

/// Avatar circulaire avec indicateur de statut de présence.
///
/// Affiche :
/// - Image de profil (avec cache) ou fallback (initiales ou icône)
/// - Indicateur de statut en bas à droite (online, offline, busy, etc.)
///
/// Exemple d'utilisation :
/// ```dart
/// ChatAvatarStatus(
///   imageUrl: user.photoUrl,
///   status: UserStatus.online,
///   initials: 'JD',
///   onTap: () => openProfile(user.id),
/// )
/// ```
class ChatAvatarStatus extends StatelessWidget {
  /// URL de l'image de profil (sanitisée automatiquement)
  final String? imageUrl;

  /// Statut de présence (online, offline, busy, away, doNotDisturb)
  final String status;

  /// Rayon de l'avatar en pixels (défaut : 24)
  final double radius;

  /// Callback au tap (optionnel)
  final VoidCallback? onTap;

  /// Initiales à afficher si image absente (optionnel, ex: "JD")
  final String? initials;

  /// Nom pour label accessibility (optionnel)
  final String? name;

  const ChatAvatarStatus({
    super.key,
    this.imageUrl,
    this.status = UserStatus.offline,
    this.radius = _kDefaultRadius,
    this.onTap,
    this.initials,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeUrl = _AvatarValidators.sanitizeUrl(imageUrl);
    final safeStatus = _AvatarValidators.validateStatus(status);
    final safeInitials = _AvatarValidators.extractInitials(initials ?? name);

    // Label accessibility dynamique
    final statusLabel = _getStatusLabel(l10n, safeStatus);
    final nameLabel = name ?? l10n.t('avatar_user');
    final semanticsLabel = onTap != null
        ? '${l10n.t('avatar_view_profile')}: $nameLabel - $statusLabel'
        : '$nameLabel - $statusLabel';

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  debugPrint('[ChatAvatar] 👆 Tapped: $nameLabel');
                  onTap!();
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Avatar principal ──
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.card, width: _kBorderWidth),
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
                ),
                child: ClipOval(
                  child: safeUrl != null
                      ? CachedNetworkImage(
                          imageUrl: safeUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildFallback(safeInitials),
                          errorWidget: (_, __, ___) {
                            debugPrint('[ChatAvatar] ⚠️ Image load failed: ${safeUrl.substring(0, safeUrl.length > 40 ? 40 : safeUrl.length)}...');
                            return _buildFallback(safeInitials);
                          },
                        )
                      : _buildFallback(safeInitials),
                ),
              ),

              // ── Indicateur de statut ──
              Positioned(
                bottom: _kIndicatorOffset,
                right: _kIndicatorOffset,
                child: Container(
                  padding: const EdgeInsets.all(_kIndicatorPadding),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    shape: BoxShape.circle,
                  ),
                  child: UserStatus.presenceIndicator(
                    safeStatus,
                    size: radius * _kIndicatorRatio,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit le fallback (initiales ou icône)
  Widget _buildFallback(String initials) {
    if (initials.isNotEmpty) {
      return Container(
        color: ThixPolicy.primary.withOpacity(0.1),
        child: Center(
          child: Text(
            initials.length > _kMaxInitialsLength
                ? initials.substring(0, _kMaxInitialsLength)
                : initials,
            style: TextStyle(
              color: ThixPolicy.primary,
              fontSize: radius * 0.7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.person_rounded,
        size: radius * _kFallbackIconRatio,
        color: ThixPolicy.textMuted,
      ),
    );
  }

  /// Retourne le label i18n du statut
  String _getStatusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case UserStatus.online:
        return l10n.t('avatar_status_online');
      case UserStatus.busy:
        return l10n.t('avatar_status_busy');
      case UserStatus.away:
        return l10n.t('avatar_status_away');
      case UserStatus.doNotDisturb:
        return l10n.t('avatar_status_dnd');
      case UserStatus.offline:
      default:
        return l10n.t('avatar_status_offline');
    }
  }
}
