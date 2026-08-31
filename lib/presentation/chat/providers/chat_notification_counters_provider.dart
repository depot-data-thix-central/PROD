// lib/presentation/chat/providers/notification_counters_provider.dart
//
// ============================================================================
// NOTIFICATION COUNTERS — Realtime + DB sync
// ============================================================================
//
// Centralise les compteurs de notifications pour la bottom bar :
//   - unreadMessages    (messages non lus dans toutes conversations)
//   - missedCalls       (appels manqués non lus)
//   - newConnections    (demandes de connexion en attente)
//   - pendingEscalations (escalades assignées non traitées)
//
// Architecture :
//   1. `refresh()` au démarrage (batch query unique)
//   2. 3 channels Realtime filtrés par user (events incrémentaux)
//   3. Debounce 500ms sur updates pour éviter le spam
//   4. Rollback optimiste si action serveur échoue
//
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart' show currentUserProvider;
import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show supabaseClientProvider;

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kDbTimeout = Duration(seconds: 10);
const Duration _kDebounceDelay = Duration(milliseconds: 500);
const int _kMaxCounterValue = 9999; // Protection DoS + UI cap
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Status values pour `escalation_steps.status`
enum EscalationStatus {
  pending(0),
  inProgress(1),
  resolved(2),
  rejected(3);

  final int code;
  const EscalationStatus(this.code);
}

/// Status values pour `connections.status`
const String _kConnectionPending = 'pending';

/// Status values pour `call_history.status`
const String _kCallStatusMissed = 'missed';

// ============================================================================
// VALIDATORS
// ============================================================================
class _NotificationValidators {
  _NotificationValidators._();

  /// Valide un UUID v4 strict
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Clamp un compteur à [_kMaxCounterValue]
  static int safeCount(int value) {
    if (value < 0) return 0;
    if (value > _kMaxCounterValue) return _kMaxCounterValue;
    return value;
  }

  /// Extrait et valide un user_id d'un payload Realtime
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

/// État des compteurs de notifications.
///
/// Immuable, exposé via StateNotifier. Chaque champ est borné entre
/// 0 et [_kMaxCounterValue] pour protection DoS et UI.
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

  /// Total de toutes les notifications (pour le badge global)
  int get total => _NotificationValidators.safeCount(
        unreadMessages + missedCalls + newConnections + pendingEscalations,
      );

  /// Vrai si au moins une notification existe
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

/// Notifier pour les compteurs de notifications.
///
/// **Cycle de vie** :
/// - Créé au premier `ref.watch`
/// - S'abonne aux changements d'auth (cleanup/reconnect auto)
/// - Dispose proprement les 3 channels Realtime
///
/// **Sécurité** :
/// - Validation UUID sur tous les user_ids
/// - Sanitization des payloads Realtime
/// - Protection DoS (max 9999 par compteur)
/// - Pas de stack traces exposées à l'UI
class NotificationCountersNotifier extends StateNotifier<NotificationCounters> {
  final Ref _ref;

  String? _userId;
  bool _isDisposed = false;
  bool _isRefreshInProgress = false;
  Timer? _refreshDebounce;

  RealtimeChannel? _missedCallsChannel;
  RealtimeChannel? _connectionsChannel;
  RealtimeChannel? _escalationsChannel;
  StreamSubscription? _authSubscription;

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
    _authSubscription?.cancel();
    _cleanupChannels();
    debugPrint('[NotificationCounters] 👋 Disposed');
    super.dispose();
  }

  // ── AUTH BINDING ─────────────────────────────────────────────────────

  /// Écoute les changements d'utilisateur (logout/login/switch).
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

  // ── INIT ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_isDisposed) return;

    final userId = _userId ?? _client.auth.currentUser?.id;
    if (!_NotificationValidators.isValidUuid(userId)) {
      debugPrint('[NotificationCounters] ⚠️ No valid user ID');
      return;
    }

    _userId = userId;
    debugPrint('[NotificationCounters] 🌐 Init for user ${_obfuscate(userId)}');

    await refresh();
    _subscribeRealtime();
  }

  // ── REFRESH (debounced, race-safe) ───────────────────────────────────

  /// Rafraîchit tous les compteurs.
  ///
  /// Protection contre les appels concurrents et debouncing automatique
  /// pour éviter le spam sur updates Realtime groupés.
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
      // Batch les 3 count queries pour réduire latence
      final results = await Future.wait([
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
          'calls=${results[0]}, connections=${results[1]}, escalations=${results[2]}');
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

  // ── COUNT QUERIES ────────────────────────────────────────────────────

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
    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('escalation_steps')
            .select('id')
            .eq('to_agent_id', _userId!)
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

  // ── REALTIME SUBSCRIPTIONS ───────────────────────────────────────────

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
    _missedCallsChannel = _client
        .channel('thix_missed_calls_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_history',
          filter: PostgresChangeFilter(
            type: PostgresFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (payload) {
            if (_isDisposed) return;
            final record = payload.newRecord;
            final status = record['status']?.toString();
            if (status == _kCallStatusMissed) {
              state = state.copyWith(missedCalls: state.missedCalls + 1);
              debugPrint('[NotificationCounters] ➕ Missed call received');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_history',
          filter: PostgresChangeFilter(
            type: PostgresFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'call_history',
          filter: PostgresChangeFilter(
            type: PostgresFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('[NotificationCounters] ✓ Missed calls channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Missed calls error: $error');
          }
        });
  }

  void _subscribeConnections() {
    _connectionsChannel = _client
        .channel('thix_connections_$_userId')
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
                (requesterId == _userId || responderId == _userId)) {
              state = state.copyWith(newConnections: state.newConnections + 1);
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
            debugPrint('[NotificationCounters] ✓ Connections channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Connections error: $error');
          }
        });
  }

  void _subscribeEscalations() {
    _escalationsChannel = _client
        .channel('thix_escalations_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'escalation_steps',
          filter: PostgresChangeFilter(
            type: PostgresFilterType.eq,
            column: 'to_agent_id',
            value: _userId,
          ),
          callback: (payload) {
            if (_isDisposed) return;
            final record = payload.newRecord;
            final status = record['status'];
            if (status == EscalationStatus.pending.code) {
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
          filter: PostgresChangeFilter(
            type: PostgresFilterType.eq,
            column: 'to_agent_id',
            value: _userId,
          ),
          callback: (_) {
            if (!_isDisposed) refresh();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('[NotificationCounters] ✓ Escalations channel subscribed');
          } else if (error != null) {
            debugPrint('[NotificationCounters] ❌ Escalations error: $error');
          }
        });
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────

  /// Marque tous les appels manqués comme lus.
  ///
  /// **Rollback automatique** si la requête serveur échoue : le compteur
  /// est restauré à sa valeur précédente.
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
      debugPrint('[NotificationCounters] ❌ Mark read failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          missedCalls: previousCount,
          lastError: 'Échec du marquage des appels',
        );
      }
    }
  }

  /// Réinitialise le compteur de nouvelles connexions (côté client).
  void clearNewConnections() {
    state = state.copyWith(newConnections: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared connections counter');
  }

  /// Réinitialise le compteur d'escalades en attente (côté client).
  void clearPendingEscalations() {
    state = state.copyWith(pendingEscalations: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared escalations counter');
  }

  /// Réinitialise le compteur de messages non lus (côté client).
  void clearUnreadMessages() {
    state = state.copyWith(unreadMessages: 0);
    debugPrint('[NotificationCounters] 🧹 Cleared messages counter');
  }

  // ── CLEANUP ──────────────────────────────────────────────────────────

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

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider principal pour les compteurs de notifications.
///
/// Usage :
/// ```dart
/// final counters = ref.watch(notificationCountersProvider);
/// final badge = counters.total;
/// final hasNotifs = counters.hasAny;
/// ```
final notificationCountersProvider = StateNotifierProvider<
    NotificationCountersNotifier, NotificationCounters>((ref) {
  return NotificationCountersNotifier(ref);
});

// ── DERIVED PROVIDERS (rebuild optimization) ─────────────────────────

/// Nombre total de notifications (pour badge global).
final totalNotificationsProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).total;
});

/// Vrai si au moins une notification existe.
final hasNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationCountersProvider).hasAny;
});

/// Nombre d'appels manqués non lus.
final missedCallsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).missedCalls;
});

/// Nombre de demandes de connexion en attente.
final pendingConnectionsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).newConnections;
});

/// Nombre d'escalades assignées non traitées.
final pendingEscalationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).pendingEscalations;
});

/// Nombre de messages non lus.
final unreadMessagesCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCountersProvider).unreadMessages;
});

/// Dernière erreur (pour debug UI / toast).
final notificationCountersErrorProvider = Provider<String?>((ref) {
  return ref.watch(notificationCountersProvider).lastError;
});
