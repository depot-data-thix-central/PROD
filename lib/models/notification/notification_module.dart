// lib/models/notification/notification_module.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// MODULES THIX ID — Regroupement logique des notifications
//
// Aligné avec :
//   - ThixSection (notification_counters_service.dart) → badges constellation
//   - notification_catalog.dart → icônes/couleurs centralisées
//   - Schéma DB v2 (colonne `category` + `type`)
//
// Usage :
//   - Filtrer les notifications par module : notif.module == NotificationModule.chat
//   - Grouper dans le hub : notifications.where((n) => n.module == module)
//   - Compter par module : module.count(notifications)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:thix_id/models/notification/app_notification.dart';

/// Modules THIX ID pouvant recevoir des notifications, avec leur
/// correspondance vers les valeurs de la colonne `type` de la table
/// `notifications` et la colonne `category`.
enum NotificationModule {
  chat,        // Messages, appels
  money,       // Transactions, paiements
  live,        // Lives, co-animation
  network,     // Thix Pro (réseau social)
  health,      // Santé, SOS
  market,      // Boutique, commandes
  opportunity, // Opportunités
  job,         // Emplois
  event,       // Événements
  formation,   // Formations, certificats
  media,       // Thidia (vidéos, contenus)
  reservation, // Réservations
  country,     // Mon Pays (civique)
  sos,         // Alertes SOS (sous-module de health)
  doc,         // Coffre-fort (documents partagés)
  ia,          // Assistant IA (Sona, TDIA)
  system,      // Système, sécurité
  generic,     // Fallback
}

extension NotificationModuleX on NotificationModule {
  // ════════════════════════════════════════════════════════════════════════
  // MAPPING TYPE → MODULE (tous les types du système)
  // ════════════════════════════════════════════════════════════════════════

  /// Valeurs de `notifications.type` regroupées sous ce module.
  /// Un module peut couvrir plusieurs types (ex: 'like', 'comment', 'repost'
  /// alimentent tous le module "network").
  List<String> get typeKeys {
    switch (this) {
      case NotificationModule.chat:
        return const [
          'chat',
          'message',
          'call',
          'call_missed',
          'call_ended',
          'voice_note',
        ];
      
      case NotificationModule.money:
        return const [
          'money',
          'payment',
          'thix_money',
          'payment_received',
          'payout_released',
          'refund_requested',
          'refund_processed',
        ];
      
      case NotificationModule.live:
        return const [
          'live',
          'live_request',
          'live_invite',
          'cohost_request',
          'live_started',
          'live_ended',
        ];
      
      case NotificationModule.network:
        return const [
          'network',
          'post',
          'like',
          'comment',
          'comment_like',
          'comment_reply',
          'repost',
          'follow',
          'friend_request',
          'friend_accepted',
          'friend_rejected',
          'mention',
          'tag',
          'profile_visit',
        ];
      
      case NotificationModule.health:
        return const [
          'health',
          'thix_sante',
          'health_alert',
          'appointment_reminder',
        ];
      
      case NotificationModule.market:
        return const [
          'market',
          'order',
          'order_new',
          'order_status',
          'shop',
          'shop_review',
          'product_review',
        ];
      
      case NotificationModule.opportunity:
        return const [
          'opportunity',
          'opportunity_new',
          'opportunity_match',
        ];
      
      case NotificationModule.job:
        return const [
          'job',
          'emploi',
          'job_new',
          'job_match',
          'application_received',
          'application_status',
          'interview_scheduled',
        ];
      
      case NotificationModule.event:
        return const [
          'event',
          'evenement',
          'event_new',
          'event_reminder',
          'event_update',
        ];
      
      case NotificationModule.formation:
        return const [
          'formation',
          'course',
          'certificate',
          'course_new',
          'course_update',
          'certificate_earned',
          'assignment_due',
        ];
      
      case NotificationModule.media:
        return const [
          'media',
          'thix_media',
          'tdia',
          'media_like',
          'media_comment',
          'media_reply',
          'media_new',
          'media_featured',
        ];
      
      case NotificationModule.reservation:
        return const [
          'reservation',
          'booking',
          'reservation_confirmed',
          'reservation_cancelled',
          'reservation_reminder',
        ];
      
      case NotificationModule.country:
        return const [
          'country',
          'mon_pays',
          'civic',
          'civic_alert',
          'government_update',
        ];
      
      case NotificationModule.sos:
        return const [
          'sos',
          'emergency',
          'sos_ack',
          'sos_resolved',
        ];
      
      case NotificationModule.doc:
        return const [
          'doc',
          'document',
          'doc_shared',
          'doc_opened',
          'doc_screenshot',
          'doc_expired',
        ];
      
      case NotificationModule.ia:
        return const [
          'ia',
          'tdia',
          'assistant',
          'ai_response',
          'ai_suggestion',
          'sona_message',
        ];
      
      case NotificationModule.system:
        return const [
          'system',
          'security',
          'security_alert',
          'password_changed',
          'login_attempt',
          'verification_required',
          'app_update',
        ];
      
      case NotificationModule.generic:
        return const ['generic'];
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // MAPPING CATEGORY → MODULE
  // ════════════════════════════════════════════════════════════════════════

  /// Catégories DB (`notifications.category`) couvertes par ce module.
  /// Utilisé pour filtrer rapidement par catégorie.
  List<String> get categoryKeys {
    switch (this) {
      case NotificationModule.chat:
        return const ['messages'];
      case NotificationModule.money:
        return const ['money'];
      case NotificationModule.live:
        return const ['media']; // Lives sont dans la catégorie media
      case NotificationModule.network:
        return const ['network'];
      case NotificationModule.health:
        return const ['health'];
      case NotificationModule.market:
        return const ['market'];
      case NotificationModule.opportunity:
        return const ['opportunities'];
      case NotificationModule.job:
        return const ['jobs'];
      case NotificationModule.event:
        return const ['events'];
      case NotificationModule.formation:
        return const ['formations'];
      case NotificationModule.media:
        return const ['media'];
      case NotificationModule.reservation:
        return const ['reservation'];
      case NotificationModule.country:
        return const ['monPays', 'country'];
      case NotificationModule.sos:
        return const ['health']; // SOS est sous-catégorie de health
      case NotificationModule.doc:
        return const ['info']; // Documents sont dans info
      case NotificationModule.ia:
        return const ['info']; // IA est dans info
      case NotificationModule.system:
        return const ['system'];
      case NotificationModule.generic:
        return const ['system'];
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS DE FILTRAGE
  // ════════════════════════════════════════════════════════════════════════

  /// Indique si une notification appartient à ce module.
  bool matches(AppNotification notif) {
    // Vérifier d'abord le type (plus précis)
    if (typeKeys.contains(notif.type)) return true;
    // Puis la catégorie (plus large)
    if (categoryKeys.contains(notif.category)) return true;
    return false;
  }

  /// Compte les notifications de ce module dans une liste.
  int count(List<AppNotification> notifications) {
    return notifications.where(matches).length;
  }

  /// Filtre les notifications de ce module.
  List<AppNotification> filter(List<AppNotification> notifications) {
    return notifications.where(matches).toList();
  }

  /// Compte les notifications NON LUES de ce module.
  int countUnread(List<AppNotification> notifications) {
    return notifications.where((n) => matches(n) && !n.read).length;
  }

  // ════════════════════════════════════════════════════════════════════════
  // MÉTADONNÉS VISUELLES (via catalogue centralisé)
  // ════════════════════════════════════════════════════════════════════════

  /// Type de notification "représentatif" pour récupérer icône/couleur.
  /// Utilisé quand on veut afficher l'icône du module (pas d'une notif spécifique).
  String get representativeType {
    switch (this) {
      case NotificationModule.chat: return 'message';
      case NotificationModule.money: return 'payment_received';
      case NotificationModule.live: return 'live_invite';
      case NotificationModule.network: return 'like';
      case NotificationModule.health: return 'health';
      case NotificationModule.market: return 'order_new';
      case NotificationModule.opportunity: return 'opportunity';
      case NotificationModule.job: return 'job';
      case NotificationModule.event: return 'event';
      case NotificationModule.formation: return 'formation';
      case NotificationModule.media: return 'media_like';
      case NotificationModule.reservation: return 'reservation';
      case NotificationModule.country: return 'civic';
      case NotificationModule.sos: return 'sos';
      case NotificationModule.doc: return 'doc_shared';
      case NotificationModule.ia: return 'sona_message';
      case NotificationModule.system: return 'system';
      case NotificationModule.generic: return 'generic';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EXTENSIONS GLOBALES (lookup rapide)
// ════════════════════════════════════════════════════════════════════════════

/// Trouve le module correspondant à un type de notification.
/// Retourne `NotificationModule.generic` si aucun module ne correspond.
NotificationModule moduleFromType(String type) {
  for (final module in NotificationModule.values) {
    if (module.typeKeys.contains(type)) return module;
  }
  return NotificationModule.generic;
}

/// Trouve le module correspondant à une catégorie DB.
/// Retourne `NotificationModule.generic` si aucune catégorie ne correspond.
NotificationModule moduleFromCategory(String category) {
  for (final module in NotificationModule.values) {
    if (module.categoryKeys.contains(category)) return module;
  }
  return NotificationModule.generic;
}

/// Extension sur `AppNotification` pour accéder directement au module.
extension AppNotificationModuleX on AppNotification {
  /// Module auquel appartient cette notification.
  NotificationModule get module {
    // Priorité : type (plus précis) > category (plus large)
    final fromType = moduleFromType(type);
    if (fromType != NotificationModule.generic) return fromType;
    return moduleFromCategory(category);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS DE GROUPEMENT (pour le hub de notifications)
// ════════════════════════════════════════════════════════════════════════════

/// Regroupe une liste de notifications par module.
/// Retourne une Map : {module: [notifications]}.
Map<NotificationModule, List<AppNotification>> groupByModule(
  List<AppNotification> notifications,
) {
  final groups = <NotificationModule, List<AppNotification>>{};
  
  for (final notif in notifications) {
    final module = notif.module;
    groups.putIfAbsent(module, () => []).add(notif);
  }
  
  return groups;
}

/// Compte les notifications par module.
/// Retourne une Map : {module: count}.
Map<NotificationModule, int> countByModule(List<AppNotification> notifications) {
  final counts = <NotificationModule, int>{};
  
  for (final module in NotificationModule.values) {
    final count = module.count(notifications);
    if (count > 0) counts[module] = count;
  }
  
  return counts;
}

/// Compte les notifications NON LUES par module.
/// Retourne une Map : {module: unreadCount}.
Map<NotificationModule, int> countUnreadByModule(List<AppNotification> notifications) {
  final counts = <NotificationModule, int>{};
  
  for (final module in NotificationModule.values) {
    final count = module.countUnread(notifications);
    if (count > 0) counts[module] = count;
  }
  
  return counts;
}

/// Retourne les modules ayant au moins une notification non lue,
/// triés par nombre de notifications décroissant.
List<NotificationModule> modulesWithUnread(List<AppNotification> notifications) {
  final counts = countUnreadByModule(notifications);
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.map((e) => e.key).toList();
}
