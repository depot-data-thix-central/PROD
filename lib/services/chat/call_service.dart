// lib/services/chat/call_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/chat/call_status.dart';
import 'call_token_service.dart';

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

  /// ✅ CORRECTION : crée le moteur UNE SEULE FOIS et le réutilise.
  /// Ne JAMAIS faire release() + create() entre deux appels
  /// (déclenche le bug "Null check operator" du SDK, issue #2202).
  Future<RtcEngine> _ensureEngine(String appId) async {
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
          debugPrint('👤 Remote left $remoteUid');
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
    debugPrint('✅ Engine initialisé (appId=${appId.substring(0, 6)}…)');
    return engine;
  }

  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid) onUserLeft,
    required void Function(String error) onError,
  }) async {
    // ✅ Anti double-join (arrivée d'appel + accept simultanés)
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

      await engine.joinChannel(
        token: cred.token.trim(),
        channelId: channel,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      debugPrint('✅ joinChannel OK channel=$channel uid=$uid');
    } catch (e, st) {
      // ✅ Stack trace complète pour diagnostic si ça échoue encore
      debugPrint('❌ Agora init/join: $e\n$st');
      onError('agora: $e');
      await leave(); // ✅ leave() au lieu de disposeEngine()
      _joining = false;
      rethrow;
    }

    _joining = false;
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setVideoOff(bool off) async {
    await _engine?.muteLocalVideoStream(off);
    if (!off) {
      await _engine?.enableLocalVideo(true);
      await _engine?.startPreview();
    }
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await _engine?.setEnableSpeakerphone(on);
    } catch (_) {}
  }

  /// ✅ Quitte le channel SANS détruire le moteur (à utiliser entre les appels)
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

  /// ✅ À appeler UNIQUEMENT à la fermeture de l'app (jamais entre 2 appels)
  Future<void> disposeEngine() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _initializedAppId = null;
  }
}
