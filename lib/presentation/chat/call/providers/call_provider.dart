// lib/presentation/chat/call/providers/call_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../models/chat/call_invite.dart';
import '../../../../models/chat/call_status.dart';
import '../../../../services/chat/call_service.dart';
import '../../../../services/chat/call_signaling_service.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

class CallState {
  final CallStatus status;
  final CallType type;
  final String? inviteId;
  final String? channelName;
  final String? remoteUserId;
  final String? remoteName;
  final String? remoteAvatar;
  final int? remoteUid;
  final bool muted;
  final bool videoOff;
  final bool speakerOn;
  final bool isFrontCam;
  final bool isCaller;
  final Duration duration;
  final String? error;
  final String? conversationId;

  const CallState({
    this.status = CallStatus.idle,
    this.type = CallType.audio,
    this.inviteId,
    this.channelName,
    this.remoteUserId,
    this.remoteName,
    this.remoteAvatar,
    this.remoteUid,
    this.muted = false,
    this.videoOff = false,
    this.speakerOn = true,
    this.isFrontCam = true,
    this.isCaller = true,
    this.duration = Duration.zero,
    this.error,
    this.conversationId,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? type,
    String? inviteId,
    String? channelName,
    String? remoteUserId,
    String? remoteName,
    String? remoteAvatar,
    int? remoteUid,
    bool? muted,
    bool? videoOff,
    bool? speakerOn,
    bool? isFrontCam,
    bool? isCaller,
    Duration? duration,
    String? error,
    bool clearError = false,
    String? conversationId,
  }) {
    return CallState(
      status: status ?? this.status,
      type: type ?? this.type,
      inviteId: inviteId ?? this.inviteId,
      channelName: channelName ?? this.channelName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteName: remoteName ?? this.remoteName,
      remoteAvatar: remoteAvatar ?? this.remoteAvatar,
      remoteUid: remoteUid ?? this.remoteUid,
      muted: muted ?? this.muted,
      videoOff: videoOff ?? this.videoOff,
      speakerOn: speakerOn ?? this.speakerOn,
      isFrontCam: isFrontCam ?? this.isFrontCam,
      isCaller: isCaller ?? this.isCaller,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
      conversationId: conversationId ?? this.conversationId,
    );
  }

  bool get isVideo => type == CallType.video;
  bool get isActive =>
      status == CallStatus.ringing ||
      status == CallStatus.accepted ||
      status == CallStatus.ongoing;
}

class CallNotifier extends StateNotifier<CallState> {
  final _media = CallMediaService();
  final _signal = CallSignalingService();
  final Ref ref;

  final AudioPlayer _ringPlayer = AudioPlayer();

  Timer? _timer;
  Timer? _ringTimeout;
  StreamSubscription? _statusSub;

  CallNotifier(this.ref) : super(const CallState());

  // ─── SONS ──────────────────────────────────────────────────────────────────

  Future<void> _playRingtone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('Erreur lecture sonnerie: $e');
    }
  }

  Future<void> _playOfflineTone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.release);
      await _ringPlayer.play(AssetSource('sounds/offline.mp3'));
    } catch (e) {
      debugPrint('Erreur lecture son hors-ligne: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {}
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  int _uidFrom(String userId) {
    var hash = 0x811c9dc5;
    for (final c in userId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }

  Future<String?> _getOrCreateConversationId(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final db = Supabase.instance.client;
      final res = await db
          .from('conversations')
          .select('id')
          .contains('participant_ids', [currentUserId, otherUserId])
          .eq('is_group', false)
          .maybeSingle();

      if (res != null) {
        return res['id'] as String;
      } else {
        final newConv = await db.from('conversations').insert({
          'participant_ids': [currentUserId, otherUserId],
          'is_group': false,
        }).select('id').single();
        return newConv['id'] as String;
      }
    } catch (e) {
      debugPrint('_getOrCreateConversationId: $e');
      return null;
    }
  }

  /// Marque l'appel en échec + log visible dans la console
  void _fail(String where, Object e) {
    final msg = '$e';
    debugPrint('❌ CALL FAIL [$where]: $msg');
    state = state.copyWith(status: CallStatus.failed, error: msg);
  }

  // ─── CALLER ────────────────────────────────────────────────────────────────

  Future<void> start({
    required String myUserId,
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
    String? conversationId,
  }) async {
    try {
      final convId =
          conversationId ?? await _getOrCreateConversationId(myUserId, calleeId);

      state = state.copyWith(
        status: CallStatus.ringing,
        type: type,
        isCaller: true,
        remoteUserId: calleeId,
        remoteName: calleeName,
        remoteAvatar: calleeAvatar,
        conversationId: convId,
        clearError: true,
      );

      final invite = await _signal.startCall(calleeId: calleeId, type: type);

      if (invite.status == CallStatus.busy) {
        state = state.copyWith(status: CallStatus.busy, error: 'Occupé');
        _playOfflineTone();
        Future.delayed(const Duration(seconds: 3), () => hangUp(skipSignal: true));
        return;
      }

      if (invite.channelName.isEmpty) {
        _fail('start', 'channel_name vide après rpc_start_call');
        _playOfflineTone();
        Future.delayed(const Duration(seconds: 2), () => hangUp(skipSignal: true));
        return;
      }

      state = state.copyWith(
        inviteId: invite.id,
        channelName: invite.channelName,
      );

      _playRingtone();

      _ringTimeout?.cancel();
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (state.status == CallStatus.ringing && state.inviteId != null) {
          await _signal.markMissed(state.inviteId!);
          await hangUp();
        }
      });

      _statusSub?.cancel();
      _statusSub = _signal.watchInviteStatus(invite.id).listen((s) async {
        if (s == CallStatus.accepted || s == CallStatus.ongoing) {
          _ringTimeout?.cancel();
          _stopRingtone();
          await _joinAgora(myUserId);
        } else if (s == CallStatus.rejected || s == CallStatus.canceled) {
          _stopRingtone();
          _playOfflineTone();
          Future.delayed(const Duration(seconds: 2), () => hangUp(skipSignal: true));
        } else if (s.isFinished) {
          await hangUp(skipSignal: true);
        }
      });
    } catch (e) {
      _fail('start', e);
      _playOfflineTone();
      Future.delayed(const Duration(seconds: 2), () => hangUp(skipSignal: true));
    }
  }

  // ─── CALLEE ────────────────────────────────────────────────────────────────

  Future<void> acceptIncoming({
    required CallInvite invite,
    required String myUserId,
    String? callerName,
    String? callerAvatar,
  }) async {
    try {
      debugPrint(
        '📞 acceptIncoming id=\( {invite.id} channel= \){invite.channelName} caller=${invite.callerId}',
      );

      if (invite.channelName.trim().isEmpty) {
        _fail('acceptIncoming', 'channel_name manquant sur l’invite');
        return;
      }

      final convId =
          await _getOrCreateConversationId(myUserId, invite.callerId);

      state = state.copyWith(
        status: CallStatus.accepted,
        type: invite.callType,
        isCaller: false,
        inviteId: invite.id,
        channelName: invite.channelName,
        remoteUserId: invite.callerId,
        remoteName: callerName ?? invite.callerName,
        remoteAvatar: callerAvatar ?? invite.callerAvatar,
        conversationId: convId,
        clearError: true,
      );

      _stopRingtone();
      await _signal.accept(invite.id);
      await _joinAgora(myUserId);
    } catch (e) {
      _fail('acceptIncoming', e);
    }
  }

  Future<void> rejectIncoming(String inviteId) async {
    _stopRingtone();
    try {
      await _signal.reject(inviteId);
    } catch (e) {
      debugPrint('rejectIncoming: $e');
    }
    state = const CallState();
  }

  // ─── AGORA ─────────────────────────────────────────────────────────────────

  Future<void> _joinAgora(String myUserId) async {
    final channel = state.channelName?.trim();
    final inviteId = state.inviteId;

    debugPrint(
      '📞 _joinAgora channel=\( channel uid= \){_uidFrom(myUserId)} type=${state.type}',
    );

    if (channel == null || channel.isEmpty) {
      _fail('_joinAgora', 'channel_name vide — impossible de joindre Agora');
      return;
    }

    try {
      final uid = _uidFrom(myUserId);

      await _media.join(
        channel: channel,
        type: state.type,
        uid: uid,
        onUserJoined: (remoteUid) async {
          debugPrint('📞 remote joined uid=$remoteUid');
          state = state.copyWith(
            remoteUid: remoteUid,
            status: CallStatus.ongoing,
          );
          if (inviteId != null) {
            try {
              await _signal.markOngoing(inviteId);
            } catch (e) {
              debugPrint('markOngoing: $e');
            }
          }
          _startTimer();
        },
        onUserLeft: (_) async {
          _playOfflineTone();
          Future.delayed(const Duration(seconds: 1), () => hangUp());
        },
        onError: (err) {
          // Erreur Agora runtime (token invalide, etc.)
          debugPrint('❌ Agora onError: $err');
          state = state.copyWith(
            status: CallStatus.failed,
            error: err,
          );
        },
      );

      // Join local OK → on passe en ongoing même si remote pas encore là
      if (state.status == CallStatus.accepted) {
        state = state.copyWith(status: CallStatus.ongoing);
        _startTimer();
      }
    } catch (e, st) {
      debugPrint('❌ _joinAgora exception: $e\n$st');
      // Messages typiques : token, micro, caméra, network
      _fail('_joinAgora', e);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(duration: DateTime.now().difference(start));
    });
  }

  // ─── CONTROLES ─────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _media.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleVideo() async {
    final next = !state.videoOff;
    await _media.setVideoOff(next);
    state = state.copyWith(videoOff: next);
  }

  Future<void> switchCamera() async {
    await _media.switchCamera();
    state = state.copyWith(isFrontCam: !state.isFrontCam);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await _media.setSpeaker(next);
    state = state.copyWith(speakerOn: next);
  }

  // ─── HANG UP ───────────────────────────────────────────────────────────────

  Future<void> hangUp({bool skipSignal = false}) async {
    _stopRingtone();

    final inviteId = state.inviteId;
    final secs = state.duration.inSeconds;
    final wasCaller = state.isCaller;
    final wasRinging = state.status == CallStatus.ringing;
    final convId = state.conversationId;
    final isVideoCall = state.isVideo;
    final duration = state.duration;

    _timer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();

    await _media.disposeEngine();

    if (!skipSignal && inviteId != null) {
      try {
        if (wasRinging && wasCaller) {
          await _signal.cancel(inviteId);
        } else {
          await _signal.end(inviteId, durationSec: secs);
        }
      } catch (_) {}
    }

    if (convId != null && convId.isNotEmpty) {
      try {
        final chatSvc = ref.read(chatServiceProvider);
        final isMissed = duration.inSeconds == 0;
        final mediaTypeStr = isVideoCall ? 'call_video' : 'call_audio';
        final textType = isVideoCall ? 'Appel vidéo' : 'Appel audio';

        final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
        final h = duration.inHours;
        final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';
        final textDuration = isMissed ? 'manqué' : '($timeStr)';
        final content = '$textType $textDuration';

        if (wasCaller) {
          await chatSvc.sendMessage(
            conversationId: convId,
            content: content,
            mediaType: mediaTypeStr,
          );
        }
      } catch (e) {
        debugPrint('Erreur sauvegarde historique appel dans chat: $e');
      }
    }

    state = const CallState();
  }

  @override
  void dispose() {
    _stopRingtone();
    _ringPlayer.dispose();
    _timer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();
    _media.disposeEngine();
    _signal.dispose();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(ref);
});
