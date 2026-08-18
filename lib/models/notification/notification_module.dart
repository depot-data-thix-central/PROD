// lib/models/notification/notification_module.dart

/// Modules THIX ID pouvant recevoir des notifications, avec leur
/// correspondance vers les valeurs de la colonne `type` de la table
/// `notifications`.
enum NotificationModule {
  chat,
  money,
  live,
  network, // Thix Pro
  health,
  market,
  opportunity,
  job,
  event,
  formation,
  media,
  reservation,
  country, // Mon Pays
  sos,
  doc,
  ia,
  generic,
}

extension NotificationModuleX on NotificationModule {
  /// Valeurs de `notifications.type` regroupées sous ce module.
  /// Un module peut couvrir plusieurs types (ex: 'job' et 'opportunity'
  /// alimentent tous deux le badge "Opportunités").
  List<String> get typeKeys {
    switch (this) {
      case NotificationModule.chat:
        return const ['chat', 'message'];
      case NotificationModule.money:
        return const ['money', 'payment', 'thix_money'];
      case NotificationModule.live:
        return const ['live', 'live_request', 'cohost_request'];
      case NotificationModule.network:
        return const ['network', 'post', 'like', 'comment', 'follow'];
      case NotificationModule.health:
        return const ['health', 'thix_sante'];
      case NotificationModule.market:
        return const ['market', 'order', 'shop'];
      case NotificationModule.opportunity:
        return const ['opportunity'];
      case NotificationModule.job:
        return const ['job', 'emploi'];
      case NotificationModule.event:
        return const ['event', 'evenement'];
      case NotificationModule.formation:
        return const ['formation', 'course', 'certificate'];
      case NotificationModule.media:
        return const ['media', 'thix_media'];
      case NotificationModule.reservation:
        return const ['reservation', 'booking'];
      case NotificationModule.country:
        return const ['country', 'mon_pays', 'civic'];
      case NotificationModule.sos:
        return const ['sos', 'emergency'];
      case NotificationModule.doc:
        return const ['doc', 'document'];
      case NotificationModule.ia:
        return const ['ia', 'tdia', 'assistant'];
      case NotificationModule.generic:
        return const ['generic'];
    }
  }
}
