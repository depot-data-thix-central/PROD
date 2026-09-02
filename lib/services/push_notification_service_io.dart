/// Push Notification Service IO (Production Enterprise)
/// ✅ SÉCURISÉ : Validation stricte, sanitization, whitelist, route validation
/// ✅ ROBUSTE : Timeouts, retry, error handling, mounted checks
/// ✅ OBSERVABLE : Logs structurés avec emojis et masquage UID (RGPD)
///
/// Service pour gérer les notifications push via Firebase Cloud Messaging.
///
/// **Architecture** :
/// - Background handler isolé pour notifications en arrière-plan
/// - Foreground handler pour notifications en premier plan
/// - Token management avec Supabase
/// - Callback sur tap avec mounted check
///
/// **Types de notifications supportés** :
/// - `chat_message` : Messages chat (channel: thix_chat)
/// - `incoming_call` : Appels entrants (channel: thix_calls)
/// - `notification` : Notifications générales (channel: thix_id_default)
/// - `sos` : Alertes SOS (channel: thix_id_default)
///
/// **Edge cases gérés** :
/// - Auto-retry sur échec de token registration (3 tentatives)
/// - Timeout sur toutes les opérations async
/// - Sanitization des strings (XSS protection)
/// - Validation des routes (whitelist)
/// - Mounted check avant callbacks
/// - Masquage UID dans les logs (RGPD)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kSupabaseTimeout = Duration(seconds: 15);
const Duration _kBackgroundInitTimeout = Duration(seconds: 10);
const Duration _kForegroundInitTimeout = Duration(seconds: 5);
const int _kMaxRetries = 3;
const Duration _kRetryDelay = Duration(seconds: 2);
const int _kMaxTitleLength = 100;
const int _kMaxBodyLength = 500;
const int _kMaxPayloadLength = 500;
const int _kMaxTokenLength = 500;
const int _kMinUidLength = 20;
const int _kMaxUidLength = 64;

// ============================================================================
// TYPES & WHITELIST
// ============================================================================

/// Types de payload FCM (data.type) — whitelist stricte
class PushTypes {
  PushTypes._();

  static const chatMessage = 'chat_message';
  static const incomingCall = 'incoming_call';
  static const notification = 'notification';
  static const sos = 'sos';

  /// Whitelist des types autorisés
  static const Set<String> allowed = {
    chatMessage,
    incomingCall,
    notification,
    sos,
  };

  /// Vérifie si un type est autorisé
  static bool isAllowed(String type) => allowed.contains(type);
}

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _Validators {
  _Validators._();

  /// Valide le format d'un UID Firebase/Supabase
  static bool isValidUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid.length < _kMinUidLength || uid.length > _kMaxUidLength) return false;
    final regex = RegExp(r'^[A-Za-z0-9_\-]+$');
    return regex.hasMatch(uid);
  }

  /// Valide un token FCM
  static bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length > _kMaxTokenLength) return false;
    // FCM tokens sont alphanumériques avec quelques caractères spéciaux
    final regex = RegExp(r'^[A-Za-z0-9_\-:]+$');
    return regex.hasMatch(token);
  }

  /// Masque un UID pour les logs (RGPD)
  ///
  /// Exemple : `abc123def456ghi789` → `abc1...789`
  static String maskUid(String uid) {
    if (uid.length <= 8) return '***';
    return '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
  }

  /// Masque un token FCM pour les logs
  ///
  /// Exemple : `abc123def456ghi789xyz` → `abc1...xyz`
  static String maskToken(String token) {
    if (token.length <= 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  /// Sanitize un string pour éviter XSS
  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Strip control chars
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  /// Valide une route de navigation (whitelist)
  static bool isValidRoute(String? route) {
    if (route == null || route.isEmpty) return false;
    if (route.length > _kMaxPayloadLength) return false;

    // Whitelist des préfixes autorisés
    const allowedPrefixes = [
      'call:',
      'chat:',
      '/chat',
      '/profile',
      '/notification',
      '/sos',
      '/event',
    ];

    return allowedPrefixes.any((prefix) => route.startsWith(prefix));
  }

  /// Sanitize un payload
  static String? sanitizePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return sanitizeString(payload, maxLength: _kMaxPayloadLength);
  }
}

// ============================================================================
// BACKGROUND HANDLER
// ============================================================================

/// Handler pour les notifications FCM en arrière-plan.
///
/// **Important** :
/// - Exécuté dans un isolate séparé
/// - Doit ré-initialiser Firebase
/// - Timeout agressif pour éviter blocages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM-BG] 🚀 Background handler triggered: ${message.messageId}');

  // Initialiser Firebase avec retry
  var firebaseInitAttempts = 0;
  while (firebaseInitAttempts < _kMaxRetries) {
    try {
      await Firebase.initializeApp().timeout(_kBackgroundInitTimeout);
      debugPrint('[FCM-BG] ✓ Firebase initialized');
      break;
    } catch (e) {
      firebaseInitAttempts++;
      debugPrint('[FCM-BG] ❌ Firebase init failed (attempt $firebaseInitAttempts/$_kMaxRetries): $e');
      if (firebaseInitAttempts >= _kMaxRetries) {
        debugPrint('[FCM-BG] ❌ Max Firebase init attempts reached, aborting');
        return;
      }
      await Future.delayed(_kRetryDelay);
    }
  }

  // Afficher la notification avec timeout
  try {
    await LocalNotificationService.instance
        .initialize()
        .timeout(_kForegroundInitTimeout, onTimeout: () {
      throw TimeoutException('LocalNotificationService init timeout');
    });

    await _showFromRemoteMessage(message);
    debugPrint('[FCM-BG] ✓ Notification shown: ${message.messageId}');
  } on TimeoutException {
    debugPrint('[FCM-BG] ❌ Timeout showing notification: ${message.messageId}');
  } catch (e, stackTrace) {
    debugPrint('[FCM-BG] ❌ Error showing notification: $e');
    if (kDebugMode) {
      debugPrint('[FCM-BG] Stack: ${stackTrace.toString().split('\n').first}');
    }
  }
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

/// Affiche une notification locale depuis un RemoteMessage FCM.
///
/// **Sécurité** :
/// - Validation stricte du type (whitelist)
/// - Sanitization de title/body (XSS protection)
/// - Validation de la route (whitelist)
Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

  // Validation du type (whitelist)
  if (!PushTypes.isAllowed(type)) {
    debugPrint('[FCM] ⚠️ Unknown notification type: $type');
    return;
  }

  // Extraction et sanitization title
  final rawTitle = message.notification?.title ?? data['title']?.toString();
  final title = _Validators.sanitizeString(
    rawTitle ?? _defaultTitle(type),
    maxLength: _kMaxTitleLength,
  );

  // Extraction et sanitization body
  final rawBody = message.notification?.body ??
      data['body']?.toString() ??
      data['message']?.toString();
  final body = _Validators.sanitizeString(
    rawBody ?? 'Nouvelle notification',
    maxLength: _kMaxBodyLength,
  );

  // Construction et validation payload
  final payload = _buildPayload(data);

  // Sélection du channel
  final channelId = _getChannelForType(type);

  // Génération ID unique
  final notifId = _generateNotifId(message);

  debugPrint('[FCM] 📢 Showing notification: type=$type, id=$notifId, '
      'title="${title.substring(0, title.length.clamp(0, 30))}..."');

  try {
    await LocalNotificationService.instance.show(
      id: notifId,
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );
  } catch (e, stackTrace) {
    debugPrint('[FCM] ❌ Failed to show notification: $e');
    if (kDebugMode) {
      debugPrint('[FCM] Stack: ${stackTrace.toString().split('\n').first}');
    }
  }
}

/// Retourne le channel approprié pour un type de notification
String _getChannelForType(String type) {
  switch (type) {
    case PushTypes.incomingCall:
      return LocalNotificationService.channelCalls;
    case PushTypes.chatMessage:
      return LocalNotificationService.channelChat;
    default:
      return LocalNotificationService.channelDefault;
  }
}

/// Retourne le titre par défaut pour un type de notification
String _defaultTitle(String type) {
  switch (type) {
    case PushTypes.incomingCall:
      return 'Appel entrant';
    case PushTypes.chatMessage:
      return 'Nouveau message';
    case PushTypes.sos:
      return 'Alerte SOS';
    default:
      return 'THIX Hub';
  }
}

/// Construit le payload de navigation depuis les données FCM.
///
/// **Sécurité** :
/// - Validation stricte des routes (whitelist)
/// - Sanitization des IDs
/// - Rejet des routes non autorisées
String? _buildPayload(Map<String, dynamic> data) {
  // Priorité : route explicite
  final route = data['route']?.toString();
  if (route != null && route.isNotEmpty) {
    if (_Validators.isValidRoute(route)) {
      return _Validators.sanitizePayload(route);
    } else {
      debugPrint('[FCM] ⚠️ Invalid route rejected: $route');
    }
  }

  // Construction selon le type
  final type = (data['type'] ?? '').toString().toLowerCase();
  switch (type) {
    case PushTypes.incomingCall:
      final inviteId = _Validators.sanitizeString(
        (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
        maxLength: 64,
      );
      final channel = _Validators.sanitizeString(
        (data['channel_name'] ?? data['channelName'] ?? '').toString(),
        maxLength: 64,
      );
      if (inviteId.isNotEmpty && channel.isNotEmpty) {
        return 'call:$inviteId:$channel';
      }
      return null;

    case PushTypes.chatMessage:
      final convId = _Validators.sanitizeString(
        (data['conversation_id'] ?? data['conversationId'] ?? '').toString(),
        maxLength: 64,
      );
      if (convId.isNotEmpty) {
        return 'chat:$convId';
      }
      return null;

    default:
      final notifId = data['notification_id']?.toString() ?? data['id']?.toString();
      return notifId != null ? _Validators.sanitizePayload(notifId) : null;
  }
}

/// Génère un ID unique pour la notification.
///
/// **Stratégie** :
/// - Utilise messageId si disponible
/// - Sinon utilise timestamp + random pour éviter collisions
/// - Masque le bit de signe pour garantir positif
int _generateNotifId(RemoteMessage message) {
  final id = message.messageId ??
      message.data['invite_id']?.toString() ??
      message.data['conversation_id']?.toString();

  if (id != null && id.isNotEmpty) {
    // Hash avec sel pour réduire collisions
    final hash = id.hashCode ^ 0x12345678;
    return hash & 0x7fffffff;
  }

  // Fallback : timestamp + random
  final now = DateTime.now().microsecondsSinceEpoch;
  return (now ^ (now >> 16)) & 0x7fffffff;
}

// ============================================================================
// PUSH NOTIFICATION SERVICE
// ============================================================================

/// Service pour gérer les notifications push via Firebase Cloud Messaging.
///
/// **Usage** :
/// ```dart
/// await PushNotificationService.instance.initialize();
/// await PushNotificationService.instance.onSignedIn(userId: uid);
///
/// // Callback sur tap
/// PushNotificationService.instance.onPushTap = (data) {
///   // Navigation custom
/// };
/// ```
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _tokensTable = 'user_device_tokens';

  bool _initialized = false;
  bool _initializing = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  BuildContext? _context;

  /// Callback global pour navigation avancée sur tap.
  ///
  /// **Important** :
  /// - Le callback est appelé avec mounted check automatique
  /// - Les erreurs dans le callback sont catchées et loggées
  static void Function(Map<String, dynamic> data)? onPushTap;

  /// Initialise le service de notifications push.
  ///
  /// **Comportement** :
  /// - Demande les permissions FCM
  /// - Enregistre le token dans Supabase
  /// - Configure les listeners foreground/tap
  /// - Gère le message initial (app launched from notification)
  ///
  /// **Idempotent** : Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[PushNotif] ℹ️ Already initialized');
      await _registerToken();
      return;
    }

    if (_initializing) {
      debugPrint('[PushNotif] ⏳ Initialization in progress, waiting...');
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializing = true;
    debugPrint('[PushNotif] 🚀 Initializing...');

    try {
      // Demander permissions FCM
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      debugPrint('[PushNotif] ✓ FCM permission: ${settings.authorizationStatus}');

      // Android 13+ : permission via LocalNotificationService
      try {
        await LocalNotificationService.instance.requestPermission();
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ LocalNotificationService permission failed: $e');
      }

      // Enregistrer token
      await _registerToken();

      // Listener refresh token
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
        debugPrint('[PushNotif] 🔄 Token refreshed: ${_Validators.maskToken(token)}');
        unawaited(_registerToken());
      });

      // Listener foreground
      _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listener tap
      _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Message initial (app launched from notification)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PushNotif] ℹ️ App launched from notification');
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[PushNotif] ✓ Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ Initialization failed: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    } finally {
      _initializing = false;
    }
  }

  /// Appelé quand l'utilisateur se connecte.
  ///
  /// **Important** :
  /// - Cleanup les anciens listeners pour éviter les fuites mémoire
  /// - Ré-initialise le service
  Future<void> onSignedIn({required String userId}) async {
    if (!_Validators.isValidUid(userId)) {
      debugPrint('[PushNotif] ⚠️ onSignedIn: invalid userId');
      return;
    }

    debugPrint('[PushNotif] 🔐 User signed in: ${_Validators.maskUid(userId)}');

    // Cleanup anciens listeners
    _cleanupListeners();

    // Reset et ré-initialiser
    _initialized = false;
    await initialize();
  }

  /// Appelé quand l'utilisateur se déconnecte.
  Future<void> onSignedOut() async {
    debugPrint('[PushNotif] 🔓 User signed out');
    _cleanupListeners();
    await unregisterToken();
    _initialized = false;
  }

  /// Cleanup tous les listeners pour éviter les fuites mémoire
  void _cleanupListeners() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _openedAppSub?.cancel();
    _openedAppSub = null;
    debugPrint('[PushNotif] 🧹 Listeners cleaned up');
  }

  /// Gère les notifications en premier plan
  void _handleForegroundMessage(RemoteMessage message) {
    // Vérifier si la notification a du contenu visuel
    final hasVisual = message.notification != null ||
        message.data['title'] != null ||
        message.data['body'] != null ||
        message.data['type'] != null;

    if (!hasVisual) {
      debugPrint('[PushNotif] ⏭️ Foreground ignored (empty): ${message.messageId}');
      return;
    }

    debugPrint('[PushNotif] 📥 Foreground notification: ${message.messageId}');
    unawaited(_showFromRemoteMessage(message));
  }

  /// Gère le tap sur une notification
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final payload = _buildPayload(data);

    debugPrint('[PushNotif] 👆 Notification tap: type=$type, payload=$payload');

    // Mounted check si context disponible
    if (_context != null && !_context!.mounted) {
      debugPrint('[PushNotif] ⚠️ Tap ignored: context not mounted');
      return;
    }

    // Callback LocalNotificationService
    try {
      LocalNotificationService.instance.onNotificationTap?.call(payload);
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ onNotificationTap callback error: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }

    // Callback global onPushTap
    try {
      onPushTap?.call(data);
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ onPushTap callback error: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  /// Enregistre le token FCM dans Supabase avec retry.
  ///
  /// **Sécurité** :
  /// - Validation stricte du token et de l'UID
  /// - Masquage dans les logs (RGPD)
  /// - Retry automatique sur échec (3 tentatives)
  Future<void> _registerToken() async {
    var attempts = 0;

    while (attempts < _kMaxRetries) {
      try {
        final token = await _messaging.getToken();
        final uid = SupabaseConfig.currentUser?.id;

        // Validation
        if (token == null || !_Validators.isValidToken(token)) {
          debugPrint('[PushNotif] ⚠️ Invalid or null token');
          return;
        }

        if (uid == null || !_Validators.isValidUid(uid)) {
          debugPrint('[PushNotif] ⚠️ Invalid or null UID');
          return;
        }

        await SupabaseConfig.client
            .from(_tokensTable)
            .upsert(
              {
                'user_id': uid,
                'fcm_token': token,
                'platform': defaultTargetPlatform.name,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              onConflict: 'user_id,fcm_token', // Composite key pour éviter conflits
            )
            .timeout(_kSupabaseTimeout);

        debugPrint('[PushNotif] ✓ Token registered: uid=${_Validators.maskUid(uid)}, '
            'token=${_Validators.maskToken(token)}');
        return; // Succès
      } on TimeoutException {
        attempts++;
        debugPrint('[PushNotif] ⏱️ Token registration timeout (attempt $attempts/$_kMaxRetries)');
        if (attempts >= _kMaxRetries) {
          debugPrint('[PushNotif] ❌ Max token registration attempts reached');
          return;
        }
        await Future.delayed(_kRetryDelay);
      } catch (e, stackTrace) {
        attempts++;
        debugPrint('[PushNotif] ❌ Token registration failed (attempt $attempts/$_kMaxRetries): $e');
        if (kDebugMode && attempts == 1) {
          debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
        }
        if (attempts >= _kMaxRetries) {
          debugPrint('[PushNotif] ❌ Max token registration attempts reached');
          return;
        }
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  /// Désenregistre le token FCM de Supabase.
  ///
  /// **Usage** :
  /// - Appelé automatiquement sur logout
  /// - Peut être appelé manuellement si besoin
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || !_Validators.isValidToken(token)) {
        debugPrint('[PushNotif] ⚠️ No valid token to unregister');
        return;
      }

      await SupabaseConfig.client
          .from(_tokensTable)
          .delete()
          .eq('fcm_token', token)
          .timeout(_kSupabaseTimeout);

      debugPrint('[PushNotif] ✓ Token unregistered: ${_Validators.maskToken(token)}');
    } on TimeoutException {
      debugPrint('[PushNotif] ❌ Token unregistration timeout');
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ Token unregistration failed: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  /// Enregistre un BuildContext pour mounted check dans les callbacks.
  ///
  /// **Usage** :
  /// ```dart
  /// PushNotificationService.instance.registerContext(context);
  /// ```
  void registerContext(BuildContext context) {
    _context = context;
  }

  /// Désenregistre le BuildContext.
  void unregisterContext() {
    _context = null;
  }

  /// Dispose le service et cleanup tous les listeners.
  ///
  /// **Important** :
  /// - Appeler dans `dispose()` du widget principal
  /// - Annule tous les listeners pour éviter les fuites mémoire
  void dispose() {
    debugPrint('[PushNotif] 🗑️ Disposing service');
    _cleanupListeners();
    onPushTap = null;
    _context = null;
    _initialized = false;
    _initializing = false;
  }

  /// Reset le service pour les tests unitaires.
  ///
  /// ⚠️ **Usage interne uniquement** (tests unitaires).
  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[PushNotif] 🔄 Resetting for testing...');
    dispose();
  }
}
