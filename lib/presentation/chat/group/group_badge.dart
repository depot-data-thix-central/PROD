// lib/presentation/chat/group/widgets/group_badge.dart
//
// ============================================================================
// GROUP BADGE — Production Enterprise++ (Dépasse WhatsApp)
// ============================================================================
//
// Widget de badge affichant le rôle d'un membre dans un groupe.
//
// Fonctionnalités :
//   - 8 rôles supportés : owner, admin, moderator, editor, member, muted, observer, bot
//   - Mode compact (icône seule) ou complet (icône + texte)
//   - Couleurs ThixPolicy pour cohérence design system
//   - Support i18n via AppLocalizations
//   - Accessibilité VoiceOver via Semantics
//   - Validation fontSize (clamp 8-24)
//   - RepaintBoundary pour performance
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
//
//   // À partir d'une String (legacy)
//   GroupBadge(role: GroupRole.fromString('owner'))
//   ```
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
/// **Hiérarchie** (du plus élevé au plus bas) :
/// - `owner` : Propriétaire du groupe (permissions maximales, non transférable)
/// - `admin` : Administrateur du groupe (permissions complètes)
/// - `moderator` : Modérateur (peut supprimer messages, muter membres)
/// - `editor` : Éditeur (peut modifier description/avatar du groupe)
/// - `member` : Membre standard
/// - `muted` : Membre muté (lecture seule temporaire)
/// - `observer` : Observateur (lecture seule permanente, pas de statut en ligne)
/// - `bot` : Compte bot automatisé
enum GroupRole {
  /// Propriétaire du groupe (permissions maximales).
  owner(
    dbValue: 'owner',
    i18nKey: 'group_role_owner',
    fallbackLabel: 'Propriétaire',
    color: Color(0xFFE3B23C), // Or premium
    icon: Icons.workspace_premium_rounded,
  ),

  /// Administrateur du groupe.
  admin(
    dbValue: 'admin',
    i18nKey: 'group_role_admin',
    fallbackLabel: 'Admin',
    color: Color(0xFFE3B23C), // Or
    icon: Icons.star_rounded,
  ),

  /// Modérateur du groupe.
  moderator(
    dbValue: 'moderator',
    i18nKey: 'group_role_moderator',
    fallbackLabel: 'Modérateur',
    color: Color(0xFF2D6CDF), // Bleu
    icon: Icons.shield_rounded,
  ),

  /// Éditeur du groupe.
  editor(
    dbValue: 'editor',
    i18nKey: 'group_role_editor',
    fallbackLabel: 'Éditeur',
    color: Color(0xFF10B981), // Vert
    icon: Icons.edit_rounded,
  ),

  /// Membre standard.
  member(
    dbValue: 'member',
    i18nKey: 'group_role_member',
    fallbackLabel: 'Membre',
    color: Color(0xFF6B7690), // Gris
    icon: null,
  ),

  /// Membre muté (lecture seule temporaire).
  muted(
    dbValue: 'muted',
    i18nKey: 'group_role_muted',
    fallbackLabel: 'Muté',
    color: Color(0xFFEF4444), // Rouge
    icon: Icons.volume_off_rounded,
  ),

  /// Observateur (lecture seule permanente).
  observer(
    dbValue: 'observer',
    i18nKey: 'group_role_observer',
    fallbackLabel: 'Observateur',
    color: Color(0xFF8B5CF6), // Violet
    icon: Icons.visibility_rounded,
  ),

  /// Compte bot automatisé.
  bot(
    dbValue: 'bot',
    i18nKey: 'group_role_bot',
    fallbackLabel: 'Bot',
    color: Color(0xFF6B7690), // Gris
    icon: Icons.smart_toy_rounded,
  );

  /// Valeur stockée en base de données.
  final String dbValue;

  /// Clé i18n pour le label traduit.
  final String i18nKey;

  /// Label de fallback en français.
  final String fallbackLabel;

  /// Couleur associée au rôle.
  final Color color;

  /// Icône associée au rôle (optionnelle).
  final IconData? icon;

  const GroupRole({
    required this.dbValue,
    required this.i18nKey,
    required this.fallbackLabel,
    required this.color,
    this.icon,
  });

  /// Label traduit via AppLocalizations.
  String localizedLabel(AppLocalizations? l10n) {
    if (l10n == null) return fallbackLabel;
    try {
      final translated = l10n.t(i18nKey);
      return translated == i18nKey ? fallbackLabel : translated;
    } catch (_) {
      return fallbackLabel;
    }
  }

  /// Parse une string en `GroupRole`.
  ///
  /// **Exemples** :
  /// ```dart
  /// GroupRole.fromString('admin');      // GroupRole.admin
  /// GroupRole.fromString('OWNER');      // GroupRole.owner (case-insensitive)
  /// GroupRole.fromString('unknown');    // GroupRole.member (fallback)
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

  /// Vérifie si ce rôle a des privilèges d'administration.
  bool get hasAdminPrivileges => this == owner || this == admin;

  /// Vérifie si ce rôle peut modérer (supprimer messages, muter).
  bool get canModerate => hasAdminPrivileges || this == moderator;

  /// Vérifie si ce rôle peut éditer les infos du groupe.
  bool get canEditGroupInfo => hasAdminPrivileges || this == editor;

  /// Vérifie si ce rôle est restreint (lecture seule).
  bool get isRestricted => this == muted || this == observer;
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
///
/// // À partir d'une String (legacy)
/// GroupBadge(role: GroupRole.fromString('owner'))
/// ```
class GroupBadge extends StatelessWidget {
  /// Rôle du membre.
  final GroupRole role;

  /// Taille de police du texte (clampée entre 8 et 24).
  final double fontSize;

  /// Mode compact : affiche uniquement l'icône (pas de texte).
  final bool isCompact;

  /// Afficher uniquement l'icône (alias de isCompact).
  final bool iconOnly;

  const GroupBadge({
    super.key,
    required this.role,
    this.fontSize = _kDefaultFontSize,
    this.isCompact = false,
    this.iconOnly = false,
  });

  /// Constructor legacy acceptant une String pour `role`.
  ///
  /// ⚠️ **Déprécié** : Utiliser le constructor principal avec `GroupRole.fromString()`.
  @Deprecated('Use GroupBadge(role: GroupRole.fromString(roleString)) instead')
  factory GroupBadge.fromString({
    Key? key,
    required String role,
    double fontSize = _kDefaultFontSize,
    bool isCompact = false,
    bool iconOnly = false,
  }) {
    return GroupBadge(
      key: key,
      role: GroupRole.fromString(role),
      fontSize: fontSize,
      isCompact: isCompact,
      iconOnly: iconOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeFontSize = _GroupBadgeValidators.clampFontSize(fontSize);
    final label = role.localizedLabel(l10n);
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
            color: role.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: role.color.withOpacity(0.3),
              width: _kBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (role.icon != null) ...[
                Icon(
                  role.icon,
                  size: safeFontSize + _kIconSizeOffset,
                  color: role.color,
                ),
                if (!effectiveCompact) const SizedBox(width: _kIconTextSpacing),
              ],
              if (!effectiveCompact || role.icon == null)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: safeFontSize,
                    fontWeight: FontWeight.w600,
                    color: role.color,
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

/// Extension sur `GroupRole` pour utilitaires supplémentaires.
extension GroupRoleUtilsX on GroupRole {
  /// Retourne un badge widget prêt à l'emploi.
  Widget toBadge({
    Key? key,
    double fontSize = _kDefaultFontSize,
    bool isCompact = false,
    bool iconOnly = false,
  }) {
    return GroupBadge(
      key: key,
      role: this,
      fontSize: fontSize,
      isCompact: isCompact,
      iconOnly: iconOnly,
    );
  }
}
