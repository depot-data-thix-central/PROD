// lib/presentation/notifications/notification_providers.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDERS — Système de notifications complet
//
// Architecture :
//   - notificationsStreamProvider : flux temps réel (Realtime + polling)
//   - notificationsProvider : liste d'AppNotification (type-safe)
//   - notificationProvider(id) : une notification spécifique
//   - notificationsByModuleProvider : groupement par module
//   - activeModulesProvider : modules avec notifications non lues
//
// Mutations :
//   - markNotifRead / markAllNotifRead / markCategoryRead
//   - deleteNotification / deleteAllNotifications
//   - openNotification (markRead + retour route)
//   - refreshNotifications (pull-to-refresh)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/notification/app_notification.dart';
import 'package:thix_id/models/notification/notification_module.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/notifications/notification_catalog.dart';

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS DE BASE
// ════════════════════════════════════════════════════════════════════════════

/// Service singleton pour les opérations sur les notifications.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// UID de l'utilisateur connecté (null si non authentifié).
final myUidProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

// ════════════════════════════════════════════════════════════════════════════
// STREAM BRUT (Map<String, dynamic>)
// ════════════════════════════════════════════════════════════════════════════

/// Flux brut des notifications (avant conversion en AppNotification).
/// Utilisé en interne par notificationsProvider.
final notificationsRawStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ No UID, returning empty stream');
    return Stream.value(const []);
  }
  debugPrint('[NotifProviders] 🚀 Starting stream for ${uid.substring(0, 8)}...');
  return ref.watch(notificationServiceProvider).streamForUser(uid);
});

// ════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS (type-safe via AppNotification)
// ════════════════════════════════════════════════════════════════════════════

/// Liste complète des notifications de l'utilisateur (type-safe).
/// Convertit automatiquement les Map en AppNotification.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final raw = ref.watch(notificationsRawStreamProvider).valueOrNull ?? const [];
  return raw
      .map((map) {
        try {
          return AppNotification.fromMap(map);
        } catch (e) {
          debugPrint('[NotifProviders] ❌ Failed to parse notification: $e');
          return null;
        }
      })
      .whereType<AppNotification>()
      .toList();
});

/// Nombre total de notifications non lues (pour la cloche du header).
final unreadTotalProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.read).length;
});

/// Indique si le flux de notifications est en cours de chargement initial.
final notificationsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(notificationsRawStreamProvider).isLoading;
});

/// Indique si le flux de notifications a rencontré une erreur.
final notificationsErrorProvider = Provider<Object?>((ref) {
  return ref.watch(notificationsRawStreamProvider).error;
});

// ════════════════════════════════════════════════════════════════════════════
// NOTIFICATION SPÉCIFIQUE (famille)
// ════════════════════════════════════════════════════════════════════════════

/// Récupère une notification spécifique par son ID.
/// Retourne null si la notification n'existe pas.
final notificationProvider =
    Provider.family<AppNotification?, String>((ref, id) {
  final notifications = ref.watch(notificationsProvider);
  try {
    return notifications.firstWhere((n) => n.id == id);
  } catch (_) {
    return null;
  }
});

// ════════════════════════════════════════════════════════════════════════════
// GROUPEMENT PAR CATÉGORIE (legacy, pour compatibilité)
// ════════════════════════════════════════════════════════════════════════════

/// Notifications groupées par catégorie (string).
/// ⚠️ Préférer [notificationsByModuleProvider] pour le nouveau système.
final notifByCategoryProvider =
    Provider<Map<String, List<AppNotification>>>((ref) {
  final all = ref.watch(notificationsProvider);
  final map = <String, List<AppNotification>>{};
  for (final n in all) {
    final cat = n.normalizedCategory;
    (map[cat] ??= []).add(n);
  }
  return map;
});

/// Nombre de notifications non lues par catégorie.
final unreadByCategoryProvider = Provider<Map<String, int>>((ref) {
  final byCat = ref.watch(notifByCategoryProvider);
  return byCat.map((k, v) => MapEntry(k, v.where((n) => !n.read).length));
});

// ════════════════════════════════════════════════════════════════════════════
// GROUPEMENT PAR MODULE (nouveau système)
// ════════════════════════════════════════════════════════════════════════════

/// Notifications groupées par module (type-safe).
/// Utilisé pour les onglets du hub de notifications.
final notificationsByModuleProvider =
    Provider<Map<NotificationModule, List<AppNotification>>>((ref) {
  final all = ref.watch(notificationsProvider);
  return groupByModule(all);
});

/// Nombre de notifications non lues par module.
final unreadByModuleProvider = Provider<Map<NotificationModule, int>>((ref) {
  final all = ref.watch(notificationsProvider);
  return countUnreadByModule(all);
});

/// Modules ayant au moins une notification non lue,
/// triés par nombre de notifications décroissant.
/// Utilisé pour afficher les onglets actifs dans le hub.
final activeModulesProvider = Provider<List<NotificationModule>>((ref) {
  final all = ref.watch(notificationsProvider);
  return modulesWithUnread(all);
});

/// Module avec le plus de notifications non lues (pour la couleur de la cloche).
/// Retourne null si aucune notification non lue.
final mostActiveModuleProvider = Provider<NotificationModule?>((ref) {
  final active = ref.watch(activeModulesProvider);
  return active.isNotEmpty ? active.first : null;
});

// ════════════════════════════════════════════════════════════════════════════
// FILTRES SPÉCIAUX
// ════════════════════════════════════════════════════════════════════════════

/// Notifications non lues uniquement.
final unreadNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => !n.read).toList();
});

/// Notifications récentes (< 2 min) non lues.
/// Utilisé pour déterminer si on doit afficher une bannière pop.
final recentUnreadProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => !n.read && n.isRecent).toList();
});

/// Notifications de haute priorité (priority >= 5).
final highPriorityProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => n.isHighPriority).toList();
});

/// Notifications SOS (critiques).
final sosAlertsProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => n.isSosAlert).toList();
});

// ════════════════════════════════════════════════════════════════════════════
// MUTATIONS (mark / delete / open)
// ════════════════════════════════════════════════════════════════════════════

/// Marque une notification comme lue.
/// Retourne true si succès, false sinon.
Future<bool> markNotifRead(WidgetRef ref, String id) {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ markNotifRead: no UID');
    return Future.value(false);
  }
  debugPrint('[NotifProviders] ✓ markNotifRead: ${id.substring(0, 8)}...');
  return ref.read(notificationServiceProvider).markRead(uid: uid, notificationId: id);
}

/// Marque TOUTES les notifications comme lues.
Future<bool> markAllNotifRead(WidgetRef ref) {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ markAllNotifRead: no UID');
    return Future.value(false);
  }
  debugPrint('[NotifProviders] ✓ markAllNotifRead');
  return ref.read(notificationServiceProvider).markAllRead(uid);
}

/// Marque comme lues toutes les notifications d'une catégorie donnée.
Future<bool> markCategoryRead(WidgetRef ref, String category) {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ markCategoryRead: no UID');
    return Future.value(false);
  }
  debugPrint('[NotifProviders] ✓ markCategoryRead: $category');
  return ref.read(notificationServiceProvider).markCategoryRead(uid: uid, category: category);
}

/// Marque comme lues toutes les notifications d'un module donné.
Future<bool> markModuleRead(WidgetRef ref, NotificationModule module) async {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ markModuleRead: no UID');
    return false;
  }
  
  // Marquer toutes les catégories du module
  final categories = module.categoryKeys;
  if (categories.isEmpty) {
    debugPrint('[NotifProviders] ⚠️ markModuleRead: no categories for $module');
    return false;
  }
  
  debugPrint('[NotifProviders] ✓ markModuleRead: $module (${categories.length} categories)');
  
  final results = await Future.wait(
    categories.map((cat) => ref.read(notificationServiceProvider)
        .markCategoryRead(uid: uid, category: cat)),
  );
  
  return results.any((r) => r);
}

/// Supprime une notification.
Future<bool> deleteNotification(WidgetRef ref, String id) {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ deleteNotification: no UID');
    return Future.value(false);
  }
  debugPrint('[NotifProviders] ✓ deleteNotification: ${id.substring(0, 8)}...');
  return ref.read(notificationServiceProvider).delete(uid: uid, notificationId: id);
}

/// Supprime TOUTES les notifications.
Future<bool> deleteAllNotifications(WidgetRef ref) {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ deleteAllNotifications: no UID');
    return Future.value(false);
  }
  debugPrint('[NotifProviders] ✓ deleteAllNotifications');
  return ref.read(notificationServiceProvider).deleteAll(uid);
}

/// Marque une notification comme lue et retourne sa route pour deep-link.
/// Usage typique : tap sur une notification dans le hub.
/// 
/// Retourne la route si succès, null sinon.
Future<String?> openNotification(WidgetRef ref, String id) async {
  final uid = ref.read(myUidProvider);
  if (uid == null) {
    debugPrint('[NotifProviders] ⚠️ openNotification: no UID');
    return null;
  }
  
  final notif = ref.read(notificationProvider(id));
  if (notif == null) {
    debugPrint('[NotifProviders] ⚠️ openNotification: notification not found');
    return null;
  }
  
  debugPrint('[NotifProviders] ✓ openNotification: ${id.substring(0, 8)}...');
  
  // Marquer comme lue (non-bloquant)
  unawaited(markNotifRead(ref, id));
  
  // Retourner la route pour deep-link
  return notif.deepLink;
}

// ════════════════════════════════════════════════════════════════════════════
// REFRESH (pull-to-refresh)
// ════════════════════════════════════════════════════════════════════════════

/// Force un rafraîchissement du flux de notifications.
/// Utile pour le pull-to-refresh dans le hub.
Future<void> refreshNotifications(WidgetRef ref) async {
  debugPrint('[NotifProviders] 🔄 Refreshing notifications');
  ref.invalidate(notificationsRawStreamProvider);
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS (legacy compatibility)
// ════════════════════════════════════════════════════════════════════════════

/// ⚠️ DEPRECATED : Préférer [notificationsProvider] qui retourne List<AppNotification>.
/// Retourne la liste brute des notifications (Map<String, dynamic>).
@Deprecated('Use notificationsProvider instead')
final notificationsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(notificationsRawStreamProvider);
});

/// ⚠️ DEPRECATED : Préférer [notificationsProvider].
/// Retourne les notifications groupées par catégorie (Map<String, dynamic>).
@Deprecated('Use notifByCategoryProvider instead')
final notifByCategoryRawProvider =
    Provider<Map<String, List<Map<String, dynamic>>>>((ref) {
  final all = ref.watch(notificationsRawStreamProvider).valueOrNull ?? const [];
  final map = <String, List<Map<String, dynamic>>>{};
  for (final n in all) {
    final cat = (n['category'] ?? notifMeta(n['type']?.toString()).category).toString();
    (map[cat] ??= []).add(n);
  }
  return map;
});
