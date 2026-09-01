// lib/presentation/chat/escalation/services/escalation_service.dart
//
// ============================================================================
// ESCALATION SERVICE — Production Enterprise
// ============================================================================
//
// Service de gestion du cycle de vie complet des escalades :
//   - Création (caller → target agent)
//   - Acceptation / Refus (avec ownership check)
//   - Résolution
//   - Historique (par conversation ou par agent)
//   - Recherche d'agents par handle
//
// Architecture :
//   - SupabaseClient injecté via Riverpod (testable)
//   - Validation UUID stricte sur tous les IDs
//   - Sanitization XSS sur reason/comment
//   - Timeouts + retry sur appels réseau
//   - Ownership checks sur actions destructives
//
// Sécurité :
//   - Validation UUID v4 stricte
//   - Sanitization XSS (HTML, javascript:, on*=, control chars)
//   - Ownership verification (accept/reject uniquement par to_agent_id)
//   - Stack traces masquées en production (kDebugMode)
//   - Max reason 500 caractères, max comment 1000 caractères
//
// Bugs corrigés :
//   - getCurrentLevelForAgent : maintenant requête DB réelle
//   - getPendingEscalations : filtre par agentId ET level (était level seul)
//   - acceptEscalation : ne modifie plus to_agent_id (respecte la cible)
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/chat/escalation/models/escalation_level.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_priority.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_status.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_step.dart';
// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxReasonLength = 500;
const int _kMaxCommentLength = 1000;
const int _kMaxHandleLength = 50;
const int _kDefaultLimit = 20;
const int _kMaxLimit = 100;
const Duration _kDbTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;

// ============================================================================
// VALIDATORS
// ============================================================================
class _EscalationValidators {
  _EscalationValidators._();

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

  /// Valide un handle (username).
  static bool isValidHandle(String? handle) {
    if (handle == null) return false;
    final trimmed = handle.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxHandleLength) return false;
    return RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(trimmed);
  }

  /// Sanitize un texte (XSS + caractères de contrôle).
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Obfusque un ID pour les logs.
  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class EscalationException implements Exception {
  final String message;
  final Object? cause;
  const EscalationException(this.message, [this.cause]);
  @override
  String toString() => 'EscalationException: $message';
}

class EscalationPermissionException extends EscalationException {
  const EscalationPermissionException(super.message);
}

class EscalationValidationException extends EscalationException {
  const EscalationValidationException(super.message);
}

class EscalationConflictException extends EscalationException {
  const EscalationConflictException(super.message);
}

// ============================================================================
// ESCALATION SERVICE
// ============================================================================

/// Service de gestion des escalades de conversations.
///
/// **Usage** :
/// ```dart
/// final service = ref.read(escalationServiceProvider);
/// final step = await service.createEscalation(...);
/// ```
class EscalationService {
  final SupabaseClient _supabase;
  bool _isDisposed = false;

  EscalationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    debugPrint('[EscalationService] 🚀 Initialized');
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Retry helper pour appels réseau.
  Future<T> _retry<T>(
    Future<T> Function() fn, {
    required String label,
    int maxRetries = _kMaxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn().timeout(_kDbTimeout);
      } on TimeoutException {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[EscalationService] ❌ $label timeout after $attempt');
          rethrow;
        }
        debugPrint('[EscalationService] ⏱️ $label timeout, retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[EscalationService] ❌ $label failed: '
              '${kDebugMode ? e : e.toString().split('\n').first}');
          rethrow;
        }
        debugPrint('[EscalationService] ⚠️ $label error, retry $attempt: '
            '${kDebugMode ? e : e.toString().split('\n').first}');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  /// Sérialise un status en valeur DB (string).
  String _statusToDb(EscalationStatus status) => status.name;

  /// Sérialise un level en valeur DB (string).
  String _levelToDb(EscalationLevel level) => level.name;

  /// Sérialise une priority en valeur DB (string).
  String _priorityToDb(EscalationPriority priority) => priority.name;

  // ─── GET CURRENT LEVEL ─────────────────────────────────────────────

  /// Récupère le niveau d'escalade actuel d'un agent depuis son profil.
  ///
  /// **Corrigé** : effectue une vraie requête DB au lieu de retourner
  /// toujours `senior`. Retourne `agent` par défaut si non défini.
  Future<EscalationLevel> getCurrentLevelForAgent(String agentId) async {
    if (_isDisposed) return EscalationLevel.agent;

    if (!_EscalationValidators.isValidUuid(agentId)) {
      debugPrint('[EscalationService] ⚠️ getCurrentLevel: invalid agentId');
      return EscalationLevel.agent;
    }

    try {
      final response = await _retry(
        () => _supabase
            .from('profiles')
            .select('escalation_level')
            .eq('id', agentId)
            .maybeSingle(),
        label: 'getCurrentLevelForAgent',
      );

      if (response == null) {
        debugPrint('[EscalationService] ⚠️ Agent not found, default to agent');
        return EscalationLevel.agent;
      }

      final levelStr = response['escalation_level']?.toString();
      if (levelStr == null || levelStr.isEmpty) return EscalationLevel.agent;

      try {
        return EscalationLevel.values.firstWhere(
          (l) => l.name.toLowerCase() == levelStr.toLowerCase(),
          orElse: () => EscalationLevel.agent,
        );
      } catch (_) {
        return EscalationLevel.agent;
      }
    } catch (e) {
      debugPrint('[EscalationService] ❌ getCurrentLevel: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return EscalationLevel.agent;
    }
  }

  // ─── GET USER BY HANDLE ────────────────────────────────────────────

  /// Recherche un utilisateur par son handle (username).
  Future<Map<String, dynamic>?> getUserByHandle(String username) async {
    if (_isDisposed) return null;

    final handle = _EscalationValidators.sanitize(
      username,
      maxLength: _kMaxHandleLength,
    ).replaceAll('@', '');

    if (!_EscalationValidators.isValidHandle(handle)) {
      debugPrint('[EscalationService] ⚠️ Invalid handle: $handle');
      return null;
    }

    try {
      final response = await _retry(
        () => _supabase
            .from('profiles')
            .select('id, display_name, username, avatar_url')
            .eq('username', handle)
            .maybeSingle(),
        label: 'getUserByHandle',
      );

      if (response == null) return null;

      final map = Map<String, dynamic>.from(response);
      final id = map['id']?.toString() ?? '';
      if (!_EscalationValidators.isValidUuid(id)) {
        debugPrint('[EscalationService] ⚠️ getUserByHandle: invalid ID');
        return null;
      }

      return map;
    } catch (e) {
      debugPrint('[EscalationService] ❌ getUserByHandle: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return null;
    }
  }

  // ─── CREATE ESCALATION ─────────────────────────────────────────────

  /// Crée une nouvelle escalade.
  ///
  /// **Validation** :
  ///   - UUIDs valides sur tous les IDs
  ///   - Reason non vide, max 500 caractères
  ///   - Pas d'escalade pending existante pour ce couple (conversation, target)
  ///   - Target agent existe en DB
  ///
  /// **Throws** :
  ///   - [EscalationValidationException] si inputs invalides
  ///   - [EscalationConflictException] si escalade déjà en attente
  Future<EscalationStep> createEscalation({
    required String conversationId,
    required String fromAgentId,
    required String targetAgentId,
    required EscalationLevel toLevel,
    required String reason,
    required EscalationPriority priority,
    String? comment,
    String? fromAgentName,
  }) async {
    if (_isDisposed) throw StateError('EscalationService disposed');

    // Validation inputs
    if (!_EscalationValidators.isValidUuid(conversationId)) {
      throw const EscalationValidationException('conversationId invalide');
    }
    if (!_EscalationValidators.isValidUuid(fromAgentId)) {
      throw const EscalationValidationException('fromAgentId invalide');
    }
    if (!_EscalationValidators.isValidUuid(targetAgentId)) {
      throw const EscalationValidationException('targetAgentId invalide');
    }
    if (fromAgentId == targetAgentId) {
      throw const EscalationValidationException(
        'Impossible de s\'escalader soi-même',
      );
    }

    final sanitizedReason = _EscalationValidators.sanitize(
      reason,
      maxLength: _kMaxReasonLength,
    );
    if (sanitizedReason.isEmpty) {
      throw const EscalationValidationException('Reason obligatoire');
    }

    final sanitizedComment = comment != null && comment.trim().isNotEmpty
        ? _EscalationValidators.sanitize(comment, maxLength: _kMaxCommentLength)
        : null;

    final sanitizedFromAgentName = fromAgentName != null
        ? _EscalationValidators.sanitize(fromAgentName, maxLength: 100)
        : null;

    debugPrint('[EscalationService] 📤 Creating escalation: '
        'conv=${_EscalationValidators.obfuscate(conversationId)} '
        'from=${_EscalationValidators.obfuscate(fromAgentId)} '
        'to=${_EscalationValidators.obfuscate(targetAgentId)} '
        'level=${toLevel.name}');

    try {
      // 1. Vérifier qu'aucune escalade pending n'existe déjà
      final existingPending = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select('id')
            .eq('conversation_id', conversationId)
            .eq('to_agent_id', targetAgentId)
            .eq('status', _statusToDb(EscalationStatus.pending))
            .maybeSingle(),
        label: 'checkExistingPending',
      );

      if (existingPending != null) {
        throw const EscalationConflictException(
          'Une escalade est déjà en attente pour cet agent',
        );
      }

      // 2. Vérifier que le target agent existe
      final target = await _retry(
        () => _supabase
            .from('profiles')
            .select('id')
            .eq('id', targetAgentId)
            .maybeSingle(),
        label: 'verifyTargetAgent',
      );

      if (target == null) {
        throw const EscalationValidationException(
          'L\'utilisateur cible n\'existe pas',
        );
      }

      // 3. Insert de l'escalade
      final data = {
        'conversation_id': conversationId,
        'from_level': _levelToDb(EscalationLevel.agent),
        'to_level': _levelToDb(toLevel),
        'from_agent_id': fromAgentId,
        'to_agent_id': targetAgentId,
        'reason': sanitizedReason,
        'priority': _priorityToDb(priority),
        'status': _statusToDb(EscalationStatus.pending),
        'comment': sanitizedComment,
        'from_agent_name': sanitizedFromAgentName,
      };

      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .insert(data)
            .select()
            .single(),
        label: 'insertEscalation',
      );

      // 4. Update conversation status
      await _retry(
        () => _supabase
            .from('conversations')
            .update({
              'escalation_status': 'escalated',
              'current_level': _levelToDb(toLevel),
              'is_escalated': true,
              'escalated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', conversationId),
        label: 'updateConversation',
      );

      debugPrint('[EscalationService] ✓ Escalation created');

      final map = Map<String, dynamic>.from(response as Map);
      return EscalationStep.fromJson(map);
    } on EscalationException {
      rethrow;
    } catch (e) {
      debugPrint('[EscalationService] ❌ createEscalation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ─── ACCEPT ESCALATION ─────────────────────────────────────────────

  /// Accepte une escalade (ownership check : agent doit être to_agent_id).
  ///
  /// **Corrigé** : ne modifie plus `to_agent_id` (respecte la cible originale).
  Future<EscalationStep> acceptEscalation(
    String escalationId,
    String agentId,
  ) async {
    if (_isDisposed) throw StateError('EscalationService disposed');

    if (!_EscalationValidators.isValidUuid(escalationId)) {
      throw const EscalationValidationException('escalationId invalide');
    }
    if (!_EscalationValidators.isValidUuid(agentId)) {
      throw const EscalationValidationException('agentId invalide');
    }

    debugPrint('[EscalationService] ✓ Accepting escalation: '
        '${_EscalationValidators.obfuscate(escalationId)}');

    try {
      // 1. Récupérer l'escalade + ownership check
      final existing = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('id', escalationId)
            .eq('to_agent_id', agentId)  // ✅ Ownership check
            .eq('status', _statusToDb(EscalationStatus.pending))
            .maybeSingle(),
        label: 'verifyOwnershipAccept',
      );

      if (existing == null) {
        throw const EscalationPermissionException(
          'Escalade introuvable, déjà traitée, ou accès refusé',
        );
      }

      // 2. Update status (ne modifie PAS to_agent_id)
      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .update({
              'status': _statusToDb(EscalationStatus.accepted),
              'resolved_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', escalationId)
            .select()
            .single(),
        label: 'acceptUpdate',
      );

      final map = Map<String, dynamic>.from(response as Map);
      final step = EscalationStep.fromJson(map);

      // 3. Update conversation + ajouter agent aux participants
      await _retry(
        () => _supabase
            .from('conversations')
            .update({
              'assigned_agent_id': agentId,
              'escalation_status': 'accepted',
              'is_escalated': false,
            })
            .eq('id', step.conversationId),
        label: 'acceptUpdateConversation',
      );

      await _retry(
        () => _supabase.from('conversation_participants').upsert(
          {
            'conversation_id': step.conversationId,
            'user_id': agentId,
            'role': 'member',
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'conversation_id,user_id',
        ),
        label: 'acceptAddParticipant',
      );

      debugPrint('[EscalationService] ✓ Escalation accepted');
      return step;
    } on EscalationException {
      rethrow;
    } catch (e) {
      debugPrint('[EscalationService] ❌ acceptEscalation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ─── REJECT ESCALATION ─────────────────────────────────────────────

  /// Refuse une escalade (ownership check : agent doit être to_agent_id).
  Future<EscalationStep> rejectEscalation(
    String escalationId,
    String agentId,
    String reason,
  ) async {
    if (_isDisposed) throw StateError('EscalationService disposed');

    if (!_EscalationValidators.isValidUuid(escalationId)) {
      throw const EscalationValidationException('escalationId invalide');
    }
    if (!_EscalationValidators.isValidUuid(agentId)) {
      throw const EscalationValidationException('agentId invalide');
    }

    final sanitizedReason = _EscalationValidators.sanitize(
      reason,
      maxLength: _kMaxCommentLength,
    );
    if (sanitizedReason.isEmpty) {
      throw const EscalationValidationException('Motif de refus obligatoire');
    }

    debugPrint('[EscalationService] ❌ Rejecting escalation: '
        '${_EscalationValidators.obfuscate(escalationId)}');

    try {
      // 1. Ownership check
      final existing = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('id', escalationId)
            .eq('to_agent_id', agentId)  // ✅ Ownership check
            .eq('status', _statusToDb(EscalationStatus.pending))
            .maybeSingle(),
        label: 'verifyOwnershipReject',
      );

      if (existing == null) {
        throw const EscalationPermissionException(
          'Escalade introuvable, déjà traitée, ou accès refusé',
        );
      }

      // 2. Update
      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .update({
              'status': _statusToDb(EscalationStatus.rejected),
              'comment': sanitizedReason,
              'resolved_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', escalationId)
            .select()
            .single(),
        label: 'rejectUpdate',
      );

      final map = Map<String, dynamic>.from(response as Map);
      final step = EscalationStep.fromJson(map);

      // 3. Reset conversation
      await _retry(
        () => _supabase
            .from('conversations')
            .update({
              'escalation_status': 'active',
              'current_level': _levelToDb(EscalationLevel.agent),
              'is_escalated': false,
            })
            .eq('id', step.conversationId),
        label: 'rejectUpdateConversation',
      );

      debugPrint('[EscalationService] ✓ Escalation rejected');
      return step;
    } on EscalationException {
      rethrow;
    } catch (e) {
      debugPrint('[EscalationService] ❌ rejectEscalation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ─── RESOLVE ESCALATION ────────────────────────────────────────────

  /// Marque une escalade comme résolue.
  Future<EscalationStep> resolveEscalation(
    String escalationId,
    String agentId,
  ) async {
    if (_isDisposed) throw StateError('EscalationService disposed');

    if (!_EscalationValidators.isValidUuid(escalationId)) {
      throw const EscalationValidationException('escalationId invalide');
    }
    if (!_EscalationValidators.isValidUuid(agentId)) {
      throw const EscalationValidationException('agentId invalide');
    }

    debugPrint('[EscalationService] ✓ Resolving escalation: '
        '${_EscalationValidators.obfuscate(escalationId)}');

    try {
      // Ownership check : agent doit être to_agent_id
      final existing = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('id', escalationId)
            .eq('to_agent_id', agentId)  // ✅ Ownership check
            .eq('status', _statusToDb(EscalationStatus.accepted))
            .maybeSingle(),
        label: 'verifyOwnershipResolve',
      );

      if (existing == null) {
        throw const EscalationPermissionException(
          'Escalade introuvable, non acceptée, ou accès refusé',
        );
      }

      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .update({
              'status': _statusToDb(EscalationStatus.resolved),
              'resolved_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', escalationId)
            .select()
            .single(),
        label: 'resolveUpdate',
      );

      final map = Map<String, dynamic>.from(response as Map);
      final step = EscalationStep.fromJson(map);

      await _retry(
        () => _supabase
            .from('conversations')
            .update({
              'escalation_status': 'resolved',
              'is_escalated': false,
            })
            .eq('id', step.conversationId),
        label: 'resolveUpdateConversation',
      );

      debugPrint('[EscalationService] ✓ Escalation resolved');
      return step;
    } on EscalationException {
      rethrow;
    } catch (e) {
      debugPrint('[EscalationService] ❌ resolveEscalation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ─── HISTORY (par conversation) ────────────────────────────────────

  /// Récupère l'historique des escalades d'une conversation (paginé).
  Future<List<EscalationStep>> getEscalationHistory(
    String conversationId, {
    int limit = _kDefaultLimit,
    int offset = 0,
  }) async {
    if (_isDisposed) return [];
    if (!_EscalationValidators.isValidUuid(conversationId)) return [];

    final safeLimit = limit.clamp(1, _kMaxLimit);
    final safeOffset = offset.clamp(0, 10000);

    try {
      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .range(safeOffset, safeOffset + safeLimit - 1),
        label: 'getEscalationHistory',
      );

      return _parseSteps(response);
    } catch (e) {
      debugPrint('[EscalationService] ❌ getEscalationHistory: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  // ─── PENDING (dashboard par agent + niveau) ────────────────────────

  /// Récupère les escalades pending destinées à un agent spécifique
  /// d'un niveau donné (pour le dashboard).
  ///
  /// **Corrigé** : filtre maintenant par `to_agent_id` ET `to_level`.
  Future<List<EscalationStep>> getPendingEscalations(
    String agentId,
    EscalationLevel agentLevel, {
    int limit = _kDefaultLimit,
    int offset = 0,
  }) async {
    if (_isDisposed) return [];
    if (!_EscalationValidators.isValidUuid(agentId)) return [];

    final safeLimit = limit.clamp(1, _kMaxLimit);
    final safeOffset = offset.clamp(0, 10000);

    try {
      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('to_agent_id', agentId)          // ✅ Filtrage par agent
            .eq('to_level', _levelToDb(agentLevel))
            .eq('status', _statusToDb(EscalationStatus.pending))
            .order('created_at', ascending: true)
            .range(safeOffset, safeOffset + safeLimit - 1),
        label: 'getPendingEscalations',
      );

      return _parseSteps(response);
    } catch (e) {
      debugPrint('[EscalationService] ❌ getPendingEscalations: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  // ─── RECEIVED (historique complet par agent) ──────────────────────

  /// Récupère toutes les escalades reçues par un agent (pending + autres statuts).
  Future<List<EscalationStep>> getReceivedEscalations(
    String agentId, {
    int limit = _kDefaultLimit,
    int offset = 0,
  }) async {
    if (_isDisposed) return [];
    if (!_EscalationValidators.isValidUuid(agentId)) return [];

    final safeLimit = limit.clamp(1, _kMaxLimit);
    final safeOffset = offset.clamp(0, 10000);

    try {
      final response = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select()
            .eq('to_agent_id', agentId)
            .order('created_at', ascending: false)
            .range(safeOffset, safeOffset + safeLimit - 1),
        label: 'getReceivedEscalations',
      );

      return _parseSteps(response);
    } catch (e) {
      debugPrint('[EscalationService] ❌ getReceivedEscalations: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return [];
    }
  }

  // ─── COUNT PENDING (badge) ─────────────────────────────────────────

  /// Compte les escalades pending reçues par un agent (pour badge).
  Future<int> countPendingReceived(String agentId) async {
    if (_isDisposed) return 0;
    if (!_EscalationValidators.isValidUuid(agentId)) return 0;

    try {
      final r = await _retry(
        () => _supabase
            .from('escalation_steps')
            .select('id')
            .eq('to_agent_id', agentId)
            .eq('status', _statusToDb(EscalationStatus.pending))
            .count(CountOption.exact),
        label: 'countPendingReceived',
      );
      return r.count;
    } catch (e) {
      debugPrint('[EscalationService] ❌ countPendingReceived: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return 0;
    }
  }

  // ─── GET CONVERSATION ──────────────────────────────────────────────

  /// Récupère la conversation associée à une escalade.
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    if (_isDisposed) return null;
    if (!_EscalationValidators.isValidUuid(conversationId)) return null;

    try {
      final response = await _retry(
        () => _supabase
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .maybeSingle(),
        label: 'getConversation',
      );
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      debugPrint('[EscalationService] ❌ getConversation: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return null;
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Parse une liste de réponses DB en `List<EscalationStep>`.
  List<EscalationStep> _parseSteps(dynamic response) {
    if (response is! List) return [];
    final steps = <EscalationStep>[];
    for (final row in response) {
      try {
        final map = Map<String, dynamic>.from(row as Map);
        // Validation de l'ID
        final id = map['id']?.toString() ?? '';
        if (!_EscalationValidators.isValidUuid(id)) continue;
        steps.add(EscalationStep.fromJson(map));
      } catch (e) {
        debugPrint('[EscalationService] ⚠️ Skip invalid step: '
            '${kDebugMode ? e : "parse error"}');
      }
    }
    return steps;
  }

  // ─── DISPOSE ────────────────────────────────────────────────────────

  /// Marque le service comme disposé.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('[EscalationService] 👋 Disposed');
  }
}
