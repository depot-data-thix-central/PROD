// lib/services/local_notification_service_io.dart
//
/// Local Notification Service IO (Production Enterprise)
/// ✅ SÉCURISÉ : Validation stricte, sanitization des inputs
/// ✅ ROBUSTE : Error handling, mounted checks, timeouts
/// ✅ OBSERVABLE : Logs structurés avec emojis et contexte
/// ✅ FIX: Drawable resource ID must not be 0 (icon + channel IDs v3)
/// ✅ FIX: Son personnalisé (notification.mp3 + ringtone.mp3 dans res/raw/)
/// ✅ FIX: showBadge: true pour compteur sur l'icône
/// ✅ NEW: Actions Ouvrir / Répondre / Marquer lu / Muet (Quick Reply)
/// ✅ v3  : Bump canaux _v2 → _v3 (les v2 sont muets à jamais : immuables)
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
const String kActionMarkAsRead = 'MARK_AS_READ';
const String kActionMute = 'MUTE';

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

  static const String channelDefault = 'thix_id_default_v3';
  static const String channelChat = 'thix_chat_v3';
  static const String channelCalls = 'thix_calls_v3';

  static const List<String> _legacyChannels = [
    'thix_id_default_v2',
    'thix_chat_v2',
    'thix_calls_v2',
    'thix_id_default',
    'thix_chat',
    'thix_calls',
  ];

  /// Callback quand l'utilisateur tape la notification ou une action
  /// ✅ MIS À JOUR : Prend maintenant en compte le champ `input` (Quick Reply)
  void Function(String? payload, {String? actionId, String? input})? onNotificationTap;

  BuildContext? _context;

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[LocalNotif] ℹ️ Already initialized');
      return;
    }

    if (_initializing) {
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
            // ✅ Ajout de la gestion des actions en arrière-plan
            onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
          )
          .timeout(_kNotificationTimeout);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
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
        debugPrint('[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _purgeLegacyChannels(
      AndroidFlutterLocalNotificationsPlugin android) async {
    for (final id in _legacyChannels) {
      try {
        await android.deleteNotificationChannel(id);
      } catch (_) {}
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

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelCalls,
          'Appels THIX',
          description: 'Appels audio et vidéo entrants',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('ringtone'),
        ),
      );
    } catch (e) {
      debugPrint('[LocalNotif] ⚠️ Failed to create Android channels: $e');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (_context != null && !_context!.mounted) return;

    try {
      onNotificationTap?.call(
        response.payload, 
        actionId: response.actionId,
        input: response.input, // ✅ Récupère le texte tapé (Quick Reply)
      );
    } catch (e) {
      debugPrint('[LocalNotif] ❌ Notification response callback error: $e');
    }
  }

  // ✅ Gestionnaire pour quand l'app est complètement fermée (isolate séparé)
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('[LocalNotif-BG] Action: ${response.actionId}, input: ${response.input}');
  }

  Future<bool> requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Affiche une notification locale avec actions selon le type.
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
    if (!_Validators.isValidNotificationId(id)) return false;

    final sanitizedTitle = _Validators.validateAndSanitizeTitle(title);
    if (sanitizedTitle == null) return false;

    final sanitizedBody = _Validators.validateAndSanitizeBody(body);
    if (sanitizedBody == null) return false;

    if (!_initialized) {
      await initialize();
      if (!_initialized) return false;
    }

    final channel = channelId ?? channelDefault;
    final isCall = channel == channelCalls;
    final isChat = channel == channelChat;

    final List<AndroidNotificationAction> actions = [];

    if (!isCall) {
      actions.add(
        const AndroidNotificationAction(
          kActionOpen,
          'Ouvrir',
          showsUserInterface: true,
        ),
      );

      if (isChat && showReplyAction) {
        actions.add(
          const AndroidNotificationAction(
            kActionReply,
            'Répondre',
            showsUserInterface: false, 
            // ✅ CORRECTION ICI : Nouvelle syntaxe pour flutter_local_notifications v18+
            inputs: [
              AndroidNotificationActionInput(label: 'Tapez votre message...'),
            ],
          ),
        );
      }

      if (isChat && showMarkAsReadAction) {
        actions.add(
          const AndroidNotificationAction(
            kActionMarkAsRead,
            'Marquer lu',
            showsUserInterface: false,
          ),
        );
      }

      if (isChat && showMuteAction) {
        actions.add(
          const AndroidNotificationAction(
            kActionMute,
            'Muet',
            showsUserInterface: false, 
          ),
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channel,
      isCall ? 'Appels THIX' : isChat ? 'Messages THIX Chat' : 'THIX ID',
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
      return true;
    } catch (e) {
      return false;
    }
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
      showMarkAsReadAction: true,
      showMuteAction: true,
    );
  }

  Future<bool> cancel(int id) async {
    try {
      await _plugin.cancel(id).timeout(_kNotificationTimeout);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelAll() async {
    try {
      await _plugin.cancelAll().timeout(_kNotificationTimeout);
      return true;
    } catch (e) {
      return false;
    }
  }

  void registerContext(BuildContext context) => _context = context;
  void unregisterContext() => _context = null;
}
