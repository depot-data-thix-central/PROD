// lib/presentation/network/live/live_viewer_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ L'IMPORT MANQUANT EST ICI
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';

enum ViewerStatus { loading, ready, hostOffline, error }

class LiveViewerState {
  final ViewerStatus status;
  final String? errorMessage;
  final int? hostUid;
  final bool isHostVideoOff;
  final List<LiveComment> comments;
  final int viewerCount;

  const LiveViewerState({
    this.status = ViewerStatus.loading,
    this.errorMessage,
    this.hostUid,
    this.isHostVideoOff = false,
    this.comments = const [],
    this.viewerCount = 0,
  });

  LiveViewerState copyWith({
    ViewerStatus? status,
    String? errorMessage,
    int? hostUid,
    bool? isHostVideoOff,
    List<LiveComment>? comments,
    int? viewerCount,
  }) {
    return LiveViewerState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      hostUid: hostUid ?? this.hostUid,
      isHostVideoOff: isHostVideoOff ?? this.isHostVideoOff,
      comments: comments ?? this.comments,
      viewerCount: viewerCount ?? this.viewerCount,
    );
  }
}

final liveViewerControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveViewerController, LiveViewerState, LiveSession>(
  (ref, session) => LiveViewerController(session, ref),
);

class LiveViewerController extends StateNotifier<LiveViewerState> {
  final LiveSession session;
  final AutoDisposeStateNotifierProviderRef ref;

  RtcEngine? _engine;
  RealtimeChannel? _realtimeChannel;
  Completer<void>? _joinCompleter;

  LiveViewerController(this.session, this.ref) : super(const LiveViewerState()) {
    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _engine?.leaveChannel();
      _engine?.release();
    });
    Future.microtask(() => bootstrap());
  }

  RtcEngine? get engine => _engine;
  LiveService get _service => ref.read(liveServiceProvider);

  Future<void> bootstrap() async {
    state = state.copyWith(status: ViewerStatus.loading, errorMessage: null);

    // ── Aucune permission caméra/micro demandée : un spectateur ne
    // publie rien. Demander ces permissions ici serait injustifié aux
    // yeux des règles App Store / Play Store (Guideline 5.1.1 / accès
    // sans usage réel), en plus d'une mauvaise expérience utilisateur.

    AgoraCredentials credentials;
    try {
      credentials = await _service
          .fetchAgoraCredentials(session.channelName) // ✅ PARAMÈTRE 'role' EN TROP SUPPRIMÉ
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _fail("Délai dépassé lors de la connexion au direct.");
      return;
    } catch (e) {
      _fail("Impossible de rejoindre le direct : $e");
      return;
    }

    if (credentials.appId.isEmpty) {
      _fail("Configuration Agora invalide.");
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(
        appId: credentials.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Rôle AUDIENCE : ne publie ni caméra ni micro, reçoit uniquement.
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);

      _joinCompleter = Completer<void>();

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
              _joinCompleter!.complete();
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (state.hostUid == null) {
              state = state.copyWith(hostUid: remoteUid);
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (state.hostUid == remoteUid) {
              state = state.copyWith(status: ViewerStatus.hostOffline, hostUid: null);
            }
          },
          onRemoteVideoStateChanged: (connection, remoteUid, videoState, reason, elapsed) {
            if (remoteUid == state.hostUid) {
              final isOff = videoState == RemoteVideoState.remoteVideoStateStopped;
              state = state.copyWith(isHostVideoOff: isOff);
            }
          },
          onError: (err, msg) {
            debugPrint('Agora viewer onError: $err - $msg');
            if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
              _joinCompleter!.completeError(Exception("Erreur Agora ($err) : $msg"));
            }
          },
          onConnectionStateChanged: (connection, connState, reason) {
            if (connState == ConnectionStateType.connectionStateFailed) {
              if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
                _joinCompleter!.completeError(Exception("Échec de connexion au direct ($reason)."));
              }
            }
          },
        ),
      );

      await engine.joinChannel(
        token: credentials.token,
        channelId: session.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );

      _engine = engine;

      await _joinCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Connexion au direct impossible (délai dépassé).");
        },
      );

      state = state.copyWith(status: ViewerStatus.ready);
      _initRealtime();
    } catch (e) {
      debugPrint('Erreur Agora viewer: $e');
      try {
        await _engine?.leaveChannel();
        await _engine?.release();
      } catch (_) {}
      _engine = null;
      _fail(e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
    }
  }

  void _fail(String message) {
    state = state.copyWith(status: ViewerStatus.error, errorMessage: message);
  }

  void _initRealtime() {
    try {
      _realtimeChannel = _service.openRealtimeChannel(
        liveId: session.id,
        onChat: (comment) {
          state = state.copyWith(comments: [...state.comments, comment]);
        },
        onHeart: () {}, // le spectateur reçoit les cœurs mais n'a pas d'animation propre ici
        onCoHostRequest: (userId, userName) {}, // sans objet côté spectateur
        onPresenceSync: (count) {
          state = state.copyWith(viewerCount: count);
        },
      );
    } catch (e) {
      debugPrint('Erreur initRealtime viewer (non bloquante): $e');
    }
  }

  void sendComment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _realtimeChannel == null) return;

    final comment = LiveComment(
      userId: _service.currentUserId,
      userName: 'Spectateur', // remplace par le pseudo réel de l'utilisateur connecté
      text: trimmed,
    );
    _service.sendChatMessage(_realtimeChannel!, comment);
    state = state.copyWith(comments: [...state.comments, comment]);
  }

  Future<void> leaveLive() async {
    try {
      await _realtimeChannel?.unsubscribe();
    } catch (_) {}
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
  }
}
