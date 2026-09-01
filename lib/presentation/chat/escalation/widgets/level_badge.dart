// lib/presentation/chat/escalation/widgets/level_badge.dart
//
// ============================================================================
// LEVEL BADGE — Production Enterprise
// ============================================================================
//
// Widget badge affichant le niveau d'escalade d'un agent.
//
// Fonctionnalités :
//   - Affichage icône + label court (optionnel)
//   - Couleurs dynamiques selon le niveau (ThixPolicy)
//   - Support i18n via AppLocalizations
//   - Accessibilité VoiceOver via Semantics
//   - RepaintBoundary pour performance
//
// Usage :
//   ```dart
//   LevelBadge(
//     level: EscalationLevel.senior,
//     showLabel: true,
//     size: 24,
//   )
//   ```
//
// Sécurité :
//   - Validation sur `size` (min 12, max 48)
//   - Fallback si AppLocalizations null
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_level.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kDefaultSize = 24.0;
const double _kMinSize = 12.0;
const double _kMaxSize = 48.0;
const double _kIconScaleFactor = 0.7;
const double _kLabelScaleFactor = 0.5;
const double _kBorderRadius = 12.0;
const double _kBorderWidth = 1.0;
const double _kSpacing = 4.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _LevelBadgeValidators {
  _LevelBadgeValidators._();

  /// Clamp la taille entre min et max.
  static double clampSize(double size) {
    return size.clamp(_kMinSize, _kMaxSize);
  }
}

// ============================================================================
// LEVEL BADGE WIDGET
// ============================================================================

/// Badge affichant le niveau d'escalade d'un agent.
///
/// **Exemples** :
/// ```dart
/// // Badge compact (icône seulement)
/// LevelBadge(level: EscalationLevel.senior, showLabel: false)
///
/// // Badge avec label
/// LevelBadge(level: EscalationLevel.manager, showLabel: true)
///
/// // Badge personnalisé (taille)
/// LevelBadge(level: EscalationLevel.director, size: 32)
/// ```
class LevelBadge extends StatelessWidget {
  /// Niveau d'escalade à afficher.
  final EscalationLevel level;

  /// Afficher le label court (L0, L1, etc.) à côté de l'icône.
  final bool showLabel;

  /// Taille du badge (affecte icône et label).
  ///
  /// **Plage valide** : 12.0 à 48.0 (valeurs hors plage sont clampées).
  final double size;

  const LevelBadge({
    super.key,
    required this.level,
    this.showLabel = true,
    this.size = _kDefaultSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeSize = _LevelBadgeValidators.clampSize(size);

    final label = level.localizedShortLabel(l10n);
    final color = level.color;
    final icon = level.icon;

    return RepaintBoundary(
      child: Semantics(
        label: '${level.localizedLabel(l10n)} (${level.localizedShortLabel(l10n)})',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: color,
              width: _kBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: safeSize * _kIconScaleFactor,
              ),
              if (showLabel) ...[
                const SizedBox(width: _kSpacing),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: safeSize * _kLabelScaleFactor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
