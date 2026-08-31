// lib/presentation/chat/providers/presence_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart' show currentUserProvider;
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const String _kChannelName = 'thix-global-presence';
const String _kPayloadUserIdKey = 'user_id';
const int _kMaxSetSize = 10000; // Protection DoS mémoire
const Duration _kHeartbeatInterval = Duration(seconds: 30);
const Duration _kTrackTimeout = Duration(seconds: 10);
const Duration _kReconnectDelay = Duration(seconds: 3);

// ============================================================================
// VALIDATORS
// ============================================================================
class _PresenceValidators {
  _PresenceValidators._();

  /// Valide qu'un string est un UUID v4 valide
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Extrait un user_id valide d'un payload Realtime
  static String? extractUserId(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final raw = payload[_kPayloadUserIdKey];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return isValidUuid(id) ? id : null;
  }
}

// ============================================================================
// STATE
// ============================================================================

/// État de présence global : ensemble des user IDs en ligne.
class PresenceState {
  /// Set immuable des user IDs en ligne
  final Set<String> onlineUserIds;

  /// Vrai si le canal Realtime est connecté
  final bool isConnected;

  /// Dernière erreur (pour debug UI)
  final String? error;

  const PresenceState({
    this.onlineUserIds = const {},
    this.isConnected = false,
    this.error,
  });

  /// Nombre d'utilisateurs en ligne
  int get onlineCount => onlineUserIds.length;

  /// Vérifie si un utilisateur donné est en ligne
  bool isOnline(String userId) => onlineUserIds.contains(userId);

  PresenceState copyWith({
    Set<String>? onlineUserIds,
    bool? isConnected,
    String? error,
    bool clearError = false,
  }) {
    return PresenceState(
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Notifier de présence temps réel basé sur Supabase Realtime.
///
/// **Architecture** :
/// - Utilise `onPresenceSync` pour l'état initial complet
/// - Utilise `onPresenceJoin` / `onPresenceLeave` pour les updates incrémentales
/// - Heartbeat périodique pour maintenir la présence
/// - Écoute les changements d'auth pour reconnexion propre
///
/// **Sécurité** :
/// - Validation stricte des UUIDs reçus
/// - Sanitization des payloads
/// - Protection DoS (max 10 000 users)
/// - Pas d'exposition d'erreurs techniques à l'UI
class PresenceNotifier extends StateNotifier<PresenceState> {
  final Ref _ref;
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  StreamSubscription? _authSubscription;
  String? _currentUserId;
  bool _isTracked = false;
  bool _isDisposed = false;

  PresenceNotifier(this._ref) : super(const PresenceState()) {
    debugPrint('[Presence] 🚀 Initialized');
    _bindAuthChanges();
    _initPresence();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _authSubscription?.cancel();
    _cleanupChannel();
    debugPrint('[Presence] 👋 Disposed');
    super.dispose();
  }

  // ── AUTH CHANGES ──────────────────────────────────────────────────────

  /// Écoute les changements d'utilisateur (login/logout/switch).
  void _bindAuthChanges() {
    _authSubscription = _ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        final prevId = previous?.id;
        final nextId = next?.id;
        if (prevId == nextId) return;

        debugPrint('[Presence] 🔄 Auth changed: ${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

        // Logout ou switch user : cleanup de l'ancien channel
        _cleanupChannel();

        // Login ou switch : init nouveau channel
        if (nextId != null) {
          _initPresence();
        } else {
          state = const PresenceState();
        }
      },
    );
  }

  // ── INIT PRESENCE ─────────────────────────────────────────────────────

  /// Initialise le canal Realtime et s'annonce.
  void _initPresence() {
    if (_isDisposed) return;

    final myUserId = _supabase.auth.currentUser?.id;
    if (!_PresenceValidators.isValidUuid(myUserId)) {
      debugPrint('[Presence] ⚠️ No valid user ID, skipping init');
      return;
    }

    _currentUserId = myUserId;
    debugPrint('[Presence] 🌐 Initializing presence for ${_obfuscate(myUserId)}');

    try {
      _channel = _supabase.channel(
        _kChannelName,
        opts: const RealtimeChannelConfig(selfBroadcast: false),
      );

      // 1. Sync initial : état complet au join
      _channel!.onPresenceSync((_) => _handlePresenceSync());

      // 2. Updates incrémentales (plus efficace que sync à chaque fois)
      _channel!.onPresenceJoin((join) => _handlePresenceJoin(join));
      _channel!.onPresenceLeave((leave) => _handlePresenceLeave(leave));

      // 3. Subscribe avec gestion d'erreur
      _channel!.subscribe((status, [error]) {
        if (_isDisposed) return;
        _handleSubscriptionStatus(status, error);
      });
    } catch (e) {
      debugPrint('[Presence] ❌ Init failed: $e');
      state = state.copyWith(error: 'Échec de connexion présence', isConnected: false);
      _scheduleReconnect();
    }
  }

  // ── SUBSCRIPTION HANDLING ─────────────────────────────────────────────

  void _handleSubscriptionStatus(RealtimeSubscribeStatus status, Object? error) {
    if (_isDisposed) return;

    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        debugPrint('[Presence] ✓ Subscribed to $_kChannelName');
        state = state.copyWith(isConnected: true, clearError: true);
        _trackSelf();
        _startHeartbeat();
        break;

      case RealtimeSubscribeStatus.closed:
        debugPrint('[Presence] 🔌 Channel closed');
        state = state.copyWith(isConnected: false);
        _stopHeartbeat();
        _scheduleReconnect();
        break;

      case RealtimeSubscribeStatus.timedOut:
        debugPrint('[Presence] ⏱️ Subscription timed out');
        state = state.copyWith(isConnected: false, error: 'Connexion timeout');
        _scheduleReconnect();
        break;

      case RealtimeSubscribeStatus.channelError:
        debugPrint('[Presence] ❌ Channel error: $error');
        state = state.copyWith(isConnected: false, error: 'Erreur canal présence');
        _scheduleReconnect();
        break;
    }
  }

  // ── TRACKING ──────────────────────────────────────────────────────────

  /// S'annonce aux autres utilisateurs.
  Future<void> _trackSelf() async {
    if (_isDisposed || _isTracked || _channel == null || _currentUserId == null) return;

    try {
      await _channel!
          .track({_kPayloadUserIdKey: _currentUserId}).timeout(_kTrackTimeout);
      _isTracked = true;
      debugPrint('[Presence] 📢 Tracked self: ${_obfuscate(_currentUserId!)}');
    } catch (e) {
      debugPrint('[Presence] ❌ Track failed: $e');
    }
  }

  // ── HEARTBEAT ─────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) async {
      if (_isDisposed || !_isTracked || _channel == null) return;
      try {
        await _channel!.track({_kPayloadUserIdKey: _currentUserId});
      } catch (e) {
        debugPrint('[Presence] ⚠️ Heartbeat failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── PRESENCE EVENTS ──────────────────────────────────────────────────

  /// Sync initial : reconstruit le Set complet depuis l'état Realtime.
  void _handlePresenceSync() {
    if (_isDisposed) return;

    try {
      final newState = <String>{};
      final presenceMap = _channel?.presenceState() ?? {};

      for (final entry in presenceMap.entries) {
        for (final presence in entry.value) {
          final payload = presence.payload;
          final userId = _PresenceValidators.extractUserId(payload);
          if (userId != null) {
            newState.add(userId);
            if (newState.length >= _kMaxSetSize) {
              debugPrint('[Presence] ⚠️ Max set size reached ($_kMaxSetSize)');
              break;
            }
          }
        }
      }

      state = state.copyWith(onlineUserIds: newState);
      debugPrint('[Presence] ✓ Sync complete: ${newState.length} users online');
    } catch (e) {
      debugPrint('[Presence] ❌ Sync error: $e');
    }
  }

  /// Update incrémental : utilisateur(s) rejoint(s).
  void _handlePresenceJoin(RealtimePresenceJoinEvent join) {
    if (_isDisposed) return;

    try {
      final newUsers = <String>{};
      for (final presence in join.presences) {
        final userId = _PresenceValidators.extractUserId(presence.payload);
        if (userId != null) newUsers.add(userId);
      }

      if (newUsers.isEmpty) return;

      final updated = Set<String>.from(state.onlineUserIds)..addAll(newUsers);

      if (updated.length > _kMaxSetSize) {
        debugPrint('[Presence] ⚠️ Max set size would be exceeded, skipping join');
        return;
      }

      state = state.copyWith(onlineUserIds: updated);
      debugPrint('[Presence] ➕ Joined: ${newUsers.length} user(s) (total: ${updated.length})');
    } catch (e) {
      debugPrint('[Presence] ❌ Join error: $e');
    }
  }

  /// Update incrémental : utilisateur(s) parti(s).
  void _handlePresenceLeave(RealtimePresenceLeaveEvent leave) {
    if (_isDisposed) return;

    try {
      final leftUsers = <String>{};
      for (final presence in leave.presences) {
        final userId = _PresenceValidators.extractUserId(presence.payload);
        if (userId != null) leftUsers.add(userId);
      }

      if (leftUsers.isEmpty) return;

      final updated = Set<String>.from(state.onlineUserIds)..removeAll(leftUsers);
      state = state.copyWith(onlineUserIds: updated);
      debugPrint('[Presence] ➖ Left: ${leftUsers.length} user(s) (total: ${updated.length})');
    } catch (e) {
      debugPrint('[Presence] ❌ Leave error: $e');
    }
  }

  // ── RECONNECT & CLEANUP ──────────────────────────────────────────────

  void _scheduleReconnect() {
    if (_isDisposed || _currentUserId == null) return;
    debugPrint('[Presence] 🔁 Reconnecting in ${_kReconnectDelay.inSeconds}s...');
    Future.delayed(_kReconnectDelay, () {
      if (!_isDisposed && _currentUserId != null) {
        _cleanupChannel();
        _initPresence();
      }
    });
  }

  void _cleanupChannel() {
    _stopHeartbeat();
    _isTracked = false;

    final channel = _channel;
    _channel = null;

    if (channel == null) return;

    try {
      channel.unsubscribe();
      _supabase.removeChannel(channel);
      debugPrint('[Presence] 🧹 Channel cleaned up');
    } catch (e) {
      debugPrint('[Presence] ⚠️ Cleanup error: $e');
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// API publique : force un refresh de l'état de présence.
  void forceRefresh() {
    debugPrint('[Presence] 🔄 Force refresh requested');
    _cleanupChannel();
    _initPresence();
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider principal pour la présence temps réel.
///
/// Usage :
/// ```dart
/// final presence = ref.watch(presenceProvider);
/// final isOnline = presence.isOnline(userId);
/// final count = presence.onlineCount;
/// final allIds = presence.onlineUserIds;
/// ```
final presenceProvider =
    StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  return PresenceNotifier(ref);
});

/// Provider dérivé : vérifie si un utilisateur spécifique est en ligne.
///
/// Usage :
/// ```dart
/// final isUserOnline = ref.watch(isUserOnlineProvider(userId));
/// ```
final isUserOnlineProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(presenceProvider).isOnline(userId);
});

/// Provider dérivé : nombre d'utilisateurs en ligne.
final onlineCountProvider = Provider<int>((ref) {
  return ref.watch(presenceProvider).onlineCount;
});

/// Provider dérivé : état de connexion du canal Realtime.
final presenceConnectedProvider = Provider<bool>((ref) {
  return ref.watch(presenceProvider).isConnected;
});
