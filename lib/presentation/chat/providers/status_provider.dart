// lib/presentation/chat/providers/status_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/auth/auth_controller.dart' show currentUserProvider;
import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxContentLength = 500;
const int _kMaxBackgroundLength = 20;
const int _kMaxStatusIdLength = 100;
const Duration _kStatusTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;
const int _kStatusExpirationHours = 24;

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  /// Sanitize une entrée (XSS + caractères de contrôle)
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

  /// Valide une couleur hex (format #RRGGBB ou #RGB)
  static bool isValidHexColor(String color) {
    return RegExp(r'^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$').hasMatch(color);
  }

  /// Valide un statusId (alphanumérique + underscore + tiret)
  static bool isValidStatusId(String id) {
    return RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id);
  }

  /// Retourne une couleur hex safe (fallback si invalide)
  static String safeColor(String? color, {String fallback = '#1D4ED8'}) {
    if (color == null) return fallback;
    final sanitized = sanitize(color, maxLength: _kMaxBackgroundLength);
    return isValidHexColor(sanitized) ? sanitized : fallback;
  }

  /// Vérifie si un statut est expiré
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

  /// Vrai si une opération est en cours (chargement ou refresh)
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

  /// Statuts non expirés uniquement
  List<UserStatusStory> get activeItems =>
      items.where((s) => !_StatusValidators.isExpired(s)).toList();

  /// Groupé par user pour l'UI (pastilles)
  Map<String, List<UserStatusStory>> get byUser {
    final map = <String, List<UserStatusStory>>{};
    for (final s in activeItems) {
      final userId = s.userId.trim();
      if (userId.isEmpty) continue; // Protection contre userId vide
      map.putIfAbsent(userId, () => []).add(s);
    }
    return map;
  }

  /// Users ordonnés : moi d'abord, puis non vus, puis vus
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

/// Notifier pour la gestion des statuts (stories).
///
/// **Responsabilités** :
/// - Chargement des statuts visibles
/// - Création de statuts texte
/// - Marquage des statuts vus (avec rollback)
/// - Purge automatique des statuts expirés
///
/// **Sécurité** :
/// - Sanitization XSS sur tous les inputs
/// - Validation couleur hex
/// - Validation statusId
/// - Protection contre race conditions
class StatusNotifier extends StateNotifier<StatusState> {
  final Ref _ref;
  Timer? _expirationTimer;
  bool _isLoadInProgress = false;

  StatusNotifier(this._ref) : super(const StatusState()) {
    debugPrint('[StatusProvider] 🚀 Initialized');
    // Charger de manière asynchrone pour ne pas bloquer le constructeur
    Future.microtask(load);
    // Timer de purge toutes les minutes
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) => _purgeExpired());
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    debugPrint('[StatusProvider] 👋 Disposed');
    super.dispose();
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────

  /// Vérifie si l'utilisateur est authentifié
  bool _isAuthenticated() {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('[StatusProvider] ⚠️ User not authenticated');
      return false;
    }
    return true;
  }

  /// Retourne l'user ID courant
  String? _currentUserId() => _ref.read(currentUserProvider)?.id;

  /// Purge les statuts expirés de l'état
  void _purgeExpired() {
    final before = state.items.length;
    final active = state.activeItems;
    if (active.length < before) {
      state = state.copyWith(items: active);
      debugPrint('[StatusProvider] 🧹 Purged ${before - active.length} expired statuses');
    }
  }

  /// Retry helper générique
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
          debugPrint('[StatusProvider] ❌ $label: timeout after $attempt attempts');
          rethrow;
        }
        debugPrint('[StatusProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[StatusProvider] ❌ $label failed after $attempt attempts: $e');
          rethrow;
        }
        debugPrint('[StatusProvider] ⚠️ $label error — retry $attempt/$maxRetries: $e');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  /// Message user-friendly pour les erreurs
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

  // ── LOAD / REFRESH ─────────────────────────────────────────────────────

  /// Charge les statuts visibles.
  ///
  /// Protection contre les appels multiples concurrents.
  Future<void> load() async {
    if (_isLoadInProgress) {
      debugPrint('[StatusProvider] ⚠️ Load already in progress');
      return;
    }

    if (!_isAuthenticated()) {
      state = state.copyWith(isLoading: false, error: 'Non authentifié', clearError: false);
      return;
    }

    _isLoadInProgress = true;
    final isRefresh = state.items.isNotEmpty;
    state = state.copyWith(
      isLoading: !isRefresh,
      isRefreshing: isRefresh,
      clearError: true,
    );
    debugPrint('[StatusProvider] 🔄 Loading statuses (refresh=$isRefresh)');

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

  /// Rafraîchit les statuts.
  Future<void> refresh() => load();

  // ── CREATE ─────────────────────────────────────────────────────────────

  /// Crée un statut texte.
  ///
  /// **Sécurité** :
  /// - `content` sanitizé et limité à 500 caractères
  /// - `background` validé (format hex strict)
  /// - Vérification d'authentification
  Future<bool> createText(String content, {String background = '#1D4ED8'}) async {
    if (!_isAuthenticated()) {
      state = state.copyWith(error: 'Vous devez être connecté pour publier un statut');
      return false;
    }

    final sanitizedContent = _StatusValidators.sanitize(content, maxLength: _kMaxContentLength);
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

  // ── MARK VIEWED ────────────────────────────────────────────────────────

  /// Marque un statut comme vu.
  ///
  /// **Rollback automatique** si l'appel service échoue :
  /// l'état optimiste est restauré pour éviter une UI incohérente.
  Future<void> markViewed(String statusId) async {
    if (!_isAuthenticated()) return;

    final sanitizedId = _StatusValidators.sanitize(statusId, maxLength: _kMaxStatusIdLength);
    if (!_StatusValidators.isValidStatusId(sanitizedId)) {
      debugPrint('[StatusProvider] ⚠️ Invalid statusId: $statusId');
      return;
    }

    // Snapshot avant modification optimiste
    final previousItems = List<UserStatusStory>.from(state.items);

    // Mise à jour optimiste
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
      // Rollback en cas d'échec
      debugPrint('[StatusProvider] ❌ Mark viewed failed, rolling back: $e');
      state = state.copyWith(items: previousItems, error: _friendlyError(e));
    }
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

/// Provider principal pour les statuts (stories).
///
/// Usage :
/// ```dart
/// final statusState = ref.watch(statusProvider);
/// final orderedUsers = statusState.orderedUserIds;
/// final byUser = statusState.byUser;
///
/// // Actions
/// ref.read(statusProvider.notifier).refresh();
/// await ref.read(statusProvider.notifier).createText('Hello!');
/// await ref.read(statusProvider.notifier).markViewed(statusId);
/// ```
final statusProvider =
    StateNotifierProvider<StatusNotifier, StatusState>((ref) {
  return StatusNotifier(ref);
});

/// Provider dérivé pour les users ordonnés (optimisation rebuild).
final statusOrderedUsersProvider = Provider<List<String>>((ref) {
  return ref.watch(statusProvider).orderedUserIds;
});

/// Provider dérivé pour les statuts groupés par user.
final statusByUserProvider = Provider<Map<String, List<UserStatusStory>>>((ref) {
  return ref.watch(statusProvider).byUser;
});

/// Provider dérivé pour l'état de chargement.
final statusIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(statusProvider).isBusy;
});
