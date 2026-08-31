// lib/presentation/chat/providers/presence_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const String _kChannelName = 'thix-global-presence';
const String _kPayloadUserIdKey = 'user_id';
const int _kMaxSetSize = 10000;
const Duration _kHeartbeatInterval = Duration(seconds: 30);
const Duration _kTrackTimeout = Duration(seconds: 10);
const Duration _kReconnectDelay = Duration(seconds: 3);

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

class PresenceNotifier extends StateNotifier<PresenceState> {
  final Ref _ref;
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  ProviderSubscription? _authSubscription;
  String? _currentUserId;
  bool _isTracked = false;
  bool _isDisposed = false;

  PresenceNotifier(this._ref) : super(const PresenceState()) {
    debugPrint('[Presence] 🚀 Initialized');
    _bindAuthChanges();
    _initPresence();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _authSubscription?.close();
    _cleanupChannel();
    debugPrint('[Presence] 👋 Disposed');
    super.dispose();
  }

  void _bindAuthChanges() {
    _authSubscription = _ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        final prevId = previous?.id;
        final nextId = next?.id;
        if (prevId == nextId) return;

        debugPrint('[Presence] 🔄 Auth changed: '
            '${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

        _cleanupChannel();

        if (nextId != null) {
          _initPresence();
        } else {
          state = const PresenceState();
        }
      },
    );
  }

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

      _channel!.onPresenceSync((_) => _handlePresenceSync());
      _channel!.onPresenceJoin((join) => _handlePresenceJoin(join));
      _channel!.onPresenceLeave((leave) => _handlePresenceLeave(leave));

      _channel!.subscribe((status, [error]) {
        if (_isDisposed) return;
        _handleSubscriptionStatus(status, error);
      });
    } catch (e) {
      debugPrint('[Presence] ❌ Init failed: $e');
      state = state.copyWith(
          error: 'Échec de connexion présence', isConnected: false);
      _scheduleReconnect();
    }
  }

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
        state =
            state.copyWith(isConnected: false, error: 'Erreur canal présence');
        _scheduleReconnect();
        break;
    }
  }

  Future<void> _trackSelf() async {
    if (_isDisposed || _isTracked || _channel == null || _currentUserId == null) {
      return;
    }

    try {
      await _channel!
          .track({_kPayloadUserIdKey: _currentUserId}).timeout(_kTrackTimeout);
      _isTracked = true;
      debugPrint('[Presence] 📢 Tracked self: ${_obfuscate(_currentUserId!)}');
    } catch (e) {
      debugPrint('[Presence] ❌ Track failed: $e');
    }
  }

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
      debugPrint('[Presence] ➕ Joined: ${newUsers.length} user(s) '
          '(total: ${updated.length})');
    } catch (e) {
      debugPrint('[Presence] ❌ Join error: $e');
    }
  }

  void _handlePresenceLeave(dynamic leave) { // Remplacer RealtimePresenceLeaveEvent par dynamic

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
      debugPrint('[Presence] ➖ Left: ${leftUsers.length} user(s) '
          '(total: ${updated.length})');
    } catch (e) {
      debugPrint('[Presence] ❌ Leave error: $e');
    }
  }

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

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  void forceRefresh() {
    debugPrint('[Presence] 🔄 Force refresh requested');
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
