// lib/services/push_notification_service_stub.dart
//
// Stub Web — Toutes les méthodes VoIP/Badge sont des no-op.
// La gestion FCM sur Web passe par le service worker JS (firebase-messaging-sw.js),
// hors du code Dart compilé.

import 'package:flutter/foundation.dart';

/// Handler FCM background — no-op sur Web (géré par firebase-messaging-sw.js)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // ── Callbacks VoIP (no-op sur Web) ────────────────────────────────
  static void Function(String inviteId, String channelName, bool isVideo)? onVoipAccept;
  static void Function(String inviteId)? onVoipDecline;

  // ── Lifecycle ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    debugPrint('[PushNotif-Stub] ℹ️ init skipped (web)');
  }

  Future<void> onSignedIn({required String userId}) async {
    debugPrint('[PushNotif-Stub] ℹ️ onSignedIn skipped (web)');
  }

  Future<void> onSignedOut() async {
    debugPrint('[PushNotif-Stub] ℹ️ onSignedOut skipped (web)');
  }

  Future<void> unregisterToken() async {
    debugPrint('[PushNotif-Stub] ℹ️ unregisterToken skipped (web)');
  }

  // ── VoIP Bridge (no-op sur Web) ───────────────────────────────────
  Future<void> endVoipCall(String inviteId) async {
    debugPrint('[PushNotif-Stub] ℹ️ endVoipCall skipped (web): $inviteId');
  }

  Future<void> endAllVoipCalls() async {
    debugPrint('[PushNotif-Stub] ℹ️ endAllVoipCalls skipped (web)');
  }
}
