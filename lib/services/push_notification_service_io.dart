// lib/services/push_notification_service_io.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Types de payload FCM (data.type)
class PushTypes {
  static const chatMessage = 'chat_message';
  static const incomingCall = 'incoming_call';
  static const notification = 'notification';
  static const sos = 'sos';
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Isolate séparé : ré-init minimal
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    await LocalNotificationService.instance.initialize();
    await _showFromRemoteMessage(message);
  } catch (e) {
    debugPrint('FCM background handler error: $e');
  }
}

Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString();

  final title = message.notification?.title ??
      data['title']?.toString() ??
      _defaultTitle(type);

  final body = message.notification?.body ??
      data['body']?.toString() ??
      data['message']?.toString() ??
      '';

  final payload = _buildPayload(data);

  // Appels → channel prioritaire si le service local le supporte
  final isCall = type == PushTypes.incomingCall;

  await LocalNotificationService.instance.show(
    id: _notifId(message),
    title: title,
    body: body.isEmpty ? 'Nouvelle notification' : body,
    payload: payload,
    // si tu ajoutes le param optionnel dans LocalNotificationService :
    // channelId: isCall ? 'thix_calls' : null,
  );

  debugPrint(
    'FCM show type=$type title=$title payload=\( payload id= \){message.messageId}',
  );
}

String _defaultTitle(String type) {
  switch (type) {
    case PushTypes.incomingCall:
      return 'Appel entrant';
    case PushTypes.chatMessage:
      return 'Nouveau message';
    case PushTypes.sos:
      return 'Alerte SOS';
    default:
      return 'THIX Hub';
  }
}

String? _buildPayload(Map<String, dynamic> data) {
  // Priorité : route explicite, sinon construction
  final route = data['route']?.toString();
  if (route != null && route.isNotEmpty) return route;

  final type = (data['type'] ?? '').toString();
  switch (type) {
    case PushTypes.incomingCall:
      final inviteId = data['invite_id'] ?? data['inviteId'] ?? '';
      final channel = data['channel_name'] ?? data['channelName'] ?? '';
      return 'call:$inviteId:$channel';
    case PushTypes.chatMessage:
      final convId =
          data['conversation_id'] ?? data['conversationId'] ?? '';
      return 'chat:$convId';
    default:
      return data['notification_id']?.toString() ??
          data['id']?.toString();
  }
}

int _notifId(RemoteMessage message) {
  final id = message.messageId ?? message.data['invite_id'] ?? message.data['conversation_id'];
  if (id != null) return id.hashCode & 0x7fffffff;
  return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _tokensTable = 'user_device_tokens';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      await _registerToken();
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    debugPrint(
      'PushNotificationService: permission=${settings.authorizationStatus}',
    );

    // Android 13+ : permission notif aussi via LocalNotificationService
    try {
      await LocalNotificationService.instance.requestPermission();
    } catch (_) {}

    await _registerToken();
    _messaging.onTokenRefresh.listen((_) => _registerToken());

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> onSignedIn({required String userId}) async {
    _initialized = false;
    await initialize();
  }

  Future<void> onSignedOut() => unregisterToken();

  void _handleForegroundMessage(RemoteMessage message) {
    // Affiche même en data-only (appels / chat serveur)
    final hasVisual = message.notification != null ||
        message.data['title'] != null ||
        message.data['body'] != null ||
        message.data['type'] != null;

    if (!hasVisual) {
      debugPrint('FCM foreground ignored (empty): ${message.data}');
      return;
    }

    _showFromRemoteMessage(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final payload = _buildPayload(data);
    debugPrint(
      'PushNotificationService: tap type=${data['type']} payload=$payload',
    );
    LocalNotificationService.instance.onNotificationTap?.call(payload);

    // Hook optionnel pour navigation avancée
    onPushTap?.call(data);
  }

  /// Callback global (à brancher depuis main / router)
  static void Function(Map<String, dynamic> data)? onPushTap;

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      final uid = SupabaseConfig.currentUser?.id;
      if (token == null || uid == null) {
        debugPrint(
          'PushNotificationService: skip register token=${token != null} uid=$uid',
        );
        return;
      }

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
      await SupabaseConfig.client
          .from(_tokensTable)
          .delete()
          .eq('fcm_token', token);
      _initialized = false;
    } catch (e) {
      debugPrint('PushNotificationService: unregisterToken failed err=$e');
    }
  }
}
