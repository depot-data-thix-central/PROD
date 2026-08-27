// lib/presentation/chat/providers/notification_counters_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compteurs globaux pour la bottom nav et les notifications système
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

  int get total => unreadMessages + missedCalls + newConnections + pendingEscalations;
}

class NotificationCountersNotifier extends StateNotifier<NotificationCounters> {
  final SupabaseClient _client;
  String? _userId;
  RealtimeChannel? _missedCallsChannel;
  RealtimeChannel? _connectionsChannel;
  bool _isDisposed = false;

  NotificationCountersNotifier(this._client) : super(const NotificationCounters()) {
    _init();
  }

  Future<void> _init() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _userId = user.id;
    await refresh();
    _subscribeToChanges();
  }

  Future<void> refresh() async {
    if (_userId == null || _isDisposed) return;

    try {
      // Appels manqués non lus
      final missedCallsRes = await _client
          .from('call_history')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'missed')
          .eq('is_read', false);

      // Nouvelles demandes de connexion en attente
      final newConnectionsRes = await _client
          .from('connections')
          .select('id')
          .eq('status', 'pending')
          .or('requester_id.eq.$_userId,responder_id.eq.$_userId');

      // Escalades en attente
      final escalationsRes = await _client
          .from('escalation_steps')
          .select('id')
          .eq('to_agent_id', _userId!)
          .eq('status', 0);

      if (_isDisposed) return;

      state = state.copyWith(
        missedCalls: (missedCallsRes as List).length,
        newConnections: (newConnectionsRes as List).length,
        pendingEscalations: (escalationsRes as List).length,
      );
    } catch (e) {
      debugPrint('❌ NotificationCounters refresh error: $e');
    }
  }

  void _subscribeToChanges() {
    if (_userId == null || _isDisposed) return;

    // Appels manqués en temps réel
    _missedCallsChannel = _client
        .channel('missed_calls_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            if (_isDisposed) return;
            final status = payload.newRecord['status'] as String?;
            if (status == 'missed') {
              state = state.copyWith(missedCalls: state.missedCalls + 1);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            if (_isDisposed) return;
            // Si un appel manqué est marqué comme lu
            final isRead = payload.newRecord['is_read'] as bool?;
            if (isRead == true) {
              final newCount = (state.missedCalls - 1).clamp(0, 999);
              state = state.copyWith(missedCalls: newCount);
            }
          },
        )
        .subscribe();

    // Nouvelles connexions en temps réel
    _connectionsChannel = _client
        .channel('new_connections_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          callback: (payload) {
            if (_isDisposed) return;
            final requesterId = payload.newRecord['requester_id'] as String?;
            final responderId = payload.newRecord['responder_id'] as String?;
            final status = payload.newRecord['status'] as String?;
            
            if (status == 'pending' && (requesterId == _userId || responderId == _userId)) {
              state = state.copyWith(newConnections: state.newConnections + 1);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'connections',
          callback: (payload) {
            if (_isDisposed) return;
            final status = payload.newRecord['status'] as String?;
            if (status != 'pending') {
              // Connexion acceptée ou rejetée → décrémenter
              final newCount = (state.newConnections - 1).clamp(0, 999);
              state = state.copyWith(newConnections: newCount);
            }
          },
        )
        .subscribe();
  }

  void clearMissedCalls() {
    state = state.copyWith(missedCalls: 0);
    // Marquer tous les appels manqués comme lus en background
    _markAllMissedCallsAsRead();
  }

  void clearNewConnections() {
    state = state.copyWith(newConnections: 0);
  }

  Future<void> _markAllMissedCallsAsRead() async {
    if (_userId == null) return;
    try {
      await _client
          .from('call_history')
          .update({'is_read': true})
          .eq('user_id', _userId!)
          .eq('status', 'missed')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ markAllMissedCallsAsRead: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _missedCallsChannel?.unsubscribe();
    _connectionsChannel?.unsubscribe();
    super.dispose();
  }
}

final notificationCountersProvider = StateNotifierProvider<NotificationCountersNotifier, NotificationCounters>((ref) {
  return NotificationCountersNotifier(Supabase.instance.client);
});
