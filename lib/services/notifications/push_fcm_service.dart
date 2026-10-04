import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM : enregistrement token, push foreground/background, deep-link, badge.
class PushFcmService {
  PushFcmService._();
  static final PushFcmService instance = PushFcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _foregroundCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream des notifications reçues EN FOREGROUND (pour la bannière in-app).
  Stream<Map<String, dynamic>> get foregroundStream => _foregroundCtrl.stream;

  Future<void> init({required Future<void> Function(String? route) onOpenRoute}) async {
    if (kIsWeb) return;
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit, macOS: darwinInit),
        onDidReceiveNotificationResponse: (r) async {
          final route = r.payload;
          if (route != null && route.isNotEmpty) await onOpenRoute(route);
        },
      );

      const channel = AndroidNotificationChannel(
        'thix_notifications', 'Notifications THIX',
        description: 'Toutes les notifications THIX',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Token initial + refresh → device_tokens
      final token = await _fcm.getToken();
      if (token != null) await _registerToken(token);
      _fcm.onTokenRefresh.listen(_registerToken);

      // Foreground : pop locale + bannière in-app
      FirebaseMessaging.onMessage.listen((m) {
        final data = Map<String, dynamic>.from(m.data);
        data['title'] = m.notification?.title ?? 'THIX';
        data['body'] = m.notification?.body ?? '';
        _foregroundCtrl.add(data);
        _local.show(
          DateTime.now().millisecond,
          data['title'] as String? ?? 'THIX',
          data['body'] as String? ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails('thix_notifications', 'Notifications THIX',
                channelDescription: 'Toutes les notifications THIX',
                importance: Importance.high, priority: Priority.high),
          ),
          payload: data['route'] as String?,
        );
      });

      // Ouverture depuis push (background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpenRoute(m.data['route'] as String?));
      final initial = await _fcm.getInitialMessage();
      if (initial != null) await onOpenRoute(initial.data['route'] as String?);
    } catch (e) {
      debugPrint('[PushFcm] ❌ init: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('[PushFcm] ❌ token: $e');
    }
  }

  /// À appeler au logout pour ne plus pousser vers cet appareil.
  Future<void> unregister() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final token = await _fcm.getToken();
    if (uid == null || token == null) return;
    try {
      await Supabase.instance.client
          .from('device_tokens').delete()
          .eq('user_id', uid).eq('token', token);
    } catch (_) {}
  }
}
