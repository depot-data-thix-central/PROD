// lib/services/voip_call_service.dart
//
// VoipCallService — v3.0 (DEPRECATED wrapper)
//
// Ce service est un FAÇADE autour de _VoipCallManager (PushNotificationService).
// Il ne doit PLUS :
//  - initialiser CallKit (déjà fait par PushNotificationService)
//  - jouer de sonnerie / vibration (CallKit gère le natif)
//  - écouter onEvent (déjà branché dans PushNotificationService)
//
// À terme : supprimer ce fichier et migrer tous les appels vers
//           PushNotificationService.instance.endVoipCall / endAllVoipCalls.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:thix_id/services/push_notification_service.dart';

/// Wrapper déprécié autour de PushNotificationService pour compatibilité.
/// Préférez directement PushNotificationService.instance.
class VoipCallService {
  VoipCallService._();
  static final VoipCallService instance = VoipCallService._();

  /// No-op : CallKit est déjà initialisé par PushNotificationService.
  Future<void> initialize() async {
    debugPrint('[VoipCallService] ⚠️ initialize() no-op — '
        'utiliser PushNotificationService.instance');
  }

  /// Affiche un appel entrant via CallKit.
  Future<void> showIncomingCall({
    required String inviteId,
    required String callerName,
    required String callerAvatar,
    required String channelName,
    bool isVideo = false,
  }) async {
    debugPrint('[VoipCallService] showIncomingCall: $callerName');
    // Délégation impossible depuis l'extérieur de push_notification_service_io.dart
    // (classe privée _VoipCallManager). Ce wrapper ne doit plus être appelé :
    // le push FCM data-only fait tout automatiquement.
    debugPrint('[VoipCallService] ⚠️ Utilisation dépréciée. '
        'Envoyer un push FCM type=incoming_call à la place.');
  }

  /// Termine un appel.
  Future<void> endCall(String inviteId) async {
    await PushNotificationService.instance.endVoipCall(inviteId);
  }

  /// Termine tous les appels.
  Future<void> endAllCalls() async {
    await PushNotificationService.instance.endAllVoipCalls();
  }

  /// No-op : la sonnerie est gérée nativement par CallKit.
  Future<void> stopRinging() async {
    debugPrint('[VoipCallService] stopRinging() no-op (natif CallKit)');
  }
}
