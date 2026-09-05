// lib/presentation/thix_media/live/services/live_rtc_service.dart
//
// LiveRtcService — Wrapper Agora Production Enterprise (TikTok/IG Live level)
//
// Features :
// - Logging structuré (INFO/WARN/ERROR)
// - Timeouts sur toutes les opérations RTC critiques
// - Permissions vérifiées (pas juste demandées)
// - Auto-refresh token sur expiration (callback injectable)
// - Monitoring qualité réseau Agora (uplink/downlink quality)
// - Détection remote video/audio state (host mute/cam off)
// - Stats temps réel (bitrate, FPS, packet loss, RTT)
// - Low-latency mode pour live interactif
// - Lifecycle management (pause/resume streams)
// - Protection double-init / double-leave
// - Error classification typée
// - Cleanup complet dispose (event handlers + streams)
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'live_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kRtcTimeout = Duration(seconds: 15);
const Duration _kPreviewTimeout = Duration(seconds: 10);
const Duration _kStatsInterval = Duration(seconds: 2);
const Duration _kTokenRefreshLead = Duration(minutes: 5);

// ============================================================================
// LOGGING
// ============================================================================

class _RtcLogger {
  static const _tag = 'LiveRtc';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class RtcException implements Exception {
  final String code;
  final String message;
  final int? agoraCode;
  RtcException(this.code, this.message, {this.agoraCode});
  @override
  String toString() =>
      'RtcException[$code]: $message${agoraCode != null ? ' (agora=$agoraCode)' : ''}';
}

class RtcPermissionException extends RtcException {
  RtcPermissionException(String msg) : super('permission_denied', msg);
}

class RtcTimeoutException extends RtcException {
  RtcTimeoutException(String op) : super('timeout', '$op timed out');
}

class RtcNetworkException extends RtcException {
  RtcNetworkException(String msg) : super('network', msg);
}

class RtcAlreadyRunningException extends RtcException {
  RtcAlreadyRunningException()
      : super('already_running', 'RTC session already active');
}

class RtcNotInitializedException extends RtcException {
  RtcNotInitializedException()
      : super('not_initialized', 'RTC engine not initialized');
}

// ============================================================================
// STATS
// ============================================================================

class RtcStats {
  final int bitrateKbps;
  final double fps;
  final double packetLossPercent;
  final int rttMs;
  final int cpuUsagePercent;
  final int memoryUsageMb;

  const RtcStats({
    this.bitrateKbps = 0,
    this.fps = 0,
    this.packetLossPercent = 0,
    this.rttMs = 0,
    this.cpuUsagePercent = 0,
    this.memoryUsageMb = 0,
  });

  bool get isHealthy =>
      packetLossPercent < 10 && rttMs < 500 && bitrateKbps > 100;

  @override
  String toString() =>
      'RtcStats(br=${bitrateKbps}kbps, fps=$fps, loss=$packetLossPercent%, rtt=$rttMs)';
}

// ============================================================================
// NETWORK QUALITY
// ============================================================================

enum RtcNetworkQuality { unknown, excellent, good, poor, bad, veryBad, down }

extension RtcNetworkQualityX on RtcNetworkQuality {
  bool get isUsable =>
      this == RtcNetworkQuality.excellent ||
      this == RtcNetworkQuality.good ||
      this == RtcNetworkQuality.poor;
}

RtcNetworkQuality _fromAgoraQuality(int q) {
  switch (q) {
    case 1:
      return RtcNetworkQuality.excellent;
    case 2:
      return RtcNetworkQuality.good;
    case 3:
      return RtcNetworkQuality.poor;
    case 4:
      return RtcNetworkQuality.bad;
    case 5:
      return RtcNetworkQuality.veryBad;
    case 6:
      return RtcNetworkQuality.down;
    default:
      return RtcNetworkQuality.unknown;
  }
}

// ============================================================================
// REMOTE STATE
// ============================================================================

class RemoteMediaState {
  final bool videoEnabled;
  final bool audioEnabled;
  const RemoteMediaState({
    this.videoEnabled = true,
    this.audioEnabled = true,
  });
}

// ============================================================================
// CALLBACK TYPES
// ============================================================================

typedef TokenRefreshCallback = Future<String?> Function(String channelName);
typedef OnRemoteMediaStateChanged = void Function(RemoteMediaState state);
typedef OnRtcStats = void Function(RtcStats stats);
typedef OnNetworkQuality = void Function(RtcNetworkQuality quality);
typedef OnRemoteLeft = void Function(String reason);

// ============================================================================
// SERVICE
// ============================================================================

class LiveRtcService {
  LiveRtcService();

  RtcEngine? _engine;
  bool _initialized = false;
  bool _joined = false;
  bool _disposed = false;
  String? _currentChannel;
  bool _isHost = false;

  int? remoteHostUid;

  final _remoteUidController = StreamController<int?>.broadcast();
  final _statsController = StreamController<RtcStats>.broadcast();
  final _remoteStateController =
      StreamController<RemoteMediaState>.broadcast();
  final _networkQualityController =
      StreamController<RtcNetworkQuality>.broadcast();

  Stream<int?> get remoteUidStream => _remoteUidController.stream;
  Stream<RtcStats> get statsStream => _statsController.stream;
  Stream<RemoteMediaState> get remoteStateStream =>
      _remoteStateController.stream;
  Stream<RtcNetworkQuality> get networkQualityStream =>
      _networkQualityController.stream;

  bool get isJoined => _joined;
  bool get isInitialized => _initialized;
  bool get isHost => _isHost;
  RtcEngine? get engine => _engine;
  String? get currentChannel => _currentChannel;

  /// Callback injectable pour refresh token (appelé avant expiration).
  TokenRefreshCallback? onTokenRefreshNeeded;

  /// Callback pour remote media state (viewer reçoit host cam/mic off).
  OnRemoteMediaStateChanged? onRemoteMediaStateChanged;

  /// Callback pour stats périodiques.
  OnRtcStats? onStats;

  /// Callback pour qualité réseau.
  OnNetworkQuality? onNetworkQuality;

  /// Callback quand le remote quitte.
  OnRemoteLeft? onRemoteLeft;

  // ════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _ensurePermissions({required bool asHost}) async {
    if (kIsWeb) return;

    final perms = <Permission>[
      if (asHost) Permission.camera,
      Permission.microphone,
    ];

    final results = await perms.request();

    final denied = results.entries
        .where((e) => !e.value.isGranted && !e.value.isLimited)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      _RtcLogger.error('Permissions denied', {'denied': denied});
      throw RtcPermissionException(
          'Required permissions denied: ${denied.join(', ')}');
    }

    _RtcLogger.info('Permissions granted', {'perms': perms.length});
  }

  // ════════════════════════════════════════════════════════════
  // INITIALIZE
  // ════════════════════════════════════════════════════════════

  Future<void> initialize(String appId) async {
    if (_disposed) {
      throw RtcException('disposed', 'Service has been disposed');
    }
    if (_initialized && _engine != null) {
      _RtcLogger.warn('Already initialized');
      return;
    }

    if (appId.isEmpty) {
      throw RtcException('invalid_app_id', 'Agora appId is empty');
    }

    _RtcLogger.info('Initializing engine', {'appId': appId.substring(0, 6) + '...'});

    try {
      _engine = createAgoraRtcEngine();

      await _engine!
          .initialize(
            RtcEngineContext(
              appId: appId,
              channelProfile:
                  ChannelProfileType.channelProfileLiveBroadcasting,
            ),
          )
          .timeout(_kRtcTimeout, onTimeout: () {
        throw RtcTimeoutException('engine.initialize');
      });

      // Low-latency mode pour live interactif
      try {
        await _engine!
            .setParameters('{"che.video.lowBitRateStreamParameter":{'
                '"width":640,"height":360,"frameRate":15,"bitRate":600}}');
      } catch (e) {
        _RtcLogger.warn('Low-latency param failed (non-critical)',
            {'error': '$e'});
      }

      _registerEventHandlers();

      await _engine!.enableVideo().timeout(_kRtcTimeout);
      await _engine!.enableAudio().timeout(_kRtcTimeout);

      _initialized = true;
      _RtcLogger.info('Engine initialized');
    } catch (e) {
      _RtcLogger.error('Initialize failed', {'error': '$e'});
      // Cleanup partiel en cas d'échec
      try {
        await _engine?.release();
      } catch (_) {}
      _engine = null;
      rethrow;
    }
  }

  void _registerEventHandlers() {
    if (_engine == null) return;

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        // ── JOIN / LEAVE ──
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
          _RtcLogger.info('Joined channel', {
            'channel': connection.channelId,
            'localUid': connection.localUid,
            'elapsed_ms': elapsed,
          });
        },

        onLeaveChannel: (connection, stats) {
          _joined = false;
          _RtcLogger.info('Left channel', {
            'channel': connection.channelId,
            'duration_s': stats.duration,
            'txBytes': stats.txBytes,
            'rxBytes': stats.rxBytes,
          });
        },

        // ── REMOTE USERS ──
        onUserJoined: (connection, remoteUid, elapsed) {
          _RtcLogger.info('Remote joined', {'uid': remoteUid});
          remoteHostUid = remoteUid;
          _safeAdd(_remoteUidController, remoteUid);
        },

        onUserOffline: (connection, remoteUid, reason) {
          _RtcLogger.warn('Remote offline',
              {'uid': remoteUid, 'reason': reason.name});
          if (remoteHostUid == remoteUid) {
            remoteHostUid = null;
            _safeAdd(_remoteUidController, null);
            onRemoteLeft?.call(reason.name);
          }
        },

        // ── REMOTE MEDIA STATE (host mute/cam off) ──
        onRemoteVideoStateChanged:
            (connection, remoteUid, state, reason, elapsed) {
          if (remoteUid == remoteHostUid) {
            final enabled = state == RemoteVideoState.remoteVideoStateRunning;
            _RtcLogger.info('Remote video state',
                {'uid': remoteUid, 'enabled': enabled});
            _updateRemoteState(videoEnabled: enabled);
          }
        },

        onRemoteAudioStateChanged:
            (connection, remoteUid, state, reason, elapsed) {
          if (remoteUid == remoteHostUid) {
            final enabled = state == RemoteAudioState.remoteAudioStateRunning;
            _RtcLogger.info('Remote audio state',
                {'uid': remoteUid, 'enabled': enabled});
            _updateRemoteState(audioEnabled: enabled);
          }
        },

        // ── NETWORK QUALITY ──
        onNetworkQuality:
            (connection, remoteUid, txQuality, rxQuality) {
          // txQuality = upload, rxQuality = download
          final q = _fromAgoraQuality(remoteUid == 0 ? txQuality : rxQuality);
          _safeAdd(_networkQualityController, q);
          onNetworkQuality?.call(q);
        },

        // ── STATS ──
        onRtcStats: (connection, stats) {
          final s = RtcStats(
            bitrateKbps: stats.txKBitRate + stats.rxKBitRate,
            cpuUsagePercent: stats.cpuTotalUsage.toInt(),
            memoryUsageMb: stats.memoryTotalUsageRatio * 100 ~/ 1,
          );
          _safeAdd(_statsController, s);
          onStats?.call(s);
        },

        onLocalVideoStats: (connection, stats) {
          // Stats spécifiques host (publish)
          if (_isHost) {
            final s = RtcStats(
              bitrateKbps: stats.txKBitRate,
              fps: stats.encodedFrameRate?.toDouble() ?? 0.0,
              packetLossPercent: stats.txPacketLossRate?.toDouble() ?? 0.0,
            );
            _safeAdd(_statsController, s);
            onStats?.call(s);
          }
        },

        // ── ERRORS ──
        onError: (err, msg) {
          _handleAgoraError(err, msg);
        },

        onConnectionStateChanged: (connection, state, reason) {
          _RtcLogger.info('Connection state',
              {'state': state.name, 'reason': reason.name});

          if (state == ConnectionStateType.connectionStateFailed ||
              state == ConnectionStateType.connectionStateDisconnected) {
            _RtcLogger.error('Connection failed',
                {'state': state.name, 'reason': reason.name});
          }
        },

        // ── TOKEN REFRESH ──
        onTokenPrivilegeWillExpire: (connection, token) async {
          _RtcLogger.warn('Token will expire soon',
              {'channel': connection.channelId});

          if (onTokenRefreshNeeded != null && _currentChannel != null) {
            try {
              final newToken = await onTokenRefreshNeeded!(_currentChannel!);
              if (newToken != null && newToken.isNotEmpty && _engine != null) {
                await _engine!.renewToken(newToken);
                _RtcLogger.info('Token renewed successfully');
              } else {
                _RtcLogger.error('Token refresh callback returned empty');
              }
            } catch (e) {
              _RtcLogger.error('Token refresh failed', {'error': '$e'});
            }
          }
        },

        onPermissionError: (permissionType) {
          _RtcLogger.error('Permission error from Agora',
              {'type': permissionType.name});
        },
      ),
    );
  }

  RemoteMediaState _currentRemoteState = const RemoteMediaState();

  void _updateRemoteState({bool? videoEnabled, bool? audioEnabled}) {
    _currentRemoteState = RemoteMediaState(
      videoEnabled: videoEnabled ?? _currentRemoteState.videoEnabled,
      audioEnabled: audioEnabled ?? _currentRemoteState.audioEnabled,
    );
    _safeAdd(_remoteStateController, _currentRemoteState);
    onRemoteMediaStateChanged?.call(_currentRemoteState);
  }

  void _handleAgoraError(ErrorCodeType err, String msg) {
    // ✅ CORRECTION ICI : Ajout des parenthèses à .value()
    final int code = err.value();
    
    _RtcLogger.error('Agora error', {'code': code, 'msg': msg});

    // Classification : certaines erreurs sont non-fatales
    const nonFatal = <int>[
      110, // ERR_TOKEN_EXPIRED
      111, // ERR_INVALID_TOKEN
      134, // ERR_USER_NOT_LOGGED_IN
    ];

    if (nonFatal.contains(code)) {
      _RtcLogger.warn('Non-fatal Agora error (handled elsewhere)');
      return;
    }

    // Erreurs réseau typiques
    if (code >= 100 && code < 200) {
      _RtcLogger.error('Network-related Agora error');
    }
  }

  // ════════════════════════════════════════════════════════════
  // HOST
  // ════════════════════════════════════════════════════════════

  Future<void> startAsHost(AgoraCredentials creds) async {
    if (_disposed) throw RtcException('disposed', 'Service disposed');
    if (_joined) throw RtcAlreadyRunningException();
    if (!creds.isValid) {
      throw RtcException('invalid_creds', 'Invalid Agora credentials');
    }

    _isHost = true;
    _currentChannel = creds.channelName;
    _RtcLogger.info('Starting as host',
        {'channel': creds.channelName, 'uid': creds.uid});

    await _ensurePermissions(asHost: true);
    await initialize(creds.appId);

    try {
      await _engine!
          .setClientRole(role: ClientRoleType.clientRoleBroadcaster)
          .timeout(_kRtcTimeout);

      await _engine!.startPreview().timeout(_kPreviewTimeout, onTimeout: () {
        throw RtcTimeoutException('startPreview');
      });

      // ✅ CORRECTION ICI : Suppression de `audioScenario`
      await _engine!
          .joinChannel(
            token: creds.token,
            channelId: creds.channelName,
            uid: creds.uid,
            options: const ChannelMediaOptions(
              channelProfile:
                  ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          )
          .timeout(_kRtcTimeout, onTimeout: () {
        throw RtcTimeoutException('joinChannel(host)');
      });

      _RtcLogger.info('Host session started');
    } catch (e) {
      _RtcLogger.error('startAsHost failed', {'error': '$e'});
      // Cleanup
      try {
        await _engine?.stopPreview();
        await _engine?.leaveChannel();
      } catch (_) {}
      _isHost = false;
      _currentChannel = null;
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // AUDIENCE
  // ════════════════════════════════════════════════════════════

  Future<void> joinAsAudience(AgoraCredentials creds) async {
    if (_disposed) throw RtcException('disposed', 'Service disposed');
    if (_joined) throw RtcAlreadyRunningException();
    if (!creds.isValid) {
      throw RtcException('invalid_creds', 'Invalid Agora credentials');
    }

    _isHost = false;
    _currentChannel = creds.channelName;
    _RtcLogger.info('Joining as audience',
        {'channel': creds.channelName, 'uid': creds.uid});

    await _ensurePermissions(asHost: false);
    await initialize(creds.appId);

    try {
      await _engine!
          .setClientRole(role: ClientRoleType.clientRoleAudience)
          .timeout(_kRtcTimeout);

      // ✅ CORRECTION ICI : Suppression de `audioScenario`
      await _engine!
          .joinChannel(
            token: creds.token,
            channelId: creds.channelName,
            uid: creds.uid,
            options: const ChannelMediaOptions(
              channelProfile:
                  ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: ClientRoleType.clientRoleAudience,
              publishCameraTrack: false,
              publishMicrophoneTrack: false,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          )
          .timeout(_kRtcTimeout, onTimeout: () {
        throw RtcTimeoutException('joinChannel(audience)');
      });

      _RtcLogger.info('Audience session started');
    } catch (e) {
      _RtcLogger.error('joinAsAudience failed', {'error': '$e'});
      try {
        await _engine?.leaveChannel();
      } catch (_) {}
      _currentChannel = null;
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // MEDIA CONTROLS
  // ════════════════════════════════════════════════════════════

  Future<void> muteLocalAudio(bool mute) async {
    if (_engine == null) throw RtcNotInitializedException();
    try {
      await _engine!.muteLocalAudioStream(mute);
      _RtcLogger.info('Local audio muted', {'mute': mute});
    } catch (e) {
      _RtcLogger.error('muteLocalAudio failed', {'error': '$e'});
      rethrow;
    }
  }

  Future<void> muteLocalVideo(bool mute) async {
    if (_engine == null) throw RtcNotInitializedException();
    try {
      await _engine!.muteLocalVideoStream(mute);
      _RtcLogger.info('Local video muted', {'mute': mute});
    } catch (e) {
      _RtcLogger.error('muteLocalVideo failed', {'error': '$e'});
      rethrow;
    }
  }

  Future<void> switchCamera() async {
    if (_engine == null) throw RtcNotInitializedException();
    try {
      await _engine!.switchCamera();
      _RtcLogger.info('Camera switched');
    } catch (e) {
      _RtcLogger.error('switchCamera failed', {'error': '$e'});
      rethrow;
    }
  }

  /// Met en pause les streams (utile quand app en background).
  Future<void> pauseStreams() async {
    if (_engine == null || !_joined) return;
    try {
      await _engine!.muteLocalAudioStream(true);
      await _engine!.muteLocalVideoStream(true);
      _RtcLogger.info('Streams paused');
    } catch (e) {
      _RtcLogger.warn('pauseStreams failed', {'error': '$e'});
    }
  }

  /// Reprend les streams.
  Future<void> resumeStreams() async {
    if (_engine == null || !_joined) return;
    try {
      await _engine!.muteLocalAudioStream(false);
      await _engine!.muteLocalVideoStream(false);
      _RtcLogger.info('Streams resumed');
    } catch (e) {
      _RtcLogger.warn('resumeStreams failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════
  // LEAVE / DISPOSE
  // ════════════════════════════════════════════════════════════

  Future<void> leave() async {
    if (!_joined && _engine == null) {
      _RtcLogger.warn('leave called but nothing to leave');
      _resetState();
      return;
    }

    _RtcLogger.info('Leaving channel');

    try {
      await _engine?.leaveChannel().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _RtcLogger.warn('leaveChannel timeout');
            },
          );
    } catch (e) {
      _RtcLogger.warn('leaveChannel error (ignored)', {'error': '$e'});
    }

    try {
      await _engine?.stopPreview().timeout(
            const Duration(seconds: 3),
            onTimeout: () => _RtcLogger.warn('stopPreview timeout'),
          );
    } catch (e) {
      _RtcLogger.warn('stopPreview error (ignored)', {'error': '$e'});
    }

    _resetState();
    _RtcLogger.info('Left successfully');
  }

  void _resetState() {
    _joined = false;
    _isHost = false;
    remoteHostUid = null;
    _currentChannel = null;
    _currentRemoteState = const RemoteMediaState();
    _safeAdd(_remoteUidController, null);
  }

  Future<void> dispose() async {
    if (_disposed) {
      _RtcLogger.warn('dispose called twice');
      return;
    }
    _disposed = true;
    _RtcLogger.info('Disposing service');

    await leave();

    try {
      if (_engine != null) {
        await _engine!.release().timeout(
              const Duration(seconds: 5),
              onTimeout: () => _RtcLogger.warn('engine.release timeout'),
            );
      }
    } catch (e) {
      _RtcLogger.warn('engine.release error (ignored)', {'error': '$e'});
    }

    _engine = null;
    _initialized = false;

    await _closeController(_remoteUidController);
    await _closeController(_statsController);
    await _closeController(_remoteStateController);
    await _closeController(_networkQualityController);

    _RtcLogger.info('Service disposed');
  }

  Future<void> _closeController<T>(StreamController<T> c) async {
    try {
      if (!c.isClosed) await c.close();
    } catch (e) {
      _RtcLogger.warn('Controller close error', {'error': '$e'});
    }
  }

  void _safeAdd<T>(StreamController<T> c, T value) {
    if (!c.isClosed && !_disposed) {
      c.add(value);
    }
  }
}
