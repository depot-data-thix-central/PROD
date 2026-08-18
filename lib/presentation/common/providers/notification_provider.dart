// lib/presentation/common/providers/notification_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/notification/app_notification.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationService notificationService(NotificationServiceRef ref) => NotificationService();

/// Flux des notifications de l'utilisateur connecté (mappées en modèle typé).
@riverpod
Stream<List<AppNotification>> myNotifications(MyNotificationsRef ref) {
  final uid = SupabaseConfig.currentUser?.id;
  if (uid == null) return const Stream.empty();

  final service = ref.watch(notificationServiceProvider);
  return service.streamForUser(uid).map(
        (rows) => rows.map(AppNotification.fromMap).toList(growable: false),
      );
}

/// Compteur de notifications non lues — alimente le badge sur la cloche.
@riverpod
Stream<int> unreadNotificationCount(UnreadNotificationCountRef ref) {
  final uid = SupabaseConfig.currentUser?.id;
  if (uid == null) return Stream.value(0);

  final service = ref.watch(notificationServiceProvider);
  return service.streamUnreadCount(uid);
}
