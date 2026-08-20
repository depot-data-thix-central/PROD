/// Pont SOS → THIX Chat + Call (Agora / rpc_start_call) — production
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

  /// Protocole complet au déclenchement SOS :
  /// 1) Chat groupe SOS
  /// 2) Appels audio vers Cercle 1
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
    } else {
      debugPrint('SosCallBridge: aucun user_id cercle 1 — chat non créé');
    }

    final calls = await callCircle(
      incident: incident,
      contacts: contacts,
    );

    return SosActivationResult(
      incident: incident,
      conversationId: conversationId,
      calls: calls.calls,
    );
  }

  /// Appelle tous les secours d'un cercle (1, 2 ou 3)
  Future<SosActivationResult> callCircle({
    required SosIncident incident,
    required List<SosContact> contacts,
  }) async {
    final callResults = <SosCallAttempt>[];

    if (contacts.isEmpty) {
      debugPrint(
        'SosCallBridge.callCircle: aucun contact cercle ${incident.activeCircle}',
      );
      return SosActivationResult(
        incident: incident,
        conversationId: null,
        calls: callResults,
      );
    }

    for (final c in contacts) {
      final calleeId = await _sos.resolveContactUserId(c);
      if (calleeId == null || calleeId.isEmpty) {
        callResults.add(
          SosCallAttempt(
            contactName: c.name,
            success: false,
            error: 'Pas de compte THIX lié',
          ),
        );
        await _sos.logEventPublic(incident.id, 'CALL_SKIPPED', {
          'circle': incident.activeCircle,
          'contact': c.name,
          'reason': 'no_thix_user',
        });
        continue;
      }

      try {
        final invite = await _signaling.startCall(
          calleeId: calleeId,
          type: CallType.audio,
        );

        callResults.add(
          SosCallAttempt(
            contactName: c.name,
            success: true,
            inviteId: invite.id,
            channelName: invite.channelName,
          ),
        );

        await _sos.logEventPublic(incident.id, 'CALL_STARTED', {
          'circle': incident.activeCircle,
          'contact': c.name,
          'contact_user_id': calleeId,
          'invite_id': invite.id,
          'channel': invite.channelName,
        });
      } catch (e, st) {
        debugPrint('SosCallBridge.callCircle ${c.name}: $e\n$st');
        callResults.add(
          SosCallAttempt(
            contactName: c.name,
            success: false,
            error: e.toString(),
          ),
        );
        await _sos.logEventPublic(incident.id, 'CALL_FAILED', {
          'circle': incident.activeCircle,
          'contact': c.name,
          'error': e.toString(),
        });
      }
    }

    return SosActivationResult(
      incident: incident,
      conversationId: null,
      calls: callResults,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Résultats
// ─────────────────────────────────────────────────────────────

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

  int get ringingCount => calls.where((c) => c.success).length;

  int get failedCount => calls.where((c) => !c.success).length;

  /// Alias rétrocompat
  int get answeredOrRinging => ringingCount;
}
