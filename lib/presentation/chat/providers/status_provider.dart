// lib/presentation/chat/providers/status_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxContentLength = 500;
const int _kMaxBackgroundLength = 20;
const int _kMaxStatusIdLength = 100;
const Duration _kStatusTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidHexColor(String color) {
    return RegExp(r'^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$').hasMatch(color);
  }

  static bool isValidStatusId(String id) {
    return RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id);
  }

  static String safeColor(String? color, {String fallback = '#1D4ED8'}) {
    if (color == null) return fallback;
    final sanitized = sanitize(color, maxLength: _kMaxBackgroundLength);
    return isValidHexColor(sanitized) ? sanitized : fallback;
  }

  static bool isExpired(UserStatusStory status) {
    if (status.expiresAt == null) return false;
    return DateTime.now().isAfter(status.expiresAt!);
  }
}

// ============================================================================
// STATE
// ============================================================================
class StatusState {
  final List<UserStatusStory> items;
  final bool isLoading;
  final String? error;
  final bool isRefreshing;

  const StatusState({
    this.items = const [],
    this.isLoading = true,
    this.error,
    this.isRefreshing = false,
  });

  bool get isBusy => isLoading || isRefreshing;

  StatusState copyWith({
    List<UserStatusStory>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return StatusState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  List<UserStatusStory> get activeItems =>
      items.where((s) => !_StatusValidators.isExpired(s)).toList();

  Map<String, List<UserStatusStory>> get byUser {
    final map = <String, List<UserStatusStory>>{};
    for (final s in activeItems) {
      final userId = s.userId.trim();
      if (userId.isEmpty) continue;
      map.putIfAbsent(userId, () => []).add(s);
    }
    return map;
  }

  List<String> get orderedUserIds {
    final map = byUser;
    final mine = <String>[];
    final unseen = <String>[];
    final seen = <String>[];

    for (final entry in map.entries) {
      final userId = entry.key;
      final list = entry.value;

      if (list.isEmpty) continue;

      final isMine = list.any((s) => s.isMine);
      final allViewed = list.every((s) => s.hasViewed || s.isMine);

      if (isMine) {
        mine.add(userId);
      } else if (allViewed) {
        seen.add(userId);
      } else {
        unseen.add(userId);
      }
    }
    return [...mine, ...unseen, ...seen];
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class StatusNotifier extends StateNotifier<StatusState> {
  final Ref _ref;
  Timer? _expirationTimer;
  bool _isLoadInProgress = false;

  StatusNotifier(this._ref) : super(const StatusState()) {
    debugPrint('[StatusProvider] 🚀 Initialized');
    Future.microtask(load);
    _expirationTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => _purgeExpired());
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    debugPrint('[StatusProvider] 👋 Disposed');
    super.dispose();
  }

  bool _isAuthenticated() {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('[StatusProvider] ⚠️ User not authenticated');
      return false;
    }
    return true;
  }

  String? _currentUserId() => _ref.read(currentUserProvider)?.id;

  void _purgeExpired() {
    final before = state.items.length;
    final active = state.activeItems;
    if (active.length < before) {
      state = state.copyWith(items: active);
      debugPrint('[StatusProvider] 🧹 Purged ${before - active.length} expired');
    }
  }

  Future<T> _retry<T>(
    Future<T> Function() fn, {
    required String label,
    int maxRetries = _kMaxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn().timeout(_kStatusTimeout);
      } on TimeoutException {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[StatusProvider] ❌ $label: timeout after $attempt');
          rethrow;
        }
        debugPrint('[StatusProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[StatusProvider] ❌ $label failed: $e');
          rethrow;
        }
        debugPrint('[StatusProvider] ⚠️ $label error — retry $attempt: $e');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('timeout')) {
      return 'Erreur de connexion. Vérifiez votre réseau.';
    }
    if (msg.contains('unauthorized') || msg.contains('forbidden')) {
      return 'Accès non autorisé.';
    }
    if (msg.contains('not found')) {
      return 'Statut introuvable.';
    }
    return 'Une erreur est survenue.';
  }

  Future<void> load() async {
    if (_isLoadInProgress) {
      debugPrint('[StatusProvider] ⚠️ Load already in progress');
      return;
    }

    if (!_isAuthenticated()) {
      state = state.copyWith(
          isLoading: false, error: 'Non authentifié', clearError: false);
      return;
    }

    _isLoadInProgress = true;
    final isRefresh = state.items.isNotEmpty;
    state = state.copyWith(
      isLoading: !isRefresh,
      isRefreshing: isRefresh,
      clearError: true,
    );
    debugPrint('[StatusProvider] 🔄 Loading (refresh=$isRefresh)');

    try {
      final items = await _retry(
        () => _ref.read(statusServiceProvider).getVisibleStatuses(),
        label: 'getVisibleStatuses',
      );
      state = state.copyWith(
        items: items,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
      debugPrint('[StatusProvider] ✓ Loaded ${items.length} statuses');
    } catch (e) {
      debugPrint('[StatusProvider] ❌ Load failed: $e');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: _friendlyError(e),
      );
    } finally {
      _isLoadInProgress = false;
    }
  }

  Future<void> refresh() => load();

  Future<bool> createText(String content, {String background = '#1D4ED8'}) async {
    if (!_isAuthenticated()) {
      state = state.copyWith(
          error: 'Vous devez être connecté pour publier un statut');
      return false;
    }

    final sanitizedContent =
        _StatusValidators.sanitize(content, maxLength: _kMaxContentLength);
    if (sanitizedContent.isEmpty) {
      debugPrint('[StatusProvider] ⚠️ Empty content');
      state = state.copyWith(error: 'Le contenu ne peut pas être vide');
      return false;
    }

    final safeBackground = _StatusValidators.safeColor(background);
    debugPrint('[StatusProvider] 📝 Creating text status (bg=$safeBackground)');

    try {
      final id = await _retry(
        () => _ref.read(statusServiceProvider).createTextStatus(
              content: sanitizedContent,
              background: safeBackground,
            ),
        label: 'createTextStatus',
      );

      if (id != null) {
        debugPrint('[StatusProvider] ✓ Status created: $id');
        await load();
        return true;
      }

      state = state.copyWith(error: 'Échec de création du statut');
      return false;
    } catch (e) {
      debugPrint('[StatusProvider] ❌ Create failed: $e');
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<void> markViewed(String statusId) async {
    if (!_isAuthenticated()) return;

    final sanitizedId =
        _StatusValidators.sanitize(statusId, maxLength: _kMaxStatusIdLength);
    if (!_StatusValidators.isValidStatusId(sanitizedId)) {
      debugPrint('[StatusProvider] ⚠️ Invalid statusId: $statusId');
      return;
    }

    final previousItems = List<UserStatusStory>.from(state.items);

    state = state.copyWith(
      items: state.items
          .map((s) => s.statusId == sanitizedId
              ? UserStatusStory(
                  statusId: s.statusId,
                  userId: s.userId,
                  displayName: s.displayName,
                  avatarUrl: s.avatarUrl,
                  content: s.content,
                  mediaUrl: s.mediaUrl,
                  mediaType: s.mediaType,
                  background: s.background,
                  createdAt: s.createdAt,
                  expiresAt: s.expiresAt,
                  isMine: s.isMine,
                  hasViewed: true,
                )
              : s)
          .toList(),
    );

    debugPrint('[StatusProvider] 👁️ Marking viewed: $sanitizedId');

    try {
      await _retry(
        () => _ref.read(statusServiceProvider).markViewed(sanitizedId),
        label: 'markViewed[$sanitizedId]',
      );
      debugPrint('[StatusProvider] ✓ Marked viewed: $sanitizedId');
    } catch (e) {
      debugPrint('[StatusProvider] ❌ Mark viewed failed, rollback: $e');
      state = state.copyWith(items: previousItems, error: _friendlyError(e));
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final statusProvider =
    StateNotifierProvider<StatusNotifier, StatusState>((ref) {
  return StatusNotifier(ref);
});

final statusOrderedUsersProvider = Provider<List<String>>((ref) {
  return ref.watch(statusProvider).orderedUserIds;
});

final statusByUserProvider =
    Provider<Map<String, List<UserStatusStory>>>((ref) {
  return ref.watch(statusProvider).byUser;
});

final statusIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(statusProvider).isBusy;
});
