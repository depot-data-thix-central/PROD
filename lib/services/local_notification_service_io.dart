// lib/services/local_notification_service_io.dart
//
// Local Notification Service IO v3.4.1 (Production Enterprise + Wedding + THIX Info)
//
// CHANGELOG v3.4.1 :
//   ✅ FIX v18.0.1 : `vibrationPattern: Int64List.fromList` retiré du contexte `const`
//   ✅ FIX v18.0.1 : `FilePathAndroidNotificationDetails` -> `FilePathAndroidBitmap`
//   ✅ FIX v18.0.1 : `hideLargeIconOnExpandedState` -> `hideExpandedLargeIcon`
//   ✅ Ajout de l'import `dart:typed_data` pour `Int64List`
//
// CHANGELOG v3.4 :
//   ✅ Ajout des canaux "THIX Info Breaking" (prioritaire, son d'alerte)
//   ✅ Ajout du canal "THIX Info Actualités" (articles à la une, nouveautés)
//   ✅ Gestion spécifique des breaking news (LED rouge, vibration forte)
//
// CHANGELOG v3.3 :
//   ✅ Ajout de `showWeddingMessage` pour les messages de mariage avec actions.
//   ✅ Ajout de `showWeddingAlert` pour les alertes de mariage (RSVP, menu, tâches).
//   ✅ Ajout du channel "Wedding" pour séparer les notifications d'événements 
//      des messages généraux.
// ============================================================================

import 'dart:async';
import 'dart:typed_data'; // ✅ Ajouté pour Int64List

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

  // ── Canaux de notification ──
  static const String channelDefault = 'thix_id_default_v3';
  static const String channelChat = 'thix_chat_v3';
  static const String channelCalls = 'thix_calls_v3';
  static const String channelWedding = 'thix_wedding_v3';
  
  // 🆕 THIX Info
  static const String channelNewsBreaking = 'thix_news_breaking_v1'; // 🔴 Prioritaire
  static const String channelNews = 'thix_news_general_v1';         // 📰 Actualités

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
      debugPrint('[LocalNotif] ✓ Initialized successfully (v3.4.1)');

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
      // ── Canal par défaut ──
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

      // ── Canal Chat ──
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

      // ── Canal Appels ──
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

      // ── Canal Mariages ──
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelWedding,
          'Mariages & Événements',
          description: 'Mises à jour de vos mariages (RSVP, menu, tâches...)',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      );

      // 🆕 Canal THIX Info Breaking (prioritaire — alertes urgentes)
      // ✅ FIX : Suppression du `const` car Int64List.fromList n'est pas constant
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelNewsBreaking,
          '🔴 Alertes Info',
          description: 'Flash info urgent et actualités prioritaires THIX Info',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFDC2626), // Rouge
          showBadge: true,
          // Si tu as un son dédié : RawResourceAndroidNotificationSound('alert_news')
          sound: const RawResourceAndroidNotificationSound('notification'),
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        ),
      );

      // 🆕 Canal THIX Info Général (actualités normales)
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelNews,
          '📰 Actualités THIX Info',
          description: 'Articles à la une et nouveautés',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      );
    } catch (e) {
      debugPrint('[LocalNotif] ⚠️ Failed to create Android channels: $e');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;
    final input = response.input;

    debugPrint('[LocalNotif] 📨 Response: action=$actionId '
        'input="${input ?? '(null)'}" payload=$payload');

    onNotificationTap?.call(payload, actionId: actionId, input: input);
  }

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
    final isWedding = channel == channelWedding;
    // 🆕 Détection des canaux THIX Info
    final isNewsBreaking = channel == channelNewsBreaking;
    final isNews = channel == channelNews;

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

    // ── Détermination du nom / description / catégorie Android ──
    final String channelName;
    final String channelDesc;
    final AndroidNotificationCategory category;
    final bool fullScreenIntent;
    final RawResourceAndroidNotificationSound sound;
    final String summaryText;

    if (isCall) {
      channelName = 'Appels THIX';
      channelDesc = 'Appels entrants';
      category = AndroidNotificationCategory.call;
      fullScreenIntent = true;
      sound = const RawResourceAndroidNotificationSound('ringtone');
      summaryText = 'Appel';
    } else if (isNewsBreaking) {
      // 🆕 Breaking news : priorité max, full-screen, vibration forte
      channelName = '🔴 Alertes Info';
      channelDesc = 'Flash info urgent THIX Info';
      category = AndroidNotificationCategory.alarm;
      fullScreenIntent = true; // Force l'affichage même écran verrouillé
      sound = const RawResourceAndroidNotificationSound('notification');
      summaryText = '🔴 Alerte Info';
    } else if (isNews) {
      // 🆕 Actualité standard
      channelName = '📰 Actualités THIX Info';
      channelDesc = 'Articles à la une';
      category = AndroidNotificationCategory.social;
      fullScreenIntent = false;
      sound = const RawResourceAndroidNotificationSound('notification');
      summaryText = 'THIX Info';
    } else if (isWedding) {
      channelName = 'Mariages & Événements';
      channelDesc = 'Mises à jour de mariages';
      category = AndroidNotificationCategory.event;
      fullScreenIntent = false;
      sound = const RawResourceAndroidNotificationSound('notification');
      summaryText = 'Mariage';
    } else if (isChat) {
      channelName = 'Messages THIX Chat';
      channelDesc = 'Nouveaux messages';
      category = AndroidNotificationCategory.message;
      fullScreenIntent = false;
      sound = const RawResourceAndroidNotificationSound('notification');
      summaryText = 'THIX Chat';
    } else {
      channelName = 'THIX ID';
      channelDesc = 'Notifications THIX';
      category = AndroidNotificationCategory.social;
      fullScreenIntent = false;
      sound = const RawResourceAndroidNotificationSound('notification');
      summaryText = 'THIX Hub';
    }

    // ── Pattern de vibration spécifique au breaking news ──
    Int64List? vibrationPattern;
    if (isNewsBreaking) {
      vibrationPattern = Int64List.fromList([0, 400, 150, 400, 150, 400]);
    }

    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: channelDesc,
      importance: (isNewsBreaking || isCall) ? Importance.max : Importance.high,
      priority: (isNewsBreaking || isCall) ? Priority.max : Priority.high,
      icon: 'notification_icon',
      category: category,
      fullScreenIntent: fullScreenIntent,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      enableLights: isNewsBreaking,
      ledColor: isNewsBreaking ? const Color(0xFFDC2626) : null,
      ledOnMs: isNewsBreaking ? 1000 : null,
      ledOffMs: isNewsBreaking ? 500 : null,
      channelShowBadge: true,
      autoCancel: true,
      actions: actions.isEmpty ? null : actions,
      sound: sound,
      // Pour breaking news : image de preview si fournie
      styleInformation: BigTextStyleInformation(
        sanitizedBody,
        contentTitle: sanitizedTitle,
        summaryText: summaryText,
      ),
      // Couleur d'accent pour les breaking news
      color: isNewsBreaking ? const Color(0xFFDC2626) : null,
      colorized: isNewsBreaking,
    );

    // ── Détails iOS ──
    // Breaking news = critical si possible, sinon timeSensitive
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: isNewsBreaking
          ? InterruptionLevel.critical
          : (isCall
              ? InterruptionLevel.timeSensitive
              : isNews
                  ? InterruptionLevel.timeSensitive
                  : InterruptionLevel.active),
      categoryIdentifier: isChat ? _kIosChatCategory : null,
      // Son d'alerte pour breaking news (si configuré côté iOS)
      sound: isNewsBreaking ? 'alert_news.caf' : null,
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

  /// ✅ Afficher un message de mariage (avec options "Répondre")
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
      showReplyAction: true,
      showMarkAsReadAction: true,
      showMuteAction: true,
    );
  }

  /// ✅ Afficher une alerte de mariage (RSVP, menu, tâche, etc.)
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
      showReplyAction: false,
      showMarkAsReadAction: false,
      showMuteAction: false,
    );
  }

  // 🆕 THIX Info — Breaking news (alerte urgente)
  Future<bool> showNewsBreaking({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
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

    // Actions : "Ouvrir" uniquement
    final actions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        kActionOpen,
        'Lire',
        showsUserInterface: true,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      channelNewsBreaking,
      '🔴 Alertes Info',
      channelDescription: 'Flash info urgent THIX Info',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'notification_icon',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 150, 400, 150, 400]),
      enableLights: true,
      ledColor: const Color(0xFFDC2626),
      ledOnMs: 1000,
      ledOffMs: 500,
      channelShowBadge: true,
      autoCancel: true,
      actions: actions,
      sound: const RawResourceAndroidNotificationSound('notification'),
      color: const Color(0xFFDC2626),
      colorized: true,
      // ✅ FIX 1 : FilePathAndroidNotificationDetails -> FilePathAndroidBitmap
      largeIcon: imageUrl != null
          ? FilePathAndroidBitmap(imageUrl)
          : null,
      // ✅ FIX 2 : hideLargeIconOnExpandedState -> hideExpandedLargeIcon
      styleInformation: BigPictureStyleInformation(
        imageUrl != null
            ? FilePathAndroidBitmap(imageUrl)
            : const DrawableResourceAndroidBitmap('notification_icon'),
        contentTitle: sanitizedTitle,
        summaryText: '🔴 Alerte Info',
        largeIcon: null,
        hideExpandedLargeIcon: true, 
      ),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      sound: 'alert_news.caf',
      attachments: imageUrl != null
          ? [DarwinNotificationAttachment(imageUrl)]
          : null,
    );

    try {
      await _plugin
          .show(
            id,
            sanitizedTitle,
            sanitizedBody,
            NotificationDetails(android: androidDetails, iOS: iosDetails),
            payload: payload,
          )
          .timeout(_kNotificationTimeout);
      return true;
    } catch (e) {
      debugPrint('[LocalNotif] ❌ showNewsBreaking failed: $e');
      return false;
    }
  }

  // 🆕 THIX Info — Actualité standard
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
