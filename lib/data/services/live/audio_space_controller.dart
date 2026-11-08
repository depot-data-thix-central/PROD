// lib/data/services/live/audio_space_controller.dart
//
// ============================================================================
// 🎙️ AUDIO SPACE CONTROLLER — miroir Riverpod du AudioSpaceManager (v3)
// ============================================================================
// Ne possède plus de moteur : tout passe par le manager (singleton).
// Le fermer ne coupe pas le salon.
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_manager.dart';

class AudioSpaceController extends StateNotifier<AudioSpaceManagerState> {
  AudioSpaceController() : super(AudioSpaceManager.instance.state) {
    _sub = _m.stream.listen((s) {
      if (mounted) state = s;
    });
  }

  StreamSubscription<AudioSpaceManagerState>? _sub;

  AudioSpaceManager get _m => AudioSpaceManager.instance;

  // ── Infos ──
  String get myId => _m.myId;
  bool get isHost => _m.isHost;
  bool get canModerate => _m.canModerate;
  bool canSpeak(AudioSpaceParticipant p) => p.role.canSpeak;
  List<AudioSpaceParticipant> get participants => state.participants;
  String get hostName => state.space?.hostName ?? '';

  // ── Cycle de vie ──
  Future<void> join({
    required AudioSpace space,
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) =>
      _m.join(
        space: space,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
      );

  Future<void> leave() => _m.leave();
  Future<void> endSpace() => _m.endSpace();
  void acknowledge() => _m.reset();

  // ── Participant ──
  Future<void> toggleMute() => _m.toggleMute();
  Future<void> toggleHandRaise() => _m.toggleHandRaise();
  Future<void> sendChat(String text) => _m.sendChat(text);
  Future<void> sendReaction(String emoji) => _m.sendReaction(emoji);

  // ── Modération ──
  Future<void> promoteToSpeaker(AudioSpaceParticipant p) =>
      _m.promoteToSpeaker(p);
  Future<void> promoteToCohost(AudioSpaceParticipant p) =>
      _m.promoteToCohost(p);
  Future<void> demoteToListener(AudioSpaceParticipant p) =>
      _m.demoteToListener(p);
  Future<void> kick(AudioSpaceParticipant p) => _m.kick(p);
  Future<void> hostMute(String userId, bool muted) =>
      _m.hostMute(userId, muted);
  Future<void> hostMuteAll() => _m.hostMuteAll();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final audioSpaceControllerProvider =
    StateNotifierProvider<AudioSpaceController, AudioSpaceManagerState>(
  (ref) => AudioSpaceController(),
);
