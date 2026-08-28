import 'package:flutter/foundation.dart';

import 'sos_remote_capture_service.dart';

/// Daemon victime : écoute les CMD_* dès que le SOS est actif.
class SosVictimCaptureDaemon {
  SosVictimCaptureDaemon._();
  static final SosVictimCaptureDaemon instance = SosVictimCaptureDaemon._();

  String? _incidentId;

  Future<void> start({
    required String incidentId,
    String? conversationId,
    void Function(String msg)? onInfo,
    void Function(Object err)? onError,
  }) async {
    if (_incidentId == incidentId) return;
    stop();
    _incidentId = incidentId;
    debugPrint('SosVictimCaptureDaemon start $incidentId');
    SosRemoteCaptureService.instance.listenAsVictim(
      incidentId: incidentId,
      conversationId: conversationId,
      onInfo: onInfo,
      onError: onError,
    );
  }

  void stop() {
    SosRemoteCaptureService.instance.stop();
    _incidentId = null;
  }
}
