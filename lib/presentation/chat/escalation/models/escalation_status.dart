// lib/presentation/chat/escalation/models/escalation_status.dart
//
// ============================================================================
// ESCALATION STATUS — Production Enterprise
// ============================================================================
//
// Enum représentant le cycle de vie complet d'une escalade.
//
// Cycle de vie :
//   pending → accepted → resolved
//   pending → rejected
//   pending → timeout (automatique après X heures)
//   pending → canceled (par l'expéditeur)
//
// Architecture :
//   - Valeur DB explicite via `dbValue` (découplée du nom enum)
//   - Clés i18n pour internationalisation des labels
//   - Couleurs ThixPolicy pour cohérence design system
//   - Parser `fromString` robuste pour désérialisation DB
//
// Usage :
//   ```dart
//   final status = EscalationStatus.fromString('accepted');
//   final label = status.localizedLabel(l10n);
//   final color = status.color;
//   ```
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

/// Statut du cycle de vie d'une escalade.
///
/// **États** :
/// - `pending` : Escalade créée, en attente de réponse
/// - `accepted` : Escalade acceptée par l'agent cible
/// - `rejected` : Escalade refusée (avec motif)
/// - `timeout` : Escalade expirée automatiquement
/// - `resolved` : Escalade résolue par l'agent
/// - `canceled` : Escalade annulée par l'expéditeur
/// - `active` : Conversation active (non-escaladée, état initial)
enum EscalationStatus {
  /// Escalade en attente de réponse.
  pending(
    dbValue: 'pending',
    i18nKey: 'escalation_status_pending',
    fallbackLabel: 'En attente',
  ),

  /// Escalade acceptée par l'agent cible.
  accepted(
    dbValue: 'accepted',
    i18nKey: 'escalation_status_accepted',
    fallbackLabel: 'Acceptée',
  ),

  /// Escalade refusée (avec motif obligatoire).
  rejected(
    dbValue: 'rejected',
    i18nKey: 'escalation_status_rejected',
    fallbackLabel: 'Refusée',
  ),

  /// Escalade expirée automatiquement (timeout).
  timeout(
    dbValue: 'timeout',
    i18nKey: 'escalation_status_timeout',
    fallbackLabel: 'Expirée',
  ),

  /// Escalade résolue par l'agent.
  resolved(
    dbValue: 'resolved',
    i18nKey: 'escalation_status_resolved',
    fallbackLabel: 'Résolue',
  ),

  /// Escalade annulée par l'expéditeur.
  canceled(
    dbValue: 'canceled',
    i18nKey: 'escalation_status_canceled',
    fallbackLabel: 'Annulée',
  ),

  /// Conversation active (état initial, non-escaladée).
  active(
    dbValue: 'active',
    i18nKey: 'escalation_status_active',
    fallbackLabel: 'Active',
  );

  /// Valeur stockée en base de données.
  ///
  /// Découplée du nom enum pour permettre refactor sans migration DB.
  final String dbValue;

  /// Clé i18n pour le label traduit.
  final String i18nKey;

  /// Label de fallback en français (si i18n indisponible).
  final String fallbackLabel;

  const EscalationStatus({
    required this.dbValue,
    required this.i18nKey,
    required this.fallbackLabel,
  });

  // ─── LABELS ─────────────────────────────────────────────────────────

  /// Label traduit via AppLocalizations.
  ///
  /// **Usage** :
  /// ```dart
  /// final label = status.localizedLabel(AppLocalizations.of(context));
  /// ```
  ///
  /// Retourne le fallback FR si la clé n'existe pas dans les traductions.
  String localizedLabel(AppLocalizations? l10n) {
    if (l10n == null) return fallbackLabel;
    try {
      return l10n.t(i18nKey);
    } catch (_) {
      return fallbackLabel;
    }
  }

  /// Label de fallback (français hardcodé).
  ///
  /// ⚠️ À éviter en production. Préférer [localizedLabel].
  @Deprecated('Use localizedLabel(l10n) instead for i18n support')
  String get label => fallbackLabel;

  // ─── COULEURS (ThixPolicy) ──────────────────────────────────────────

  /// Couleur associée au statut (ThixPolicy design system).
  Color get color {
    switch (this) {
      case EscalationStatus.pending:
        return ThixPolicy.warning;
      case EscalationStatus.accepted:
        return ThixPolicy.success;
      case EscalationStatus.rejected:
        return ThixPolicy.danger;
      case EscalationStatus.timeout:
        return ThixPolicy.textMuted;
      case EscalationStatus.resolved:
        // Version plus foncée du success pour distinguer de accepted
        return _darken(ThixPolicy.success, 0.2);
      case EscalationStatus.canceled:
        return _darken(ThixPolicy.textMuted, 0.2);
      case EscalationStatus.active:
        return ThixPolicy.primary;
    }
  }

  /// Couleur de fond (pour badges, containers).
  ///
  /// Version avec 10% d'opacité de [color].
  Color get backgroundColor => color.withOpacity(0.1);

  /// Couleur de bordure (pour badges).
  ///
  /// Version avec 20% d'opacité de [color].
  Color get borderColor => color.withOpacity(0.2);

  // ─── ICONES ─────────────────────────────────────────────────────────

  /// Icône Material associée au statut.
  IconData get icon {
    switch (this) {
      case EscalationStatus.pending:
        return Icons.hourglass_top_rounded;
      case EscalationStatus.accepted:
        return Icons.check_circle_rounded;
      case EscalationStatus.rejected:
        return Icons.cancel_rounded;
      case EscalationStatus.timeout:
        return Icons.timer_off_rounded;
      case EscalationStatus.resolved:
        return Icons.done_all_rounded;
      case EscalationStatus.canceled:
        return Icons.block_rounded;
      case EscalationStatus.active:
        return Icons.chat_bubble_rounded;
    }
  }

  // ─── ÉTATS ──────────────────────────────────────────────────────────

  /// Vrai si l'escalade est dans un état terminal (ne peut plus évoluer).
  bool get isTerminal =>
      this == rejected ||
      this == timeout ||
      this == resolved ||
      this == canceled;

  /// Vrai si l'escalade peut encore être acceptée/refusée.
  bool get isActionable => this == pending;

  /// Vrai si l'escalade a été traitée positivement (accepted ou resolved).
  bool get isSuccess => this == accepted || this == resolved;

  /// Vrai si l'escalade a été traitée négativement (rejected, timeout, canceled).
  bool get isFailure =>
      this == rejected || this == timeout || this == canceled;

  // ─── PARSING ────────────────────────────────────────────────────────

  /// Parse une string DB en `EscalationStatus`.
  ///
  /// **Exemples** :
  /// ```dart
  /// EscalationStatus.fromString('accepted'); // EscalationStatus.accepted
  /// EscalationStatus.fromString('PENDING');  // EscalationStatus.pending (case-insensitive)
  /// EscalationStatus.fromString('unknown');  // EscalationStatus.pending (fallback)
  /// EscalationStatus.fromString(null);       // EscalationStatus.pending (fallback)
  /// ```
  ///
  /// [fallback] : Statut à retourner si parsing échoue (défaut: `pending`).
  static EscalationStatus fromString(String? value, {EscalationStatus fallback = EscalationStatus.pending}) {
    if (value == null || value.isEmpty) return fallback;

    final normalized = value.trim().toLowerCase();

    // Recherche par dbValue
    for (final status in EscalationStatus.values) {
      if (status.dbValue == normalized) return status;
    }

    // Fallback : recherche par nom enum (compatibilité legacy)
    for (final status in EscalationStatus.values) {
      if (status.name.toLowerCase() == normalized) return status;
    }

    return fallback;
  }

  /// Parse un index (legacy) en `EscalationStatus`.
  ///
  /// ⚠️ Déprécié : utiliser [fromString] avec `dbValue` à la place.
  @Deprecated('Use fromString(dbValue) instead of index-based lookup')
  static EscalationStatus fromIndex(int? index) {
    if (index == null || index < 0 || index >= EscalationStatus.values.length) {
      return EscalationStatus.pending;
    }
    return EscalationStatus.values[index];
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Assombrit une couleur d'un facteur donné (0.0 = inchangé, 1.0 = noir).
  static Color _darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darkened.toColor();
  }
}

// ============================================================================
// EXTENSIONS
// ============================================================================

/// Extension sur `String` pour conversion facile en `EscalationStatus`.
extension EscalationStatusStringX on String? {
  /// Convertit une string en `EscalationStatus`.
  ///
  /// ```dart
  /// final status = 'accepted'.toEscalationStatus();
  /// ```
  EscalationStatus toEscalationStatus({
    EscalationStatus fallback = EscalationStatus.pending,
  }) {
    return EscalationStatus.fromString(this, fallback: fallback);
  }
}

/// Extension sur `Map` pour extraction facile du statut.
extension EscalationStatusMapX on Map<String, dynamic> {
  /// Extrait le statut depuis une map (clé 'status' ou 'escalation_status').
  ///
  /// ```dart
  /// final status = row.toEscalationStatus();
  /// ```
  EscalationStatus toEscalationStatus({
    String key = 'status',
    EscalationStatus fallback = EscalationStatus.pending,
  }) {
    final value = this[key]?.toString() ?? this['escalation_status']?.toString();
    return EscalationStatus.fromString(value, fallback: fallback);
  }
}
