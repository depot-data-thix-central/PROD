// lib/presentation/network/live/live_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kCredentialsTimeout = Duration(seconds: 12);
const Duration _kJoinTimeout = Duration(seconds: 10);
const Duration _kCoHostRequestTimeout = Duration(seconds: 30);
const Duration _kViewerDebounce = Duration(milliseconds: 500);
const Duration _kHeartRateLimit = Duration(milliseconds: 100);
const int _kMaxCommentsInMemory = 200;
const int _kMaxCommentLength = 300;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _LiveControllerValidators {
  _LiveControllerValidators._();

  static String sanitize(String? input, {int maxLength = _kMaxCommentLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final liveControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveController, LiveState, LiveSession>(
  (ref, session) => LiveController(session, ref),
);

// ============================================================================
// CONTRÔLEUR
// ============================================================================
class LiveController extends StateNotifier<LiveState> {
  final LiveSession session;
  final AutoDisposeStateNotifierProviderRef ref;

  RtcEngine? _engine;
  RealtimeChannel? _realtimeChannel;
  final StreamController<void> _heartController = StreamController<void>.broadcast();
  final StreamController<void> _viewerUpdateController = StreamController<int>.broadcast();

  void Function(String userId, String userName)? onCoHostRequest;

  Completer<void>? _joinCompleter;
  Timer? _joinTimeoutTimer;
  Timer? _viewerDebounceTimer;
  Timer? _coHostRequestTimer;
  DateTime? _lastHeartTime;

  bool _isBootstrapping = false;
  bool _isDisposed = false;
  bool _realtimeConnected = false;

  LiveController(this.session, this.ref) : super(const LiveState()) {
    debugPrint('[Live] Controller created for session ${session.id}');

    ref.onDispose(() {
      _isDisposed = true;
      _cleanup();
      debugPrint('[Live] Controller disposed for session ${session.id}');
    });
  }

  // ─── GETTERS PUBLICS ───
  RtcEngine? get engine => _engine;
  Stream<void> get heartStream => _heartController.stream;
  bool get isEnding => state.isEnding;
  bool get isReady => state.status == LiveScreenStatus.ready;
  bool get canRetry => state.status == LiveScreenStatus.error || state.status == LiveScreenStatus.permissionDenied;

  LiveService get _service => ref.read(liveServiceProvider);

  // ─── BOOTSTRAP ───
  Future<void> bootstrap({
    bool initialVideoEnabled = true,
    bool initialMicEnabled = true,
  }) async {
    if (_isDisposed) {
      debugPrint('[Live] ⚠️ bootstrap called on disposed controller');
      return;
    }
    if (_isBootstrapping) {
      debugPrint('[Live] ⚠️ bootstrap already in progress — ignored');
      return;
    }

    _isBootstrapping = true;
    _cancelAllTimers();

    state = state.copyWith(
      status: LiveScreenStatus.loading,
      errorMessage: null,
      isVideoOff: !initialVideoEnabled,
      isMuted: !initialMicEnabled,
    );

    try {
      // 1. Vérification permissions (mobile uniquement)
      if (!kIsWeb) {
        final statuses = await [Permission.camera, Permission.microphone].request();
        final camOk = statuses[Permission.camera]?.isGranted ?? true;
        final micOk = statuses[Permission.microphone]?.isGranted ?? true;
        if (!camOk || !micOk) {
          debugPrint('[Live] ⚠️ Permissions denied: camera=$camOk, mic=$micOk');
          state = state.copyWith(status: LiveScreenStatus.permissionDenied);
          return;
        }
      }

      // 2. Récupération credentials Agora
      AgoraCredentials credentials;
      try {
        debugPrint('[Live] Fetching Agora credentials for ${session.channelName}');
        credentials = await _service
            .fetchAgoraCredentials(session.channelName)
            .timeout(_kCredentialsTimeout);
      } on TimeoutException {
        _fail("Délai dépassé lors de la récupération du token Agora. Vérifiez votre connexion.");
        return;
      } catch (e) {
        _fail("Impossible de récupérer les identifiants du direct : $e");
        return;
      }

      if (credentials.appId.isEmpty || credentials.token.isEmpty) {
        _fail("Configuration Agora invalide : App ID ou Token manquant côté serveur.");
        return;
      }
      debugPrint('[Live] ✓ Credentials retrieved (appId=${credentials.appId.substring(0, 8)}...)');

      // 3. Initialisation moteur Agora
      try {
        await _ensureEngineClean();
        final engine = createAgoraRtcEngine();

        await engine.initialize(RtcEngineContext(
          appId: credentials.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));

        if (!state.isVideoOff) {
          await engine.enableVideo();
          await engine.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 720, height: 1280),
              frameRate: 15,
              bitrate: 0,
              orientationMode: OrientationMode.orientationModeAdaptive,
              degradationPreference: DegradationPreference.maintainQuality,
            ),
          );
          await engine.startPreview();
        }

        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

        _joinCompleter = Completer<void>();
        _registerEngineHandlers(engine);

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

        await _joinCompleter!.future.timeout(_kJoinTimeout, onTimeout: () {
          throw TimeoutException("Connexion au direct impossible (délai dépassé).");
        });

        if (_isDisposed) {
          debugPrint('[Live] ⚠️ Controller disposed during join — cleanup');
          await _ensureEngineClean();
          return;
        }

        state = state.copyWith(status: LiveScreenStatus.ready);
        debugPrint('[Live] ✓ Channel joined successfully');

        _initRealtime();
      } catch (e) {
        debugPrint('[Live] ❌ Agora error: $e');
        await _ensureEngineClean();
        _fail(e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
      }
    } finally {
      _isBootstrapping = false;
    }
  }

  void _registerEngineHandlers(RtcEngine engine) {
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[Live] ✓ onJoinChannelSuccess uid=${connection.localUid} elapsed=${elapsed}ms');
          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.complete();
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[Live] 👤 User joined: uid=$remoteUid');
          if (!state.coHostUids.contains(remoteUid)) {
            state = state.copyWith(coHostUids: [...state.coHostUids, remoteUid]);
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Live] 👋 User offline: uid=$remoteUid reason=$reason');
          state = state.copyWith(
            coHostUids: state.coHostUids.where((id) => id != remoteUid).toList(),
          );
        },
        onError: (err, msg) {
          debugPrint('[Live] ❌ onError: $err - $msg');
          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.completeError(_mapAgoraError(err, msg));
          } else if (state.status == LiveScreenStatus.ready) {
            debugPrint('[Live] ⚠️ Non-blocking error during broadcast');
          }
        },
        onConnectionStateChanged: (connection, connState, reason) {
          debugPrint('[Live] 📡 Connection state: $connState / $reason');
          if (connState == ConnectionStateType.connectionStateFailed) {
            if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
              _joinCompleter!.completeError(_mapConnectionFailure(reason));
            }
          }
        },
      ),
    );
  }

  // ─── NETTOYAGE ───
  Future<void> _ensureEngineClean() async {
    try {
      if (_engine != null) {
        try {
          await _engine!.leaveChannel();
        } catch (e) {
          debugPrint('[Live] Cleanup leaveChannel error: $e');
        }
        try {
          await _engine!.release();
        } catch (e) {
          debugPrint('[Live] Cleanup release error: $e');
        }
        _engine = null;
      }
    } catch (e) {
      debugPrint('[Live] Cleanup engine error: $e');
    }

    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.completeError(Exception('Cleanup'));
    }
    _joinCompleter = null;
  }

  void _cancelAllTimers() {
    _joinTimeoutTimer?.cancel();
    _joinTimeoutTimer = null;
    _viewerDebounceTimer?.cancel();
    _viewerDebounceTimer = null;
    _coHostRequestTimer?.cancel();
    _coHostRequestTimer = null;
  }

  void _cleanup() {
    _cancelAllTimers();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[Live] Cleanup realtime error: $e');
    }
    _realtimeChannel = null;
    _realtimeConnected = false;

    // Cleanup engine synchrone (dispose ne doit pas await)
    try {
      _engine?.leaveChannel();
    } catch (_) {}
    try {
      _engine?.release();
    } catch (_) {}
    _engine = null;

    try {
      _heartController.close();
    } catch (_) {}
    try {
      _viewerUpdateController.close();
    } catch (_) {}
  }

  void _fail(String message) {
    debugPrint('[Live] ❌ _fail: $message');
    _cancelAllTimers();
    _ensureEngineClean();
    state = state.copyWith(status: LiveScreenStatus.error, errorMessage: message);
  }

  // ─── ERREURS ───
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
        return Exception("Serveurs Agora indisponibles. Réessayez plus tard.");
      case ErrorCodeType.errJoinChannelRejected:
        return Exception("Connexion déjà en cours sur ce direct.");
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

  // ─── REALTIME ───
  void _initRealtime() {
    try {
      debugPrint('[Live] Initializing Realtime channel for ${session.id}');
      _realtimeChannel = _service.openRealtimeChannel(
        liveId: session.id,
        onChat: (comment) {
          final sanitizedComment = LiveComment(
            userId: comment.userId,
            userName: _LiveControllerValidators.sanitize(comment.userName, maxLength: 50),
            text: _LiveControllerValidators.sanitize(comment.text, maxLength: _kMaxCommentLength),
          );
          _addComment(sanitizedComment);
        },
        onHeart: () => _heartController.add(null),
        onCoHostRequest: (userId, userName) {
          final safeUserName = _LiveControllerValidators.sanitize(userName, maxLength: 50);
          _handleCoHostRequestWithTimeout(userId, safeUserName);
        },
        onPresenceSync: (count) => _updateViewerCount(count),
      );
      _realtimeConnected = true;
      debugPrint('[Live] ✓ Realtime channel initialized');
    } catch (e) {
      debugPrint('[Live] ⚠️ Realtime init error (non-blocking): $e');
    }
  }

  void _addComment(LiveComment comment) {
    final updated = [...state.comments, comment];
    // Limiter le nombre de commentaires en mémoire
    final trimmed = updated.length > _kMaxCommentsInMemory
        ? updated.sublist(updated.length - _kMaxCommentsInMemory)
        : updated;
    state = state.copyWith(comments: trimmed);
  }

  void _updateViewerCount(int count) {
    // Debounce pour éviter les updates trop fréquentes
    _viewerDebounceTimer?.cancel();
    _viewerDebounceTimer = Timer(_kViewerDebounce, () {
      if (!_isDisposed && state.viewerCount != count) {
        state = state.copyWith(viewerCount: count);
      }
    });
  }

  void _handleCoHostRequestWithTimeout(String userId, String userName) {
    // Auto-expire la demande après 30s
    _coHostRequestTimer?.cancel();
    _coHostRequestTimer = Timer(_kCoHostRequestTimeout, () {
      debugPrint('[Live] ⏱️ Co-host request from $userId expired');
    });
    onCoHostRequest?.call(userId, userName);
  }

  // ─── COMMENTAIRES ───
  void sendComment(String text) {
    final sanitized = _LiveControllerValidators.sanitize(text, maxLength: _kMaxCommentLength);
    if (sanitized.isEmpty || _realtimeChannel == null) {
      debugPrint('[Live] ⚠️ sendComment rejected (empty or no channel)');
      return;
    }

    final comment = LiveComment(
      userId: _service.currentUserId,
      userName: session.hostName,
      text: sanitized,
    );

    try {
      _service.sendChatMessage(_realtimeChannel!, comment);
      _addComment(comment);
      debugPrint('[Live] 💬 Comment sent');
    } catch (e) {
      debugPrint('[Live] ❌ sendComment error: $e');
    }
  }

  // ─── HEARTS (rate-limited) ───
  void triggerHeart() {
    final now = DateTime.now();
    if (_lastHeartTime != null && now.difference(_lastHeartTime!) < _kHeartRateLimit) {
      return; // Rate limit : max 10 cœurs/seconde
    }
    _lastHeartTime = now;
    _heartController.add(null);
  }

  // ─── CO-HOST ───
  void respondToCoHost(String targetUserId, bool accepted) {
    if (_realtimeChannel == null) {
      debugPrint('[Live] ⚠️ respondToCoHost: no realtime channel');
      return;
    }
    try {
      _service.respondToCoHost(_realtimeChannel!, targetUserId, accepted);
      _coHostRequestTimer?.cancel();
      debugPrint('[Live] 👥 Co-host ${accepted ? "accepted" : "rejected"}: $targetUserId');
    } catch (e) {
      debugPrint('[Live] ❌ respondToCoHost error: $e');
    }
  }

  // ─── CONTRÔLES AUDIO/VIDÉO ───
  Future<void> toggleVideo() async {
    final newState = !state.isVideoOff;
    state = state.copyWith(isVideoOff: newState);

    try {
      if (newState) {
        await _engine?.disableVideo();
        debugPrint('[Live] 📹 Video disabled');
      } else {
        await _engine?.enableVideo();
        await _engine?.startPreview();
        debugPrint('[Live] 📹 Video enabled');
      }
    } catch (e) {
      debugPrint('[Live] ❌ toggleVideo error: $e');
      state = state.copyWith(isVideoOff: !newState); // Rollback
    }
  }

  void toggleMute() {
    final newState = !state.isMuted;
    state = state.copyWith(isMuted: newState);

    try {
      _engine?.muteLocalAudioStream(newState);
      debugPrint('[Live] 🎙️ Mute: $newState');
    } catch (e) {
      debugPrint('[Live] ❌ toggleMute error: $e');
      state = state.copyWith(isMuted: !newState);
    }
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
      state = state.copyWith(isFrontCamera: !state.isFrontCamera);
      debugPrint('[Live] 🔄 Camera switched');
    } catch (e) {
      debugPrint('[Live] ❌ switchCamera error: $e');
    }
  }

  Future<void> toggleBeauty() async {
    final newState = !state.isBeautyEnabled;
    state = state.copyWith(isBeautyEnabled: newState);

    try {
      await _engine?.setBeautyEffectOptions(
        enabled: newState,
        options: const BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: 0.7,
          smoothnessLevel: 0.5,
          rednessLevel: 0.1,
        ),
      );
      debugPrint('[Live] ✨ Beauty: $newState');
    } catch (e) {
      debugPrint('[Live] ❌ toggleBeauty error: $e');
      state = state.copyWith(isBeautyEnabled: !newState);
    }
  }

  // ─── FIN DE DIRECT ───
  Future<void> endBroadcast() async {
    if (state.isEnding || _isDisposed) return;

    debugPrint('[Live] 🛑 Ending broadcast for session ${session.id}');
    state = state.copyWith(isEnding: true);

    // 1. Terminer la session côté serveur
    try {
      await _service.endLiveSession(session.id).timeout(const Duration(seconds: 10));
      debugPrint('[Live] ✓ Server session ended');
    } catch (e) {
      debugPrint('[Live] ⚠️ endLiveSession error (non-blocking): $e');
    }

    // 2. Realtime unsubscribe
    try {
      await _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
      _realtimeConnected = false;
      debugPrint('[Live] ✓ Realtime unsubscribed');
    } catch (e) {
      debugPrint('[Live] ⚠️ unsubscribe error: $e');
    }

    // 3. Agora cleanup
    try {
      await _ensureEngineClean();
      debugPrint('[Live] ✓ Agora engine cleaned');
    } catch (e) {
      debugPrint('[Live] ⚠️ engine cleanup error: $e');
    }
  }
}
