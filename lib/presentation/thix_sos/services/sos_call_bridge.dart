// lib/presentation/thix_sos/services/sos_call_bridge.dart

/// Pont SOS → THIX Chat + appels.
/// Chat TOUJOURS créé (même 0 membre résolu). Agora caméra reporté hors trigger.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_models.dart';
import 'sos_crisis_media_service.dart';
import 'sos_service.dart';
import 'sos_victim_capture_daemon.dart';

const Duration _kChatTimeout = Duration(seconds: 12);
const Duration _kCallTimeout = Duration(seconds: 10);
const Duration _kPhoneTimeout = Duration(seconds: 5);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxPhoneLength = 20;
const int _kMaxNameLength = 80;

class _BridgeValidators {
  _BridgeValidators._();

  static String safeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Unknown';
    final trimmed = name.trim();
    if (trimmed.length <= _kMaxNameLength) return trimmed;
    return '${trimmed.substring(0, _kMaxNameLength)}…';
  }

  static String safePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length <= 5) return '***';
    return '\( {cleaned.substring(0, 3)}*** \){cleaned.substring(cleaned.length - 2)}';
  }

  static String sanitizePayload(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    final trimmed = input.trim();
    if (trimmed.length > maxLength) return trimmed.substring(0, maxLength);
    return trimmed;
  }

  static bool isValidPhone(String? phone) {
    if (phone == null) return false;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 6 && cleaned.length <= _kMaxPhoneLength;
  }
}

Future<T> _bridgeRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kChatTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosBridge] ❌ $label: timeout after $attempt');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosBridge] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

class SosCallBridge {
  SosCallBridge({
    SosService? sos,
    CallSignalingService? signaling,
  })  : _sos = sos ?? SosService(),
        _signaling = signaling ?? CallSignalingService();

  final SosService _sos;
  final CallSignalingService _signaling;
  bool _isActivating = false;

  /// 1) Groupe Chat TOUJOURS (cercles 1+2+3)
  /// 2) Event SOS_STARTED pour ouvrir la chambre secours
  /// 3) Appels cercle 1 en parallèle
  /// 4) Daemon capture (sans Agora au trigger)
  Future<SosActivationResult> activateProtocol(SosIncident incident) async {
    if (_isActivating) {
      debugPrint('[SosBridge] ⚠️ Activation already in progress');
      return SosActivationResult(
        incident: incident,
        conversationId: incident.chatConversationId,
        calls: const [],
      );
    }
    _isActivating = true;

    String? conversationId = incident.chatConversationId;

    try {
      final allContacts = await _sos.getContactsAllCircles();
      final circle1 =
          allContacts.where((c) => c.circle == 1).toList(growable: false);

      final userIds = await _sos.resolveAllCircleUserIds(allContacts);
      final circle1Ids = await _sos.resolveAllCircleUserIds(circle1);

      debugPrint(
        '[SosBridge] protocol contacts=${allContacts.length} '
        'resolved=\( {userIds.length} c1= \){circle1.length}',
      );

      // Chat : toujours, même 0 membre résolu (victime seule).
      try {
        conversationId = await _bridgeRetry(
          () => _sos.createSosChat(
            incidentId: incident.id,
            publicId: incident.publicId,
            participantUserIds: userIds,
          ),
          label: 'createSosChat',
          timeout: _kChatTimeout,
        );
        debugPrint('[SosBridge] ✓ Chat SOS $conversationId');
      } catch (e) {
        debugPrint('[SosBridge] ❌ Chat SOS failed: $e');
      }

      // Daemon avant les appels : les CMD_* marchent même si l'appel rate.
      try {
        await SosVictimCaptureDaemon.instance.start(
          incidentId: incident.id,
          conversationId: conversationId,
        );
      } catch (e) {
        debugPrint('[SosBridge] daemon: $e');
      }

      // SOS_STARTED : déclenche GlobalSosListener côté secours.
      try {
        await _sos.logEventPublic(incident.id, 'SOS_STARTED', {
          'circle1_user_ids': circle1Ids,
          'all_user_ids': userIds,
          'victim_id': SupabaseConfig.currentUser?.id,
          'public_id': incident.publicId,
          'conversation_id': conversationId,
        });
      } catch (e) {
        debugPrint('[SosBridge] SOS_STARTED: $e');
      }

      List<SosCallAttempt> calls = const [];
      try {
        calls = await callCircle(
          incident: incident,
          circle: 1,
          contacts: circle1,
        );
      } catch (e) {
        debugPrint('[SosBridge] calls: $e');
      }

      // Caméra live : NE PAS démarrer ici (timeout bouton + sos_error_camera).
      // La chambre de crise victime lance Agora à l'ouverture.

      return SosActivationResult(
        incident: incident,
        conversationId: conversationId,
        calls: calls,
      );
    } catch (e, stack) {
      debugPrint('[SosBridge] ❌ activateProtocol failed: $e\n$stack');
      return SosActivationResult(
        incident: incident,
        conversationId: conversationId,
        calls: const [],
      );
    } finally {
      _isActivating = false;
    }
  }

  Future<List<SosCallAttempt>> callCircle({
    required SosIncident incident,
    required int circle,
    required List<SosContact> contacts,
  }) async {
    if (contacts.isEmpty) return const [];
    final futures = contacts.map((contact) => _callOneContact(
          incident: incident,
          circle: circle,
          contact: contact,
        ));
    return Future.wait(futures);
  }

  Future<void> _cleanupOnError(
    String incidentId,
    String? conversationId,
    bool cameraStarted,
  ) async {
    try {
      if (cameraStarted) {
        await SosCrisisMediaService.instance.leave();
      }
    } catch (_) {}
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final res = await Permission.camera.request();
      return res.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Optionnel : à appeler depuis la chambre de crise, PAS depuis le bouton SOS.
  Future<void> startCrisisCamera(String incidentId) async {
    if (kIsWeb) return;
    final hasCam = await _ensureCameraPermission();
    if (!hasCam) {
      await _sos.logEventPublic(incidentId, 'CAMERA_CHANNEL_FAILED', {
        'error': 'permission_denied',
      });
      return;
    }
    await SosCrisisMediaService.instance.startVictimBroadcast(incidentId);
    await _sos.logEventPublic(incidentId, 'CAMERA_CHANNEL_READY', {
      'channel': SosCrisisMediaService.channelFor(incidentId),
      'mode': 'victim_broadcast',
    });
  }

  Future<SosCallAttempt> _callOneContact({
    required SosIncident incident,
    required int circle,
    required SosContact contact,
  }) async {
    final safeName = _BridgeValidators.safeName(contact.name);
    final calleeId = await _sos.resolveContactUserId(contact);

    if (calleeId != null && calleeId.isNotEmpty) {
      try {
        final invite = await _bridgeRetry(
          () => _signaling.startCall(
            calleeId: calleeId,
            type: CallType.audio,
          ),
          label: 'startCall[$safeName]',
          timeout: _kCallTimeout,
        );

        await _sos.logEventPublic(incident.id, 'CALL_STARTED', {
          'circle': circle,
          'contact_hash': base64Encode(utf8.encode(safeName)).substring(0, 8),
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
      } catch (e) {
        await _sos.logEventPublic(incident.id, 'CALL_FAILED', {
          'circle': circle,
          'mode': 'thix_audio',
          'error': _BridgeValidators.sanitizePayload(e.toString(), maxLength: 100),
        });
      }
    }

    final phone = contact.phone?.trim();
    if (_BridgeValidators.isValidPhone(phone)) {
      final ok = await _launchPhone(phone!);
      await _sos.logEventPublic(
        incident.id,
        ok ? 'CALL_PHONE_LAUNCHED' : 'CALL_PHONE_FAILED',
        {
          'circle': circle,
          'phone_masked': _BridgeValidators.safePhone(phone),
          'mode': 'native_phone',
        },
      );
      return SosCallAttempt(
        contactName: contact.name,
        circle: circle,
        success: ok,
        mode: SosCallMode.nativePhone,
        error: ok ? null : 'Impossible d\'ouvrir l\'appel téléphonique',
      );
    }

    await _sos.logEventPublic(incident.id, 'CALL_SKIPPED', {
      'circle': circle,
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
    if (kIsWeb) return false;
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || !_BridgeValidators.isValidPhone(cleaned)) {
      return false;
    }
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final canLaunch = await canLaunchUrl(uri).timeout(_kPhoneTimeout);
      if (!canLaunch) return false;
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).timeout(_kPhoneTimeout);
    } catch (_) {
      return false;
    }
  }
}

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
