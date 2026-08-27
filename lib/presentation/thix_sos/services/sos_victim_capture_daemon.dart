// lib/presentation/thix_sos/services/sos_victim_capture_daemon.dart
import 'package:flutter/foundation.dart';

import 'sos_remote_capture_service.dart';

/// Daemon côté VICTIME : exécute les commandes du secours en arrière-plan,
/// même si la victime n'a ouvert aucune page.
class SosVictimCaptureDaemon {
  SosVictimCaptureDaemon._();
  static final SosVictimCaptureDaemon instance = SosVictimCaptureDaemon._();

  final SosRemoteCaptureService _remote = SosRemoteCaptureService.instance;
  String? _incidentId;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start({
    required String incidentId,
    String? conversationId,
  }) async {
    if (_running && _incidentId == incidentId) return;
    _incidentId = incidentId;
    _running = true;

    debugPrint('🛰️ SosVictimCaptureDaemon START incident=$incidentId');

    _remote.listenAsVictim(
      incidentId: incidentId,
      conversationId: conversationId,
      onInfo: (m) => debugPrint('🛰️ capture: $m'),
      onError: (e) => debugPrint('🛰️ capture error: $e'),
    );
  }

  void stop() {
    if (!_running) return;
    _remote.stop();
    _running = false;
    _incidentId = null;
    debugPrint('🛰️ SosVictimCaptureDaemon STOP');
  }
}
