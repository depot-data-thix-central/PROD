// lib/services/push_notification_service_stub.dart
import 'package:flutter/foundation.dart';

/// Sur web, aucun handler FCM natif n'est enregistré ici — la gestion
/// FCM sur web passe par le service worker JS (firebase-messaging-sw.js),
/// hors du code Dart compilé.
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  Future<void> initialize() async {
    debugPrint('PushNotificationService: skip init (web)');
  }

  Future<void> onSignedIn({required String userId}) async {
    debugPrint('PushNotificationService: onSignedIn skipped (web)');
  }

  Future<void> onSignedOut() async {
    debugPrint('PushNotificationService: onSignedOut skipped (web)');
  }

  Future<void> unregisterToken() async {}
}
