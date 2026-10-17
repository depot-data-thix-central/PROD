// lib/services/notifications/push_fcm_service.dart
//
// v2 — COUCHE DE COMPATIBILITÉ.
//
// Le vrai push (token, notifications, appels, taps) est géré par
// PushNotificationService (lib/services/push_notification_service*.dart).
// Cette classe garde le même API (instance, init, foregroundStream, unregister)
// pour que NotifBannerListener continue de fonctionner, mais elle ne fait plus :
//  - d'écriture dans la table legacy `device_tokens`
//  - de FlutterLocalNotificationsPlugin.initialize() (qui écrasait le tap handler)
//  - de getInitialMessage() / onMessageOpenedApp (déjà traités ailleurs → doublons)
//
// Elle ne fait QUE transmettre les messages reçus en foreground vers
// `foregroundStream` (bannière in-app).
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushFcmService {
  PushFcmService._();
  static final PushFcmService instance = PushFcmService._();

  /// Web non supporté → toutes les méthodes deviennent no-op
  bool get _supported => !kIsWeb;

  final StreamController<Map<String, dynamic>> _foregroundCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<RemoteMessage>? _sub;

  /// Stream des notifications reçues EN FOREGROUND (pour la bannière in-app).
  Stream<Map<String, dynamic>> get foregroundStream => _foregroundCtrl.stream;

  /// [onOpenRoute] est conservé pour compatibilité mais n'est plus utilisé :
  /// l'ouverture depuis une notification est gérée par PushNotificationService
  /// et LocalNotificationService.onNotificationTap (main.dart).
  Future<void> init({
    Future<void> Function(String? route)? onOpenRoute,
  }) async {
    if (!_supported) {
      debugPrint('[PushFcm] ℹ️ Web: push disabled');
      return;
    }
    if (_sub != null) return; // déjà branché : pas de doublon

    try {
      _sub = FirebaseMessaging.onMessage.listen((m) {
        final type = (m.data['type'] ?? '').toString().toLowerCase();

        // Les appels ont leur propre interface : pas de bannière
        if (type == 'incoming_call' || type == 'call_hangup') return;

        final data = Map<String, dynamic>.from(m.data);
        data['title'] = m.notification?.title ??
            m.data['title']?.toString() ??
            'THIX';
        data['body'] = m.notification?.body ??
            m.data['body']?.toString() ??
            m.data['message']?.toString() ??
            '';

        _foregroundCtrl.add(data);
      });

      debugPrint('[PushFcm] ✓ foreground stream branché (compat)');
    } catch (e) {
      debugPrint('[PushFcm] ❌ init: $e');
    }
  }

  /// Compat : le token est désormais retiré par PushNotificationService
  /// (déconnexion réelle gérée dans main.dart). On coupe seulement l'écoute.
  Future<void> unregister() async {
    await _sub?.cancel();
    _sub = null;
  }
}
