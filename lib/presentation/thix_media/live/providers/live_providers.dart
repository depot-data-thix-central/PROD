// lib/presentation/thix_media/live/providers/live_providers.dart
//
// Live Providers v3.0.2 — Providers Riverpod pour le système Live
//
// Ce fichier expose les providers partagés entre :
//   - LiveHostPage (host)
//   - LiveViewerPage (viewer/spectateur)
//   - Tous les écrans qui ont besoin d'accéder au LiveService
//
// NOTE : Les providers de setup/go-live (GoLiveState) sont dans
//        go_live_provider.dart (séparés pour cohérence).
//
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ IMPORT pour usage INTERNE dans ce fichier
import 'package:thix_id/data/models/live/live_model.dart';
import '../services/live_service.dart';

// ✅ EXPORT pour usage EXTERNE (par les fichiers qui importent ce fichier)
// Ré-export pour faciliter l'accès depuis les widgets
export 'package:thix_id/data/models/live/live_model.dart'
    show LiveRole, GuestStatus, LiveGuest;

// ============================================================================
// LIVE SERVICE (singleton global)
// ============================================================================

/// Provider singleton pour [LiveService].
///
/// Utilisé par :
///   - LiveHostPage (start/end live, sendLikeBatch, sendGuestInvite, promote/demote)
///   - LiveViewerPage (join, sendMessage, acceptGuestInvite, rejectGuestInvite)
///
/// Pourquoi un provider singleton :
///   - Évite de recréer le service à chaque rebuild
///   - Partage le cache de tokens Agora entre tous les écrans
///   - Partage le rate-limiter global (anti-spam chat)
///
/// Usage :
/// ```dart
/// final liveService = ref.read(liveServiceProvider);
/// await liveService.sendMessage(...);
/// ```
final liveServiceProvider = Provider<LiveService>((ref) {
  final service = LiveService();

  // Cleanup quand le provider est disposé (ex: logout, app restart)
  ref.onDispose(() {
    service.clearCache();
  });

  return service;
});

// ============================================================================
// LIVE SERVICE LISTENER (pour widgets qui veulent réagir aux changements)
// ============================================================================

/// Provider auto-dispose qui donne accès à [LiveService] avec cleanup automatique.
///
/// Utile pour les widgets temporaires (dialogs, bottom sheets) qui ont besoin
/// du service mais ne doivent pas le garder en mémoire après fermeture.
///
/// Usage :
/// ```dart
/// final liveService = ref.watch(liveServiceAutoDisposeProvider);
/// ```
final liveServiceAutoDisposeProvider =
    Provider.autoDispose<LiveService>((ref) {
  return LiveService();
});

// ============================================================================
// LIVE SESSION STATE (état partagé du live en cours)
// ============================================================================

/// État global du live courant (partagé entre host + viewer).
///
/// Contient :
///   - L'ID du live actif (null si aucun live)
///   - Le rôle de l'utilisateur (host/guest/viewer)
///   - L'URL de partage
///
/// Utile pour :
///   - Afficher un badge "En live" dans la bottom nav
///   - Savoir si l'utilisateur est actuellement dans un live
///   - Coordonner la navigation (ex: revenir au live si minimisé)
class CurrentLiveState {
  final String? liveId;
  final String? channelName;
  final LiveRole role;
  final DateTime? joinedAt;

  const CurrentLiveState({
    this.liveId,
    this.channelName,
    this.role = LiveRole.viewer,
    this.joinedAt,
  });

  bool get isInLive => liveId != null;
  bool get isHost => role == LiveRole.host;
  bool get isOnStage => role == LiveRole.host ||
      role == LiveRole.guest ||
      role == LiveRole.coHost;
  bool get isViewer => role == LiveRole.viewer;

  CurrentLiveState copyWith({
    String? liveId,
    String? channelName,
    LiveRole? role,
    DateTime? joinedAt,
  }) {
    return CurrentLiveState(
      liveId: liveId ?? this.liveId,
      channelName: channelName ?? this.channelName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// Reset complet (à appeler au leave/end)
  static const empty = CurrentLiveState();
}

/// Notifier pour l'état du live courant
class CurrentLiveNotifier extends StateNotifier<CurrentLiveState> {
  CurrentLiveNotifier() : super(CurrentLiveState.empty);

  /// Appelé quand l'utilisateur démarre un live (host)
  void startLive({
    required String liveId,
    required String channelName,
  }) {
    state = CurrentLiveState(
      liveId: liveId,
      channelName: channelName,
      role: LiveRole.host,
      joinedAt: DateTime.now(),
    );
  }

  /// Appelé quand l'utilisateur rejoint un live (viewer)
  void joinAsViewer({
    required String liveId,
    required String channelName,
  }) {
    state = CurrentLiveState(
      liveId: liveId,
      channelName: channelName,
      role: LiveRole.viewer,
      joinedAt: DateTime.now(),
    );
  }

  /// Appelé quand un viewer accepte une invitation (devient guest)
  void promotedToBroadcaster() {
    if (!state.isInLive) return;
    state = state.copyWith(role: LiveRole.guest);
  }

  /// Appelé quand un guest est rétrogradé (revient viewer)
  void demotedToViewer() {
    if (!state.isInLive) return;
    state = state.copyWith(role: LiveRole.viewer);
  }

  /// Appelé quand le live est quitté ou terminé
  void leave() {
    state = CurrentLiveState.empty;
  }
}

/// Provider de l'état du live courant.
///
/// Usage :
/// ```dart
/// final currentLive = ref.watch(currentLiveProvider);
/// if (currentLive.isInLive) {
///   // Afficher badge "En live"
/// }
/// ```
final currentLiveProvider =
    StateNotifierProvider<CurrentLiveNotifier, CurrentLiveState>((ref) {
  return CurrentLiveNotifier();
});
