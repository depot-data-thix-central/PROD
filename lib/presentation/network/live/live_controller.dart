// lib/presentation/network/live/live_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';

final liveControllerProvider = StateNotifierProvider.autoDispose.family<LiveController, LiveState, LiveSession>(
  (ref, session) {
    return LiveController(session, ref);
  },
);

class LiveController extends StateNotifier<LiveState> {
  final LiveSession session;
  final AutoDisposeStateNotifierProviderRef ref;

  RtcEngine? _engine;
  RealtimeChannel? _realtimeChannel;
  final StreamController<void> _heartController = StreamController<void>.broadcast();
  void Function(String userId, String userName)? onCoHostRequest;

  // Complété par onJoinChannelSuccess, ou par le timeout de secours ci-dessous.
  Completer<void>? _joinCompleter;
  Timer? _joinTimeoutTimer;

  // Empêche un second bootstrap() de démarrer pendant qu'un premier
  // est encore en cours (protection supplémentaire, en plus du retrait
  // de l'auto-bootstrap dans le constructeur ci-dessous).
  bool _isBootstrapping = false;

  LiveController(this.session, this.ref) : super(const LiveState()) {
    ref.onDispose(() {
      _joinTimeoutTimer?.cancel();
      _realtimeChannel?.unsubscribe();
      _engine?.leaveChannel();
      _engine?.release();
      _heartController.close();
    });
    // ⚠️ CORRECTIF : plus d'auto-bootstrap ici. L'ancien code appelait
    // bootstrap() automatiquement via Future.microtask ET l'écran
    // (LiveBroadcastScreen._attachListenersOnce) l'appelait une seconde
    // fois avec les vrais paramètres vidéo/micro. Les deux joinChannel()
    // concurrents sur le même canal provoquaient AgoraRtcException(-17,
    // null) — ERR_JOIN_CHANNEL_REJECTED : rejoindre un canal déjà en
    // cours de connexion. Le déclenchement se fait maintenant
    // uniquement depuis LiveBroadcastScreen._attachListenersOnce(),
    // qui connaît les vraies valeurs initiales choisies dans
    // LivePrepScreen et qui ne s'exécute qu'une seule fois grâce à son
    // propre flag _listenersAttached.
  }

  RtcEngine? get engine => _engine;
  Stream<void> get heartStream => _heartController.stream;

  LiveService get _service => ref.read(liveServiceProvider);

  Future<void> bootstrap({
    bool initialVideoEnabled = true,
    bool initialMicEnabled = true,
  }) async {
    // Filet de sécurité supplémentaire : si bootstrap() est appelé alors
    // qu'une tentative est déjà en cours, on ignore l'appel au lieu de
    // laisser deux joinChannel() se percuter.
    if (_isBootstrapping) {
      debugPrint('bootstrap() déjà en cours — appel ignoré.');
      return;
    }
    _isBootstrapping = true;

    _joinTimeoutTimer?.cancel();

    state = state.copyWith(
      status: LiveScreenStatus.loading,
      errorMessage: null,
      isVideoOff: !initialVideoEnabled,
      isMuted: !initialMicEnabled,
    );

    try {
      if (!kIsWeb) {
        final statuses = await [Permission.camera, Permission.microphone].request();
        final camOk = statuses[Permission.camera]?.isGranted ?? true;
        final micOk = statuses[Permission.microphone]?.isGranted ?? true;
        if (!camOk || !micOk) {
          state = state.copyWith(status: LiveScreenStatus.permissionDenied);
          return;
        }
      }

      AgoraCredentials credentials;
      try {
        credentials = await _service.fetchAgoraCredentials(session.channelName)
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        _fail("Délai dépassé lors de la récupération du token Agora. Vérifiez votre connexion.");
        return;
      } catch (e) {
        _fail("Impossible de récupérer les identifiants du direct : $e");
        return;
      }

      if (credentials.appId.isEmpty) {
        _fail("Configuration Agora invalide : App ID manquant côté serveur.");
        return;
      }

      try {
        // Si un ancien moteur existe déjà (retry manuel via le bouton
        // "Réessayer"), on le libère proprement d'abord — c'est ce qui
        // évite aussi un -17 en cas de nouvelle tentative après échec.
        if (_engine != null) {
          try {
            await _engine!.leaveChannel();
            await _engine!.release();
          } catch (_) {}
          _engine = null;
        }

        final engine = createAgoraRtcEngine();
        await engine.initialize(RtcEngineContext(
          appId: credentials.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));

        if (!state.isVideoOff) {
          await engine.enableVideo();
          await engine.startPreview();
        }

        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

        _joinCompleter = Completer<void>();

        engine.registerEventHandler(
          RtcEngineEventHandler(
            onJoinChannelSuccess: (connection, elapsed) {
              debugPrint('Agora: canal rejoint avec succès (uid=${connection.localUid})');
              if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
                _joinCompleter!.complete();
              }
            },
            onUserJoined: (connection, remoteUid, elapsed) {
              if (!state.coHostUids.contains(remoteUid)) {
                state = state.copyWith(coHostUids: [...state.coHostUids, remoteUid]);
              }
            },
            onUserOffline: (connection, remoteUid, reason) {
              state = state.copyWith(
                coHostUids: state.coHostUids.where((id) => id != remoteUid).toList(),
              );
            },
            onError: (err, msg) {
              debugPrint('Agora onError: $err - $msg');
              if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
                _joinCompleter!.completeError(_mapAgoraError(err, msg));
              } else if (state.status == LiveScreenStatus.ready) {
                debugPrint('Agora erreur en direct (non bloquante): $msg');
              }
            },
            onConnectionStateChanged: (connection, connState, reason) {
              debugPrint('Agora état connexion: $connState / raison: $reason');
              if (connState == ConnectionStateType.connectionStateFailed) {
                if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
                  _joinCompleter!.completeError(_mapConnectionFailure(reason));
                }
              }
            },
          ),
        );

        await engine.joinChannel(
          token: credentials.token,
          channelId: session.channelName,
          uid: 0,
          options: ChannelMediaOptions(
            publishCameraTrack: !state.isVideoOff,
            publishMicrophoneTrack: !state.isMuted,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );

        _engine = engine;

        // ── On attend la CONFIRMATION réelle de connexion
        // (onJoinChannelSuccess) avant de passer l'écran à "ready".
        await _joinCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception(
                "Connexion au direct impossible (délai dépassé). Vérifiez votre réseau ou réessayez.");
          },
        );

        state = state.copyWith(status: LiveScreenStatus.ready);
        _initRealtime();
      } catch (e) {
        debugPrint('Erreur Agora: $e');
        try {
          await _engine?.leaveChannel();
          await _engine?.release();
        } catch (_) {}
        _engine = null;
        _fail(e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
      }
    } finally {
      _isBootstrapping = false;
    }
  }

  /// Traduit les codes d'erreur Agora les plus courants en messages
  /// compréhensibles au lieu du générique "Inconnue".
  Exception _mapAgoraError(ErrorCodeType err, String msg) {
    switch (err) {
      case ErrorCodeType.errInvalidAppId:
        return Exception("App ID Agora invalide. Vérifiez la configuration côté serveur.");
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
        return Exception("Token Agora invalide ou expiré. Réessayez dans un instant.");
      case ErrorCodeType.errInvalidChannelName:
        return Exception("Nom de canal invalide.");
      case ErrorCodeType.errNoServerResources:
        return Exception("Serveurs Agora indisponibles pour le moment. Réessayez plus tard.");
      case ErrorCodeType.errJoinChannelRejected:
        return Exception("Connexion déjà en cours sur ce direct. Réessayez dans un instant.");
      default:
        return Exception("Erreur Agora ($err) : $msg");
    }
  }

  Exception _mapConnectionFailure(ConnectionChangedReasonType reason) {
    switch (reason) {
      case ConnectionChangedReasonType.connectionChangedInvalidToken:
        return Exception("Token de connexion invalide.");
      case ConnectionChangedReasonType.connectionChangedInvalidAppId:
        return Exception("App ID invalide.");
      case ConnectionChangedReasonType.connectionChangedInvalidChannelName:
        return Exception("Nom de canal invalide.");
      case ConnectionChangedReasonType.connectionChangedRejectedByServer:
        return Exception("Connexion refusée par le serveur Agora.");
      default:
        return Exception("Échec de connexion au direct ($reason).");
    }
  }

  void _fail(String message) {
    _joinTimeoutTimer?.cancel();
    state = state.copyWith(status: LiveScreenStatus.error, errorMessage: message);
  }

  void _initRealtime() {
    try {
      _realtimeChannel = _service.openRealtimeChannel(
        liveId: session.id,
        onChat: (comment) {
          state = state.copyWith(comments: [...state.comments, comment]);
        },
        onHeart: () => _heartController.add(null),
        onCoHostRequest: (userId, userName) => onCoHostRequest?.call(userId, userName),
        onPresenceSync: (count) {
          state = state.copyWith(viewerCount: count);
        },
      );
    } catch (e) {
      // Le direct vidéo fonctionne déjà (status = ready) — on ne fait pas
      // échouer tout l'écran si seul le chat temps réel a un souci.
      debugPrint('Erreur initRealtime (non bloquante): $e');
    }
  }

  // ─── Actions ───
  void sendComment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _realtimeChannel == null) return;

    final comment = LiveComment(
      userId: _service.currentUserId,
      userName: session.hostName,
      text: trimmed,
    );
    _service.sendChatMessage(_realtimeChannel!, comment);
    state = state.copyWith(comments: [...state.comments, comment]);
  }

  void triggerHeart() => _heartController.add(null);

  void respondToCoHost(String targetUserId, bool accepted) {
    if (_realtimeChannel == null) return;
    _service.respondToCoHost(_realtimeChannel!, targetUserId, accepted);
  }

  Future<void> toggleVideo() async {
    state = state.copyWith(isVideoOff: !state.isVideoOff);
    if (state.isVideoOff) {
      await _engine?.disableVideo();
    } else {
      await _engine?.enableVideo();
    }
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    _engine?.muteLocalAudioStream(state.isMuted);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  Future<void> toggleBeauty() async {
    state = state.copyWith(isBeautyEnabled: !state.isBeautyEnabled);
    await _engine?.setBeautyEffectOptions(
      enabled: state.isBeautyEnabled,
      options: const BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.7,
        smoothnessLevel: 0.5,
        rednessLevel: 0.1,
      ),
    );
  }

  Future<void> endBroadcast() async {
    if (state.isEnding) return;
    state = state.copyWith(isEnding: true);

    try {
      await _service.endLiveSession(session.id);
    } catch (e) {
      debugPrint('Erreur suppression session: $e');
    }
    try {
      await _realtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('Erreur unsubscribe: $e');
    }
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
      }
    } catch (e) {
      debugPrint('Erreur fermeture Agora: $e');
    }
  }
}
