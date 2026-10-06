// lib/presentation/chat/group/group_badge.dart
//
// ============================================================================
// GROUP BADGE — Production Enterprise++ (Dépasse WhatsApp)
// ============================================================================
//
// Widget de badge affichant le rôle d'un membre dans un groupe.
// Utilise GroupRole depuis models/chat/group_info.dart (source unique).
//
// Fonctionnalités :
//   - 8 rôles supportés : owner, admin, moderator, editor, member, muted, observer, bot
//   - Mode compact (icône seule) ou complet (icône + texte)
//   - Couleurs ThixPolicy pour cohérence design system
//   - Support i18n via AppLocalizations
//   - Accessibilité VoiceOver via Semantics
//   - Validation fontSize (clamp 8-24)
//   - RepaintBoundary pour performance
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/group_info.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kDefaultFontSize = 10.0;
const double _kMinFontSize = 8.0;
const double _kMaxFontSize = 24.0;
const double _kLetterSpacing = 0.3;
const double _kBorderRadius = 12.0;
const double _kBorderWidth = 1.0;
const double _kIconSizeOffset = 2.0;
const double _kCompactHorizontalPadding = 6.0;
const double _kCompactVerticalPadding = 2.0;
const double _kNormalHorizontalPadding = 10.0;
const double _kNormalVerticalPadding = 4.0;
const double _kIconTextSpacing = 4.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupBadgeValidators {
  _GroupBadgeValidators._();

  static double clampFontSize(double fontSize) {
    return fontSize.clamp(_kMinFontSize, _kMaxFontSize);
  }

  /// Parse une couleur hex (#RRGGBB) en Color
  static Color parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// ============================================================================
// GROUP BADGE WIDGET
// ============================================================================

/// Widget de badge affichant le rôle d'un membre dans un groupe.
class GroupBadge extends StatelessWidget {
  final GroupRole role;
  final double fontSize;
  final bool isCompact;
  final bool iconOnly;

  const GroupBadge({
    super.key,
    required this.role,
    this.fontSize = _kDefaultFontSize,
    this.isCompact = false,
    this.iconOnly = false,
  });

  @Deprecated('Use GroupBadge(role: GroupRoleX.fromString(roleString)) instead')
  factory GroupBadge.fromString({
    Key? key,
    required String role,
    double fontSize = _kDefaultFontSize,
    bool isCompact = false,
    bool iconOnly = false,
  }) {
    return GroupBadge(
      key: key,
      role: GroupRoleX.fromString(role),
      fontSize: fontSize,
      isCompact: isCompact,
      iconOnly: iconOnly,
    );
  }

  /// Retourne la couleur du rôle (parse le hex depuis le modèle)
  Color _getColor() {
    return _GroupBadgeValidators.parseHexColor(role.badgeColor);
  }

  /// Retourne l'icône du rôle
  IconData? _getIcon() {
    switch (role) {
      case GroupRole.owner:
        return Icons.workspace_premium_rounded;
      case GroupRole.admin:
        return Icons.star_rounded;
      case GroupRole.moderator:
        return Icons.shield_rounded;
      case GroupRole.editor:
        return Icons.edit_rounded;
      case GroupRole.member:
        return null;
      case GroupRole.muted:
        return Icons.volume_off_rounded;
      case GroupRole.observer:
        return Icons.visibility_rounded;
      case GroupRole.bot:
        return Icons.smart_toy_rounded;
    }
  }

  /// Retourne le label traduit du rôle
  String _getLabel(AppLocalizations? l10n) {
    if (l10n == null) return role.displayName;
    try {
      final key = 'group_role_${role.name}';
      final translated = l10n.t(key);
      return translated == key ? role.displayName : translated;
    } catch (_) {
      return role.displayName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeFontSize = _GroupBadgeValidators.clampFontSize(fontSize);
    final label = _getLabel(l10n);
    final color = _getColor();
    final icon = _getIcon();
    final effectiveCompact = isCompact || iconOnly;

    return RepaintBoundary(
      child: Semantics(
        label: label,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: effectiveCompact ? _kCompactHorizontalPadding : _kNormalHorizontalPadding,
            vertical: effectiveCompact ? _kCompactVerticalPadding : _kNormalVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: _kBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: safeFontSize + _kIconSizeOffset,
                  color: color,
                ),
                if (!effectiveCompact) const SizedBox(width: _kIconTextSpacing),
              ],
              if (!effectiveCompact || icon == null)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: safeFontSize,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: _kLetterSpacing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
