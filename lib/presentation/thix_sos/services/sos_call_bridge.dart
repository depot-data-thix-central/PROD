/// Pont SOS → THIX Call (Agora / rpc_start_call)
import 'package:flutter/foundation.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

import '../models/sos_models.dart';
import 'sos_service.dart';

class SosCallBridge {
  SosCallBridge({
    SosService? sos,
    CallSignalingService? signaling,
  })  : _sos = sos ?? SosService(),
        _signaling = signaling ?? CallSignalingService();

  final SosService _sos;
  final CallSignalingService _signaling;

  /// Après trigger SOS : chat + appels cercle 1
  Future<SosActivationResult> activateProtocol(SosIncident incident) async {
    final contacts = await _sos.getContactsByCircle(1);
    final userIds = <String>[];

    for (final c in contacts) {
      final id = await _sos.resolveContactUserId(c);
      if (id != null && id.isNotEmpty) userIds.add(id);
    }

    String? conversationId;
    if (userIds.isNotEmpty) {
      conversationId = await _sos.createSosChat(
        incidentId: incident.id,
        publicId: incident.publicId,
        participantUserIds: userIds,
      );
    }

    final callResults = <SosCallAttempt>[];

    for (final c in contacts) {
      final calleeId = await _sos.resolveContactUserId(c);
      if (calleeId == null) {
        callResults.add(SosCallAttempt(
          contactName: c.name,
          success: false,
          error: 'Pas de compte THIX lié',
        ));
        continue;
      }

      try {
        final invite = await _signaling.startCall(
          calleeId: calleeId,
          type: CallType.audio,
        );
        callResults.add(SosCallAttempt(
          contactName: c.name,
          success: true,
          inviteId: invite.id,
          channelName: invite.channelName,
        ));
        await _sos./* private log via public method if needed */ 
            getEvents(incident.id); // no-op keep
      } catch (e) {
        debugPrint('SosCallBridge call ${c.name}: $e');
        callResults.add(SosCallAttempt(
          contactName: c.name,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return SosActivationResult(
      incident: incident,
      conversationId: conversationId,
      calls: callResults,
    );
  }
}

class SosCallAttempt {
  final String contactName;
  final bool success;
  final String? inviteId;
  final String? channelName;
  final String? error;

  const SosCallAttempt({
    required this.contactName,
    required this.success,
    this.inviteId,
    this.channelName,
    this.error,
  });
}

class SosActivationResult {
  final SosIncident incident;
  final String? conversationId;
  final List<SosCallAttempt> calls;

  const SosActivationResult({
    required this.incident,
    this.conversationId,
    required this.calls,
  });

  int get answeredOrRinging => calls.where((c) => c.success).length;
}
