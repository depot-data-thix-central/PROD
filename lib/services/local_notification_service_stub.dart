/// Local Notification Service Stub (Web) — Production Enterprise
/// ✅ API IDENTIQUE à la version IO (v3.5) pour cohérence compile-time
/// ✅ NO-OP sur web (plateforme non supportée)
/// ✅ OBSERVABLE : Logs structurés pour debug
///
/// **Important** :
/// - Cette classe DOIT avoir exactement la même API publique que
///   `LocalNotificationService` dans `local_notification_service_io.dart`
/// - Le compilateur choisit l'une ou l'autre via les conditional imports
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Identifiants d'actions (partagés avec main.dart)
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';
const String kActionMarkAsRead = 'MARK_AS_READ';
const String kActionMute = 'MUTE';

// ============================================================================
// SERVICE (WEB STUB)
// ============================================================================

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  /// Callback appelé quand l'utilisateur tape sur une notification.
  /// Sur web, ce callback ne sera jamais appelé.
  void Function(String? payload, {String? actionId, String? input})?
      onNotificationTap;

  /// Canaux (cohérence API avec la version IO)
  static const String channelDefault = 'thix_id_default_v3';
  static const String channelChat = 'thix_chat_v3';
  static const String channelCalls = 'thix_calls_v3';
  static const String channelWedding = 'thix_wedding_v3';
  static const String channelNewsBreaking = 'thix_news_breaking_v1';
  static const String channelNews = 'thix_news_general_v1';

  BuildContext? _context;

  /// Identifiant de notification d'une conversation (no-op sur web).
  static int chatNotificationId(String conversationId) =>
      conversationId.hashCode & 0x7fffffff;

  /// Extrait l'id de conversation d'un payload (même logique que la version IO).
  static String? conversationIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (payload.startsWith('chat:')) {
      final id = payload.substring(5).trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  Future<void> initialize() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip initialize (web platform)');
  }

  @Deprecated('Use initialize() instead')
  Future<void> init() => initialize();

  Future<bool> requestPermission() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip requestPermission (web platform)');
    return true;
  }

  Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    bool showReplyAction = false,
    bool showMarkAsReadAction = false,
    bool showMuteAction = false,
  }) async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip show (web platform): '
        'id=$id, title="$title", channel=${channelId ?? channelDefault}');
    return false;
  }

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

  Future<bool> showChatMessage({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? conversationId,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelChat,
    );
  }

  Future<bool> showWeddingMessage({
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
      channelId: channelWedding,
    );
  }

  Future<bool> showWeddingAlert({
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
      channelId: channelWedding,
    );
  }

  Future<bool> showNewsBreaking({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelNewsBreaking,
    );
  }

  Future<bool> showNewsArticle({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelNews,
    );
  }

  /// Supprime la notification et l'historique d'une conversation (no-op sur web).
  Future<void> clearChat(String conversationId) async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip clearChat (web platform)');
  }

  Future<bool> cancel(int id) async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip cancel (web platform): id=$id');
    return false;
  }

  Future<bool> cancelAll() async {
    debugPrint('[LocalNotif-Stub] ℹ️ Skip cancelAll (web platform)');
    return false;
  }

  void registerContext(BuildContext context) {
    _context = context;
    debugPrint('[LocalNotif-Stub] ℹ️ registerContext (web platform, no-op)');
  }

  void unregisterContext() {
    _context = null;
    debugPrint('[LocalNotif-Stub] ℹ️ unregisterContext (web platform, no-op)');
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[LocalNotif-Stub] 🔄 Resetting for testing (web platform)...');
    onNotificationTap = null;
    _context = null;
  }
}
