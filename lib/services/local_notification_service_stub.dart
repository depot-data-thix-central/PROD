// lib/services/local_notification_service_stub.dart
import 'package:flutter/foundation.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    debugPrint('LocalNotificationService: skip init (web)');
  }

  Future<void> init() => initialize();

  Future<bool> requestPermission() async => true;

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('LocalNotificationService: show skipped (web) title=$title');
  }

  Future<void> cancel(int id) async {}
  Future<void> cancelAll() async {}
}
