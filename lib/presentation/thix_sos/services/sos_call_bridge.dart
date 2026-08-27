/// Pont SOS → THIX Chat + Call (Agora) + fallback tel — production
import 'package:flutter/foundation.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_models.dart';
import 'sos_crisis_media_service.dart';
import 'sos_service.dart';

class SosCallBridge {
  SosCallBridge({
    SosService? sos,
    CallSignalingService? signaling,
  })  : _sos = sos ?? SosService(),
        _signaling = signaling ?? CallSignalingService();

  final SosService _sos;
  final CallSignalingService _signaling;

  /// Au déclenchement SOS :
  /// 1) Chat groupe cercle 1
  /// 2) Appels audio (THIX) + SMS/tel si pas de compte
  Future<SosActivationResult> activateProtocol(SosIncident incident) async {
    const circle = 1;
    final contacts = await _sos.getContactsByCircle(circle);

    // Résoudre les userIds THIX
    final userIds = <String>[];
    for (final c in contacts) {
      final id = await _sos.resolveContactUserId(c);
      if (id != null && id.isNotEmpty) userIds.add(id);
    }

    String? conversationId;
    if (userIds.isNotEmpty) {
      try {
        conversationId = await _sos.createSosChat(
          incidentId: incident.id,
          publicId: incident.publicId,
          participantUserIds: userIds,
        );
      } catch (e) {
        debugPrint('SosCallBridge: chat SOS échoué: $e');
      }
    } else {
      debugPrint('SosCallBridge: aucun user THIX cercle 1 — pas de chat');
    }

    final calls = await callCircle(
      incident: incident,
      circle: circle,
      contacts: contacts,
    );

    // Caméra crise (indépendante de l'appel audio 1-1)
    try {
      await SosCrisisMediaService.instance.startVictimBroadcast(incident.id);
      await _sos.logEventPublic(incident.id, 'CAMERA_CHANNEL_READY', {
        'channel': SosCrisisMediaService.channelFor(incident.id),
        'mode': 'victim_broadcast',
      });
    } catch (e) {
      debugPrint('SosCallBridge: camera crise échouée: $e');
      await _sos.logEventPublic(incident.id, 'CAMERA_CHANNEL_FAILED', {
        'error': e.toString(),
      });
    }

    return SosActivationResult(
      incident: incident,
      conversationId: conversationId,
      calls: calls.calls,
    );
  }

  /// Appelle tous les secours d’un cercle (1, 2 ou 3)
  Future<SosActivationResult> callCircle({
    required SosIncident incident,
    required int circle,
    required List<SosContact> contacts,
  }) async {
    final callResults = <SosCallAttempt>[];

    if (contacts.isEmpty) {
      debugPrint('SosCallBridge.callCircle: aucun contact cercle $circle');
      await _sos.logEventPublic(incident.id, 'CALL_CIRCLE_EMPTY', {
        'circle': circle,
      });
      return SosActivationResult(
        incident: incident,
        conversationId: null,
        calls: callResults,
      );
    }

    // Marquer le statut incident (côté service si dispo)
    try {
      await _sos.escalateToCircle(incident.id, circle);
    } catch (_) {}

    for (final c in contacts) {
      final attempt = await _callOneContact(
        incident: incident,
        circle: circle,
        contact: c,
      );
      callResults.add(attempt);
    }

    return SosActivationResult(
      incident: incident,
      conversationId: null,
      calls: callResults,
    );
  }

  Future<SosCallAttempt> _callOneContact({
    required SosIncident incident,
    required int circle,
    required SosContact contact,
  }) async {
    final calleeId = await _sos.resolveContactUserId(contact);

    // 1) Appel in-app THIX (Agora) si compte lié — AUDIO UNIQUEMENT
    if (calleeId != null && calleeId.isNotEmpty) {
      try {
        final invite = await _signaling.startCall(
          calleeId: calleeId,
          type: CallType.audio,
        );

        await _sos.logEventPublic(incident.id, 'CALL_STARTED', {
          'circle': circle,
          'contact': contact.name,
          'contact_user_id': calleeId,
          'invite_id': invite.id,
          'channel': invite.channelName,
          'mode': 'thix_audio',
        });

        return SosCallAttempt(
          contactName: contact.name,
          circle: circle,
          success: true,
          mode: SosCallMode.thixAudio,
          inviteId: invite.id,
          channelName: invite.channelName,
        );
      } catch (e, st) {
        debugPrint('SosCallBridge THIX call ${contact.name}: $e\n$st');
        await _sos.logEventPublic(incident.id, 'CALL_FAILED', {
          'circle': circle,
          'contact': contact.name,
          'mode': 'thix_audio',
          'error': e.toString(),
        });
        // continue vers fallback tel
      }
    }

    // 2) Fallback : ouvrir l’appel téléphonique natif
    final phone = contact.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final ok = await _launchPhone(phone);
      await _sos.logEventPublic(
        incident.id,
        ok ? 'CALL_PHONE_LAUNCHED' : 'CALL_PHONE_FAILED',
        {
          'circle': circle,
          'contact': contact.name,
          'phone': phone,
          'mode': 'native_phone',
        },
      );
      return SosCallAttempt(
        contactName: contact.name,
        circle: circle,
        success: ok,
        mode: SosCallMode.nativePhone,
        error: ok ? null : 'Impossible d’ouvrir l’appel téléphonique',
      );
    }

    // 3) Rien à appeler
    await _sos.logEventPublic(incident.id, 'CALL_SKIPPED', {
      'circle': circle,
      'contact': contact.name,
      'reason': 'no_thix_user_no_phone',
    });

    return SosCallAttempt(
      contactName: contact.name,
      circle: circle,
      success: false,
      mode: SosCallMode.none,
      error: 'Pas de compte THIX ni de numéro',
    );
  }

  Future<bool> _launchPhone(String raw) async {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri);
      }
    } catch (e) {
      debugPrint('launchPhone: $e');
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────

enum SosCallMode { thixAudio, nativePhone, none }

class SosCallAttempt {
  final String contactName;
  final int circle;
  final bool success;
  final SosCallMode mode;
  final String? inviteId;
  final String? channelName;
  final String? error;

  const SosCallAttempt({
    required this.contactName,
    this.circle = 1,
    required this.success,
    this.mode = SosCallMode.thixAudio,
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
  int get answeredOrRinging => ringingCount;
}
