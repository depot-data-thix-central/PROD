// lib/services/chat/call_service.dart
//
// ============================================================================
// CALL MEDIA SERVICE — Production Enterprise
// ============================================================================
//
// Service de gestion des appels audio/vidéo avec Agora RTC.
//
// Architecture singleton :
//   - Le SDK Agora ne supporte qu'UN SEUL engine par process
//   - Pattern singleton manuel GARANTI (factory + static)
//   - Cycle de vie : create() une fois → join()/leave() multiples
//   - release() UNIQUEMENT à la fermeture de l'app (disposeEngine)
//
// ⚠️ IMPORTANT : Ne JAMAIS faire release() + create() entre deux appels
// (déclenche le bug "Null check operator" du SDK Agora, issue #2202)
//
// Sécurité :
//   - Validation regex stricte sur channel (alphanum + _ -)
//   - Validation uid (positive int)
//   - Sanitization sur appId/token (trim + validation)
//   - Stack traces masquées en production (kDebugMode)
//   - Timeout + retry sur tous les appels réseau
//
// Robustesse :
//   - _isDisposed guard sur toutes les méthodes
//   - _joining flag avec protection double-join
//   - Cleanup callbacks dans disposeEngine
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

  /// Valide un channel name Agora (alphanumérique + underscore + tiret).
  static bool isValidChannel(String? channel) {
    if (channel == null) return false;
    final trimmed = channel.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  /// Valide un UID Agora (entier positif non-nul).
  ///
  /// Note : uid=0 est réservé par Agora pour auto-assignation,
  /// mais nous exigeons un uid explicite pour la traçabilité.
  static bool isValidUid(int uid) {
    return uid > 0 && uid <= 0x7FFFFFFF; // Max int32 positif
  }

  /// Valide un appId Agora (non vide, longueur min, alphanumérique).
  static bool isValidAppId(String? appId) {
    if (appId == null) return false;
    final trimmed = appId.trim();
    if (trimmed.isEmpty || trimmed.length < _kMinAppIdLength) return false;
    return RegExp(r'^[a-zA-Z0-9]{10,}$').hasMatch(trimmed);
  }

  /// Sanitize un token (trim + longueur raisonnable).
  static String sanitizeToken(String? token) {
    if (token == null) return '';
    final trimmed = token.trim();
    // Les tokens Agora peuvent être longs (JWT), on limite à 2KB
    return trimmed.length > 2048 ? trimmed.substring(0, 2048) : trimmed;
  }

  /// Obfusque un appId pour les logs.
  static String obfuscateAppId(String? appId) {
    if (appId == null || appId.length <= 6) return '***';
    return '${appId.substring(0, 6)}...';
  }
}

// ============================================================================
// CALL MEDIA SERVICE (Singleton)
// ============================================================================

/// Service singleton de gestion des appels audio/vidéo Agora.
///
/// **Singleton garanti** : Le SDK Agora ne supporte qu'un engine par process.
/// Le factory retourne toujours la même instance.
///
/// **Usage via Riverpod** :
/// ```dart
/// final callMediaServiceProvider = Provider<CallMediaService>((ref) {
///   return CallMediaService(); // Retourne le singleton
/// });
/// ```
class CallMediaService {
  // Singleton pattern
  static final CallMediaService _instance = CallMediaService._internal();
  factory CallMediaService() => _instance;
  CallMediaService._internal() {
    debugPrint('[CallMediaService] 🚀 Singleton initialized');
  }

  // ── STATE ────────────────────────────────────────────────────────────

  RtcEngine? _engine;
  String? _initializedAppId;
  bool _joined = false;
  bool _joining = false;
  String? _channel;
  bool _isDisposed = false;

  // Callbacks du call en cours (réassignés à chaque join)
  void Function(int)? _onUserJoined;
  void Function(int)? _onUserLeft;
  void Function(String)? _onError;

  // ── PUBLIC GETTERS ───────────────────────────────────────────────────

  /// Instance du moteur Agora (nullable si non-initialisé).
  RtcEngine? get engine => _engine;

  /// Vrai si le moteur a rejoint un canal.
  bool get isJoined => _joined;

  /// Vrai si le service a été disposé.
  bool get isDisposed => _isDisposed;

  // ── PERMISSIONS ──────────────────────────────────────────────────────

  /// Demande les permissions micro/caméra selon le type d'appel.
  ///
  /// Sur Web, les permissions sont gérées différemment (pas de permission_handler).
  Future<void> _ensurePermissions(CallType type) async {
    if (_isDisposed) {
      throw StateError('CallMediaService disposed');
    }

    try {
      // Microphone
      if (!kIsWeb) {
        final mic = await Permission.microphone
            .request()
            .timeout(_kPermissionTimeout);
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

    // Caméra (uniquement si appel vidéo)
    if (type == CallType.video && !kIsWeb) {
      try {
        final cam = await Permission.camera
            .request()
            .timeout(_kPermissionTimeout);
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

  /// Crée le moteur RTC UNE SEULE FOIS et le réutilise entre les appels.
  ///
  /// Si l'appId change (cas rare), le moteur précédent est nettoyé proprement.
  Future<RtcEngine> _ensureEngine(String appId) async {
    if (_isDisposed) {
      throw StateError('CallMediaService disposed');
    }

    // Réutiliser si déjà initialisé avec le même appId
    if (_engine != null && _initializedAppId == appId) {
      return _engine!;
    }

    // appId différent (cas rare) : nettoyage propre avant recréation
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
    }

    final engine = createAgoraRtcEngine();

    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Handler enregistré UNE fois, avec des callbacks null-safe
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] ✓ Joined ${conn.channelId} '
              '(elapsed: ${elapsed}ms)');
          _joined = true;
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 👤 Remote joined: $remoteUid');
          _onUserJoined?.call(remoteUid);
        },
        onUserOffline: (conn, remoteUid, reason) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 👋 Remote offline: $remoteUid '
              '(reason: $reason)');
          _onUserLeft?.call(remoteUid);
        },
        onLeaveChannel: (conn, stats) {
          if (_isDisposed) return;
          debugPrint('[CallMediaService] 🚪 Left channel ${conn.channelId}');
          _joined = false;
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
      // Non supporté sur Web
      debugPrint('[CallMediaService] ⚠️ setEnableSpeakerphone: $e');
    }

    _engine = engine;
    _initializedAppId = appId;
    debugPrint('[CallMediaService] ✓ Engine initialized '
        '(appId=${_CallMediaValidators.obfuscateAppId(appId)})');
    return engine;
  }

  // ── TOKEN RETRIEVAL (avec retry) ─────────────────────────────────────

  /// Récupère un token Agora avec retry automatique.
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

        // Validation du token reçu
        if (!_CallMediaValidators.isValidAppId(cred.appId)) {
          throw FormatException('Invalid appId received');
        }
        if (_CallMediaValidators.sanitizeToken(cred.token).isEmpty) {
          throw FormatException('Empty token received');
        }

        debugPrint('[CallMediaService] ✓ Token obtained '
            '(appId=${_CallMediaValidators.obfuscateAppId(cred.appId)}, '
            'channel=${cred.channel}, uid=${cred.uid})');

        return cred;
      } on TimeoutException {
        lastError = TimeoutException('Token request timeout');
        attempt++;
        if (attempt <= _kMaxRetries) {
          debugPrint('[CallMediaService] ⏱️ Token timeout, '
              'retry $attempt/$_kMaxRetries');
          await Future.delayed(_kRetryDelay);
        }
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt <= _kMaxRetries) {
          debugPrint('[CallMediaService] ⚠️ Token error, '
              'retry $attempt/$_kMaxRetries: $e');
          await Future.delayed(_kRetryDelay);
        }
      }
    }

    throw lastError ?? Exception('Token retrieval failed after retries');
  }

  // ── LOCAL PREVIEW ────────────────────────────────────────────────────

  /// Démarre la préview caméra locale AVANT l'acceptation.
  ///
  /// Utilisé par l'appelant pendant la sonnerie pour voir sa propre caméra
  /// en plein écran avant que l'appelé ne décroche.
  Future<void> prepareLocalPreview({
    required String channel,
    required int uid,
  }) async {
    if (_isDisposed) {
      throw StateError('CallMediaService disposed');
    }

    // Validation inputs
    if (!_CallMediaValidators.isValidChannel(channel)) {
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallMediaValidators.isValidUid(uid)) {
      throw ArgumentError('Invalid uid');
    }

    debugPrint('[CallMediaService] 📹 Preparing local preview '
        '(channel=${_obfuscateChannel(channel)}, uid=$uid)');

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

  /// Rejoint un canal Agora pour un appel audio ou vidéo.
  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid) onUserLeft,
    required void Function(String error) onError,
  }) async {
    if (_isDisposed) {
      throw StateError('CallMediaService disposed');
    }

    // Validation inputs
    if (!_CallMediaValidators.isValidChannel(channel)) {
      onError('Invalid channel name');
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallMediaValidators.isValidUid(uid)) {
      onError('Invalid uid');
      throw ArgumentError('Invalid uid');
    }

    // Anti double-join (arrivée d'appel + accept simultanés)
    if (_joining) {
      debugPrint('[CallMediaService] ⚠️ join ignored: already in progress');
      return;
    }
    _joining = true;

    // Assign callbacks
    _onUserJoined = onUserJoined;
    _onUserLeft = onUserLeft;
    _onError = onError;

    try {
      // Permissions
      await _ensurePermissions(type);
    } catch (e) {
      debugPrint('[CallMediaService] ❌ Permission denied: $e');
      onError('permission: ${e is PermissionDeniedException ? e.message : "denied"}');
      _joining = false;
      rethrow;
    }

    // Token
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

    // Join channel
    try {
      final engine = await _ensureEngine(cred.appId.trim());

      if (type == CallType.video) {
        await engine.enableVideo();
        await engine.enableLocalVideo(true);
        await engine.startPreview();
      } else {
        await engine.enableLocalVideo(false);
      }

      await engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );

      _channel = channel;
      _joined = false;

      // Join avec timeout
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

      debugPrint('[CallMediaService] ✓ Joined channel '
          '(channel=${_obfuscateChannel(channel)}, '
          'uid=$uid, video=${type == CallType.video})');
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

  /// Active/désactive le micro.
  Future<void> setMuted(bool muted) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(muted);
      debugPrint('[CallMediaService] 🎤 Mute: $muted');
    } catch (e) {
      debugPrint('[CallMediaService] ❌ setMuted failed: $e');
    }
  }

  /// Active/désactive la caméra.
  Future<void> setVideoOff(bool off) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.muteLocalVideoStream(off);
      if (!off) {
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      }
      debugPrint('[CallMediaService] 📹 Video off: $off');
    } catch (e) {
      debugPrint('[CallMediaService] ❌ setVideoOff failed: $e');
    }
  }

  /// Bascule entre caméra avant/arrière.
  Future<void> switchCamera() async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.switchCamera();
      debugPrint('[CallMediaService] 🔄 Camera switched');
    } catch (e) {
      debugPrint('[CallMediaService] ❌ switchCamera failed: $e');
    }
  }

  /// Active/désactive le haut-parleur.
  Future<void> setSpeaker(bool on) async {
    if (_isDisposed || _engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(on);
      debugPrint('[CallMediaService] 🔊 Speaker: $on');
    } catch (e) {
      // Non supporté sur Web
      debugPrint('[CallMediaService] ⚠️ setSpeaker (web): $e');
    }
  }

  // ── LEAVE / DISPOSE ──────────────────────────────────────────────────

  /// Quitte le canal SANS détruire le moteur (à utiliser entre les appels).
  ///
  /// Cette méthode doit être appelée dans hangUp() pour quitter proprement
  /// le canal sans libérer le moteur RTC (qui sera réutilisé au prochain appel).
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
    _channel = null;
    _joining = false;
  }

  /// Libère complètement le moteur RTC.
  ///
  /// ⚠️ À appeler UNIQUEMENT à la fermeture de l'app (dispose())
  /// Ne jamais appeler entre deux appels (déclenche le bug "Null check operator")
  Future<void> disposeEngine() async {
    if (_isDisposed) return;

    debugPrint('[CallMediaService] 🧹 Disposing engine');
    _isDisposed = true;

    await leave();

    try {
      await _engine?.release();
    } catch (e) {
      debugPrint('[CallMediaService] ⚠️ release error: $e');
    }

    _engine = null;
    _initializedAppId = null;
    _joined = false;
    _joining = false;
    _channel = null;

    // Cleanup callbacks pour éviter fuites mémoire
    _onUserJoined = null;
    _onUserLeft = null;
    _onError = null;

    debugPrint('[CallMediaService] 👋 Engine disposed');
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscateChannel(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception levée quand une permission est refusée.
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(this.message);

  @override
  String toString() => 'PermissionDeniedException: $message';
}
