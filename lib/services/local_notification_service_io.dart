// lib/services/local_notification_service_io.dart
//
/// Local Notification Service IO (Production Enterprise)
/// ✅ SÉCURISÉ : Validation stricte, sanitization des inputs
/// ✅ ROBUSTE : Error handling, mounted checks, timeouts
/// ✅ OBSERVABLE : Logs structurés avec emojis et contexte
/// ✅ FIX: Drawable resource ID must not be 0 (icon + channel IDs v3)
/// ✅ FIX: Son personnalisé (notification.mp3 + ringtone.mp3 dans res/raw/)
/// ✅ FIX: showBadge: true pour compteur sur l'icône
/// ✅ NEW: Actions Ouvrir / Répondre sur les notifications
/// ✅ v3  : Bump canaux _v2 → _v3 (les v2 sont muets à jamais : immuables)
/// ✅ v3  : Suppression automatique des canaux legacy au démarrage
/// ✅ v3  : Canal appels avec son 'ringtone' (res/raw/ringtone.mp3)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kNotificationTimeout = Duration(seconds: 10);
const int _kMaxTitleLength = 100;
const int _kMaxBodyLength = 500;
const int _kMinNotificationId = 0;
const int _kMaxNotificationId = 2147483647;

// Action IDs
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _Validators {
  _Validators._();

  static bool isValidNotificationId(int id) {
    return id >= _kMinNotificationId && id <= _kMaxNotificationId;
  }

  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String? validateAndSanitizeTitle(String? title) {
    if (title == null || title.trim().isEmpty) return null;
    return sanitizeString(title, maxLength: _kMaxTitleLength);
  }

  static String? validateAndSanitizeBody(String? body) {
    if (body == null || body.trim().isEmpty) return null;
    return sanitizeString(body, maxLength: _kMaxBodyLength);
  }
}

// ============================================================================
// SERVICE
// ============================================================================

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _initializing = false;

  // ✅ v3 : canaux bumpés de _v2 → _v3 (les v2 sont muets à jamais :
  // Android verrouille un canal une fois créé ; les v2 avaient été créés
  // AVANT que les fichiers son res/raw/ existent)
  static const String channelDefault = 'thix_id_default_v3';
  static const String channelChat = 'thix_chat_v3';
  static const String channelCalls = 'thix_calls_v3';

  // ✅ v3 : canaux legacy à supprimer au démarrage (muets à jamais)
  static const List<String> _legacyChannels = [
    'thix_id_default_v2',
    'thix_chat_v2',
    'thix_calls_v2',
    'thix_id_default',
    'thix_chat',
    'thix_calls',
  ];

  /// Callback quand l'utilisateur tape la notification ou une action
  void Function(String? payload, {String? actionId})? onNotificationTap;

  BuildContext? _context;

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[LocalNotif] ℹ️ Already initialized');
      return;
    }

    if (_initializing) {
      debugPrint('[LocalNotif] ⏳ Initialization in progress, waiting...');
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializing = true;
    debugPrint('[LocalNotif] 🚀 Initializing...');

    try {
      const androidSettings =
          AndroidInitializationSettings('notification_icon');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin
          .initialize(
            const InitializationSettings(
              android: androidSettings,
              iOS: iosSettings,
            ),
            onDidReceiveNotificationResponse: (response) {
              _handleNotificationResponse(response);
            },
          )
          .timeout(_kNotificationTimeout);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        // ✅ v3 : purge des canaux legacy (muets à jamais) AVANT de recréer
        await _purgeLegacyChannels(android);
        await _createAndroidChannels(android);
      }

      _initialized = true;
      debugPrint('[LocalNotif] ✓ Initialized successfully (v3)');
    } on TimeoutException {
      debugPrint('[LocalNotif] ❌ Initialization timeout');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ Initialization failed: $e');
      if (kDebugMode) {
        debugPrint(
            '[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    } finally {
      _initializing = false;
    }
  }

  // ✅ v3 : Suppression des anciens canaux immuables (créés sans fichier son)
  Future<void> _purgeLegacyChannels(
      AndroidFlutterLocalNotificationsPlugin android) async {
    debugPrint('[LocalNotif] 🧹 Purging legacy channels...');
    for (final id in _legacyChannels) {
      try {
        await android.deleteNotificationChannel(id);
        debugPrint('[LocalNotif] 🗑️ Legacy channel supprimé: $id');
      } catch (e) {
        // Normal : le canal n'existe pas encore → on ignore silencieusement
      }
    }
  }

  Future<void> _createAndroidChannels(
      AndroidFlutterLocalNotificationsPlugin android) async {
    try {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelDefault,
          'THIX ID',
          description: 'Notifications générales THIX',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      );

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelChat,
          'Messages THIX Chat',
          description: 'Nouveaux messages',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      );

      // ✅ v3 : AJOUT du son 'ringtone' au canal appels (était absent en v2)
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelCalls,
          'Appels THIX',
          description: 'Appels audio et vidéo entrants',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('ringtone'), // ✅ AJOUTÉ
        ),
      );

      debugPrint('[LocalNotif] ✓ Android channels created (v3) with sound + badge');
    } catch (e) {
      debugPrint('[LocalNotif] ⚠️ Failed to create Android channels: $e');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (_context != null && !_context!.mounted) {
      debugPrint('[LocalNotif] ⚠️ Notification response ignored: context not mounted');
      return;
    }

    final payload = response.payload;
    final actionId = response.actionId;

    try {
      onNotificationTap?.call(payload, actionId: actionId);
      debugPrint(
          '[LocalNotif] ✓ Notification response: action=$actionId payload=$payload');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ Notification response callback error: $e');
      if (kDebugMode) {
        debugPrint(
            '[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  @Deprecated('Use initialize() instead')
  Future<void> init() => initialize();

  Future<bool> requestPermission() async {
    debugPrint('[LocalNotif] 🔐 Requesting permissions...');

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        final granted = status.isGranted;
        debugPrint(
            '[LocalNotif] ${granted ? "✓" : "❌"} Android permission: $status');
        return granted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        final result = granted ?? false;
        debugPrint(
            '[LocalNotif] ${result ? "✓" : "❌"} iOS permission: $result');
        return result;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ requestPermission failed: $e');
      if (kDebugMode) {
        debugPrint(
            '[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
      return false;
    }
  }

  /// Affiche une notification locale avec actions selon le type.
  ///
  /// [showReplyAction] : true pour les messages chat → bouton Répondre
  Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    bool showReplyAction = false,
  }) async {
    if (!_Validators.isValidNotificationId(id)) {
      debugPrint('[LocalNotif] ⚠️ show: invalid ID $id');
      return false;
    }

    final sanitizedTitle = _Validators.validateAndSanitizeTitle(title);
    if (sanitizedTitle == null) {
      debugPrint('[LocalNotif] ⚠️ show: empty or invalid title');
      return false;
    }

    final sanitizedBody = _Validators.validateAndSanitizeBody(body);
    if (sanitizedBody == null) {
      debugPrint('[LocalNotif] ⚠️ show: empty or invalid body');
      return false;
    }

    if (!_initialized) {
      debugPrint('[LocalNotif] ⏳ Auto-initializing...');
      await initialize();
      if (!_initialized) {
        debugPrint('[LocalNotif] ❌ show: initialization failed');
        return false;
      }
    }

    final channel = channelId ?? channelDefault;
    final isCall = channel == channelCalls;
    final isChat = channel == channelChat || showReplyAction;

    debugPrint(
        '[LocalNotif] 📢 Showing notification: id=$id, channel=$channel, '
        'title="${sanitizedTitle.substring(0, sanitizedTitle.length.clamp(0, 30))}..."');

    // Actions selon le type
    final List<AndroidNotificationAction> actions = [];

    if (!isCall) {
      // Bouton Ouvrir pour toutes les notifs (sauf appels)
      actions.add(
        const AndroidNotificationAction(
          kActionOpen,
          'Ouvrir',
          showsUserInterface: true,
        ),
      );

      // Bouton Répondre uniquement pour le chat
      if (isChat) {
        actions.add(
          const AndroidNotificationAction(
            kActionReply,
            'Répondre',
            showsUserInterface: true,
          ),
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channel,
      isCall
          ? 'Appels THIX'
          : isChat
              ? 'Messages THIX Chat'
              : 'THIX ID',
      channelDescription: isCall
          ? 'Appels entrants'
          : isChat
              ? 'Nouveaux messages'
              : 'Notifications THIX',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'notification_icon',
      category: isCall
          ? AndroidNotificationCategory.call
          : isChat
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.social,
      fullScreenIntent: isCall,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      autoCancel: true,
      actions: actions.isEmpty ? null : actions,
      // ✅ v3 : son conditionnel — 'ringtone' pour appels, 'notification' sinon
      sound: isCall
          ? const RawResourceAndroidNotificationSound('ringtone')
          : const RawResourceAndroidNotificationSound('notification'),
      styleInformation: BigTextStyleInformation(
        sanitizedBody,
        contentTitle: sanitizedTitle,
        summaryText: isChat ? 'THIX Chat' : 'THIX Hub',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin
          .show(id, sanitizedTitle, sanitizedBody, details, payload: payload)
          .timeout(_kNotificationTimeout);
      debugPrint('[LocalNotif] ✓ Notification shown: id=$id');
      return true;
    } on TimeoutException {
      debugPrint('[LocalNotif] ❌ show: timeout for id=$id');
      return false;
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ show failed: $e');
      if (kDebugMode) {
        debugPrint(
            '[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
      return false;
    }
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
  }) {
    return show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelChat,
      showReplyAction: true,
    );
  }

  Future<bool> cancel(int id) {
    if (!_Validators.isValidNotificationId(id)) {
      debugPrint('[LocalNotif] ⚠️ cancel: invalid ID $id');
      return Future.value(false);
    }
    return _cancelInternal(id);
  }

  Future<bool> _cancelInternal(int id) async {
    try {
      await _plugin.cancel(id).timeout(_kNotificationTimeout);
      debugPrint('[LocalNotif] ✓ Notification cancelled: id=$id');
      return true;
    } on TimeoutException {
      debugPrint('[LocalNotif] ❌ cancel: timeout for id=$id');
      return false;
    } catch (e) {
      debugPrint('[LocalNotif] ❌ cancel failed: $e');
      return false;
    }
  }

  Future<bool> cancelAll() async {
    try {
      await _plugin.cancelAll().timeout(_kNotificationTimeout);
      debugPrint('[LocalNotif] ✓ All notifications cancelled');
      return true;
    } on TimeoutException {
      debugPrint('[LocalNotif] ❌ cancelAll: timeout');
      return false;
    } catch (e) {
      debugPrint('[LocalNotif] ❌ cancelAll failed: $e');
      return false;
    }
  }

  void registerContext(BuildContext context) {
    _context = context;
  }

  void unregisterContext() {
    _context = null;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[LocalNotif] 🔄 Resetting for testing...');
    _initialized = false;
    _initializing = false;
    onNotificationTap = null;
    _context = null;
  }
}
