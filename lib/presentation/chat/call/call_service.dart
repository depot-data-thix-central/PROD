// lib/services/chat/call_service.dart
//
// ============================================================================
// CALL MEDIA SERVICE — v2.1
// ============================================================================
// Corrections :
//  ✅ Création du moteur Agora SÉRIALISÉE (plus de 2 moteurs en parallèle)
//  ✅ join() idempotent : un 2e appel pour le même canal ne coupe plus l'appel en cours
//  ✅ disposeEngine() ne rend plus le singleton inutilisable
// ============================================================================

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_token_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMinAppIdLength = 10;
const int _kMaxChannelLength = 100;
const Duration _kTokenTimeout = Duration(seconds: 15);
const Duration _kJoinTimeout = Duration(seconds: 30);
const Duration _kPermissionTimeout = Duration(seconds: 10);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallMediaValidators {
  _CallMediaValidators._();

  static bool isValidChannel(String? channel) {
    if (channel == null) return false;
    final trimmed = channel.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  static bool isValidUid(int uid) => uid > 0 && uid <= 0x7FFFFFFF;

  static bool isValidAppId(String? appId) {
    if (appId == null) return false;
    final trimmed = appId.trim();
    if (trimmed.isEmpty || trimmed.length < _kMinAppIdLength) return false;
    return RegExp(r'^[a-zA-Z0-9]{10,}$').hasMatch(trimmed);
  }

  static String sanitizeToken(String? token) {
    if (token == null) return '';
    final trimmed = token.trim();
    return trimmed.length > 2048 ? trimmed.substring(0, 2048) : trimmed;
  }

  static String obfuscateAppId(String? appId) {
    if (appId == null || appId.length <= 6) return '***';
    return '${appId.substring(0, 6)}...';
  }
}

// ============================================================================
// CALL MEDIA SERVICE (Singleton)
// ============================================================================
class CallMediaService {
  static final CallMediaService _instance = CallMediaService._internal();
  factory CallMediaService() => _instance;
  CallMediaService._internal() {
    debugPrint('[CallMediaService] 🚀 Singleton initialized');
  }

  // ── STATE ────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  String? _initializedAppId;
  Future<void>? _engineInit; // verrou : une seule création de moteur à la fois
  bool _joined = false;
  bool _joining = false;
  bool _joinIssued = false; // joinChannel déjà envoyé pour _channel
  String? _channel;
  bool _isDisposed = false;

  void Function(int)? _onUserJoined;
  void Function(int)? _onUserLeft;
  void Function(String)? _onError;

  // ── PUBLIC GETTERS ───────────────────────────────────────────────────
  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;
  bool get isDisposed => _isDisposed;

  // ── PERMISSIONS ──────────────────────────────────────────────────────
  Future<void> _ensurePermissions(CallType type) async {
    if (_isDisposed) throw StateError('CallMediaService disposed');

    try {
      if (!kIsWeb) {
        final mic = await Permission.microphone.request().timeout(_kPermissionTimeout);
        if (!mic.isGranted) {
          throw PermissionDeniedException('Microphone permission denied');
        }
      }
    } on TimeoutException {
      throw TimeoutException('Microphone permission request timeout');
    } catch (e) {
      if (!kIsWeb) rethrow;
      debugPrint('[CallMediaService] ⚠️ Web mic permission: $e');
    }

    if (type == CallType.video && !kIsWeb) {
      try {
        final cam = await Permission.camera.request().timeout(_kPermissionTimeout);
        if (!cam.isGranted) {
          throw PermissionDeniedException('Camera permission denied');
        }
      } on TimeoutException {
        throw TimeoutException('Camera permission request timeout');
      } catch (e) {
        if (!kIsWeb) rethrow;
        debugPrint('[CallMediaService] ⚠️ Web camera permission: $e');
      }
    }
  }

  // ── ENGINE MANAGEMENT ────────────────────────────────────────────────

  /// Retourne le moteur, en le créant UNE SEULE FOIS même si plusieurs
  /// appels arrivent en même temps (aperçu caméra + join).
  Future<RtcEngine> _ensureEngine(String appId) async {
    if (_isDisposed) throw StateError('CallMediaService disposed');

    // Si une création est en cours, on attend sa fin avant de décider.
    while (_engineInit != null) {
      try {
        await _engineInit;
      } catch (_) {}
    }
    if (_isDisposed) throw StateError('CallMediaService disposed');

    if (_engine != null && _initializedAppId == appId) return _engine!;

    final completer = Completer<void>();
    _engineInit = completer.future;
    try {
      return await _createEngine(appId);
    } finally {
      _engineInit = null;
      completer.complete();
    }
  }

  Future<RtcEngine> _createEngine(String appId) async {
    if (_engine != null) {
      debugPrint('[CallMediaService] 🔄 AppId changed, recreating engine');
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _initializedAppId = null;
      _joined = false;
      _joinIssued = false;
    }

    final engine = createAgoraRtcEngine();

    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] ✓ Joined ${conn.channelId} (elapsed: ${elapsed}ms)');
          _joined = true;
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 👤 Remote joined: $remoteUid');
          _onUserJoined?.call(remoteUid);
        },
        onUserOffline: (conn, remoteUid, reason) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 👋 Remote offline: $remoteUid (reason: $reason)');
          _onUserLeft?.call(remoteUid);
        },
        onLeaveChannel: (conn, stats) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 🚪 Left channel ${conn.channelId}');
          _joined = false;
          _joinIssued = false;
        },
        onError: (err, msg) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] ❌ Agora error: code=$err msg=$msg');
          _onError?.call('agora: $err $msg');
        },
      ),
    );

    await engine.enableAudio();
    try {
      await engine.setEnableSpeakerphone(true);
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ setEnableSpeakerphone: $e');
    }

    _engine = engine;
    _initializedAppId = appId;
    debugPrint('[CallMediaService] ✓ Engine initialized '
        '(appId=${_CallMediaValidators.obfuscateAppId(appId)})');
    return engine;
  }

  // ── TOKEN RETRIEVAL ──────────────────────────────────────────────────
  Future<CallTokenResult> _getTokenWithRetry({
    required String channel,
    required int uid,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= _kMaxRetries) {
      try {
        final cred = await CallTokenService()
            .getToken(channel: channel, uid: uid)
            .timeout(_kTokenTimeout);

        if (!_CallMediaValidators.isValidAppId(cred.appId)) {
          throw FormatException('Invalid appId received');
        }
        if (_CallMediaValidators.sanitizeToken(cred.token).isEmpty) {
          throw FormatException('Empty token received');
        }
        return cred;
      } on TimeoutException {
        lastError = TimeoutException('Token request timeout');
        attempt++;
        if (attempt <= _kMaxRetries) await Future.delayed(_kRetryDelay);
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt <= _kMaxRetries) await Future.delayed(_kRetryDelay);
      }
    }
    throw lastError ?? Exception('Token retrieval failed after retries');
  }

  // ── LOCAL PREVIEW ────────────────────────────────────────────────────
  Future<void> prepareLocalPreview({
    required String channel,
    required int uid,
  }) async {
    if (_isDisposed) throw StateError('CallMediaService disposed');
    if (!_CallMediaValidators.isValidChannel(channel)) {
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallMediaValidators.isValidUid(uid)) throw ArgumentError('Invalid uid');

    debugPrint('[CallMediaService] 📹 Preparing local preview (uid=$uid)');

    await _ensurePermissions(CallType.video);
    final cred = await _getTokenWithRetry(channel: channel, uid: uid);

    try {
      final engine = await _ensureEngine(cred.appId.trim());
      await engine.enableVideo();
      await engine.enableLocalVideo(true);
      await engine.startPreview();
      debugPrint('[CallMediaService] ✓ Local preview started');
    } catch (e) {
      debugPrint('[CallMediaService] ❌ prepareLocalPreview failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ── JOIN CHANNEL ─────────────────────────────────────────────────────
  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid) onUserLeft,
    required void Function(String error) onError,
  }) async {
    if (_isDisposed) throw StateError('CallMediaService disposed');

    if (!_CallMediaValidators.isValidChannel(channel)) {
      onError('Invalid channel name');
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallMediaValidators.isValidUid(uid)) {
      onError('Invalid uid');
      throw ArgumentError('Invalid uid');
    }

    // ✅ Idempotence : déjà connecté (ou en cours) à CE canal → on garde
    // l'appel tel quel, on met seulement les callbacks à jour.
    if (_channel == channel && (_joined || _joinIssued || _joining)) {
      _onUserJoined = onUserJoined;
      _onUserLeft = onUserLeft;
      _onError = onError;
      debugPrint('[CallMediaService] ⚠️ join ignored: already in this channel');
      return;
    }
    if (_joining) {
      debugPrint('[CallMediaService] ⚠️ join ignored: another join in progress');
      return;
    }
    _joining = true;

    _onUserJoined = onUserJoined;
    _onUserLeft = onUserLeft;
    _onError = onError;

    try {
      await _ensurePermissions(type);
    } catch (e) {
      debugPrint('[CallMediaService] ❌ Permission denied: $e');
      onError('permission: ${e is PermissionDeniedException ? e.message : "denied"}');
      _joining = false;
      rethrow;
    }

    late final CallTokenResult cred;
    try {
      cred = await _getTokenWithRetry(channel: channel, uid: uid);
    } catch (e) {
      debugPrint('[CallMediaService] ❌ Token failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      onError('token: ${kDebugMode ? e : "retrieval failed"}');
      _joining = false;
      rethrow;
    }

    try {
      final engine = await _ensureEngine(cred.appId.trim());

      // Reste d'un ancien canal différent : on le quitte proprement
      if (_joined && _channel != null && _channel != channel) {
        try {
          await engine.leaveChannel();
        } catch (_) {}
        _joined = false;
        _joinIssued = false;
      }

      if (type == CallType.video) {
        await engine.enableVideo();
        await engine.enableLocalVideo(true);
        await engine.startPreview();
      } else {
        await engine.enableLocalVideo(false);
      }

      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      _channel = channel;
      _joined = false;

      await engine
          .joinChannel(
            token: _CallMediaValidators.sanitizeToken(cred.token),
            channelId: channel,
            uid: uid,
            options: ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              channelProfile: ChannelProfileType.channelProfileCommunication,
              publishMicrophoneTrack: true,
              publishCameraTrack: type == CallType.video,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          )
          .timeout(_kJoinTimeout);

      _joinIssued = true;
      debugPrint('[CallMediaService] ✓ Join sent (uid=$uid, video=${type == CallType.video})');
    } on TimeoutException {
      debugPrint('[CallMediaService] ❌ Join timeout');
      onError('agora: join timeout');
      await leave();
      _joining = false;
      rethrow;
    } catch (e) {
      debugPrint('[CallMediaService] ❌ Join failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      onError('agora: ${kDebugMode ? e : "join failed"}');
      await leave();
      _joining = false;
      rethrow;
    }

    _joining = false;
  }

  // ── MEDIA CONTROLS ───────────────────────────────────────────────────
  Future<void> setMuted(bool muted) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(muted);
    } catch (e) {
      debugPrint('[CallMediaService] ❌ setMuted failed: $e');
    }
  }

  Future<void> setVideoOff(bool off) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.muteLocalVideoStream(off);
      if (!off) {
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      }
    } catch (e) {
      debugPrint('[CallMediaService] ❌ setVideoOff failed: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.switchCamera();
    } catch (e) {
      debugPrint('[CallMediaService] ❌ switchCamera failed: $e');
    }
  }

  Future<void> setSpeaker(bool on) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(on);
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ setSpeaker (web): $e');
    }
  }

  // ── LEAVE / DISPOSE ──────────────────────────────────────────────────

  /// Quitte le canal SANS détruire le moteur (à utiliser entre les appels).
  Future<void> leave() async {
    if (_isDisposed) return;

    debugPrint('[CallMediaService] 🚪 Leaving channel');
    try {
      await _engine?.stopPreview();
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ stopPreview error: $e');
    }
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ leaveChannel error: $e');
    }

    _joined = false;
    _joinIssued = false;
    _channel = null;
    _joining = false;
  }

  /// Libère le moteur RTC (fermeture de l'app uniquement).
  /// Le singleton reste réutilisable ensuite (si le provider est recréé).
  Future<void> disposeEngine() async {
    if (_isDisposed) return;

    debugPrint('[CallMediaService] 🧹 Disposing engine');
    _isDisposed = true; // bloque les callbacks pendant la libération

    try {
      await _engine?.stopPreview();
    } catch (_) {}
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    try {
      await _engine?.release();
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ release error: $e');
    }

    _engine = null;
    _initializedAppId = null;
    _engineInit = null;
    _joined = false;
    _joinIssued = false;
    _joining = false;
    _channel = null;
    _onUserJoined = null;
    _onUserLeft = null;
    _onError = null;

    _isDisposed = false; // ✅ le singleton redevient utilisable
    debugPrint('[CallMediaService] 👋 Engine disposed');
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(this.message);

  @override
  String toString() => 'PermissionDeniedException: $message';
}
