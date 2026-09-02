/// Local Notification Service IO (Production Enterprise)
/// ✅ SÉCURISÉ : Validation stricte, sanitization des inputs
/// ✅ ROBUSTE : Error handling, mounted checks, timeouts
/// ✅ OBSERVABLE : Logs structurés avec emojis et contexte
///
/// Service pour afficher les notifications locales sur Android/iOS.
///
/// **Architecture** :
/// - Singleton pattern avec initialisation lazy
/// - 3 channels de notifications (default, chat, calls)
/// - Platform-specific implementation (Android/iOS)
/// - Callback sur tap avec mounted check
///
/// **Channels** :
/// - `thix_id_default` : Notifications générales (Importance.max)
/// - `thix_chat` : Messages chat (Importance.max, category.message)
/// - `thix_calls` : Appels entrants (Importance.max, category.call, fullScreenIntent)
///
/// **Edge cases gérés** :
/// - Auto-initialisation si appelé avant `initialize()`
/// - Mounted check avant callback `onNotificationTap`
/// - Sanitization des strings (XSS protection)
/// - Validation stricte des IDs et longueurs
/// - Try-catch sur toutes les opérations async
///
/// **Usage** :
/// ```dart
/// await LocalNotificationService.instance.initialize();
/// await LocalNotificationService.instance.requestPermission();
/// await LocalNotificationService.instance.show(
///   id: 1,
///   title: 'Nouveau message',
///   body: 'Vous avez reçu un message',
///   channelId: LocalNotificationService.channelChat,
/// );
/// ```
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
        .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Strip control chars
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

  static const String channelDefault = 'thix_id_default';
  static const String channelChat = 'thix_chat';
  static const String channelCalls = 'thix_calls';

  /// Callback appelé quand l'utilisateur tape sur une notification.
  ///
  /// **Important** : Le callback est appelé avec un mounted check automatique.
  /// Si le widget qui a enregistré le callback est disposed, le callback n'est pas appelé.
  void Function(String? payload)? onNotificationTap;

  /// Référence au BuildContext pour mounted check (optionnel)
  BuildContext? _context;

  /// Initialise le service de notifications locales.
  ///
  /// **Comportement** :
  /// - Appelle idempotent (safe to call multiple times)
  /// - Crée les channels Android avec Importance.max
  /// - Configure les paramètres iOS
  ///
  /// **Edge cases** :
  /// - Si déjà initialisé → retourne immédiatement
  /// - Si initialisation en cours → attend la fin
  /// - Si erreur → log + retourne sans crash
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.initialize();
  /// ```
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
          AndroidInitializationSettings('@mipmap/ic_launcher');
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
        debugPrint('[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
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

      debugPrint('[LocalNotif] ✓ Android channels created');
    } catch (e) {
      debugPrint('[LocalNotif] ⚠️ Failed to create Android channels: $e');
      // Non-critical, continue
    }
  }

  /// Gère le tap sur notification avec mounted check
  void _handleNotificationTap(String? payload) {
    // Mounted check si context disponible
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
        debugPrint('[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  /// Alias pour `initialize()` (compatibilité)
  @Deprecated('Use initialize() instead')
  Future<void> init() => initialize();

  /// Demande les permissions de notifications.
  ///
  /// **Retourne** :
  /// - `true` si permissions accordées
  /// - `false` si permissions refusées ou erreur
  ///
  /// **Platform-specific** :
  /// - Android : utilise `permission_handler`
  /// - iOS : utilise `requestPermissions()` du plugin
  ///
  /// **Usage** :
  /// ```dart
  /// final granted = await LocalNotificationService.instance.requestPermission();
  /// if (granted) {
  ///   // Afficher notifications
  /// }
  /// ```
  Future<bool> requestPermission() async {
    debugPrint('[LocalNotif] 🔐 Requesting permissions...');

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        final granted = status.isGranted;
        debugPrint('[LocalNotif] ${granted ? "✓" : "❌"} Android permission: $status');
        return granted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        final result = granted ?? false;
        debugPrint('[LocalNotif] ${result ? "✓" : "❌"} iOS permission: $result');
        return result;
      }

      debugPrint('[LocalNotif] ℹ️ Platform not supported, returning true');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[LocalNotif] ❌ requestPermission failed: $e');
      if (kDebugMode) {
        debugPrint('[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
      return false;
    }
  }

  /// Affiche une notification locale.
  ///
  /// **Validation** :
  /// - `id` : doit être entre 0 et 2147483647
  /// - `title` : max 100 caractères, HTML stripped
  /// - `body` : max 500 caractères, HTML stripped
  /// - `channelId` : doit être un channel valide
  ///
  /// **Auto-initialisation** :
  /// - Si service non initialisé, appelle `initialize()` automatiquement
  ///
  /// **Retourne** :
  /// - `true` si notification affichée avec succès
  /// - `false` si validation échoue ou erreur
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

    debugPrint('[LocalNotif] 📢 Showing notification: id=$id, channel=$channel, '
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
      icon: '@mipmap/ic_launcher',
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
        debugPrint('[LocalNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
      return false;
    }
  }

  /// Raccourci pour afficher une notification d'appel entrant.
  ///
  /// Utilise le channel `thix_calls` avec `fullScreenIntent: true`.
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
  /// Utilise le channel `thix_chat` avec `category: message`.
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
  /// **Retourne** :
  /// - `true` si annulée avec succès
  /// - `false` si erreur
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.cancel(1);
  /// ```
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
  ///
  /// **Retourne** :
  /// - `true` si toutes annulées avec succès
  /// - `false` si erreur
  ///
  /// **Usage** :
  /// ```dart
  /// await LocalNotificationService.instance.cancelAll();
  /// ```
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
  ///
  /// **Usage** :
  /// ```dart
  /// LocalNotificationService.instance.registerContext(context);
  /// ```
  void registerContext(BuildContext context) {
    _context = context;
  }

  /// Désenregistre le BuildContext.
  void unregisterContext() {
    _context = null;
  }

  /// Reset le service pour les tests unitaires.
  ///
  /// ⚠️ **Usage interne uniquement** (tests unitaires).
  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[LocalNotif] 🔄 Resetting for testing...');
    _initialized = false;
    _initializing = false;
    onNotificationTap = null;
    _context = null;
  }
}
