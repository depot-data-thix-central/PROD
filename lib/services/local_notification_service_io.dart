// lib/services/local_notification_service_io.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelDefault = 'thix_id_default';
  static const String channelChat = 'thix_chat';
  static const String channelCalls = 'thix_calls';

  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelDefault,
        'THIX ID',
        description: 'Notifications générales THIX',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelChat,
        'Messages THIX Chat',
        description: 'Nouveaux messages',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelCalls,
        'Appels THIX',
        description: 'Appels audio et vidéo entrants',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
    debugPrint('LocalNotificationService: initialisé');
  }

  Future<void> init() => initialize();

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    if (!_initialized) await initialize();

    final channel = channelId ?? channelDefault;
    final isCall = channel == channelCalls;

    final androidDetails = AndroidNotificationDetails(
      channel,
      isCall
          ? 'Appels THIX'
          : channel == channelChat
              ? 'Messages THIX Chat'
              : 'THIX ID',
      channelDescription: isCall
          ? 'Appels entrants'
          : 'Notifications THIX',
      importance: isCall ? Importance.max : Importance.high,
      priority: isCall ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      category: isCall
          ? AndroidNotificationCategory.call
          : AndroidNotificationCategory.message,
      fullScreenIntent: isCall,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('LocalNotificationService: show failed err=$e');
    }
  }

  /// Raccourci appel entrant
  Future<void> showIncomingCall({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelCalls,
    );
  }

  /// Raccourci message chat
  Future<void> showChatMessage({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelChat,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
