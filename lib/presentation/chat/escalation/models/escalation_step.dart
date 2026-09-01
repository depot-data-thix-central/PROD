// lib/presentation/chat/escalation/models/escalation_step.dart
//
// ============================================================================
// ESCALATION STEP — Production Enterprise
// ============================================================================
//
// Modèle représentant une étape d'escalade de conversation.
//
// Architecture :
//   - Immutable (Equatable pour comparaison par valeur)
//   - Parsing robuste (support int legacy + string moderne)
//   - Sérialisation avec dbValue (strings) pour découplage DB
//   - Validation UUID sur les IDs critiques
//   - Parse dates safe avec fallback
//
// Cycle de vie typique :
//   1. Création (status: pending)
//   2. Acceptation OU Refus (status: accepted/rejected)
//   3. Résolution (status: resolved) OU Expiration (timeout)
//
// Usage :
//   ```dart
//   final step = EscalationStep.fromJson(dbRow);
//   if (step.isPending) {
//     // Afficher boutons Accept/Reject
//   }
//   ```
// ============================================================================

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:thix_id/presentation/chat/escalation/models/escalation_level.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_priority.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_status.dart';

// ============================================================================
// VALIDATORS
// ============================================================================
class _EscalationStepValidators {
  _EscalationStepValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Parse une date ISO8601 de manière sûre.
  ///
  /// Retourne `null` si parsing échoue.
  static DateTime? tryParseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      debugPrint('[EscalationStep] ⚠️ Date parse failed: '
          '${kDebugMode ? e : "invalid format"}');
      return null;
    }
  }

  /// Sanitize une string (trim + max length).
  static String safeString(dynamic value, {int maxLength = 1000}) {
    if (value == null) return '';
    final s = value.toString().trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }
}

// ============================================================================
// ESCALATION STEP MODEL
// ============================================================================

/// Étape d'escalade de conversation.
///
/// **Champs critiques** :
/// - `id` : UUID de l'escalade
/// - `conversationId` : UUID de la conversation concernée
/// - `fromAgentId` / `toAgentId` : UUIDs des agents
/// - `status` : État actuel du cycle de vie
///
/// **Immutable** : Utiliser [copyWith] pour créer une version modifiée.
class EscalationStep extends Equatable {
  /// UUID unique de l'escalade.
  final String id;

  /// UUID de la conversation escaladée.
  final String conversationId;

  /// Niveau de l'agent expéditeur.
  final EscalationLevel fromLevel;

  /// Niveau cible de l'escalade.
  final EscalationLevel toLevel;

  /// UUID de l'agent qui initie l'escalade.
  final String fromAgentId;

  /// Nom de l'agent expéditeur (optionnel, pour affichage).
  final String? fromAgentName;

  /// UUID de l'agent destinataire.
  final String toAgentId;

  /// Nom de l'agent destinataire (optionnel, pour affichage).
  final String? toAgentName;

  /// Raison principale de l'escalade.
  final String reason;

  /// Priorité de traitement.
  final EscalationPriority priority;

  /// Statut actuel du cycle de vie.
  final EscalationStatus status;

  /// Commentaire additionnel (optionnel).
  final String? comment;

  /// Date de création de l'escalade.
  final DateTime createdAt;

  /// Date de résolution/acceptation/refus (null si en cours).
  final DateTime? resolvedAt;

  const EscalationStep({
    required this.id,
    required this.conversationId,
    required this.fromLevel,
    required this.toLevel,
    required this.fromAgentId,
    this.fromAgentName,
    required this.toAgentId,
    this.toAgentName,
    required this.reason,
    required this.priority,
    required this.status,
    this.comment,
    required this.createdAt,
    this.resolvedAt,
  });

  // ─── VALIDATION ─────────────────────────────────────────────────────

  /// Vrai si tous les UUIDs critiques sont valides.
  bool get hasValidIds =>
      _EscalationStepValidators.isValidUuid(id) &&
      _EscalationStepValidators.isValidUuid(conversationId) &&
      _EscalationStepValidators.isValidUuid(fromAgentId) &&
      _EscalationStepValidators.isValidUuid(toAgentId);

  /// Vrai si l'escalade peut être traitée (pending).
  bool get isPending => status.isActionable;

  /// Vrai si l'escalade est dans un état terminal.
  bool get isTerminal => status.isTerminal;

  /// Vrai si l'escalade a été traitée positivement.
  bool get isSuccess => status.isSuccess;

  /// Vrai si l'escalade a été traitée négativement.
  bool get isFailure => status.isFailure;

  /// Vrai si l'escalade a une date de résolution.
  bool get isResolved => resolvedAt != null;

  // ─── FROM JSON (parsing robuste) ────────────────────────────────────

  /// Crée une instance depuis un JSON DB.
  ///
  /// **Supporte** :
  /// - Valeurs int (legacy, basées sur index enum)
  /// - Valeurs string (moderne, basées sur dbValue)
  /// - Fallback sur valeurs par défaut si parsing échoue
  ///
  /// **Exemple** :
  /// ```dart
  /// final step = EscalationStep.fromJson({
  ///   'id': 'uuid-...',
  ///   'conversation_id': 'uuid-...',
  ///   'from_level': 'agent',      // ✅ String moderne
  ///   'to_level': 1,              // ✅ Int legacy
  ///   'status': 'pending',        // ✅ String moderne
  ///   'priority': 'high',
  ///   // ...
  /// });
  /// ```
  factory EscalationStep.fromJson(Map<String, dynamic> json) {
    final createdAt = _EscalationStepValidators.tryParseDate(json['created_at'])
        ?? DateTime.now().toUtc();

    return EscalationStep(
      id: _EscalationStepValidators.safeString(json['id']),
      conversationId: _EscalationStepValidators.safeString(json['conversation_id']),
      fromLevel: _parseLevel(json['from_level']),
      toLevel: _parseLevel(json['to_level']),
      fromAgentId: _EscalationStepValidators.safeString(json['from_agent_id']),
      fromAgentName: _safeNullableString(json['from_agent_name']),
      toAgentId: _EscalationStepValidators.safeString(json['to_agent_id']),
      toAgentName: _safeNullableString(json['to_agent_name']),
      reason: _EscalationStepValidators.safeString(json['reason'], maxLength: 500),
      priority: _parsePriority(json['priority']),
      status: _parseStatus(json['status']),
      comment: _safeNullableString(json['comment'], maxLength: 1000),
      createdAt: createdAt,
      resolvedAt: _EscalationStepValidators.tryParseDate(json['resolved_at']),
    );
  }

  /// Parse une string nullable de manière sûre.
  static String? _safeNullableString(dynamic value, {int maxLength = 1000}) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  // ─── TO JSON (sérialisation) ────────────────────────────────────────

  /// Sérialise vers un JSON DB.
  ///
  /// Utilise les `dbValue` (strings) pour découplage de l'ordre enum.
  ///
  /// ⚠️ **Migration** : Si votre DB utilise encore des ints (index),
  /// remplacez `dbValue` par `index` dans les appels ci-dessous.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'from_level': fromLevel.dbValue,      // ✅ String moderne
      'to_level': toLevel.dbValue,          // ✅ String moderne
      'from_agent_id': fromAgentId,
      'from_agent_name': fromAgentName,
      'to_agent_id': toAgentId,
      'to_agent_name': toAgentName,
      'reason': reason,
      'priority': priority.dbValue,         // ✅ String moderne
      'status': status.dbValue,             // ✅ String moderne
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  /// Sérialisation legacy avec index (compatibilité DB ancienne).
  ///
  /// ⚠️ **Déprécié** : Utiliser [toJson] avec dbValue à la place.
  @Deprecated('Use toJson() with dbValue strings instead of index-based')
  Map<String, dynamic> toJsonLegacy() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'from_level': fromLevel.index,
      'to_level': toLevel.index,
      'from_agent_id': fromAgentId,
      'from_agent_name': fromAgentName,
      'to_agent_id': toAgentId,
      'to_agent_name': toAgentName,
      'reason': reason,
      'priority': priority.index,
      'status': status.index,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  // ─── PARSERS (support int + string) ─────────────────────────────────

  /// Parse un niveau depuis int (legacy) ou string (moderne).
  ///
  /// **Fallback** : `EscalationLevel.agent` si parsing échoue.
  static EscalationLevel _parseLevel(dynamic value) {
    if (value == null) return EscalationLevel.agent;

    // Support int legacy
    if (value is int) {
      if (value >= 0 && value < EscalationLevel.values.length) {
        return EscalationLevel.values[value];
      }
      debugPrint('[EscalationStep] ⚠️ Level index out of range: $value');
      return EscalationLevel.agent;
    }

    // Support string moderne
    if (value is String) {
      // Essayer d'abord comme dbValue
      final normalized = value.trim().toLowerCase();
      for (final level in EscalationLevel.values) {
        if (level.dbValue == normalized || level.name.toLowerCase() == normalized) {
          return level;
        }
      }

      // Fallback : essayer comme int string (legacy)
      try {
        final index = int.parse(normalized);
        if (index >= 0 && index < EscalationLevel.values.length) {
          return EscalationLevel.values[index];
        }
      } catch (_) {
        // Pas un int, continuer
      }

      debugPrint('[EscalationStep] ⚠️ Unknown level: $value');
      return EscalationLevel.agent;
    }

    return EscalationLevel.agent;
  }

  /// Parse une priorité depuis int (legacy) ou string (moderne).
  ///
  /// **Fallback** : `EscalationPriority.medium` si parsing échoue.
  static EscalationPriority _parsePriority(dynamic value) {
    if (value == null) return EscalationPriority.medium;

    // Support int legacy
    if (value is int) {
      if (value >= 0 && value < EscalationPriority.values.length) {
        return EscalationPriority.values[value];
      }
      debugPrint('[EscalationStep] ⚠️ Priority index out of range: $value');
      return EscalationPriority.medium;
    }

    // Support string moderne
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final priority in EscalationPriority.values) {
        if (priority.dbValue == normalized || priority.name.toLowerCase() == normalized) {
          return priority;
        }
      }

      // Fallback : essayer comme int string (legacy)
      try {
        final index = int.parse(normalized);
        if (index >= 0 && index < EscalationPriority.values.length) {
          return EscalationPriority.values[index];
        }
      } catch (_) {
        // Pas un int, continuer
      }

      debugPrint('[EscalationStep] ⚠️ Unknown priority: $value');
      return EscalationPriority.medium;
    }

    return EscalationPriority.medium;
  }

  /// Parse un statut depuis int (legacy) ou string (moderne).
  ///
  /// **Fallback** : `EscalationStatus.pending` si parsing échoue.
  static EscalationStatus _parseStatus(dynamic value) {
    if (value == null) return EscalationStatus.pending;

    // Support int legacy
    if (value is int) {
      if (value >= 0 && value < EscalationStatus.values.length) {
        return EscalationStatus.values[value];
      }
      debugPrint('[EscalationStep] ⚠️ Status index out of range: $value');
      return EscalationStatus.pending;
    }

    // Support string moderne (utilise le parser robuste de EscalationStatus)
    if (value is String) {
      return EscalationStatus.fromString(value);
    }

    return EscalationStatus.pending;
  }

  // ─── COPY WITH ──────────────────────────────────────────────────────

  /// Crée une copie avec les champs spécifiés modifiés.
  ///
  /// Pour setter explicitement un champ nullable à `null`,
  /// utiliser les flags `clearXxx` :
  /// ```dart
  /// step.copyWith(clearComment: true);  // comment = null
  /// step.copyWith(clearResolvedAt: true);  // resolvedAt = null
  /// ```
  EscalationStep copyWith({
    String? id,
    String? conversationId,
    EscalationLevel? fromLevel,
    EscalationLevel? toLevel,
    String? fromAgentId,
    String? fromAgentName,
    bool clearFromAgentName = false,
    String? toAgentId,
    String? toAgentName,
    bool clearToAgentName = false,
    String? reason,
    EscalationPriority? priority,
    EscalationStatus? status,
    String? comment,
    bool clearComment = false,
    DateTime? createdAt,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
  }) {
    return EscalationStep(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      fromLevel: fromLevel ?? this.fromLevel,
      toLevel: toLevel ?? this.toLevel,
      fromAgentId: fromAgentId ?? this.fromAgentId,
      fromAgentName: clearFromAgentName ? null : (fromAgentName ?? this.fromAgentName),
      toAgentId: toAgentId ?? this.toAgentId,
      toAgentName: clearToAgentName ? null : (toAgentName ?? this.toAgentName),
      reason: reason ?? this.reason,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      comment: clearComment ? null : (comment ?? this.comment),
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
    );
  }

  // ─── EQUATABLE ──────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        id,
        conversationId,
        fromLevel,
        toLevel,
        fromAgentId,
        fromAgentName,
        toAgentId,
        toAgentName,
        reason,
        priority,
        status,
        comment,
        createdAt,
        resolvedAt,
      ];

  @override
  String toString() {
    return 'EscalationStep('
        'id: ${_obfuscate(id)}, '
        'conv: ${_obfuscate(conversationId)}, '
        'status: ${status.name}, '
        'priority: ${priority.name}, '
        'from: ${_obfuscate(fromAgentId)}, '
        'to: ${_obfuscate(toAgentId)}'
        ')';
  }

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// EXTENSIONS
// ============================================================================

/// Extension sur `List<EscalationStep>` pour opérations courantes.
extension EscalationStepListX on List<EscalationStep> {
  /// Filtre les escalades pending.
  List<EscalationStep> get pendingOnly =>
      where((s) => s.isPending).toList();

  /// Filtre les escalades résolues.
  List<EscalationStep> get resolvedOnly =>
      where((s) => s.status == EscalationStatus.resolved).toList();

  /// Trouve une escalade par ID (retourne null si non trouvée).
  EscalationStep? findById(String id) {
    try {
      return firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Compte les escalades par statut.
  Map<EscalationStatus, int> countByStatus() {
    final counts = <EscalationStatus, int>{};
    for (final step in this) {
      counts[step.status] = (counts[step.status] ?? 0) + 1;
    }
    return counts;
  }
}

/// Extension sur `Map<String, dynamic>` pour conversion facile.
extension EscalationStepMapX on Map<String, dynamic> {
  /// Convertit une map DB en `EscalationStep`.
  ///
  /// ```dart
  /// final step = dbRow.toEscalationStep();
  /// ```
  EscalationStep toEscalationStep() => EscalationStep.fromJson(this);
}
