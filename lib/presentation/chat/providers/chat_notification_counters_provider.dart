// lib/presentation/chat/providers/chat_notification_counters_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kDbTimeout = Duration(seconds: 10);
const Duration _kDebounceDelay = Duration(milliseconds: 500);
const int _kMaxCounterValue = 9999;
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Status values pour escalation_steps.status
enum EscalationStatus {
  pending(0),
  inProgress(1),
  resolved(2),
  rejected(3);

  final int code;
  const EscalationStatus(this.code);
}

const String _kConnectionPending = 'pending';
const String _kCallStatusMissed = 'missed';

// ============================================================================
// VALIDATORS
// ============================================================================
class _NotificationValidators {
  _NotificationValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static int safeCount(int value) {
    if (value < 0) return 0;
    if (value > _kMaxCounterValue) return _kMaxCounterValue;
    return value;
  }

  static String? extractUserId(Map<String, dynamic> record, String key) {
    final raw = record[key];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return isValidUuid(id) ? id : null;
  }
}

// ============================================================================
// STATE
// ============================================================================

class NotificationCounters {
  final int unreadMessages;
  final int missedCalls;
  final int newConnections;
  final int pendingEscalations;
  final String? lastError;
  final bool isRefreshing;

  const NotificationCounters({
    this.unreadMessages = 0,
    this.missedCalls = 0,
    this.newConnections = 0,
    this.pendingEscalations = 0,
    this.lastError,
    this.isRefreshing = false,
  });

  int get total => _NotificationValidators.safeCount(
        unreadMessages + missedCalls + newConnections + pendingEscalations,
      );

  bool get hasAny => total > 0;

  NotificationCounters copyWith({
    int? unreadMessages,
    int? missedCalls,
    int? newConnections,
    int? pendingEscalations,
    String? lastError,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return NotificationCounters(
      unreadMessages: unreadMessages != null
          ? _NotificationValidators.safeCount(unreadMessages)
          : this.unreadMessages,
      missedCalls: missedCalls != null
          ? _NotificationValidators.safeCount(missedCalls)
          : this.missedCalls,
      newConnections: newConnections != null
          ? _NotificationValidators.safeCount(newConnections)
          : this.newConnections,
      pendingEscalations: pendingEscalations != null
          ? _NotificationValidators.safeCount(pendingEscalations)
          : this.pendingEscalations,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class NotificationCountersNotifier extends StateNotifier<NotificationCounters> {
  final Ref _ref;

  String? _userId;
  bool _isDisposed = false;
  bool _isRefreshInProgress = false;
  Timer? _refreshDebounce;

  RealtimeChannel? _missedCallsChannel;
  RealtimeChannel? _connectionsChannel;
  RealtimeChannel? _escalationsChannel;
  ProviderSubscription? _authSubscription;

  NotificationCountersNotifier(this._ref)
      : super(const NotificationCounters()) {
    debugPrint('[NotificationCounters] 🚀 Initialized');
    _bindAuthChanges();
    _init();
  }

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  @override
  void dispose() {
    _isDisposed = true;
    _refreshDebounce?.cancel();
    _authSubscription?.close();
    _cleanupChannels();
    debugPrint('[NotificationCounters] 👋 Disposed');
    super.dispose();
  }

  void _bindAuthChanges() {
    _authSubscription = _ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        final prevId = previous?.id;
        final nextId = next?.id;
        if (prevId == nextId) return;

        debugPrint('[NotificationCounters] 🔄 Auth changed: '
            '${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

        _cleanupChannels();
        state = const NotificationCounters();

        if (nextId != null) {
          _userId = nextId;
          _init();
        } else {
          _userId = null;
        }
      },
    );
  }

  Future<void> _init() async {
    if (_isDisposed) return;

    final userId = _userId ?? _client.auth.currentUser?.id;
    if (!_NotificationValidators.isValidUuid(userId)) {
      debugPrint('[NotificationCounters] ⚠️ No valid user ID');
      return;
    }

    _userId = userId;
    debugPrint(
        '[NotificationCounters] 🌐 Init for user ${_obfuscate(userId)}');

    await refresh();
    _subscribeRealtime();
  }

  Future<void> refresh({bool immediate = false}) async {
    if (_isDisposed || _userId == null) return;

    if (!immediate) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(_kDebounceDelay, () => _doRefresh());
      return;
    }

    await _doRefresh();
  }

  Future<void> _doRefresh() async {
    if (_isDisposed || _userId == null || _isRefreshInProgress) return;

    _isRefreshInProgress = true;
    state = state.copyWith(isRefreshing: true, clearError: true);
    debugPrint('[NotificationCounters] 🔄 Refreshing counters');

    try {
      final results = await Future.wait<dynamic>([
        _safeCountMissedCalls(),
        _safeCountConnections(),
        _safeCountEscalations(),
      ]).timeout(_kDbTimeout);

      if (_isDisposed) return;

      state = state.copyWith(
        missedCalls: results[0] as int,
        newConnections: results[1] as int,
        pendingEscalations: results[2] as int,
        isRefreshing: false,
        clearError: true,
      );
      debugPrint('[NotificationCounters] ✓ Counters refreshed: '
          'calls=${results[0]}, connections=${results[1]}, '
          'escalations=${results[2]}');
    } catch (e) {
      debugPrint('[NotificationCounters] ❌ Refresh failed: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isRefreshing: false,
          lastError: 'Échec du chargement des notifications',
        );
      }
    } finally {
      _isRefreshInProgress = false;
    }
  }

  Future<int> _safeCountMissedCalls() async {
    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('call_history')
            .select('id')
            .eq('user_id', _userId!)
            .eq('status', _kCallStatusMissed)
            .eq('is_read', false)
            .timeout(_kDbTimeout);
        return _NotificationValidators.safeCount((res as List).length);
      } catch (e) {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[NotificationCounters] ❌ missedCalls failed: $e');
          return 0;
        }
        debugPrint('[NotificationCounters] ⚠️ missedCalls retry $attempt');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  Future<int> _safeCountConnections() async {
    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('connections')
            .select('id')
            .eq('status', _kConnectionPending)
            .or('requester_id.eq.${_userId!},responder_id.eq.${_userId!}')
            .timeout(_kDbTimeout);
        return _NotificationValidators.safeCount((res as List).length);
      } catch (e) {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[NotificationCounters] ❌ connections failed: $e');
          return 0;
        }
        debugPrint('[NotificationCounters] ⚠️ connections retry $attempt');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  Future<int> _safeCountEscalations() async {
    final userId = _userId;
    if (userId == null) return 0;

    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('escalation_steps')
            .select('id')
            .eq('to_agent_id', userId)
            .eq('status', EscalationStatus.pending.code)
            .timeout(_kDbTimeout);
        return _NotificationValidators.safeCount((res as List).length);
      } catch (e) {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[NotificationCounters] ❌ escalations failed: $e');
          return 0;
        }
        debugPrint('[NotificationCounters] ⚠️ escalations retry $attempt');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  void _subscribeRealtime() {
    if (_isDisposed || _userId == null) return;

    debugPrint('[NotificationCounters] 📡 Subscribing to 3 channels');

    try {
      _subscribeMissedCalls();
      _subscribeConnections();
      _subscribeEscalations();
    } catch (e) {
      debugPrint('[NotificationCounters] ❌ Subscribe failed: $e');
    }
  }

  void _subscribeMissedCalls() {
    final userId = _userId;
    if (userId == null) return;

    _missedCallsChannel = _client
        .channel('thix_missed_calls_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_history',
          callback: (payload) {
            if (_isDisposed) return;
            final record = payload.newRecord;
            final userIdFromRecord = record['user_id']?.toString();
            final status = record['status']?.toString();
            if (userIdFromRecord == userId && status == _kCallStatusMissed) {
              state = state.copyWith(missedCalls: state.missedCalls + 1);
              debugPrint('[NotificationCounters] ➕ Missed call received');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_history',
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'call_history',
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint(
                '[NotificationCounters] ✓ Missed calls channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Missed calls error: $error');
          }
        });
  }

  void _subscribeConnections() {
    final userId = _userId;
    if (userId == null) return;

    _connectionsChannel = _client
        .channel('thix_connections_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          callback: (payload) {
            if (_isDisposed) return;
            final record = payload.newRecord;
            final requesterId =
                _NotificationValidators.extractUserId(record, 'requester_id');
            final responderId =
                _NotificationValidators.extractUserId(record, 'responder_id');
            final status = record['status']?.toString();

            if (status == _kConnectionPending &&
                (requesterId == userId || responderId == userId)) {
              state = state.copyWith(
                  newConnections: state.newConnections + 1);
              debugPrint('[NotificationCounters] ➕ New connection request');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'connections',
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'connections',
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint(
                '[NotificationCounters] ✓ Connections channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Connections error: $error');
          }
        });
  }

  void _subscribeEscalations() {
    final userId = _userId;
    if (userId == null) return;

    _escalationsChannel = _client
        .channel('thix_escalations_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'escalation_steps',
          callback: (payload) {
            if (_isDisposed) return;
            final record = payload.newRecord;
            final toAgentId = record['to_agent_id']?.toString();
            final status = record['status'];
            if (toAgentId == userId &&
                status == EscalationStatus.pending.code) {
              state = state.copyWith(
                  pendingEscalations: state.pendingEscalations + 1);
              debugPrint('[NotificationCounters] ➕ New escalation assigned');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'escalation_steps',
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint(
                '[NotificationCounters] ✓ Escalations channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Escalations error: $error');
          }
        });
  }

  Future<void> clearMissedCalls() async {
    if (_userId == null) return;

    final previousCount = state.missedCalls;
    state = state.copyWith(missedCalls: 0);
    debugPrint('[NotificationCounters] 🧹 Clearing missed calls');

    try {
      await _client
          .from('call_history')
          .update({'is_read': true})
          .eq('user_id', _userId!)
          .eq('status', _kCallStatusMissed)
          .eq('is_read', false)
          .timeout(_kDbTimeout);
      debugPrint('[NotificationCounters] ✓ Missed calls marked as read');
    } catch (e) {
      debugPrint(
          '[NotificationCounters] ❌ Mark read failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          missedCalls: previousCount,
          lastError: 'Échec du marquage des appels',
        );
      }
    }
  }

  void clearNewConnections() {
    state = state.copyWith(newConnections: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared connections counter');
  }

  void clearPendingEscalations() {
    state = state.copyWith(pendingEscalations: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared escalations counter');
  }

  void clearUnreadMessages() {
    state = state.copyWith(unreadMessages: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared messages counter');
  }

  void _cleanupChannels() {
    debugPrint('[NotificationCounters] 🧹 Cleaning up channels');

    final channels = [
      _missedCallsChannel,
      _connectionsChannel,
      _escalationsChannel,
    ];

    _missedCallsChannel = null;
    _connectionsChannel = null;
    _escalationsChannel = null;

    for (final channel in channels) {
      if (channel == null) continue;
      try {
        channel.unsubscribe();
        _client.removeChannel(channel);
      } catch (e) {
        debugPrint('[NotificationCounters] ⚠️ Channel cleanup error: $e');
      }
    }
  }

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final notificationCountersProvider = StateNotifierProvider<
    NotificationCountersNotifier, NotificationCounters>((ref) {
  return NotificationCountersNotifier(ref);
});

final totalNotificationsProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).total;
});

final hasNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationCountersProvider).hasAny;
});

final missedCallsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).missedCalls;
});

final pendingConnectionsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).newConnections;
});

final pendingEscalationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).pendingEscalations;
});

final unreadMessagesCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).unreadMessages;
});

final notificationCountersErrorProvider = Provider<String?>((ref) {
  return ref.watch(notificationCountersProvider).lastError;
});
