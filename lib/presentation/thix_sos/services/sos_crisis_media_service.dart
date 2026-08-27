/// Canal caméra de crise — indépendant de l'appel audio THIX.
/// Channel Agora: soscam_{incidentId sans tirets}
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class SosCrisisMediaService {
  SosCrisisMediaService._();
  static final SosCrisisMediaService instance = SosCrisisMediaService._();

  final CallMediaService _media = CallMediaService();

  String? _incidentId;
  String? _channel;
  bool _publishing = false;
  bool _joined = false;
  final Set<int> remoteUids = {};

  final _remoteCtrl = StreamController<Set<int>>.broadcast();
  Stream<Set<int>> get remoteUidsStream => _remoteCtrl.stream;

  String? get channel => _channel;
  bool get isJoined => _joined;
  bool get isPublishing => _publishing;
  RtcEngine? get engine => _media.engine;

  static String channelFor(String incidentId) {
    final compact = incidentId.replaceAll('-', '');
    return 'soscam_$compact';
  }

  int _uidFrom(String userId) {
    var h = 0;
    for (final c in userId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h == 0 ? 1 : h;
  }

  Future<void> _ensurePerms({required bool camera}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted && !kIsWeb) {
      throw Exception('Micro refusé');
    }
    if (camera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted && !kIsWeb) {
        throw Exception('Caméra refusée');
      }
    }
  }

  /// Victime : publie caméra + micro sur le canal crise.
  Future<void> startVictimBroadcast(String incidentId) async {
    await _ensurePerms(camera: true);
    await _join(
      incidentId: incidentId,
      type: CallType.video,
      publishVideo: true,
      publishAudio: true,
    );
    _publishing = true;
  }

  /// Secours : voit / entend la victime. Caméra locale off par défaut.
  Future<void> joinAsResponder(String incidentId) async {
    await _ensurePerms(camera: false);
    await _join(
      incidentId: incidentId,
      type: CallType.video,
      publishVideo: false,
      publishAudio: true,
    );
    _publishing = false;
    await _media.setVideoOff(true);
  }

  Future<void> _join({
    required String incidentId,
    required CallType type,
    required bool publishVideo,
    required bool publishAudio,
  }) async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    if (_joined && _incidentId == incidentId) return;

    if (_joined) await leave();

    _incidentId = incidentId;
    _channel = channelFor(incidentId);
    remoteUids.clear();

    await _media.join(
      channel: _channel!,
      type: type,
      uid: _uidFrom(uid),
      onUserJoined: (remoteUid) {
        remoteUids.add(remoteUid);
        _remoteCtrl.add({...remoteUids});
      },
      onUserLeft: (remoteUid) {
        remoteUids.remove(remoteUid);
        _remoteCtrl.add({...remoteUids});
      },
      onError: (err) => debugPrint('SOS crisis media: $err'),
    );

    if (!publishVideo) {
      await _media.setVideoOff(true);
    }
    if (!publishAudio) {
      await _media.setMuted(true);
    }

    _joined = true;
  }

  Future<void> switchCamera() => _media.switchCamera();

  Future<void> setMuted(bool muted) => _media.setMuted(muted);

  Future<void> setLocalCamera(bool on) async {
    await _media.setVideoOff(!on);
    _publishing = on;
  }

  Future<void> leave() async {
    try {
      await _media.leave();
    } catch (_) {}
    _joined = false;
    _publishing = false;
    _incidentId = null;
    _channel = null;
    remoteUids.clear();
    _remoteCtrl.add({});
  }
}
