import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/notification_service.dart';
import 'notification_catalog.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final myUidProvider = Provider<String?>((ref) => Supabase.instance.client.auth.currentUser?.id);

final notificationsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationServiceProvider).streamForUser(uid);
});

final unreadTotalProvider = Provider<int>((ref) =>
    ref.watch(notificationsStreamProvider).valueOrNull
        ?.where((n) => n['read'] != true).length ?? 0);

final notifByCategoryProvider =
    Provider<Map<String, List<Map<String, dynamic>>>>((ref) {
  final all = ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  final map = <String, List<Map<String, dynamic>>>{};
  for (final n in all) {
    final cat = (n['category'] ?? notifMeta(n['type']?.toString()).category).toString();
    (map[cat] ??= []).add(n);
  }
  return map;
});

final unreadByCategoryProvider = Provider<Map<String, int>>((ref) {
  final byCat = ref.watch(notifByCategoryProvider);
  return byCat.map((k, v) => MapEntry(k, v.where((n) => n['read'] != true).length));
});

Future<bool> markNotifRead(WidgetRef ref, String id) {
  final uid = ref.read(myUidProvider);
  if (uid == null) return Future.value(false);
  return ref.read(notificationServiceProvider).markRead(uid: uid, notificationId: id);
}

Future<bool> markAllNotifRead(WidgetRef ref) {
  final uid = ref.read(myUidProvider);
  if (uid == null) return Future.value(false);
  return ref.read(notificationServiceProvider).markAllRead(uid);
}
