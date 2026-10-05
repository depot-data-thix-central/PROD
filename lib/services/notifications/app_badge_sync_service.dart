// lib/services/notifications/app_badge_sync_service.dart
// Synchronise le badge de l'icône : iOS (AppBadgePlus) + Android (notification-résumé avec number)
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppBadgeSyncService {
  AppBadgeSyncService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _lastCount = -1;

  /// Notification-résumé silencieuse qui porte le compteur pour les launchers Android
  static const int _kSummaryId = 999999;
  static const String _kChannelId = 'thix_badge_sync';

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          'Compteur THIX',
          description: 'Maintient le badge chiffré sur l\'icône de l\'application',
          importance: Importance.low,
          showBadge: true,
        ),
      );
      // Android 13+ : permission notifications
      await android?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('[BadgeSync] ❌ init: $e');
    }
  }

  /// Met à jour le badge partout (icône launcher + iOS)
  static Future<void> sync(int count) async {
    final safe = count < 0 ? 0 : count;
    if (safe == _lastCount) return; // évite le spam
    _lastCount = safe;
    if (kIsWeb) return;

    await init();

    // iOS + certains OEM Android
    try {
      if (safe == 0) {
        // ✅ FIX : updateBadge(0) au lieu de clearBadge()
        await AppBadgePlus.updateBadge(0);
      } else {
        await AppBadgePlus.updateBadge(safe);
      }
    } catch (e) {
      debugPrint('[BadgeSync] ⚠️ AppBadgePlus: $e');
    }

    // Android : notification-résumé silencieuse portant `number`
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (safe == 0) {
          await _plugin.cancel(_kSummaryId);
        } else {
          await _plugin.show(
            _kSummaryId,
            'THIX Hub',
            safe == 1 ? '1 notification non lue' : '$safe notifications non lues',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _kChannelId,
                'Compteur THIX',
                channelDescription:
                    'Maintient le badge chiffré sur l\'icône de l\'application',
                importance: Importance.low,
                priority: Priority.low,
                silent: true,
                playSound: false,
                enableVibration: false,
                onlyAlertOnce: true,
                showWhen: false,
                number: safe,
              ),
            ),
            payload: 'badge_summary',
          );
        }
        debugPrint('[BadgeSync] 🔢 Icon badge → $safe');
      } catch (e) {
        debugPrint('[BadgeSync] ❌ summary: $e');
      }
    }
  }
}
