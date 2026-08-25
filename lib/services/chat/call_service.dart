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
  bool _joined = false;
  String? _channel;

  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;

  Future<void> _ensurePermissions(CallType type) async {
    // Sur web, permission_handler est limité : on tente quand même
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

  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid) onUserLeft,
    required void Function(String error) onError,
  }) async {
    try {
      await _ensurePermissions(type);
    } catch (e) {
      debugPrint('❌ permissions: $e');
      onError('permission: $e');
      rethrow;
    }

    if (_engine != null) {
      await disposeEngine();
    }

    late final CallTokenResult cred;
    try {
      cred = await CallTokenService().getToken(channel: channel, uid: uid);
      debugPrint(
        '✅ Token OK appId=\( {cred.appId} len= \){cred.appId.length} '
        'channel=\( {cred.channel} uid= \){cred.uid} tokenLen=${cred.token.length}',
      );
    } catch (e) {
      debugPrint('❌ getToken: $e');
      onError('token: $e');
      rethrow;
    }

    if (cred.appId.trim().isEmpty || cred.token.trim().isEmpty) {
      onError('token: appId ou token vide');
      throw Exception('appId ou token vide');
    }

    // App ID Agora = 32 caractères hex en général
    if (cred.appId.trim().length < 10) {
      onError('token: appId suspect (${cred.appId})');
      throw Exception('appId invalide: ${cred.appId}');
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: cred.appId.trim(),
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // ⚠️ Important sur Web : laisser le temps au moteur de démarrer
      await Future.delayed(const Duration(milliseconds: 300));

      await _engine!.enableAudio();
      if (type == CallType.video) {
        await _engine!.enableVideo();
      }
      await _engine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      await _engine!.setEnableSpeakerphone(true);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (conn, elapsed) {
            debugPrint('✅ Joined ${conn.channelId}');
            _joined = true;
          },
          onUserJoined: (conn, remoteUid, elapsed) {
            debugPrint('👤 Remote joined $remoteUid');
            onUserJoined(remoteUid);
          },
          onUserOffline: (conn, remoteUid, reason) {
            debugPrint('👤 Remote left $remoteUid');
            onUserLeft(remoteUid);
          },
          onError: (err, msg) {
            debugPrint('❌ Agora onError code=$err msg=$msg');
            onError('agora: $err $msg');
          },
        ),
      );

      if (type == CallType.video) {
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      } else {
        await _engine!.enableLocalVideo(false);
      }

      _channel = channel;

      await _engine!.joinChannel(
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
    } catch (e) {
      debugPrint('❌ Agora init/join: $e');
      onError('agora: $e');
      await disposeEngine();
      rethrow;
    }
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
    await _engine?.setEnableSpeakerphone(on);
  }

  Future<void> leave() async {
    try {
      await _engine?.stopPreview();
      await _engine?.leaveChannel();
    } catch (_) {}
    _joined = false;
    _channel = null;
  }

  Future<void> disposeEngine() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }
}
