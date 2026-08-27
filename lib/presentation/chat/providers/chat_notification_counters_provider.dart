import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationCounters {
  final int unreadMessages;
  final int missedCalls;
  final int newConnections;
  final int pendingEscalations;

  const NotificationCounters({
    this.unreadMessages = 0,
    this.missedCalls = 0,
    this.newConnections = 0,
    this.pendingEscalations = 0,
  });

  NotificationCounters copyWith({
    int? unreadMessages,
    int? missedCalls,
    int? newConnections,
    int? pendingEscalations,
  }) {
    return NotificationCounters(
      unreadMessages: unreadMessages ?? this.unreadMessages,
      missedCalls: missedCalls ?? this.missedCalls,
      newConnections: newConnections ?? this.newConnections,
      pendingEscalations: pendingEscalations ?? this.pendingEscalations,
    );
  }

  int get total =>
      unreadMessages + missedCalls + newConnections + pendingEscalations;
}

class NotificationCountersNotifier
    extends StateNotifier<NotificationCounters> {
  final SupabaseClient _client;

  String? _userId;
  bool _isDisposed = false;

  RealtimeChannel? _missedCallsChannel;
  RealtimeChannel? _connectionsChannel;
  RealtimeChannel? _escalationsChannel;

  NotificationCountersNotifier(this._client)
      : super(const NotificationCounters()) {
    _init();
  }

  Future<void> _init() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _userId = user.id;

    await refresh();
    _subscribeRealtime();
  }

  Future<void> refresh() async {
    if (_isDisposed || _userId == null) return;

    try {
      final missedCalls = await _safeCountMissedCalls();
      final newConnections = await _safeCountConnections();
      final pendingEscalations = await _safeCountEscalations();

      if (_isDisposed) return;

      state = state.copyWith(
        missedCalls: missedCalls,
        newConnections: newConnections,
        pendingEscalations: pendingEscalations,
      );
    } catch (e) {
      debugPrint('NotificationCounters refresh error: $e');
    }
  }

  Future<int> _safeCountMissedCalls() async {
    try {
      final res = await _client
          .from('call_history')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'missed')
          .eq('is_read', false);

      return (res as List).length;
    } catch (e) {
      debugPrint('missed calls count error: $e');
      return 0;
    }
  }

  Future<int> _safeCountConnections() async {
    try {
      final res = await _client
          .from('connections')
          .select('id')
          .eq('status', 'pending')
          .or('requester_id.eq.${_userId!},responder_id.eq.${_userId!}');

      return (res as List).length;
    } catch (e) {
      debugPrint('connections count error: $e');
      return 0;
    }
  }

  Future<int> _safeCountEscalations() async {
    try {
      final res = await _client
          .from('escalation_steps')
          .select('id')
          .eq('to_agent_id', _userId!)
          .eq('status', 0);

      return (res as List).length;
    } catch (e) {
      debugPrint('escalations count error: $e');
      return 0;
    }
  }

  void _subscribeRealtime() {
    if (_isDisposed || _userId == null) return;

    _missedCallsChannel = _client
        .channel('thix_missed_calls_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_history',
          callback: (payload) {
            if (_isDisposed) return;

            final record = payload.newRecord;
            final userId = record['user_id']?.toString();
            final status = record['status']?.toString();

            if (userId == _userId && status == 'missed') {
              state = state.copyWith(
                missedCalls: state.missedCalls + 1,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_history',
          callback: (_) {
            if (!_isDisposed) {
              refresh();
            }
          },
        )
        .subscribe();

    _connectionsChannel = _client
        .channel('thix_connections_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          callback: (payload) {
            if (_isDisposed) return;

            final record = payload.newRecord;
            final requesterId = record['requester_id']?.toString();
            final responderId = record['responder_id']?.toString();
            final status = record['status']?.toString();

            if (status == 'pending' &&
                (requesterId == _userId || responderId == _userId)) {
              state = state.copyWith(
                newConnections: state.newConnections + 1,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'connections',
          callback: (_) {
            if (!_isDisposed) {
              refresh();
            }
          },
        )
        .subscribe();

    _escalationsChannel = _client
        .channel('thix_escalations_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'escalation_steps',
          callback: (payload) {
            if (_isDisposed) return;

            final record = payload.newRecord;
            final toAgentId = record['to_agent_id']?.toString();
            final status = record['status'];

            if (toAgentId == _userId && status == 0) {
              state = state.copyWith(
                pendingEscalations: state.pendingEscalations + 1,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'escalation_steps',
          callback: (_) {
            if (!_isDisposed) {
              refresh();
            }
          },
        )
        .subscribe();
  }

  void clearMissedCalls() {
    state = state.copyWith(missedCalls: 0);
    _markMissedCallsAsRead();
  }

  void clearNewConnections() {
    state = state.copyWith(newConnections: 0);
  }

  Future<void> _markMissedCallsAsRead() async {
    if (_userId == null) return;

    try {
      await _client
          .from('call_history')
          .update({'is_read': true})
          .eq('user_id', _userId!)
          .eq('status', 'missed')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('mark missed calls as read error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _missedCallsChannel?.unsubscribe();
    _connectionsChannel?.unsubscribe();
    _escalationsChannel?.unsubscribe();

    super.dispose();
  }
}

final notificationCountersProvider =
    StateNotifierProvider<NotificationCountersNotifier, NotificationCounters>(
  (ref) {
    return NotificationCountersNotifier(Supabase.instance.client);
  },
);
