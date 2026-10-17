import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class CallForegroundServiceImpl {
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'thix_call_foreground',
        channelName: 'Appel en cours',
        channelDescription: 'Maintient l’appel actif en arrière-plan',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  static Future<void> start({required bool video}) async {
    try {
      _init();
      if (await FlutterForegroundTask.isRunningService) return;

      final result = await FlutterForegroundTask.startService(
        serviceId: 4101,
        notificationTitle: 'Appel THIX en cours',
        notificationText: 'Appuyez pour revenir à l’appel',
        serviceTypes: [
          ForegroundServiceTypes.microphone,
          if (video) ForegroundServiceTypes.camera,
        ],
      );

      debugPrint('[CallForeground] start → $result');
    } catch (e) {
      debugPrint('[CallForeground] ⚠️ start failed: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        debugPrint('[CallForeground] stopped');
      }
    } catch (e) {
      debugPrint('[CallForeground] ⚠️ stop failed: $e');
    }
  }
}
