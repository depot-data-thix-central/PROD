// lib/data/services/live/audio_space_controller.dart
//
// ============================================================================
// 🎮 AUDIO SPACE CONTROLLER — Adaptateur Riverpod (v2)
// ============================================================================
// Architecture :
//   AudioSpaceManager (singleton, survit à tout)
//        ↓ stream
//   AudioSpaceController (StateNotifier, miroir du state)
//        ↓
//   UI (ref.watch / ref.read)
//
// ✅ PLUS de autoDispose → l'hôte garde le contrôle en background
// ✅ Toutes les actions délèguent au manager
// ✅ Partage + invitations + deep links intégrés
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_manager.dart';
import 'package:thix_id/data/services/live/audio_space_share_service.dart';

// ════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════

/// Instance globale du manager (singleton)
final audioSpaceManagerProvider = Provider<AudioSpaceManager>((ref) {
  return AudioSpaceManager.instance;
});

/// Controller Riverpod — ⚠️ PAS autoDispose (survit à la navigation)
final audioSpaceControllerProvider =
    StateNotifierProvider<AudioSpaceController, AudioSpaceManagerState>((ref) {
  final controller = AudioSpaceController(ref.read(audioSpaceManagerProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

// ─── Sélecteurs pratiques pour l'UI ───
final audioSpaceIsLiveProvider = Provider<bool>((ref) {
  return ref.watch(audioSpaceControllerProvider).isActive;
});

final audioSpaceIsHostProvider = Provider<bool>((ref) {
  return ref.watch(audioSpaceControllerProvider).isHost;
});

final audioSpaceIsBackgroundProvider = Provider<bool>((ref) {
  return ref.watch(audioSpaceControllerProvider).isInBackground;
});

final audioSpaceParticipantsProvider = Provider<List<AudioSpaceParticipant>>((ref) {
  return ref.watch(audioSpaceControllerProvider).participants;
});

final audioSpaceMessagesProvider = Provider<List<AudioSpaceChatMessage>>((ref) {
  return ref.watch(audioSpaceControllerProvider).messages;
});

// ════════════════════════════════════════════════════════════════════════
// CONTROLLER
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceController extends StateNotifier<AudioSpaceManagerState> {
  AudioSpaceController(this._manager) : super(AudioSpaceManagerState.initial) {
    // Miroir du state du manager
    _sub = _manager.stream.listen((s) {
      if (!mounted) return;
      state = s;
    });
  }

  final AudioSpaceManager _manager;
  StreamSubscription<AudioSpaceManagerState>? _sub;

  // ─────────────────────────────────────────────────────────────
  // GETTERS (compatibilité UI)
  // ─────────────────────────────────────────────────────────────
  AudioSpace? get space => state.space;
  AudioSpaceParticipant? get me => state.me;
  List<AudioSpaceParticipant> get participants => state.participants;
  List<AudioSpaceChatMessage> get messages => state.messages;
  bool get isActive => state.isActive;
  bool get isHost => state.isHost;
  bool get isInBackground => state.isInBackground;
  bool get isLoading => state.status == ManagerStatus.joining;
  bool get isError => state.status == ManagerStatus.error;
  String? get errorMessage => state.errorMessage;

  /// Durée écoulée formatée (HH:MM:SS ou MM:SS)
  String get elapsedFormatted {
    final d = state.elapsed;
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  bool canSpeak(AudioSpaceParticipant p) {
    return p.role == AudioSpaceRole.host ||
        p.role == AudioSpaceRole.cohost ||
        p.role == AudioSpaceRole.speaker;
  }

  /// Nom de l'hôte (pour le partage)
  String? get hostName {
    for (final p in state.participants) {
      if (p.role == AudioSpaceRole.host) return p.displayName;
    }
    return state.me?.displayName;
  }

  // ─────────────────────────────────────────────────────────────
  // CYCLE DE VIE
  // ─────────────────────────────────────────────────────────────
  Future<void> join({
    required AudioSpace space,
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) {
    return _manager.join(
      space: space,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
    );
  }

  Future<void> leave() => _manager.leave();

  Future<void> endSpace() => _manager.endSpace();

  // ─────────────────────────────────────────────────────────────
  // ACTIONS PARTICIPANT
  // ─────────────────────────────────────────────────────────────
  Future<void> sendChat(String text) => _manager.sendChat(text);

  Future<void> sendReaction(String emoji) => _manager.sendReaction(emoji);

  Future<void> toggleMute() => _manager.toggleMute();

  Future<void> toggleHandRaise() => _manager.toggleHandRaise();

  // ─────────────────────────────────────────────────────────────
  // ACTIONS HÔTE
  // ─────────────────────────────────────────────────────────────
  Future<void> promoteToSpeaker(AudioSpaceParticipant p) =>
      _manager.promoteToSpeaker(p);

  Future<void> demoteToListener(dynamic target) => _manager.demoteToListener(target);

  Future<void> kick(dynamic target) => _manager.kick(target);

  Future<void> hostMute(String userId, bool muted) =>
      _manager.hostMute(userId, muted);

  Future<void> hostMuteAll() => _manager.hostMuteAll();

  Future<void> acceptHandRaise(AudioSpaceParticipant p) =>
      _manager.acceptHandRaise(p);

  // ─────────────────────────────────────────────────────────────
  // PARTAGE + INVITATIONS
  // ─────────────────────────────────────────────────────────────
  final AudioSpaceShareService _share = AudioSpaceShareService.instance;

  /// Partager vers une plateforme
  Future<void> shareTo(ShareTarget target) async {
    final s = state;
    if (s.space == null) return;
    await _share.share(
      space: s.space!,
      target: target,
      listeners: s.participants.length,
      hostName: hostName,
    );
  }

  /// Copier le lien
  Future<void> copyLink() => shareTo(ShareTarget.copy);

  /// Lien du space (pour QR / affichage)
  String? get shareLink => state.space != null ? _share.buildLink(state.space!) : null;

  /// Inviter des contacts THIX
  Future<void> inviteUsers(List<String> userIds) async {
    final s = state;
    if (s.space == null || userIds.isEmpty) return;
    await _share.inviteUsers(
      space: s.space!,
      userIds: userIds,
      inviterName: s.me?.displayName ?? 'Hôte',
    );
  }

  /// Contacts invitables
  Future<List<Map<String, dynamic>>> getInvitableContacts(String userId) {
    return _share.getInvitableContacts(userId);
  }

  // ─────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════
// DEEP LINKS — rejoindre un space en 1 tap
// ════════════════════════════════════════════════════════════════════════
/// À appeler une fois au démarrage (main.dart ou widget racine).
/// Écoute les liens `thix://space/{id}` et `https://thix.id/space/{id}`.
void initAudioSpaceDeepLinks(Ref ref) {
  AudioSpaceDeepLinkHandler.instance.spaceLinks.listen((spaceId) async {
    debugPrint('[DeepLink] Rejoindre space → $spaceId');
    // 1. Charger le space depuis Supabase (à adapter selon ton service)
    // final space = await ref.read(audioSpaceServiceProvider).getSpaceById(spaceId);
    // 2. Rejoindre
    // if (space != null) {
    //   await ref.read(audioSpaceControllerProvider.notifier).join(
    //         space: space,
    //         displayName: '...',
    //       );
    // }
  });
}
