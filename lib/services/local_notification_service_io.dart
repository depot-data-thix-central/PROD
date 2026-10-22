// lib/services/local_notification_service_io.dart
//
// Local Notification Service IO v3.2 (Production Enterprise)
//
// CHANGELOG v3.2 (depuis v3.1) :
//   ✅ FIX BUILD: Retrait de `const` devant `iosSettings` et
//      `InitializationSettings`. DarwinNotificationAction.text/plain
//      ne sont pas des constructeurs const dans flutter_local_notifications,
//      ce qui rendait toute la chaîne invalide en compilation release.
//
// CHANGELOG v3.1 :
//   ✅ Catégories Darwin enregistrées pour iOS : REPLY (avec input texte),
//      MARK_AS_READ, MUTE.
//   ✅ Buffer d'actions en attente (cold-start).
//   ✅ Réponse background forcée en foreground pour Quick Reply.
//   ✅ Retrait du gate `context.mounted` qui bloquait les taps cold-start.
//
// Conserve tous les correctifs v3 : canaux _v3, validation, sanitization,
// ringtone.mp3 dans res/raw/, showBadge, AndroidNotificationActionInput.
// ============================================================================

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

// Identifiants d'actions (partagés avec main.dart)
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';
const String kActionMarkAsRead = 'MARK_AS_READ';
const String kActionMute = 'MUTE';

// Catégorie iOS pour les actions de chat
const String _kIosChatCategory = 'THIX_CHAT_ACTIONS';

// ============================================================================
// BUFFER D'ACTIONS EN ATTENTE (cold-start)
// ============================================================================

class _PendingActionBuffer {
  _PendingActionBuffer._();

  static String? _pendingPayload;
  static String? _pendingActionId;
  static String? _pendingInput;

  static void store(String? payload, {String? actionId, String? input}) {
    _pendingPayload = payload;
    _pendingActionId = actionId;
    _pendingInput = input;
    debugPrint('[PendingAction] ⏳ Stored: action=$actionId payload=$payload');
  }

  static ({String? payload, String? actionId, String? input})? consume() {
    if (_pendingPayload == null && _pendingActionId == null) return null;
    final r = (
      payload: _pendingPayload,
      actionId: _pendingActionId,
      input: _pendingInput,
    );
    _pendingPayload = null;
    _pendingActionId = null;
    _pendingInput = null;
    return r;
  }

  static bool get hasPending =>
      _pendingPayload != null || _pendingActionId != null;
}

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

  /// Callback quand l'utilisateur tape la notification ou une action.
  /// `input` contient le texte tapé pour les actions Quick Reply.
  void Function(String? payload, {String? actionId, String? input})?
      onNotificationTap;

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

      // ✅ v3.2 : `final` et NON `const` car DarwinNotificationAction.text()
      // et DarwinNotificationAction.plain() ne sont pas des constructeurs
      // const dans flutter_local_notifications. Utiliser `const` ici
      // provoquait l'erreur "Cannot invoke a non-'const' factory where a
      // const expression is expected" en build release.
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _kIosChatCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.text(
                kActionReply,
                'Répondre',
                buttonTitle: 'Envoyer',
                placeholder: 'Tapez votre message…',
              ),
              DarwinNotificationAction.plain(
                kActionMarkAsRead,
                'Marquer lu',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
              DarwinNotificationAction.plain(
                kActionMute,
                'Muet',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ],
      );

      // ✅ v3.2 : Pas de `const` ici non plus, car iosSettings est `final`.
      await _plugin
          .initialize(
            InitializationSettings(
              android: androidSettings,
              iOS: iosSettings,
            ),
            onDidReceiveNotificationResponse: _handleNotificationResponse,
            onDidReceiveBackgroundNotificationResponse:
                _handleBackgroundNotificationResponse,
          )
          .timeout(_kNotificationTimeout);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        await _purgeLegacyChannels(android);
        await _createAndroidChannels(android);
      }

      _initialized = true;
      debugPrint('[LocalNotif] ✓ Initialized successfully (v3.2)');

      // Rejoue une action en attente (cold-start via action)
      _flushPendingAction();
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

  /// Rejoue l'action stockée au cold-start.
  void _flushPendingAction() {
    final pending = _PendingActionBuffer.consume();
    if (pending == null) return;
    debugPrint('[LocalNotif] ▶️ Flushing pending action: '
        '${pending.actionId} payload=${pending.payload}');
    onNotificationTap?.call(
      pending.payload,
      actionId: pending.actionId,
      input: pending.input,
    );
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

  /// Réponse au premier plan (app vivante).
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;
    final input = response.input;

    debugPrint('[LocalNotif] 📨 Response: action=$actionId '
        'input="${input ?? '(null)'}" payload=$payload');

    onNotificationTap?.call(payload, actionId: actionId, input: input);
  }

  /// Réponse en arrière-plan (app fermée / isolate séparé).
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(
      NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;
    final input = response.input;

    debugPrint('[LocalNotif-BG] ⏳ Action=$actionId '
        'input="${input ?? '(null)'}" payload=$payload');

    _PendingActionBuffer.store(payload, actionId: actionId, input: input);
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
            showsUserInterface: true,
            inputs: <AndroidNotificationActionInput>[
              AndroidNotificationActionInput(label: 'Tapez votre message…'),
            ],
          ),
        );
      }

      if (isChat && showMarkAsReadAction) {
        actions.add(
          const AndroidNotificationAction(
            kActionMarkAsRead,
            'Marquer lu',
            showsUserInterface: true,
          ),
        );
      }

      if (isChat && showMuteAction) {
        actions.add(
          const AndroidNotificationAction(
            kActionMute,
            'Muet',
            showsUserInterface: true,
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

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: isChat ? _kIosChatCategory : null,
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
      debugPrint('[LocalNotif] ❌ show failed: $e');
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
