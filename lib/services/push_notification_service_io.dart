// lib/services/push_notification_service_io.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _tokensTable = 'user_device_tokens';

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('PushNotificationService: permission=${settings.authorizationStatus}');

    await _registerToken();
    _messaging.onTokenRefresh.listen((_) => _registerToken());

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Appelé après une connexion réussie : ré-enregistre le token pour
  /// le nouvel utilisateur connecté.
  Future<void> onSignedIn({required String userId}) async {
    await initialize();
  }

  /// Appelé à la déconnexion : retire le token de cet appareil.
  Future<void> onSignedOut() => unregisterToken();

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    LocalNotificationService.instance.show(
      id: message.hashCode,
      title: notification.title ?? 'THIX ID',
      body: notification.body ?? '',
      payload: message.data['route'] ?? message.data['notification_id'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    debugPrint('PushNotificationService: notification tap → route=$route');
    LocalNotificationService.instance.onNotificationTap?.call(route);
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      final uid = SupabaseConfig.currentUser?.id;
      if (token == null || uid == null) return;

      await SupabaseConfig.client.from(_tokensTable).upsert(
        {
          'user_id': uid,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
      debugPrint('PushNotificationService: token enregistré uid=$uid');
    } catch (e) {
      debugPrint('PushNotificationService: registerToken failed err=$e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await SupabaseConfig.client.from(_tokensTable).delete().eq('fcm_token', token);
    } catch (e) {
      debugPrint('PushNotificationService: unregisterToken failed err=$e');
    }
  }
}
