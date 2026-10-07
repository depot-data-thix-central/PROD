/// Local Notification Service IO (Production Enterprise)
/// ✅ SÉCURISÉ : Validation stricte, sanitization des inputs
/// ✅ ROBUSTE : Error handling, mounted checks, timeouts
/// ✅ OBSERVABLE : Logs structurés avec emojis et contexte
/// ✅ FIX: Drawable resource ID must not be 0 (icon + channel IDs v2)
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
const int _kMaxNotificationId = 2147483647; // int32 max

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _Validators {
  _Validators._();

  /// Valide un ID de notification
  static bool isValidNotificationId(int id) {
    return id >= _kMinNotificationId && id <= _kMaxNotificationId;
  }

  /// Sanitize un string pour éviter XSS dans les notifications
  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  /// Valide et sanitize un title
  static String? validateAndSanitizeTitle(String? title) {
    if (title == null || title.trim().isEmpty) return null;
    return sanitizeString(title, maxLength: _kMaxTitleLength);
  }

  /// Valide et sanitize un body
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

  // ✅ FIX: IDs suffixés _v2 pour forcer la recréation des canaux Android
  // (les anciens canaux créés avec @mipmap/ic_launcher sont cassés)
  static const String channelDefault = 'thix_id_default_v2';
  static const String channelChat = 'thix_chat_v2';
  static const String channelCalls = 'thix_calls_v2';

  /// Callback appelé quand l'utilisateur tape sur une notification.
  void Function(String? payload)? onNotificationTap;

  /// Référence au BuildContext pour mounted check (optionnel)
  BuildContext? _context;

  /// Initialise le service de notifications locales.
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
      // ✅ FIX: Utiliser 'notification_icon' (res/drawable) au lieu de '@mipmap/ic_launcher'
      // Le plugin flutter_local_notifications ne supporte PAS le format @mipmap/
      // Il faut un fichier notification_icon.png dans android/app/src/main/res/drawable/
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
              _handleNotificationTap(response.payload);
            },
          )
          .timeout(_kNotificationTimeout);

      // Android-specific channel creation
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        await _createAndroidChannels(android);
      }

      _initialized = true;
      debugPrint('[LocalNotif] ✓ Initialized successfully');
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

  /// Crée les channels Android avec Importance.max
  Future<void> _createAndroidChannels(
      AndroidFlutterLocalNotificationsPlugin android) async {
    try {
      // Channel par défaut
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelDefault,
          'THIX ID',
          description: 'Notifications générales THIX',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Channel chat
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelChat,
          'Messages THIX Chat',
          description: 'Nouveaux messages',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Channel appels
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelCalls,
          'Appels THIX',
          description: 'Appels audio et vidéo entrants',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      debugPrint('[LocalNotif] ✓ Android channels created (v2)');
    } catch (e) {
      debugPrint('[LocalNotif] ⚠️ Failed to create Android channels: $e');
    }
  }

  /// Gère le tap sur notification avec mounted check
  void _handleNotificationTap(String? payload) {
    if (_context != null && !_context!.mounted) {
      debugPrint('[LocalNotif] ⚠️ Notification tap ignored: context not mounted');
      return;
    }

    try {
      onNotificationTap?.call(payload);
      debugPrint('[LocalNotif] ✓ Notification tap handled: payload=$payload');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ Notification tap callback error: $e');
      if (kDebugMode) {
        debugPrint(
            '[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  /// Alias pour `initialize()` (compatibilité)
  @Deprecated('Use initialize() instead')
  Future<void> init() => initialize();

  /// Demande les permissions de notifications.
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

      debugPrint('[LocalNotif] ℹ️ Platform not supported, returning true');
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

  /// Affiche une notification locale.
  Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    // Validation ID
    if (!_Validators.isValidNotificationId(id)) {
      debugPrint('[LocalNotif] ⚠️ show: invalid ID $id');
      return false;
    }

    // Validation et sanitization title
    final sanitizedTitle = _Validators.validateAndSanitizeTitle(title);
    if (sanitizedTitle == null) {
      debugPrint('[LocalNotif] ⚠️ show: empty or invalid title');
      return false;
    }

    // Validation et sanitization body
    final sanitizedBody = _Validators.validateAndSanitizeBody(body);
    if (sanitizedBody == null) {
      debugPrint('[LocalNotif] ⚠️ show: empty or invalid body');
      return false;
    }

    // Auto-initialisation
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
    final isChat = channel == channelChat;

    debugPrint(
        '[LocalNotif] 📢 Showing notification: id=$id, channel=$channel, '
        'title="${sanitizedTitle.substring(0, sanitizedTitle.length.clamp(0, 30))}..."');

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
      // ✅ FIX: Utiliser 'notification_icon' au lieu de '@mipmap/ic_launcher'
      // Le fichier notification_icon.png doit exister dans res/drawable/
      icon: 'notification_icon',
      category: isCall
          ? AndroidNotificationCategory.call
          : isChat
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.status,
      fullScreenIntent: isCall,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
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

  /// Raccourci pour afficher une notification d'appel entrant.
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

  /// Annule toutes les notifications.
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

  /// Enregistre un BuildContext pour mounted check dans les callbacks.
  void registerContext(BuildContext context) {
    _context = context;
  }

  /// Désenregistre le BuildContext.
  void unregisterContext() {
    _context = null;
  }

  /// Reset le service pour les tests unitaires.
  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[LocalNotif] 🔄 Resetting for testing...');
    _initialized = false;
    _initializing = false;
    onNotificationTap = null;
    _context = null;
  }
}
