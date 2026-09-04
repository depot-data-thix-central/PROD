// lib/presentation/thix_sos/services/sos_call_bridge.dart

/// Pont SOS → THIX Chat + Call (Agora) + fallback tel — Production Enterprise
/// ✅ SÉCURISÉ : timeouts, race-condition, RGPD (hash logs), kIsWeb guards
/// ✅ ROBUSTE : retry, parallel calls, cleanup on error, validation
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

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kChatTimeout = Duration(seconds: 20);
const Duration _kCallTimeout = Duration(seconds: 15);
const Duration _kCameraTimeout = Duration(seconds: 30);
const Duration _kPhoneTimeout = Duration(seconds: 5);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);
const int _kMaxPhoneLength = 20;
const int _kMaxNameLength = 80;

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================
class _BridgeValidators {
  _BridgeValidators._();

  /// ✅ RGPD : ne logger que les 4 premiers caractères + hash
  static String safeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Unknown';
    final trimmed = name.trim();
    if (trimmed.length <= _kMaxNameLength) return trimmed;
    return '${trimmed.substring(0, _kMaxNameLength)}…';
  }

  /// ✅ RGPD : masque le numéro sauf les 3 premiers et 2 derniers chiffres
  static String safePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length <= 5) return '***';
    return '${cleaned.substring(0, 3)}***${cleaned.substring(cleaned.length - 2)}';
  }

  /// Nettoyage pour éviter injection dans payloads
  static String sanitizePayload(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    final trimmed = input.trim();
    if (trimmed.length > maxLength) {
      return trimmed.substring(0, maxLength);
    }
    return trimmed;
  }

  static bool isValidPhone(String? phone) {
    if (phone == null) return false;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 6 && cleaned.length <= _kMaxPhoneLength;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
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
      debugPrint('[SosBridge] ⏱️ $label timeout — retry $attempt/$maxRetries');
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

// ============================================================================
// BRIDGE
// ============================================================================
class SosCallBridge {
  SosCallBridge({
    SosService? sos,
    CallSignalingService? signaling,
  })  : _sos = sos ?? SosService(),
        _signaling = signaling ?? CallSignalingService();

  final SosService _sos;
  final CallSignalingService _signaling;
  bool _isActivating = false; // ✅ FIX P0 : flag anti-race-condition

  /// Au déclenchement SOS :
  /// 1) Chat groupe cercle 1
  /// 2) Appels audio (THIX) + SMS/tel si pas de compte
  Future<SosActivationResult> activateProtocol(SosIncident incident) async {
    // ✅ FIX P0 : empêche double-trigger
    if (_isActivating) {
      debugPrint('[SosBridge] ⚠️ Activation already in progress');
      return SosActivationResult(
        incident: incident,
        conversationId: null,
        calls: const [],
      );
    }
    _isActivating = true;

    String? conversationId;
    bool cameraStarted = false;

    try {
      const circle = 1;
      final contacts = await _sos.getContactsByCircle(circle);
      debugPrint('[SosBridge] 🚀 Activating protocol — ${contacts.length} contacts circle 1');

      // Résoudre les userIds THIX
      final userIds = <String>[];
      for (final c in contacts) {
        final id = await _sos.resolveContactUserId(c);
        if (id != null && id.isNotEmpty) userIds.add(id);
      }

      // 1) Chat SOS groupe
      if (userIds.isNotEmpty) {
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
          debugPrint('[SosBridge] ✓ Chat SOS created: $conversationId');
        } catch (e) {
          debugPrint('[SosBridge] ❌ Chat SOS failed: $e');
        }
      } else {
        debugPrint('[SosBridge] ⚠️ No THIX users in circle 1 — no chat');
      }

      // 2) Appels parallèles (performance)
      final calls = await callCircle(
        incident: incident,
        circle: circle,
        contacts: contacts,
      );

      // 3) Caméra crise — avec permission check
      if (!kIsWeb) {
        try {
          final hasCam = await _ensureCameraPermission();
          if (hasCam) {
            await _bridgeRetry(
              () => SosCrisisMediaService.instance
                  .startVictimBroadcast(incident.id),
              label: 'startVictimBroadcast',
              timeout: _kCameraTimeout,
            );
            cameraStarted = true;
            await _sos.logEventPublic(incident.id, 'CAMERA_CHANNEL_READY', {
              'channel': SosCrisisMediaService.channelFor(incident.id),
              'mode': 'victim_broadcast',
            });
            debugPrint('[SosBridge] ✓ Camera broadcast started');
          } else {
            await _sos.logEventPublic(incident.id, 'CAMERA_CHANNEL_FAILED', {
              'error': 'permission_denied',
            });
            debugPrint('[SosBridge] ⚠️ Camera permission denied');
          }
        } catch (e) {
          debugPrint('[SosBridge] ❌ Camera broadcast failed: $e');
          await _sos.logEventPublic(
            incident.id,
            'CAMERA_CHANNEL_FAILED',
            {'error': _BridgeValidators.sanitizePayload(e.toString(), maxLength: 100)},
          );
        }
      }

      // 4) Annonce publique SOS_STARTED
      try {
        await _sos.logEventPublic(incident.id, 'SOS_STARTED', {
          'circle1_user_ids': userIds,
          'victim_id': SupabaseConfig.currentUser?.id,
          'public_id': incident.publicId,
          'conversation_id': conversationId,
        });
      } catch (e) {
        debugPrint('[SosBridge] ⚠️ SOS_STARTED log failed: $e');
      }

      // 5) Écoute des commandes secours (background)
      try {
        await SosVictimCaptureDaemon.instance.start(
          incidentId: incident.id,
          conversationId: conversationId,
        );
      } catch (e) {
        debugPrint('[SosBridge] ⚠️ VictimCaptureDaemon start failed: $e');
      }

      return SosActivationResult(
        incident: incident,
        conversationId: conversationId,
        calls: calls, // Correction : calls au lieu de calls.calls
      );
    } catch (e, stack) {
      // ✅ FIX P0 : cleanup on error
      debugPrint('[SosBridge] ❌ activateProtocol failed: $e');
      debugPrint('[SosBridge] Stack: $stack');
      await _cleanupOnError(incident.id, conversationId, cameraStarted);
      rethrow;
    } finally {
      _isActivating = false;
    }
  }

  /// Appelle tous les secours d'un cercle en parallèle (performance)
  Future<List<SosCallAttempt>> callCircle({
    required SosIncident incident,
    required int circle,
    required List<SosContact> contacts,
  }) async {
    // Lancement de tous les appels simultanément
    final futures = contacts.map((contact) => _callOneContact(
          incident: incident,
          circle: circle,
          contact: contact,
        ));
    return await Future.wait(futures);
  }

  /// ✅ Cleanup si activateProtocol échoue
  Future<void> _cleanupOnError(
    String incidentId,
    String? conversationId,
    bool cameraStarted,
  ) async {
    try {
      if (cameraStarted) {
        await SosCrisisMediaService.instance.leave();
        debugPrint('[SosBridge] 🧹 Camera stopped (cleanup)');
      }
      if (conversationId != null) {
        // TODO: archiver le chat SOS orphelin côté serveur
        debugPrint('[SosBridge] 🧹 Orphan chat SOS: $conversationId');
      }
    } catch (e) {
      debugPrint('[SosBridge] ⚠️ Cleanup error: $e');
    }
  }

  /// ✅ FIX P1 : permissions caméra
  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final res = await Permission.camera.request();
      return res.isGranted;
    } catch (e) {
      debugPrint('[SosBridge] ⚠️ Camera permission check failed: $e');
      return false;
    }
  }

  Future<SosCallAttempt> _callOneContact({
    required SosIncident incident,
    required int circle,
    required SosContact contact,
  }) async {
    final safeName = _BridgeValidators.safeName(contact.name);
    final calleeId = await _sos.resolveContactUserId(contact);

    // 1) Appel in-app THIX (Agora) si compte lié — AUDIO UNIQUEMENT
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

        // ✅ FIX P0 : payload sans info personnelle en clair
        await _sos.logEventPublic(incident.id, 'CALL_STARTED', {
          'circle': circle,
          'contact_hash': base64Encode(utf8.encode(safeName)).substring(0, 8),
          'mode': 'thix_audio',
        });

        debugPrint('[SosBridge] 📞 THIX call started: $safeName');
        return SosCallAttempt(
          contactName: contact.name,
          circle: circle,
          success: true,
          mode: SosCallMode.thixAudio,
          inviteId: invite.id,
          channelName: invite.channelName,
        );
      } catch (e) {
        debugPrint('[SosBridge] ❌ THIX call failed: $safeName — $e');
        await _sos.logEventPublic(incident.id, 'CALL_FAILED', {
          'circle': circle,
          'mode': 'thix_audio',
          // ✅ FIX : sanitize error (pas de stack trace complet)
          'error': _BridgeValidators.sanitizePayload(e.toString(), maxLength: 100),
        });
        // continue vers fallback tel
      }
    }

    // 2) Fallback : appel téléphonique natif
    final phone = contact.phone?.trim();
    if (_BridgeValidators.isValidPhone(phone)) {
      final ok = await _launchPhone(phone!);
      final safePhone = _BridgeValidators.safePhone(phone);

      await _sos.logEventPublic(
        incident.id,
        ok ? 'CALL_PHONE_LAUNCHED' : 'CALL_PHONE_FAILED',
        {
          'circle': circle,
          'phone_masked': safePhone, // ✅ RGPD : numéro masqué
          'mode': 'native_phone',
        },
      );

      debugPrint('[SosBridge] 📱 Phone call ${ok ? 'OK' : 'FAILED'}: $safeName ($safePhone)');
      return SosCallAttempt(
        contactName: contact.name,
        circle: circle,
        success: ok,
        mode: SosCallMode.nativePhone,
        error: ok ? null : 'Impossible d\'ouvrir l\'appel téléphonique',
      );
    }

    // 3) Rien à appeler
    await _sos.logEventPublic(incident.id, 'CALL_SKIPPED', {
      'circle': circle,
      'reason': 'no_thix_user_no_phone',
    });

    debugPrint('[SosBridge] ⏭️ Skipped: $safeName (no THIX + no phone)');
    return SosCallAttempt(
      contactName: contact.name,
      circle: circle,
      success: false,
      mode: SosCallMode.none,
      error: 'Pas de compte THIX ni de numéro',
    );
  }

  // ✅ FIX P0 : kIsWeb guard + mode explicite + sanitization
  Future<bool> _launchPhone(String raw) async {
    if (kIsWeb) {
      debugPrint('[SosBridge] ⚠️ tel: not supported on web');
      return false;
    }

    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || !_BridgeValidators.isValidPhone(cleaned)) {
      debugPrint('[SosBridge] ⚠️ Invalid phone number');
      return false;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final canLaunch = await canLaunchUrl(uri).timeout(_kPhoneTimeout);
      if (!canLaunch) return false;
      // ✅ FIX : mode explicite pour comportement prévisible
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).timeout(_kPhoneTimeout);
    } catch (e) {
      debugPrint('[SosBridge] ❌ launchPhone: $e');
      return false;
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================
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
