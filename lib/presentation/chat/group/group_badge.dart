// lib/presentation/chat/group/widgets/group_badge.dart
//
// ============================================================================
// GROUP BADGE — Production Enterprise
// ============================================================================
//
// Widget de badge affichant le rôle d'un membre dans un groupe.
//
// Fonctionnalités :
//   - 4 rôles supportés : admin, moderator, member, bot
//   - Mode compact (icône seule) ou complet (icône + texte)
//   - Couleurs ThixPolicy pour cohérence design system
//   - Support i18n via AppLocalizations
//   - Accessibilité VoiceOver via Semantics
//
// Usage :
//   ```dart
//   // Badge complet
//   GroupBadge(role: GroupRole.admin)
//
//   // Badge compact (icône seule)
//   GroupBadge(role: GroupRole.moderator, isCompact: true)
//
//   // Badge avec taille custom
//   GroupBadge(role: GroupRole.member, fontSize: 12)
//   ```
//
// Sécurité :
//   - Enum type-safe (pas de String arbitraire)
//   - Validation fontSize (clamp 8-24)
//   - RepaintBoundary pour performance
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

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
// GROUP ROLE ENUM
// ============================================================================

/// Rôle d'un membre dans un groupe.
///
/// **Hiérarchie** :
/// - `admin` : Administrateur du groupe (permissions complètes)
/// - `moderator` : Modérateur (peut gérer les membres)
/// - `member` : Membre standard
/// - `bot` : Compte bot automatisé
enum GroupRole {
  /// Administrateur du groupe.
  admin(
    dbValue: 'admin',
    i18nKey: 'group_role_admin',
    fallbackLabel: 'Admin',
  ),

  /// Modérateur du groupe.
  moderator(
    dbValue: 'moderator',
    i18nKey: 'group_role_moderator',
    fallbackLabel: 'Modérateur',
  ),

  /// Membre standard.
  member(
    dbValue: 'member',
    i18nKey: 'group_role_member',
    fallbackLabel: 'Membre',
  ),

  /// Compte bot automatisé.
  bot(
    dbValue: 'bot',
    i18nKey: 'group_role_bot',
    fallbackLabel: 'Bot',
  );

  /// Valeur stockée en base de données.
  final String dbValue;

  /// Clé i18n pour le label traduit.
  final String i18nKey;

  /// Label de fallback en français.
  final String fallbackLabel;

  const GroupRole({
    required this.dbValue,
    required this.i18nKey,
    required this.fallbackLabel,
  });

  /// Label traduit via AppLocalizations.
  String localizedLabel(AppLocalizations? l10n) {
    if (l10n == null) return fallbackLabel;
    try {
      return l10n.t(i18nKey);
    } catch (_) {
      return fallbackLabel;
    }
  }

  /// Parse une string en `GroupRole`.
  ///
  /// **Exemples** :
  /// ```dart
  /// GroupRole.fromString('admin');     // GroupRole.admin
  /// GroupRole.fromString('MODERATOR'); // GroupRole.moderator (case-insensitive)
  /// GroupRole.fromString('unknown');   // GroupRole.member (fallback)
  /// ```
  static GroupRole fromString(
    String? value, {
    GroupRole fallback = GroupRole.member,
  }) {
    if (value == null || value.isEmpty) return fallback;

    final normalized = value.trim().toLowerCase();

    // Recherche par dbValue
    for (final role in GroupRole.values) {
      if (role.dbValue == normalized) return role;
    }

    // Fallback : recherche par nom enum
    for (final role in GroupRole.values) {
      if (role.name.toLowerCase() == normalized) return role;
    }

    return fallback;
  }
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupBadgeValidators {
  _GroupBadgeValidators._();

  /// Clamp la taille de police entre min et max.
  static double clampFontSize(double fontSize) {
    return fontSize.clamp(_kMinFontSize, _kMaxFontSize);
  }
}

// ============================================================================
// GROUP BADGE WIDGET
// ============================================================================

/// Widget de badge affichant le rôle d'un membre dans un groupe.
///
/// **Exemples** :
/// ```dart
/// // Badge complet (icône + texte)
/// GroupBadge(role: GroupRole.admin)
///
/// // Badge compact (icône seule)
/// GroupBadge(role: GroupRole.moderator, isCompact: true)
///
/// // Badge avec taille custom
/// GroupBadge(role: GroupRole.member, fontSize: 12)
/// ```
class GroupBadge extends StatelessWidget {
  /// Rôle du membre.
  final GroupRole role;

  /// Taille de police du texte (clampée entre 8 et 24).
  final double fontSize;

  /// Mode compact : affiche uniquement l'icône (pas de texte).
  final bool isCompact;

  const GroupBadge({
    super.key,
    required this.role,
    this.fontSize = _kDefaultFontSize,
    this.isCompact = false,
  });

  /// Constructor legacy acceptant une String pour `role`.
  ///
  /// ⚠️ **Déprécié** : Utiliser le constructor principal avec `GroupRole` enum.
  @Deprecated('Use GroupBadge(role: GroupRole.fromString(roleString)) instead')
  factory GroupBadge.fromString({
    Key? key,
    required String role,
    double fontSize = _kDefaultFontSize,
    bool isCompact = false,
  }) {
    return GroupBadge(
      key: key,
      role: GroupRole.fromString(role),
      fontSize: fontSize,
      isCompact: isCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeFontSize = _GroupBadgeValidators.clampFontSize(fontSize);
    final style = _getBadgeStyle(role);
    final label = role.localizedLabel(l10n);

    return RepaintBoundary(
      child: Semantics(
        label: label,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? _kCompactHorizontalPadding : _kNormalHorizontalPadding,
            vertical: isCompact ? _kCompactVerticalPadding : _kNormalVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: style.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: style.color.withOpacity(0.3),
              width: _kBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (style.icon != null) ...[
                Icon(
                  style.icon,
                  size: safeFontSize + _kIconSizeOffset,
                  color: style.color,
                ),
                if (!isCompact) const SizedBox(width: _kIconTextSpacing),
              ],
              if (!isCompact || style.icon == null)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: safeFontSize,
                    fontWeight: FontWeight.w600,
                    color: style.color,
                    letterSpacing: _kLetterSpacing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Retourne le style visuel associé au rôle.
  _BadgeStyle _getBadgeStyle(GroupRole role) {
    switch (role) {
      case GroupRole.admin:
        return _BadgeStyle(
          color: ThixPolicy.gold,
          icon: Icons.star_rounded,
        );
      case GroupRole.moderator:
        return _BadgeStyle(
          color: ThixPolicy.primary,
          icon: Icons.shield_rounded,
        );
      case GroupRole.bot:
        return _BadgeStyle(
          color: ThixPolicy.textMuted,
          icon: Icons.smart_toy_rounded,
        );
      case GroupRole.member:
        return _BadgeStyle(
          color: ThixPolicy.textMuted,
          icon: null,
        );
    }
  }
}

// ============================================================================
// INTERNAL STYLE CLASS
// ============================================================================

/// Style visuel d'un badge (couleur + icône optionnelle).
class _BadgeStyle {
  final Color color;
  final IconData? icon;

  const _BadgeStyle({
    required this.color,
    this.icon,
  });
}

// ============================================================================
// EXTENSIONS
// ============================================================================

/// Extension sur `String` pour conversion facile en `GroupRole`.
extension GroupRoleStringX on String? {
  /// Convertit une string en `GroupRole`.
  ///
  /// ```dart
  /// final role = 'admin'.toGroupRole();
  /// ```
  GroupRole toGroupRole({GroupRole fallback = GroupRole.member}) {
    return GroupRole.fromString(this, fallback: fallback);
  }
}
