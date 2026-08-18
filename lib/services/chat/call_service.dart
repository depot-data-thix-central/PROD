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
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw Exception('Micro refusé');

    if (type == CallType.video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) throw Exception('Caméra refusée');
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
    await _ensurePermissions(type);

    // Toujours repartir propre (évite handlers empilés + preview morte)
    if (_engine != null) {
      await disposeEngine();
    }

    final cred = await CallTokenService().getToken(channel: channel, uid: uid);

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: cred.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    await _engine!.enableAudio();
    await _engine!.enableVideo();
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
          debugPrint('❌ Agora error $err $msg');
          onError('$err: $msg');
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
      token: cred.token,
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
    );
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
