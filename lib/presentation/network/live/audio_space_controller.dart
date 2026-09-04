import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';

const Duration _kJoinTimeout = Duration(seconds: 10);
const int _kMaxChatMemory = 120;

final audioSpaceControllerProvider = StateNotifierProvider.autoDispose
    .family<AudioSpaceController, AudioSpaceState, AudioSpace>(
  (ref, space) => AudioSpaceController(space, ref),
);

class AudioSpaceController extends StateNotifier<AudioSpaceState> {
  final AudioSpace space;
  final AutoDisposeStateNotifierProviderRef ref;

  RtcEngine? _engine;
  RealtimeChannel? _channel;
  bool _disposed = false;
  bool _bootstrapping = false;
  DateTime? _lastRaiseAt;

  AudioSpaceController(this.space, this.ref) : super(const AudioSpaceState()) {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_cleanup());
    });
  }

  AudioSpaceService get _service => ref.read(audioSpaceServiceProvider);

  bool get isHost => _service.currentUserId == space.hostId;
  bool get canSpeak {
    final role = state.myRole;
    return !state.isMuted &&
        (role == AudioSpaceRole.host ||
            role == AudioSpaceRole.cohost ||
            role == AudioSpaceRole.speaker);
  }

  Future<void> bootstrap({
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) async {
    if (_disposed || _bootstrapping) return;
    _bootstrapping = true;
    state = state.copyWith(status: AudioSpaceScreenStatus.loading, errorMessage: null);

    try {
      if (!kIsWeb) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          state = state.copyWith(status: AudioSpaceScreenStatus.permissionDenied);
          return;
        }
      }

      final me = await _service.joinSpace(
        space,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: isHost ? AudioSpaceRole.host : AudioSpaceRole.listener,
        isMuted: !isHost,
        isVerified: isVerified,
      );

      final creds = await _service.fetchCredentials(space.channelName);
      await _startAgora(creds, publishMic: isHost && !me.isMuted);

      _channel = _service.openChannel(
        spaceId: space.id,
        onChat: _onChat,
        onEnded: () {
          if (!_disposed) {
            state = state.copyWith(
              status: AudioSpaceScreenStatus.error,
              errorMessage: 'Le salon a été clôturé.',
            );
          }
        },
        onRosterChanged: () => unawaited(refreshRoster()),
        onForceMute: (target, muted) async {
          if (target == _service.currentUserId) {
            await _engine?.muteLocalAudioStream(muted);
            if (!_disposed) state = state.copyWith(isMuted: muted);
          }
        },
        onRoleChanged: (target, role) async {
          if (target != _service.currentUserId) {
            unawaited(refreshRoster());
            return;
          }
          final parsed = _parseRole(role);
          final speak = parsed == AudioSpaceRole.host ||
              parsed == AudioSpaceRole.cohost ||
              parsed == AudioSpaceRole.speaker;
          await _applySpeakRole(speak);
          if (!_disposed) state = state.copyWith(myRole: parsed, isMuted: !speak);
          unawaited(refreshRoster());
        },
        onBanned: (target) {
          if (target == _service.currentUserId && !_disposed) {
            state = state.copyWith(status: AudioSpaceScreenStatus.banned);
            unawaited(_cleanup());
          }
        },
      );

      await refreshRoster();
      if (!_disposed) {
        state = state.copyWith(
          status: AudioSpaceScreenStatus.ready,
          myRole: me.role,
          isMuted: me.isMuted,
        );
      }
    } catch (e) {
      debugPrint('[AudioSpace] bootstrap error: $e');
      if (!_disposed) {
        state = state.copyWith(
          status: AudioSpaceScreenStatus.error,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      _bootstrapping = false;
    }
  }

  Future<void> refreshRoster() async {
    try {
      final list = await _service.listActiveParticipants(space.id);
      if (_disposed) return;
      state = state.copyWith(
        participants: list,
        listenerCount: list.where((p) => p.role == AudioSpaceRole.listener).length,
      );
    } catch (e) {
      debugPrint('[AudioSpace] roster error: $e');
    }
  }

  Future<void> toggleMute() async {
    if (!canSpeak && !isHost) return;
    final next = !state.isMuted;
    await _engine?.muteLocalAudioStream(next);
    await _service.setMuted(
      spaceId: space.id,
      targetUserId: _service.currentUserId,
      muted: next,
    );
    if (!_disposed) state = state.copyWith(isMuted: next);
    await _notifyRoster();
  }

  Future<void> toggleHand() async {
    if (isHost || state.myRole == AudioSpaceRole.speaker || state.myRole == AudioSpaceRole.cohost) {
      return;
    }
    final now = DateTime.now();
    if (_lastRaiseAt != null && now.difference(_lastRaiseAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastRaiseAt = now;
    final next = !state.handRaised;
    await _service.setHandRaised(space.id, next);
    if (!_disposed) state = state.copyWith(handRaised: next);
    await _notifyRoster();
  }

  Future<void> sendChat(String raw, String displayName) async {
    final body = AudioSpaceSanitizer.sanitize(raw, maxLength: 300);
    if (body.isEmpty || _channel == null) return;
    final msg = AudioSpaceChatMessage(
      userId: _service.currentUserId,
      displayName: displayName,
      body: body,
      sentAt: DateTime.now().toUtc(),
    );
    _onChat(msg);
    await _service.broadcast(_channel!, 'chat', {
      'userId': msg.userId,
      'displayName': AudioSpaceSanitizer.sanitize(displayName, maxLength: 50),
      'body': body,
      'sentAt': msg.sentAt.toIso8601String(),
    });
    unawaited(_service.persistChat(spaceId: space.id, displayName: displayName, body: body));
  }

  Future<void> promote(AudioSpaceParticipant p) async {
    if (!isHost && state.myRole != AudioSpaceRole.cohost) return;
    await _service.promoteToSpeaker(
      space: space,
      targetUserId: p.userId,
      targetVerified: p.isVerified,
    );
    await _service.broadcast(_channel!, 'role', {
      'targetUserId': p.userId,
      'role': 'speaker',
    });
    await _notifyRoster();
  }

  Future<void> demote(AudioSpaceParticipant p) async {
    if (!isHost && state.myRole != AudioSpaceRole.cohost) return;
    if (p.role == AudioSpaceRole.host) return;
    await _service.demoteToListener(spaceId: space.id, targetUserId: p.userId);
    await _service.broadcast(_channel!, 'role', {
      'targetUserId': p.userId,
      'role': 'listener',
    });
    await _service.broadcast(_channel!, 'force_mute', {
      'targetUserId': p.userId,
      'muted': true,
    });
    await _notifyRoster();
  }

  Future<void> kick(AudioSpaceParticipant p) async {
    if (!isHost) return;
    if (p.userId == space.hostId) return;
    await _service.banUser(spaceId: space.id, targetUserId: p.userId);
    await _service.broadcast(_channel!, 'banned', {'targetUserId': p.userId});
    await _notifyRoster();
  }

  Future<void> endSpace() async {
    if (!isHost) return;
    await _service.endSpace(space.id);
    if (_channel != null) {
      await _service.broadcast(_channel!, 'ended', {'spaceId': space.id});
    }
    await _cleanup();
  }

  Future<void> leave() async {
    await _service.leaveSpace(space.id);
    await _notifyRoster();
    await _cleanup();
  }

  void _onChat(AudioSpaceChatMessage msg) {
    if (_disposed) return;
    final next = [...state.messages, msg];
    if (next.length > _kMaxChatMemory) {
      next.removeRange(0, next.length - _kMaxChatMemory);
    }
    state = state.copyWith(messages: next);
  }

  Future<void> _notifyRoster() async {
    if (_channel == null) return;
    await _service.broadcast(_channel!, 'roster', {
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await refreshRoster();
  }

  Future<void> _startAgora(AgoraCredentials credentials, {required bool publishMic}) async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: credentials.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    await engine.enableAudio();
    await engine.disableVideo();
    await engine.setClientRole(
      role: publishMic
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await engine.muteLocalAudioStream(!publishMic);
    await engine.joinChannel(
      token: credentials.token,
      channelId: space.channelName,
      uid: 0,
      options: ChannelMediaOptions(
        publishMicrophoneTrack: publishMic,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
        clientRoleType: publishMic
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      ),
    ).timeout(_kJoinTimeout);
    _engine = engine;
  }

  Future<void> _applySpeakRole(bool speak) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setClientRole(
      role: speak ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
    );
    await engine.muteLocalAudioStream(!speak);
    await engine.updateChannelMediaOptions(ChannelMediaOptions(
      publishMicrophoneTrack: speak,
      clientRoleType: speak
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    ));
  }

  Future<void> _cleanup() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
  }
}

AudioSpaceRole _parseRole(String role) {
  switch (role) {
    case 'host':
      return AudioSpaceRole.host;
    case 'cohost':
      return AudioSpaceRole.cohost;
    case 'speaker':
      return AudioSpaceRole.speaker;
    default:
      return AudioSpaceRole.listener;
  }
}
