// lib/presentation/chat/escalation/models/escalation_level.dart
//
// ============================================================================
// ESCALATION LEVEL — Production Enterprise
// ============================================================================
//
// Enum représentant les niveaux hiérarchiques d'escalade.
//
// Hiérarchie :
//   agent (L0) → senior (L1) → manager (L2) → director (L3) → technical (L4)
//
// Architecture :
//   - Enhanced enum (Dart 3) avec constructor et properties
//   - Valeur DB explicite via `dbValue` (découplée du nom enum)
//   - Clés i18n pour internationalisation des labels
//   - Couleurs ThixPolicy pour cohérence design system
//   - Parser `fromString` robuste pour désérialisation DB
//   - Logique métier intégrée (canEscalateFrom, allowedTargets)
//
// Usage :
//   ```dart
//   final level = EscalationLevel.fromString('senior');
//   final label = level.localizedLabel(l10n);
//   if (level.canEscalateFrom) {
//     final targets = level.allowedTargets;
//   }
//   ```
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

/// Niveau hiérarchique d'escalade.
///
/// **Hiérarchie** :
/// - `agent` (L0) : Agent standard, peut escalader vers senior
/// - `senior` (L1) : Agent senior, peut escalader vers manager
/// - `manager` (L2) : Manager, peut escalader vers director ou technical
/// - `director` (L3) : Direction, peut escalader vers technical
/// - `technical` (L4) : Service technique, niveau terminal (pas d'escalade)
enum EscalationLevel {
  /// Agent standard (L0).
  agent(
    dbValue: 'agent',
    i18nKey: 'escalation_level_agent',
    shortI18nKey: 'escalation_level_agent_short',
    fallbackLabel: 'Agent Standard',
    fallbackShortLabel: 'L0',
    tier: 0,
  ),

  /// Agent senior (L1).
  senior(
    dbValue: 'senior',
    i18nKey: 'escalation_level_senior',
    shortI18nKey: 'escalation_level_senior_short',
    fallbackLabel: 'Agent Senior',
    fallbackShortLabel: 'L1',
    tier: 1,
  ),

  /// Manager (L2).
  manager(
    dbValue: 'manager',
    i18nKey: 'escalation_level_manager',
    shortI18nKey: 'escalation_level_manager_short',
    fallbackLabel: 'Manager',
    fallbackShortLabel: 'L2',
    tier: 2,
  ),

  /// Direction (L3).
  director(
    dbValue: 'director',
    i18nKey: 'escalation_level_director',
    shortI18nKey: 'escalation_level_director_short',
    fallbackLabel: 'Direction',
    fallbackShortLabel: 'L3',
    tier: 3,
  ),

  /// Service technique (L4).
  technical(
    dbValue: 'technical',
    i18nKey: 'escalation_level_technical',
    shortI18nKey: 'escalation_level_technical_short',
    fallbackLabel: 'Service Technique',
    fallbackShortLabel: 'L4',
    tier: 4,
  );

  /// Valeur stockée en base de données.
  final String dbValue;

  /// Clé i18n pour le label complet traduit.
  final String i18nKey;

  /// Clé i18n pour le label court traduit.
  final String shortI18nKey;

  /// Label de fallback en français (si i18n indisponible).
  final String fallbackLabel;

  /// Label court de fallback (L0, L1, etc.).
  final String fallbackShortLabel;

  /// Niveau hiérarchique numérique (0 = agent, 4 = technical).
  final int tier;

  const EscalationLevel({
    required this.dbValue,
    required this.i18nKey,
    required this.shortI18nKey,
    required this.fallbackLabel,
    required this.fallbackShortLabel,
    required this.tier,
  });

  // ─── LABELS ─────────────────────────────────────────────────────────

  /// Label complet traduit via AppLocalizations.
  ///
  /// **Usage** :
  /// ```dart
  /// final label = level.localizedLabel(AppLocalizations.of(context));
  /// // Retourne "Agent Senior" (FR) ou "Senior Agent" (EN)
  /// ```
  String localizedLabel(AppLocalizations? l10n) {
    if (l10n == null) return fallbackLabel;
    try {
      return l10n.t(i18nKey);
    } catch (_) {
      return fallbackLabel;
    }
  }

  /// Label court traduit (L0, L1, etc.).
  ///
  /// **Usage** :
  /// ```dart
  /// final short = level.localizedShortLabel(l10n);
  /// // Retourne "L1"
  /// ```
  String localizedShortLabel(AppLocalizations? l10n) {
    if (l10n == null) return fallbackShortLabel;
    try {
      return l10n.t(shortI18nKey);
    } catch (_) {
      return fallbackShortLabel;
    }
  }

  /// Label de fallback (français hardcodé).
  ///
  /// ⚠️ À éviter en production. Préférer [localizedLabel].
  @Deprecated('Use localizedLabel(l10n) instead for i18n support')
  String get label => fallbackLabel;

  /// Label court de fallback (L0, L1, etc.).
  ///
  /// ⚠️ À éviter en production. Préférer [localizedShortLabel].
  @Deprecated('Use localizedShortLabel(l10n) instead for i18n support')
  String get shortLabel => fallbackShortLabel;

  // ─── COULEURS (ThixPolicy) ──────────────────────────────────────────

  /// Couleur associée au niveau (ThixPolicy design system).
  Color get color {
    switch (this) {
      case EscalationLevel.agent:
        return ThixPolicy.primary;
      case EscalationLevel.senior:
        return ThixPolicy.success;
      case EscalationLevel.manager:
        return ThixPolicy.warning;
      case EscalationLevel.director:
        return ThixPolicy.danger;
      case EscalationLevel.technical:
        // Couleur spéciale pour service technique (violet)
        return const Color(0xFF8B5CF6);
    }
  }

  /// Couleur de fond (10% opacité).
  Color get backgroundColor => color.withOpacity(0.1);

  /// Couleur de bordure (20% opacité).
  Color get borderColor => color.withOpacity(0.2);

  // ─── ICONES ─────────────────────────────────────────────────────────

  /// Icône Material associée au niveau.
  IconData get icon {
    switch (this) {
      case EscalationLevel.agent:
        return Icons.person_rounded;
      case EscalationLevel.senior:
        return Icons.star_rounded;
      case EscalationLevel.manager:
        return Icons.people_rounded;
      case EscalationLevel.director:
        return Icons.business_center_rounded;
      case EscalationLevel.technical:
        return Icons.build_rounded;
    }
  }

  // ─── LOGIQUE MÉTIER ─────────────────────────────────────────────────

  /// Vrai si ce niveau peut initier une escalade.
  ///
  /// `technical` (L4) est le niveau terminal, pas d'escalade au-dessus.
  bool get canEscalateFrom => this != EscalationLevel.technical;

  /// Niveaux cibles autorisés pour l'escalade depuis ce niveau.
  ///
  /// **Règles** :
  /// - agent → [senior]
  /// - senior → [manager]
  /// - manager → [director, technical]
  /// - director → [technical]
  /// - technical → [] (niveau terminal)
  List<EscalationLevel> get allowedTargets {
    switch (this) {
      case EscalationLevel.agent:
        return [EscalationLevel.senior];
      case EscalationLevel.senior:
        return [EscalationLevel.manager];
      case EscalationLevel.manager:
        return [EscalationLevel.director, EscalationLevel.technical];
      case EscalationLevel.director:
        return [EscalationLevel.technical];
      case EscalationLevel.technical:
        return [];
    }
  }

  /// Vrai si [target] est un niveau cible valide depuis ce niveau.
  bool canEscalateTo(EscalationLevel target) {
    return allowedTargets.contains(target);
  }

  /// Vrai si ce niveau est supérieur à [other].
  bool isHigherThan(EscalationLevel other) {
    return tier > other.tier;
  }

  /// Vrai si ce niveau est inférieur ou égal à [other].
  bool isLowerOrEqualTo(EscalationLevel other) {
    return tier <= other.tier;
  }

  // ─── PARSING ────────────────────────────────────────────────────────

  /// Parse une string DB en `EscalationLevel`.
  ///
  /// **Exemples** :
  /// ```dart
  /// EscalationLevel.fromString('senior');    // EscalationLevel.senior
  /// EscalationLevel.fromString('MANAGER');   // EscalationLevel.manager (case-insensitive)
  /// EscalationLevel.fromString('unknown');   // EscalationLevel.agent (fallback)
  /// EscalationLevel.fromString(null);        // EscalationLevel.agent (fallback)
  /// ```
  ///
  /// [fallback] : Niveau à retourner si parsing échoue (défaut: `agent`).
  static EscalationLevel fromString(
    String? value, {
    EscalationLevel fallback = EscalationLevel.agent,
  }) {
    if (value == null || value.isEmpty) return fallback;

    final normalized = value.trim().toLowerCase();

    // Recherche par dbValue
    for (final level in EscalationLevel.values) {
      if (level.dbValue == normalized) return level;
    }

    // Fallback : recherche par nom enum (compatibilité legacy)
    for (final level in EscalationLevel.values) {
      if (level.name.toLowerCase() == normalized) return level;
    }

    return fallback;
  }

  /// Parse un index (legacy) en `EscalationLevel`.
  ///
  /// ⚠️ Déprécié : utiliser [fromString] avec `dbValue` à la place.
  @Deprecated('Use fromString(dbValue) instead of index-based lookup')
  static EscalationLevel fromIndex(int? index) {
    if (index == null || index < 0 || index >= EscalationLevel.values.length) {
      return EscalationLevel.agent;
    }
    return EscalationLevel.values[index];
  }

  /// Retourne le niveau supérieur (ou null si déjà au max).
  EscalationLevel? get nextLevel {
    if (this == EscalationLevel.technical) return null;
    return EscalationLevel.values[tier + 1];
  }

  /// Retourne le niveau inférieur (ou null si déjà au min).
  EscalationLevel? get previousLevel {
    if (this == EscalationLevel.agent) return null;
    return EscalationLevel.values[tier - 1];
  }
}

// ============================================================================
// EXTENSIONS
// ============================================================================

/// Extension sur `String` pour conversion facile en `EscalationLevel`.
extension EscalationLevelStringX on String? {
  /// Convertit une string en `EscalationLevel`.
  ///
  /// ```dart
  /// final level = 'senior'.toEscalationLevel();
  /// ```
  EscalationLevel toEscalationLevel({
    EscalationLevel fallback = EscalationLevel.agent,
  }) {
    return EscalationLevel.fromString(this, fallback: fallback);
  }
}

/// Extension sur `Map` pour extraction facile du niveau.
extension EscalationLevelMapX on Map<String, dynamic> {
  /// Extrait le niveau depuis une map (clé 'level' ou 'escalation_level').
  ///
  /// ```dart
  /// final level = row.toEscalationLevel();
  /// ```
  EscalationLevel toEscalationLevel({
    String key = 'level',
    EscalationLevel fallback = EscalationLevel.agent,
  }) {
    final value = this[key]?.toString() ?? this['escalation_level']?.toString();
    return EscalationLevel.fromString(value, fallback: fallback);
  }
}

/// Extension sur `List<EscalationLevel>` pour opérations courantes.
extension EscalationLevelListX on List<EscalationLevel> {
  /// Trie les niveaux par tier (croissant).
  List<EscalationLevel> get sortedByTier {
    final sorted = List<EscalationLevel>.from(this);
    sorted.sort((a, b) => a.tier.compareTo(b.tier));
    return sorted;
  }

  /// Retourne le niveau le plus élevé de la liste.
  EscalationLevel? get highestTier {
    if (isEmpty) return null;
    return sortedByTier.last;
  }
}
