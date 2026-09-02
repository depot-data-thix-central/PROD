/// Local Notification Service Stub (Web) — Production Enterprise
/// ✅ API IDENTIQUE à la version IO pour cohérence compile-time
/// ✅ NO-OP sur web (plateforme non supportée)
/// ✅ OBSERVABLE : Logs structurés pour debug
///
/// Implémentation stub pour le web où les notifications natives
/// ne sont pas supportées. Toutes les méthodes retournent immédiatement
/// sans effet de bord.
///
/// **Important** :
/// - Cette classe DOIT avoir exactement la même API publique que
///   `LocalNotificationService` dans `local_notification_service_io.dart`
/// - Le compilateur choisit l'une ou l'autre via les conditional imports
/// - Toute différence de signature causera des erreurs de compilation
///
/// **Usage** :
/// ```dart
/// // Importé automatiquement via conditional import :
/// import 'local_notification_service_stub.dart'
///     if (dart.library.io) 'local_notification_service_io.dart';
///
/// final service = LocalNotificationService.instance;
/// await service.initialize(); // No-op sur web
/// ```
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ============================================================================
// SERVICE (WEB STUB)
// ============================================================================

/// Stub du service de notifications locales pour le web.
///
/// Toutes les méthodes sont des no-ops qui retournent immédiatement.
/// L'API est identique à la version IO pour garantir la cohérence compile-time.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  /// Callback appelé quand l'utilisateur tape sur une notification.
  ///
  /// **Note** : Sur web, ce callback ne sera jamais appelé car les
  /// notifications natives ne sont pas supportées.
  void Function(String? payload)? onNotificationTap;

  /// Channels constants (pour cohérence API avec version IO)
  static const String channelDefault = 'thix_id_default';
  static const String channelChat = 'thix_chat';
  static const String channelCalls = 'thix_calls';

  /// Référence au BuildContext (non utilisé sur web, présent pour cohérence API)
  BuildContext? _context;

  /// Initialise le service de notifications locales.
  ///
  /// **Web** : No-op, retourne immédiatement.
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.initialize();
  /// ```
  Future<void> initialize() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip initialize (web platform)');
  }

  /// Alias pour `initialize()` (compatibilité).
  @Deprecated('Use initialize() instead')
  Future<void> init() => initialize();

  /// Demande les permissions de notifications.
  ///
  /// **Web** : Retourne toujours `true` (pas de permission requise).
  ///
  /// **Retourne** :
  /// - `true` toujours sur web
  ///
  /// **Usage** :
  /// ```dart
  /// final granted = await LocalNotificationService.instance.requestPermission();
  /// ```
  Future<bool> requestPermission() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip requestPermission (web platform)');
    return true;
  }

  /// Affiche une notification locale.
  ///
  /// **Web** : No-op, log le title pour debug.
  ///
  /// **Paramètres** :
  /// - `id` : ID unique de la notification (ignoré sur web)
  /// - `title` : Titre de la notification
  /// - `body` : Corps de la notification
  /// - `payload` : Payload optionnel (ignoré sur web)
  /// - `channelId` : Channel de notification (ignoré sur web)
  ///
  /// **Retourne** :
  /// - `false` toujours sur web (notifications non supportées)
  ///
  /// **Usage** :
  /// ```dart
  /// final success = await LocalNotificationService.instance.show(
  ///   id: 1,
  ///   title: 'Nouveau message',
  ///   body: 'Vous avez reçu un message',
  ///   channelId: LocalNotificationService.channelChat,
  /// );
  /// ```
  Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip show (web platform): '
        'id=$id, title="$title", channel=${channelId ?? channelDefault}');
    return false;
  }

  /// Raccourci pour afficher une notification d'appel entrant.
  ///
  /// **Web** : No-op, retourne `false`.
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.showIncomingCall(
  ///   id: 1,
  ///   title: 'Appel entrant',
  ///   body: 'John Doe vous appelle',
  /// );
  /// ```
  Future<bool> showIncomingCall({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelCalls,
    );
  }

  /// Raccourci pour afficher une notification de message chat.
  ///
  /// **Web** : No-op, retourne `false`.
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.showChatMessage(
  ///   id: 1,
  ///   title: 'John Doe',
  ///   body: 'Salut, comment ça va ?',
  /// );
  /// ```
  Future<bool> showChatMessage({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelChat,
    );
  }

  /// Annule une notification par son ID.
  ///
  /// **Web** : No-op, retourne `false`.
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.cancel(1);
  /// ```
  Future<bool> cancel(int id) async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip cancel (web platform): id=$id');
    return false;
  }

  /// Annule toutes les notifications.
  ///
  /// **Web** : No-op, retourne `false`.
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.cancelAll();
  /// ```
  Future<bool> cancelAll() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip cancelAll (web platform)');
    return false;
  }

  /// Enregistre un BuildContext pour mounted check dans les callbacks.
  ///
  /// **Web** : Stocke le context mais ne l'utilise jamais (no-op).
  ///
  /// **Usage** :
  /// ```dart
  /// LocalNotificationService.instance.registerContext(context);
  /// ```
  void registerContext(BuildContext context) {
    _context = context;
    debugPrint('[LocalNotif-Stub] ℹ️ registerContext (web platform, no-op)');
  }

  /// Désenregistre le BuildContext.
  ///
  /// **Usage** :
  /// ```dart
  /// LocalNotificationService.instance.unregisterContext();
  /// ```
  void unregisterContext() {
    _context = null;
    debugPrint('[LocalNotif-Stub] ℹ️ unregisterContext (web platform, no-op)');
  }

  /// Reset le service pour les tests unitaires.
  ///
  /// ⚠️ **Usage interne uniquement** (tests unitaires).
  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[LocalNotif-Stub] 🔄 Resetting for testing (web platform)...');
    onNotificationTap = null;
    _context = null;
  }
}
