// lib/presentation/chat/escalation/providers/escalation_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/escalation_step.dart';
import '../models/escalation_level.dart';
import '../models/escalation_priority.dart';
import '../services/escalation_service.dart';

final escalationServiceProvider = Provider<EscalationService>((ref) => EscalationService());

class EscalationState {
  final List<EscalationStep> pending;
  final List<EscalationStep> history;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMorePending;
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
  }) {
    return EscalationState(
      pending: pending ?? this.pending,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMorePending: hasMorePending ?? this.hasMorePending,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
    );
  }
}

class EscalationNotifier extends Notifier<EscalationState> {
  static const _limit = 20;
  int _pendingPage = 0;
  int _historyPage = 0;

  EscalationService get _service => ref.read(escalationServiceProvider);

  @override
  EscalationState build() => const EscalationState();

  /// Escalades filtrées par niveau (dashboard senior, etc.)
  Future<void> loadPending(
    String agentId,
    EscalationLevel level, {
    bool refresh = true,
  }) async {
    if (refresh) {
      _pendingPage = 0;
      state = state.copyWith(
        pending: [],
        hasMorePending: true,
        clearError: true,
      );
    }
    if (!state.hasMorePending) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _service.getPendingEscalations(
        agentId,
        level,
        limit: _limit,
        offset: _pendingPage * _limit,
      );

      state = state.copyWith(
        pending: refresh ? list : [...state.pending, ...list],
        hasMorePending: list.length == _limit,
        isLoading: false,
        isLoadingMore: false,
      );
      _pendingPage++;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  /// Escalades destinées à l'agent courant (to_agent_id + status pending).
  /// Aligné avec le badge de la liste de chat.
  Future<void> loadReceived(String agentId, {bool refresh = true}) async {
    if (refresh) {
      _pendingPage = 0;
      state = state.copyWith(
        pending: [],
        hasMorePending: true,
        clearError: true,
      );
    }
    if (!state.hasMorePending) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _service.getReceivedEscalations(
        agentId,
        limit: _limit,
        offset: _pendingPage * _limit,
      );

      state = state.copyWith(
        pending: refresh ? list : [...state.pending, ...list],
        hasMorePending: list.length == _limit,
        isLoading: false,
        isLoadingMore: false,
      );
      _pendingPage++;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadHistory(String conversationId, {bool refresh = true}) async {
    if (refresh) {
      _historyPage = 0;
      state = state.copyWith(
        history: [],
        hasMoreHistory: true,
        clearError: true,
      );
    }
    if (!state.hasMoreHistory) return;

    state = refresh
        ? state.copyWith(isLoading: true)
        : state.copyWith(isLoadingMore: true);

    try {
      final list = await _service.getEscalationHistory(
        conversationId,
        limit: _limit,
        offset: _historyPage * _limit,
      );

      state = state.copyWith(
        history: refresh ? list : [...state.history, ...list],
        hasMoreHistory: list.length == _limit,
        isLoading: false,
        isLoadingMore: false,
      );
      _historyPage++;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final step = await _service.createEscalation(
        conversationId: conversationId,
        fromAgentId: fromAgentId,
        targetAgentId: targetAgentId,
        toLevel: toLevel,
        reason: reason,
        priority: priority,
        comment: comment,
        fromAgentName: fromAgentName,
      );
      state = state.copyWith(
        pending: [step, ...state.pending],
        isLoading: false,
      );
      return step;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  Future<EscalationStep?> accept(String escalationId, String agentId) async {
  state = state.copyWith(isLoading: true, clearError: true);
  try {
    final step = await _service.acceptEscalation(escalationId, agentId);
    // Met à jour l'item dans la liste au lieu de le retirer
    final updated = state.pending.map((s) {
      return s.id == escalationId ? step : s;
    }).toList();
    state = state.copyWith(
      pending: updated,
      history: [step, ...state.history],
      isLoading: false,
    );
    return step;
  } catch (e) {
    state = state.copyWith(error: e.toString(), isLoading: false);
    return null;
  }
}

Future<EscalationStep?> reject(String escalationId, String reason) async {
  state = state.copyWith(isLoading: true, clearError: true);
  try {
    final step = await _service.rejectEscalation(escalationId, reason);
    final updated = state.pending.map((s) {
      return s.id == escalationId ? step : s;
    }).toList();
    state = state.copyWith(
      pending: updated,
      isLoading: false,
    );
    return step;
  } catch (e) {
    state = state.copyWith(error: e.toString(), isLoading: false);
    return null;
  }
}

  Future<EscalationStep?> resolve(String escalationId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final step = await _service.resolveEscalation(escalationId);
      final idx = state.history.indexWhere((s) => s.id == escalationId);
      final newHistory = [...state.history];
      if (idx != -1) {
        newHistory[idx] = step;
      } else {
        newHistory.insert(0, step);
      }
      state = state.copyWith(history: newHistory, isLoading: false);
      return step;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final escalationProvider =
    NotifierProvider<EscalationNotifier, EscalationState>(EscalationNotifier.new);
