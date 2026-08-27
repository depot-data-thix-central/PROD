// lib/services/chat/call_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/chat/call_status.dart';
import 'call_token_service.dart';

/// Service de gestion des appels audio/vidéo avec Agora RTC
/// 
/// Architecture :
/// - Singleton pour réutiliser le moteur RTC entre les appels (évite le bug "Null check operator")
/// - Cycle de vie : create() une fois → join()/leave() multiples → release() à la fermeture
/// - Supporte les préviews caméra locales avant l'acceptation
class CallMediaService {
  static final CallMediaService _i = CallMediaService._();
  factory CallMediaService() => _i;
  CallMediaService._();

  RtcEngine? _engine;
  String? _initializedAppId;
  bool _joined = false;
  bool _joining = false;
  String? _channel;

  // Callbacks du call en cours (réassignés à chaque join)
  void Function(int)? _onUserJoined;
  void Function(int)? _onUserLeft;
  void Function(String)? _onError;

  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;

  /// Demande les permissions micro/caméra selon le type d'appel
  Future<void> _ensurePermissions(CallType type) async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted && !kIsWeb) {
        throw Exception('Micro refusé');
      }
    } catch (e) {
      if (!kIsWeb) rethrow;
      debugPrint('⚠️ permission micro (web): $e');
    }

    if (type == CallType.video) {
      try {
        final cam = await Permission.camera.request();
        if (!cam.isGranted && !kIsWeb) {
          throw Exception('Caméra refusée');
        }
      } catch (e) {
        if (!kIsWeb) rethrow;
        debugPrint('⚠️ permission caméra (web): $e');
      }
    }
  }

  /// Crée le moteur RTC UNE SEULE FOIS et le réutilise entre les appels
  /// 
  /// ⚠️ IMPORTANT : Ne JAMAIS faire release() + create() entre deux appels
  /// (déclenche le bug "Null check operator" du SDK Agora, issue #2202)
  Future<RtcEngine> _ensureEngine(String appId) async {
    // Réutiliser si déjà initialisé avec le même appId
    if (_engine != null && _initializedAppId == appId) {
      return _engine!;
    }

    // appId différent (cas rare) : nettoyage propre avant recréation
    if (_engine != null) {
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
          debugPrint('✅ Joined ${conn.channelId}');
          _joined = true;
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          debugPrint('👤 Remote joined $remoteUid');
          _onUserJoined?.call(remoteUid);
        },
        onUserOffline: (conn, remoteUid, reason) {
          debugPrint('👤 Remote left $remoteUid (reason: $reason)');
          _onUserLeft?.call(remoteUid);
        },
        onLeaveChannel: (conn, stats) {
          debugPrint('🚪 Left channel ${conn.channelId}');
          _joined = false;
        },
        onError: (err, msg) {
          debugPrint('❌ Agora onError code=$err msg=$msg');
          _onError?.call('agora: $err $msg');
        },
      ),
    );

    await engine.enableAudio();
    try {
      await engine.setEnableSpeakerphone(true);
    } catch (e) {
      // Non supporté sur Web
      debugPrint('⚠️ setEnableSpeakerphone: $e');
    }

    _engine = engine;
    _initializedAppId = appId;
    debugPrint('✅ Engine initialisé (appId=${appId.length > 6 ? appId.substring(0, 6) : appId}…)');
    return engine;
  }

  /// ✅ NOUVEAU : Démarre la préview caméra locale AVANT l'acceptation
  /// 
  /// Utilisé par l'appelant pendant la sonnerie pour voir sa propre caméra
  /// en plein écran avant que l'appelé ne décroche.
  Future<void> prepareLocalPreview({
    required String channel,
    required int uid,
  }) async {
    await _ensurePermissions(CallType.video);

    late final CallTokenResult cred;
    try {
      cred = await CallTokenService().getToken(channel: channel, uid: uid);
    } catch (e) {
      debugPrint('❌ prepareLocalPreview getToken: $e');
      rethrow;
    }

    if (cred.appId.trim().isEmpty || cred.appId.trim().length < 10) {
      throw Exception('appId invalide pour la préview');
    }

    try {
      final engine = await _ensureEngine(cred.appId.trim());
      await engine.enableVideo();
      await engine.enableLocalVideo(true);
      await engine.startPreview();
      debugPrint('✅ Préview locale démarrée channel=$channel');
    } catch (e, st) {
      debugPrint('❌ prepareLocalPreview: $e\n$st');
      rethrow;
    }
  }

  /// Rejoint un canal Agora pour un appel audio ou vidéo
  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid) onUserLeft,
    required void Function(String error) onError,
  }) async {
    // Anti double-join (arrivée d'appel + accept simultanés)
    if (_joining) {
      debugPrint('⚠️ join ignoré: déjà en cours');
      return;
    }
    _joining = true;

    _onUserJoined = onUserJoined;
    _onUserLeft = onUserLeft;
    _onError = onError;

    try {
      await _ensurePermissions(type);
    } catch (e) {
      debugPrint('❌ permissions: $e');
      onError('permission: $e');
      _joining = false;
      rethrow;
    }

    late final CallTokenResult cred;
    try {
      cred = await CallTokenService().getToken(channel: channel, uid: uid);
      debugPrint(
        '✅ Token OK appId=${cred.appId} channel=${cred.channel} '
        'uid=${cred.uid} tokenLen=${cred.token.length}',
      );
    } catch (e) {
      debugPrint('❌ getToken: $e');
      onError('token: $e');
      _joining = false;
      rethrow;
    }

    if (cred.appId.trim().isEmpty ||
        cred.token.trim().isEmpty ||
        cred.appId.trim().length < 10) {
      onError('token: appId ou token invalide');
      _joining = false;
      throw Exception('appId/token invalide');
    }

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

      // ✅ CORRECTION : publishCameraTrack pour publier la vidéo
      await engine.joinChannel(
        token: cred.token.trim(),
        channelId: channel,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: type == CallType.video, // ✅ Publier la caméra si vidéo
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      debugPrint('✅ joinChannel OK channel=$channel uid=$uid video=${type == CallType.video}');
    } catch (e, st) {
      debugPrint('❌ Agora init/join: $e\n$st');
      onError('agora: $e');
      await leave(); // leave() au lieu de disposeEngine()
      _joining = false;
      rethrow;
    }

    _joining = false;
  }

  /// Active/désactive le micro
  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  /// Active/désactive la caméra
  Future<void> setVideoOff(bool off) async {
    await _engine?.muteLocalVideoStream(off);
    if (!off) {
      await _engine?.enableLocalVideo(true);
      await _engine?.startPreview();
    }
  }

  /// Bascule entre caméra avant/arrière
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  /// Active/désactive le haut-parleur
  Future<void> setSpeaker(bool on) async {
    try {
      await _engine?.setEnableSpeakerphone(on);
    } catch (_) {}
  }

  /// Quitte le canal SANS détruire le moteur (à utiliser entre les appels)
  /// 
  /// Cette méthode doit être appelée dans hangUp() pour quitter proprement
  /// le canal sans libérer le moteur RTC (qui sera réutilisé au prochain appel).
  Future<void> leave() async {
    try {
      await _engine?.stopPreview();
    } catch (_) {}
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    _joined = false;
    _channel = null;
  }

  /// Libère complètement le moteur RTC
  /// 
  /// ⚠️ À appeler UNIQUEMENT à la fermeture de l'app (dispose())
  /// Ne jamais appeler entre deux appels (déclenche le bug "Null check operator")
  Future<void> disposeEngine() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _initializedAppId = null;
  }
}
