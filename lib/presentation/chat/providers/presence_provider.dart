// lib/presentation/chat/providers/presence_provider.dart
//
// PresenceProvider — Production Enterprise (rate-limit safe)
//
// Corrections vs version précédente :
//  1. ✅ WidgetsBindingObserver → heartbeat PAUSÉ en background
//  2. ✅ Casts sûrs sur presenceState() / join / leave
//  3. ✅ Debounce 300ms sur les changements d'auth
//  4. ✅ Reconnexion exponentielle bornée (3s → 6s → 12s → 24s → 48s, max 5)
//  5. ✅ Garde anti-reconnects multiples (_reconnectScheduled)
//  6. ✅ Hook de monitoring optionnel (Sentry/Crashlytics)
//  7. ✅ Reset complet au logout
//  8. ✅ Vérification post-await du userId (anti stale)
//  9. ✅ RATE LIMIT FIX : plus de heartbeat .track() toutes les 30s
//     → un seul track() au subscribe ; Supabase gère le timeout côté serveur
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const String _kChannelName = 'thix-global-presence';
const String _kPayloadUserIdKey = 'user_id';
const int _kMaxSetSize = 10000;
const Duration _kTrackTimeout = Duration(seconds: 10);
const Duration _kReconnectBaseDelay = Duration(seconds: 3);
const Duration _kReconnectMaxDelay = Duration(seconds: 60);
const int _kMaxReconnectAttempts = 5;
const Duration _kAuthDebounce = Duration(milliseconds: 300);

// ============================================================================
// VALIDATORS
// ============================================================================
class _PresenceValidators {
  _PresenceValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

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
class PresenceState {
  final Set<String> onlineUserIds;
  final bool isConnected;
  final String? error;

  const PresenceState({
    this.onlineUserIds = const {},
    this.isConnected = false,
    this.error,
  });

  int get onlineCount => onlineUserIds.length;
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
class PresenceNotifier extends StateNotifier<PresenceState>
    with WidgetsBindingObserver {
  /// Hook optionnel : branchez Sentry/Crashlytics dans main.dart si besoin.
  static void Function(String context, Object error, [StackTrace? stack])?
      onErrorReport;

  final Ref _ref;
  RealtimeChannel? _channel;
  Timer? _authDebounce;

  ProviderSubscription<String?>? _authSubscription;

  String? _currentUserId;
  bool _isTracked = false;
  bool _isDisposed = false;
  bool _isBackgrounded = false;
  bool _reconnectScheduled = false;
  int _reconnectAttempts = 0;

  PresenceNotifier(this._ref) : super(const PresenceState()) {
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Presence] 🚀 Initialized');
    _bindAuthChanges();
    _initPresence();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _authDebounce?.cancel();
    _authSubscription?.close();
    _cleanupChannel();
    debugPrint('[Presence] 👋 Disposed');
    super.dispose();
  }

  // ── CYCLE DE VIE APP ──────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_isBackgrounded) {
          _isBackgrounded = true;
          // Optionnel : untrack en background pour libérer le slot Presence
          // unawaited(_untrackSelf());
          debugPrint('[Presence] ⏸️ Background');
        }
        break;
      case AppLifecycleState.resumed:
        _isBackgrounded = false;
        // Re-track une seule fois au retour foreground (pas de loop)
        if (_channel != null && _currentUserId != null && !_isTracked) {
          _trackSelf();
        }
        debugPrint('[Presence] ▶️ Foreground');
        break;
    }
  }

  // ── LOGGING / MONITORING ──────────────────────────────────────────────
  void _logError(String context, Object error, [StackTrace? stack]) {
    debugPrint('[Presence] ❌ $context: $error');
    if (!kDebugMode) {
      onErrorReport?.call(context, error, stack);
    }
  }

  // ── AUTH ──────────────────────────────────────────────────────────────
  void _bindAuthChanges() {
    _authSubscription = _ref.listen<String?>(
      supabaseUserIdProvider,
      (previous, next) {
        _authDebounce?.cancel();
        _authDebounce = Timer(_kAuthDebounce, () {
          if (_isDisposed) return;
          if (previous == next) return;

          debugPrint('[Presence] 🔄 Auth changed: '
              '${_obfuscate(previous)} → ${_obfuscate(next)}');

          _cleanupChannel();
          _reconnectAttempts = 0;

          if (next != null) {
            _initPresence();
          } else {
            _currentUserId = null;
            _isTracked = false;
            state = const PresenceState();
          }
        });
      },
    );
  }

  // ── INIT ──────────────────────────────────────────────────────────────
  void _initPresence() {
    if (_isDisposed) return;

    final myUserId = _supabase.auth.currentUser?.id;
    if (!_PresenceValidators.isValidUuid(myUserId)) {
      debugPrint('[Presence] ⚠️ No valid user ID, skipping init');
      return;
    }

    if (_channel != null) _cleanupChannel();

    _currentUserId = myUserId;
    debugPrint(
        '[Presence] 🌐 Initializing presence for ${_obfuscate(myUserId)}');

    try {
      _channel = _supabase.channel(
        _kChannelName,
        opts: const RealtimeChannelConfig(),
      );

      _channel!.onPresenceSync((_) => _handlePresenceSync());
      _channel!.onPresenceJoin((join) => _handlePresenceJoin(join));
      _channel!.onPresenceLeave((leave) => _handlePresenceLeave(leave));

      _channel!.subscribe((status, [error]) {
        if (_isDisposed) return;
        _handleSubscriptionStatus(status, error);
      });
    } catch (e, stack) {
      _logError('Init failed', e, stack);
      state = state.copyWith(
          error: 'Échec de connexion présence', isConnected: false);
      _scheduleReconnect();
    }
  }

  // ── SUBSCRIPTION STATUS ───────────────────────────────────────────────
  void _handleSubscriptionStatus(
      RealtimeSubscribeStatus status, Object? error) {
    if (_isDisposed) return;

    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        debugPrint('[Presence] ✓ Subscribed to $_kChannelName');
        _reconnectAttempts = 0;
        state = state.copyWith(isConnected: true, clearError: true);
        // Un seul track au subscribe — pas de heartbeat périodique
        _trackSelf();
        break;

      case RealtimeSubscribeStatus.closed:
        debugPrint('[Presence] 🔌 Channel closed');
        state = state.copyWith(isConnected: false);
        _isTracked = false;
        if (_currentUserId != null) _scheduleReconnect();
        break;

      case RealtimeSubscribeStatus.timedOut:
        debugPrint('[Presence] ⏱️ Subscription timed out');
        state = state.copyWith(isConnected: false, error: 'Connexion timeout');
        _isTracked = false;
        _scheduleReconnect();
        break;

      case RealtimeSubscribeStatus.channelError:
        _logError('Channel error', error ?? 'unknown');
        state =
            state.copyWith(isConnected: false, error: 'Erreur canal présence');
        _isTracked = false;
        _scheduleReconnect();
        break;
    }
  }

  // ── TRACK SELF (une seule fois) ───────────────────────────────────────
  Future<void> _trackSelf() async {
    final channel = _channel;
    final userId = _currentUserId;
    if (_isDisposed || _isTracked || channel == null || userId == null) return;
    if (_isBackgrounded) return;

    try {
      await channel
          .track({_kPayloadUserIdKey: userId})
          .timeout(_kTrackTimeout);

      if (_isDisposed || _channel != channel || _currentUserId != userId) {
        debugPrint('[Presence] ⚠️ Context changed during track, aborting');
        return;
      }

      _isTracked = true;
      debugPrint('[Presence] 📢 Tracked self: ${_obfuscate(userId)}');
    } catch (e, stack) {
      _logError('Track failed', e, stack);
    }
  }

  // ── PRESENCE SYNC ─────────────────────────────────────────────────────
  void _handlePresenceSync() {
    if (_isDisposed) return;

    try {
      final raw = _channel?.presenceState();
      if (raw == null || raw.isEmpty) {
        state = state.copyWith(onlineUserIds: {});
        return;
      }

      final newState = <String>{};

      // realtime_client 2.x → List<SinglePresenceState>
      for (final single in raw) {
        for (final presence in single.presences) {
          final userId =
              _PresenceValidators.extractUserId(_payloadOf(presence));
          if (userId != null) {
            newState.add(userId);
            if (newState.length >= _kMaxSetSize) break;
          }
        }
        if (newState.length >= _kMaxSetSize) break;
      }

      state = state.copyWith(onlineUserIds: newState);
      debugPrint('[Presence] ✓ Sync complete: ${newState.length} users online');
    } catch (e, stack) {
      _logError('Sync error', e, stack);
    }
  }
  // ── JOIN / LEAVE ──────────────────────────────────────────────────────
  void _handlePresenceJoin(dynamic join) {
    if (_isDisposed) return;

    try {
      final newUsers = <String>{};
      for (final presence in _presencesOf(join, preferNew: true)) {
        final userId =
            _PresenceValidators.extractUserId(_payloadOf(presence));
        if (userId != null) newUsers.add(userId);
      }
      if (newUsers.isEmpty) return;

      final updated = Set<String>.from(state.onlineUserIds)..addAll(newUsers);
      if (updated.length > _kMaxSetSize) {
        debugPrint('[Presence] ⚠️ Max set size would be exceeded, skipping');
        return;
      }

      state = state.copyWith(onlineUserIds: updated);
      debugPrint('[Presence] ➕ Joined: ${newUsers.length} user(s) '
          '(total: ${updated.length})');
    } catch (e, stack) {
      _logError('Join error', e, stack);
    }
  }

  void _handlePresenceLeave(dynamic leave) {
    if (_isDisposed) return;

    try {
      final leftUsers = <String>{};
      for (final presence in _presencesOf(leave, preferNew: false)) {
        final userId =
            _PresenceValidators.extractUserId(_payloadOf(presence));
        if (userId != null) leftUsers.add(userId);
      }
      if (leftUsers.isEmpty) return;

      final updated = Set<String>.from(state.onlineUserIds)
        ..removeAll(leftUsers);
      state = state.copyWith(onlineUserIds: updated);
      debugPrint('[Presence] ➖ Left: ${leftUsers.length} user(s) '
          '(total: ${updated.length})');
    } catch (e, stack) {
      _logError('Leave error', e, stack);
    }
  }

  // ── HELPERS PARSING ───────────────────────────────────────────────────
  static Map<String, dynamic>? _payloadOf(dynamic presence) {
    if (presence == null) return null;
    if (presence is Map) {
      final p = presence['payload'];
      return p is Map ? Map<String, dynamic>.from(p) : null;
    }
    try {
      final p = (presence as dynamic).payload;
      return p is Map ? Map<String, dynamic>.from(p) : null;
    } catch (_) {
      return null;
    }
  }

  static List _presencesOf(dynamic event, {required bool preferNew}) {
    final candidates =
        preferNew ? ['newPresences', 'presences'] : ['leftPresences', 'presences'];
    for (final name in candidates) {
      try {
        final value = _readProperty(event, name);
        if (value is List) return value;
      } catch (_) {}
    }
    return const [];
  }

  static dynamic _readProperty(dynamic target, String name) {
    switch (name) {
      case 'newPresences':
        return target.newPresences;
      case 'leftPresences':
        return target.leftPresences;
      case 'presences':
        return target.presences;
      default:
        return null;
    }
  }

  // ── RECONNECT ─────────────────────────────────────────────────────────
  void _scheduleReconnect() {
    if (_isDisposed || _currentUserId == null || _reconnectScheduled) return;

    if (_reconnectAttempts >= _kMaxReconnectAttempts) {
      _logError('Reconnect exhausted',
          'Max attempts ($_kMaxReconnectAttempts) reached');
      state = state.copyWith(error: 'Connexion présence impossible');
      return;
    }

    _reconnectScheduled = true;
    _reconnectAttempts++;

    final ms = _kReconnectBaseDelay.inMilliseconds *
        (1 << (_reconnectAttempts - 1));
    final delay = Duration(milliseconds: ms) > _kReconnectMaxDelay
        ? _kReconnectMaxDelay
        : Duration(milliseconds: ms);

    debugPrint(
        '[Presence] 🔁 Reconnect #$_reconnectAttempts in ${delay.inSeconds}s');

    Future.delayed(delay, () {
      _reconnectScheduled = false;
      if (_isDisposed || _currentUserId == null || _isBackgrounded) return;
      _cleanupChannel();
      _initPresence();
    });
  }

  // ── CLEANUP ───────────────────────────────────────────────────────────
  void _cleanupChannel() {
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

  // ── UTILS ─────────────────────────────────────────────────────────────
  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '\( {s.substring(0, 4)}... \){s.substring(s.length - 4)}';
  }

  void forceRefresh() {
    debugPrint('[Presence] 🔄 Force refresh requested');
    _reconnectAttempts = 0;
    _cleanupChannel();
    _initPresence();
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================
final presenceProvider =
    StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  return PresenceNotifier(ref);
});

final isUserOnlineProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(presenceProvider).isOnline(userId);
});

final onlineCountProvider = Provider<int>((ref) {
  return ref.watch(presenceProvider).onlineCount;
});

final presenceConnectedProvider = Provider<bool>((ref) {
  return ref.watch(presenceProvider).isConnected;
});
