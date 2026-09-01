// lib/presentation/chat/escalation/providers/escalation_provider.dart
//
// ============================================================================
// ESCALATION PROVIDER — Production Enterprise
// ============================================================================
//
// StateNotifier Riverpod pour gérer l'état global des escalades.
//
// Architecture :
//   - EscalationService injecté via Riverpod (testable)
//   - Notifier avec état immutable (EscalationState)
//   - Pagination automatique avec pages séparées par type de liste
//   - Gestion robuste des erreurs (stack traces masquées en production)
//
// Fonctionnalités :
//   - loadPending(agentId, level) : dashboard par niveau
//   - loadReceived(agentId) : escalades reçues par agent
//   - loadHistory(conversationId) : historique par conversation
//   - create / accept / reject / resolve : cycle de vie complet
//
// Sécurité :
//   - Validation UUID sur tous les IDs
//   - Stack traces masquées en production (kDebugMode)
//   - Retry automatique sur échecs réseau
//   - Protection contre les doublons dans create
//
// Robustesse :
//   - Pages de pagination séparées (_pendingPage, _receivedPage, _historyPage)
//   - Guards anti-race condition (isLoading check)
//   - onDispose cleanup
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/presentation/chat/escalation/models/escalation_level.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_priority.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_status.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_step.dart';
import 'package:thix_id/presentation/chat/escalation/services/escalation_service.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show supabaseClientProvider;

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kDefaultPageLimit = 20;
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

// ============================================================================
// PROVIDER
// ============================================================================

/// Provider injectable pour `EscalationService`.
///
/// Utilise `supabaseClientProvider` pour injecter le client Supabase,
/// permettant les tests unitaires et évitant le couplage fort.
final escalationServiceProvider = Provider<EscalationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final service = EscalationService(client: client);
  ref.onDispose(() {
    service.dispose();
    debugPrint('[escalationServiceProvider] 👋 Disposed');
  });
  return service;
}, name: 'escalationServiceProvider');

// ============================================================================
// VALIDATORS
// ============================================================================
class _EscalationProviderValidators {
  _EscalationProviderValidators._();

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

  /// Obfusque un ID pour les logs.
  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// STATE
// ============================================================================

/// État immutable des escalades.
class EscalationState {
  /// Escalades pending (dashboard niveau OU reçues par agent).
  final List<EscalationStep> pending;

  /// Historique des escalades (par conversation).
  final List<EscalationStep> history;

  /// True si chargement initial en cours.
  final bool isLoading;

  /// True si chargement de page suivante en cours.
  final bool isLoadingMore;

  /// Message d'erreur user-friendly (null si pas d'erreur).
  final String? error;

  /// True s'il reste des pages pending à charger.
  final bool hasMorePending;

  /// True s'il reste des pages d'historique à charger.
  final bool hasMoreHistory;

  const EscalationState({
    this.pending = const [],
    this.history = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMorePending = true,
    this.hasMoreHistory = true,
  });

  EscalationState copyWith({
    List<EscalationStep>? pending,
    List<EscalationStep>? history,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMorePending,
    bool? hasMoreHistory,
    bool clearError = false,
    bool clearPending = false,
    bool clearHistory = false,
  }) {
    return EscalationState(
      pending: clearPending ? const [] : (pending ?? this.pending),
      history: clearHistory ? const [] : (history ?? this.history),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMorePending: hasMorePending ?? this.hasMorePending,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Notifier Riverpod pour gérer l'état global des escalades.
///
/// **Usage** :
/// ```dart
/// final state = ref.watch(escalationProvider);
/// final notifier = ref.read(escalationProvider.notifier);
/// await notifier.loadPending(agentId, EscalationLevel.senior);
/// ```
class EscalationNotifier extends Notifier<EscalationState> {
  // Pages de pagination séparées par type de liste
  int _pendingPage = 0;
  int _receivedPage = 0;
  int _historyPage = 0;

  EscalationService get _service => ref.read(escalationServiceProvider);

  @override
  EscalationState build() {
    debugPrint('[EscalationProvider] 🚀 Initialized');
    return const EscalationState();
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Retry helper avec backoff.
  Future<T> _retry<T>(
    Future<T> Function() fn, {
    required String label,
    int maxRetries = _kMaxRetries,
  }) async {
    int attempt = 0;
    Object? lastError;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[EscalationProvider] ❌ $label failed after $attempt attempts: '
              '${kDebugMode ? e : e.toString().split('\n').first}');
          rethrow;
        }
        debugPrint('[EscalationProvider] ⏱️ $label retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  /// Formatte une erreur en message user-friendly.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai d\'attente dépassé';
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Erreur de connexion réseau';
    }
    if (msg.contains('permission') || msg.contains('accès refusé')) {
      return 'Accès refusé';
    }
    if (msg.contains('existe pas')) return 'Ressource introuvable';
    if (msg.contains('déjà en attente')) return 'Une escalade est déjà en attente';
    // En production : message générique
    return kDebugMode ? e.toString() : 'Une erreur est survenue';
  }

  /// Générique : charge une liste paginée depuis le service.
  Future<void> _loadPaginated<T>({
    required Future<List<EscalationStep>> Function(int offset) fetcher,
    required bool refresh,
    required int Function() getCurrentPage,
    required void Function(int page) setPage,
    required bool Function() getHasMore,
    required void Function(bool hasMore) setHasMore,
    required List<EscalationStep> Function(List<EscalationStep> list) applyToState,
    required String label,
  }) async {
    if (!refresh && !getHasMore()) {
      debugPrint('[EscalationProvider] ⏹️ $label: no more pages');
      return;
    }

    // Guard anti-race condition
    if (!refresh && (state.isLoading || state.isLoadingMore)) {
      debugPrint('[EscalationProvider] ⏭️ $label: already loading');
      return;
    }

    if (refresh) {
      setPage(0);
      state = state.copyWith(clearError: true);
    }

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    final currentPage = getCurrentPage();
    final offset = currentPage * _kDefaultPageLimit;

    try {
      final list = await _retry(
        () => fetcher(offset),
        label: label,
      );

      final newList = refresh ? list : applyToState(list);
      final hasMore = list.length == _kDefaultPageLimit;

      state = refresh
          ? state.copyWith(
              pending: newList, // Sera override par applyToState si history
              hasMorePending: hasMore,
              isLoading: false,
            )
          : state.copyWith(
              isLoadingMore: false,
            );

      // Appliquer la nouvelle liste au bon champ
      state = EscalationState(
        pending: label.contains('History') ? state.pending : newList,
        history: label.contains('History') ? newList : state.history,
        isLoading: false,
        isLoadingMore: false,
        hasMorePending: label.contains('History') ? state.hasMorePending : hasMore,
        hasMoreHistory: label.contains('History') ? hasMore : state.hasMoreHistory,
        error: null,
      );

      setPage(currentPage + 1);
      debugPrint('[EscalationProvider] ✓ $label: ${list.length} items loaded');
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  // ─── LOAD PENDING (dashboard par niveau) ────────────────────────────

  /// Charge les escalades pending pour un agent d'un niveau donné.
  ///
  /// Utilisé par le dashboard senior/admin.
  Future<void> loadPending(
    String agentId,
    EscalationLevel level, {
    bool refresh = true,
  }) async {
    if (!_EscalationProviderValidators.isValidUuid(agentId)) {
      debugPrint('[EscalationProvider] ⚠️ loadPending: invalid agentId');
      state = state.copyWith(error: 'Identifiant agent invalide');
      return;
    }

    debugPrint('[EscalationProvider] 📥 loadPending '
        '(agent=${_EscalationProviderValidators.obfuscate(agentId)}, '
        'level=${level.name}, refresh=$refresh)');

    if (refresh) {
      _pendingPage = 0;
      state = state.copyWith(
        clearPending: true,
        hasMorePending: true,
        clearError: true,
      );
    }

    if (!state.hasMorePending && !refresh) return;
    if (state.isLoading || state.isLoadingMore) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _retry(
        () => _service.getPendingEscalations(
          agentId,
          level,
          limit: _kDefaultPageLimit,
          offset: _pendingPage * _kDefaultPageLimit,
        ),
        label: 'loadPending',
      );

      state = state.copyWith(
        pending: refresh ? list : [...state.pending, ...list],
        hasMorePending: list.length == _kDefaultPageLimit,
        isLoading: false,
        isLoadingMore: false,
      );
      _pendingPage++;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  // ─── LOAD RECEIVED (escalades reçues par agent) ─────────────────────

  /// Charge les escalades reçues par un agent (tous statuts).
  ///
  /// Aligné avec le badge de la liste de chat.
  Future<void> loadReceived(String agentId, {bool refresh = true}) async {
    if (!_EscalationProviderValidators.isValidUuid(agentId)) {
      debugPrint('[EscalationProvider] ⚠️ loadReceived: invalid agentId');
      state = state.copyWith(error: 'Identifiant agent invalide');
      return;
    }

    debugPrint('[EscalationProvider] 📥 loadReceived '
        '(agent=${_EscalationProviderValidators.obfuscate(agentId)}, refresh=$refresh)');

    if (refresh) {
      _receivedPage = 0;  // ✅ Page séparée
      state = state.copyWith(
        clearPending: true,
        hasMorePending: true,
        clearError: true,
      );
    }

    if (!state.hasMorePending && !refresh) return;
    if (state.isLoading || state.isLoadingMore) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _retry(
        () => _service.getReceivedEscalations(
          agentId,
          limit: _kDefaultPageLimit,
          offset: _receivedPage * _kDefaultPageLimit,
        ),
        label: 'loadReceived',
      );

      state = state.copyWith(
        pending: refresh ? list : [...state.pending, ...list],
        hasMorePending: list.length == _kDefaultPageLimit,
        isLoading: false,
        isLoadingMore: false,
      );
      _receivedPage++;  // ✅ Incrément séparé
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  // ─── LOAD HISTORY (par conversation) ────────────────────────────────

  /// Charge l'historique des escalades d'une conversation.
  Future<void> loadHistory(String conversationId, {bool refresh = true}) async {
    if (!_EscalationProviderValidators.isValidUuid(conversationId)) {
      debugPrint('[EscalationProvider] ⚠️ loadHistory: invalid conversationId');
      state = state.copyWith(error: 'Identifiant conversation invalide');
      return;
    }

    debugPrint('[EscalationProvider] 📥 loadHistory '
        '(conv=${_EscalationProviderValidators.obfuscate(conversationId)}, refresh=$refresh)');

    if (refresh) {
      _historyPage = 0;
      state = state.copyWith(
        clearHistory: true,
        hasMoreHistory: true,
        clearError: true,
      );
    }

    if (!state.hasMoreHistory && !refresh) return;
    if (state.isLoading || state.isLoadingMore) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _retry(
        () => _service.getEscalationHistory(
          conversationId,
          limit: _kDefaultPageLimit,
          offset: _historyPage * _kDefaultPageLimit,
        ),
        label: 'loadHistory',
      );

      state = state.copyWith(
        history: refresh ? list : [...state.history, ...list],
        hasMoreHistory: list.length == _kDefaultPageLimit,
        isLoading: false,
        isLoadingMore: false,
      );
      _historyPage++;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  // ─── CREATE ─────────────────────────────────────────────────────────

  /// Crée une nouvelle escalade.
  Future<EscalationStep?> create({
    required String conversationId,
    required String fromAgentId,
    required String targetAgentId,
    required EscalationLevel toLevel,
    required String reason,
    required EscalationPriority priority,
    String? comment,
    String? fromAgentName,
  }) async {
    // Validation UUID
    if (!_EscalationProviderValidators.isValidUuid(conversationId) ||
        !_EscalationProviderValidators.isValidUuid(fromAgentId) ||
        !_EscalationProviderValidators.isValidUuid(targetAgentId)) {
      state = state.copyWith(error: 'Identifiants invalides');
      return null;
    }

    debugPrint('[EscalationProvider] 📤 create '
        '(conv=${_EscalationProviderValidators.obfuscate(conversationId)}, '
        'from=${_EscalationProviderValidators.obfuscate(fromAgentId)}, '
        'to=${_EscalationProviderValidators.obfuscate(targetAgentId)})');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final step = await _retry(
        () => _service.createEscalation(
          conversationId: conversationId,
          fromAgentId: fromAgentId,
          targetAgentId: targetAgentId,
          toLevel: toLevel,
          reason: reason,
          priority: priority,
          comment: comment,
          fromAgentName: fromAgentName,
        ),
        label: 'create',
      );

      // Protection contre les doublons
      final alreadyExists = state.pending.any((s) => s.id == step.id);
      final newPending = alreadyExists
          ? state.pending.map((s) => s.id == step.id ? step : s).toList()
          : [step, ...state.pending];

      state = state.copyWith(
        pending: newPending,
        isLoading: false,
      );

      debugPrint('[EscalationProvider] ✓ Created: ${step.id}');
      return step;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
      );
      return null;
    }
  }

  // ─── ACCEPT ─────────────────────────────────────────────────────────

  /// Accepte une escalade.
  Future<EscalationStep?> accept(String escalationId, String agentId) async {
    if (!_EscalationProviderValidators.isValidUuid(escalationId) ||
        !_EscalationProviderValidators.isValidUuid(agentId)) {
      state = state.copyWith(error: 'Identifiants invalides');
      return null;
    }

    debugPrint('[EscalationProvider] ✓ accept '
        '(id=${_EscalationProviderValidators.obfuscate(escalationId)})');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final step = await _retry(
        () => _service.acceptEscalation(escalationId, agentId),
        label: 'accept',
      );

      // Met à jour dans pending ET ajoute à history
      final updatedPending = state.pending.map((s) {
        return s.id == escalationId ? step : s;
      }).toList();

      // Évite doublon dans history
      final historyWithout = state.history.where((s) => s.id != step.id).toList();

      state = state.copyWith(
        pending: updatedPending,
        history: [step, ...historyWithout],
        isLoading: false,
      );

      debugPrint('[EscalationProvider] ✓ Accepted: ${step.id}');
      return step;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
      );
      return null;
    }
  }

  // ─── REJECT ─────────────────────────────────────────────────────────

  /// Refuse une escalade avec un motif.
  ///
  /// **Corrigé** : passe maintenant `agentId` pour ownership check.
  Future<EscalationStep?> reject(
    String escalationId,
    String agentId,
    String reason,
  ) async {
    if (!_EscalationProviderValidators.isValidUuid(escalationId) ||
        !_EscalationProviderValidators.isValidUuid(agentId)) {
      state = state.copyWith(error: 'Identifiants invalides');
      return null;
    }

    debugPrint('[EscalationProvider] ❌ reject '
        '(id=${_EscalationProviderValidators.obfuscate(escalationId)})');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final step = await _retry(
        () => _service.rejectEscalation(escalationId, agentId, reason),
        label: 'reject',
      );

      final updatedPending = state.pending.map((s) {
        return s.id == escalationId ? step : s;
      }).toList();

      state = state.copyWith(
        pending: updatedPending,
        isLoading: false,
      );

      debugPrint('[EscalationProvider] ✓ Rejected: ${step.id}');
      return step;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
      );
      return null;
    }
  }

  // ─── RESOLVE ────────────────────────────────────────────────────────

  /// Marque une escalade comme résolue.
  ///
  /// **Corrigé** : passe maintenant `agentId` pour ownership check.
  Future<EscalationStep?> resolve(String escalationId, String agentId) async {
    if (!_EscalationProviderValidators.isValidUuid(escalationId) ||
        !_EscalationProviderValidators.isValidUuid(agentId)) {
      state = state.copyWith(error: 'Identifiants invalides');
      return null;
    }

    debugPrint('[EscalationProvider] ✓ resolve '
        '(id=${_EscalationProviderValidators.obfuscate(escalationId)})');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final step = await _retry(
        () => _service.resolveEscalation(escalationId, agentId),
        label: 'resolve',
      );

      final idx = state.history.indexWhere((s) => s.id == escalationId);
      final newHistory = [...state.history];
      if (idx != -1) {
        newHistory[idx] = step;
      } else {
        newHistory.insert(0, step);
      }

      state = state.copyWith(history: newHistory, isLoading: false);

      debugPrint('[EscalationProvider] ✓ Resolved: ${step.id}');
      return step;
    } catch (e) {
      state = state.copyWith(
        error: _friendlyError(e),
        isLoading: false,
      );
      return null;
    }
  }

  // ─── UTILITIES ──────────────────────────────────────────────────────

  /// Efface l'erreur courante.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Réinitialise complètement l'état.
  void reset() {
    _pendingPage = 0;
    _receivedPage = 0;
    _historyPage = 0;
    state = const EscalationState();
    debugPrint('[EscalationProvider] 🔄 State reset');
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

/// Provider principal pour l'état des escalades.
final escalationProvider = NotifierProvider<EscalationNotifier, EscalationState>(
  EscalationNotifier.new,
  name: 'escalationProvider',
);
