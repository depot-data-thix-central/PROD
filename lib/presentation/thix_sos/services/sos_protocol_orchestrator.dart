// lib/presentation/thix_sos/services/sos_protocol_orchestrator.dart
/// Orchestre le protocole SOS en fond : chat + SOS_STARTED + daemon + appels.
/// Idempotent : relancer n'écrase pas un chat déjà lié à l'incident.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sos_models.dart';
import 'sos_call_bridge.dart';
import 'sos_media_outbox.dart';
import 'sos_service.dart';
import 'sos_victim_capture_daemon.dart';

class SosProtocolOrchestrator {
  SosProtocolOrchestrator({
    SosService? sos,
    SosCallBridge? bridge,
  })  : _sos = sos ?? SosService(),
        _bridge = bridge ?? SosCallBridge(sos: sos);

  final SosService _sos;
  final SosCallBridge _bridge;

  static final _running = <String>{};

  Future<SosActivationResult> run(SosIncident incident) async {
    if (_running.contains(incident.id)) {
      debugPrint('[SosOrch] already running ${incident.id}');
      return SosActivationResult(
        incident: incident,
        conversationId: incident.chatConversationId,
        calls: const [],
      );
    }
    _running.add(incident.id);
    try {
      final result = await _bridge.activateProtocol(incident);
      final conv = result.conversationId ?? incident.chatConversationId;

      if (conv != null && conv.isNotEmpty) {
        try {
          await SosVictimCaptureDaemon.instance.start(
            incidentId: incident.id,
            conversationId: conv,
          );
        } catch (e) {
          debugPrint('[SosOrch] daemon: $e');
        }
        unawaited(SosMediaOutbox.instance.flush(incident.id, conv));
      }
      return result;
    } catch (e) {
      debugPrint('[SosOrch] $e');
      return SosActivationResult(
        incident: incident,
        conversationId: incident.chatConversationId,
        calls: const [],
      );
    } finally {
      _running.remove(incident.id);
    }
  }
}
