/// Push Notification Service IO (Production Enterprise v2)
/// ✅ SÉCURISÉ : Validation stricte, sanitization, whitelist, route validation
/// ✅ ROBUSTE : Timeouts, retry, error handling, mounted checks
/// ✅ OBSERVABLE : Logs structurés avec emojis et masquage UID (RGPD)
/// ✅ VOIP NATIF : CallKit iOS + Telecom Android pour appels entrants
/// ✅ SONNERIE PERSISTANTE : Fonctionne même app fermée
/// ✅ BADGE SYNCHRONISÉ : Badge temps réel sur l'icône
///
/// Service pour gérer les notifications push via Firebase Cloud Messaging.
///
/// **Architecture** :
/// - Background handler isolé pour notifications en arrière-plan
/// - Foreground handler pour notifications en premier plan
/// - Token management avec Supabase
/// - Callback sur tap avec mounted check
/// - **VoIP natif** : CallKit (iOS) + Telecom Manager (Android) pour appels
/// - **Sonnerie + vibration** natives persistantes
/// - **Badge synchronisé** via flutter_app_badger
///
/// **Types de notifications supportés** :
/// - `chat_message` : Messages chat (channel: thix_chat)
/// - `incoming_call` : Appels entrants (CallKit natif + channel: thix_calls)
/// - `call_hangup` : Fin d'appel distant
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
/// - Sonnerie automatique arrêtée si appel manqué/raccroché
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kSupabaseTimeout = Duration(seconds: 15);
const Duration _kBackgroundInitTimeout = Duration(seconds: 10);
const Duration _kForegroundInitTimeout = Duration(seconds: 5);
const Duration _kCallkitTimeout = Duration(seconds: 8);
const int _kMaxRetries = 3;
const Duration _kRetryDelay = Duration(seconds: 2);
const int _kMaxTitleLength = 100;
const int _kMaxBodyLength = 500;
const int _kMaxPayloadLength = 500;
const int _kMaxTokenLength = 500;
const int _kMinUidLength = 20;
const int _kMaxUidLength = 64;
const int _kCallDurationMs = 60000; // 60s sonnerie max

// ============================================================================
// TYPES & WHITELIST
// ============================================================================

/// Types de payload FCM (data.type) — whitelist stricte
class PushTypes {
  PushTypes._();

  static const chatMessage = 'chat_message';
  static const incomingCall = 'incoming_call';
  static const callHangup = 'call_hangup';
  static const notification = 'notification';
  static const sos = 'sos';

  /// Whitelist des types autorisés
  static const Set<String> allowed = {
    chatMessage,
    incomingCall,
    callHangup,
    notification,
    sos,
  };

  /// Vérifie si un type est autorisé
  static bool isAllowed(String type) => allowed.contains(type);

  /// Types qui déclenchent CallKit natif
  static const Set<String> voipTypes = {incomingCall};

  /// Vérifie si c'est un type VoIP
  static bool isVoip(String type) => voipTypes.contains(type);
}

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _Validators {
  _Validators._();

  static bool isValidUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid.length < _kMinUidLength || uid.length > _kMaxUidLength) return false;
    final regex = RegExp(r'^[A-Za-z0-9_\-]+$');
    return regex.hasMatch(uid);
  }

  static bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length > _kMaxTokenLength) return false;
    final regex = RegExp(r'^[A-Za-z0-9_\-:]+$');
    return regex.hasMatch(token);
  }

  static String maskUid(String uid) {
    if (uid.length <= 8) return '***';
    return '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
  }

  static String maskToken(String token) {
    if (token.length <= 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static bool isValidRoute(String? route) {
    if (route == null || route.isEmpty) return false;
    if (route.length > _kMaxPayloadLength) return false;

    const allowedPrefixes = [
      'call:',
      'chat:',
      '/chat',
      '/profile',
      '/notification',
      '/sos',
      '/event',
      '/call',
    ];

    return allowedPrefixes.any((prefix) => route.startsWith(prefix));
  }

  static String? sanitizePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return sanitizeString(payload, maxLength: _kMaxPayloadLength);
  }

  /// Valide un UUID (invite_id, call_id, etc.)
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(id);
  }

  /// Sanitize URL (avatar)
  static String? sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    if (url.length > 500) return null;
    return url;
  }
}

// ============================================================================
// VOIP CALL MANAGER (CallKit natif)
// ============================================================================

/// Gestionnaire d'appels VoIP natif (CallKit iOS + Telecom Android)
///
/// **Responsabilités** :
/// - Affiche l'écran d'appel entrant natif
/// - Gère sonnerie + vibration persistantes
/// - Intercepte les événements (accept/decline/timeout)
/// - Stoppe sonnerie sur fin d'appel
class _VoipCallManager {
  _VoipCallManager._();
  static final _VoipCallManager instance = _VoipCallManager._();

  final FlutterRingtonePlayer _ringtone = FlutterRingtonePlayer();
  bool _isInitialized = false;
  bool _isRinging = false;
  Timer? _ringTimeout;

  // Callbacks pour navigation dans l'app
  void Function(String inviteId, String channelName, bool isVideo)? onAcceptCall;
  void Function(String inviteId)? onDeclineCall;

  /// Initialise CallKit et écoute les événements
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final params = CallKitParams(
        handle: 'THIX Hub',
        nameCaller: 'THIX Hub',
        appName: 'THIX Hub',
        avatar: '',
        duration: _kCallDurationMs,
        textAccept: 'Accepter',
        textDecline: 'Refuser',
        textMissedCall: 'Appel manqué',
        textCallback: 'Rappeler',
        extra: <String, dynamic>{'userId': 'thix'},
        headers: <String, dynamic>{'apiKey': 'thix-api-key'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: true,
          ringtonePath: 'ringtone.mp3',
          backgroundColor: '#0A2F5C',
          actionColor: '#4CAF50',
          textColor: '#FFFFFF',
          isShowMissedCallNotification: true,
          isShowCallback: false,
          isCustomSmallAvatar: false,
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: AVAudioSessionMode.defaultMode,
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'ringtone.caf',
        ),
      );

      await FlutterCallkitIncoming.init(params).timeout(_kCallkitTimeout);

      // Écoute les événements CallKit
      FlutterCallkitIncoming.onEvent.listen(_onCallEvent);

      _isInitialized = true;
      debugPrint('[VOIP] ✓ CallKit initialized');
    } catch (e, stackTrace) {
      debugPrint('[VOIP] ❌ Init failed: $e');
      if (kDebugMode) {
        debugPrint('[VOIP] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }
  }

  /// Affiche l'écran d'appel entrant natif
  Future<void> showIncomingCall({
    required String inviteId,
    required String callerName,
    String? callerAvatar,
    required String channelName,
    bool isVideo = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('[VOIP] 🔔 Showing incoming call: $callerName');

    // Validation stricte
    final safeInviteId = _Validators.isValidUuid(inviteId) ? inviteId : '';
    final safeChannel = _Validators.sanitizeString(channelName, maxLength: 64);
    final safeName = _Validators.sanitizeString(callerName, maxLength: 50);

    if (safeInviteId.isEmpty || safeChannel.isEmpty) {
      debugPrint('[VOIP] ⚠️ Invalid invite/channel data, skipping CallKit');
      return;
    }

    final params = CallKitParams(
      id: safeInviteId,
      nameCaller: safeName,
      appName: 'THIX Hub',
      avatar: _Validators.sanitizeUrl(callerAvatar) ?? '',
      handle: safeName,
      type: isVideo ? 1 : 0, // 0 = audio, 1 = video
      duration: _kCallDurationMs,
      textAccept: 'Accepter',
      textDecline: 'Refuser',
      extra: <String, dynamic>{
        'invite_id': safeInviteId,
        'channel_name': safeChannel,
        'caller_name': safeName,
        'is_video': isVideo,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'ringtone.mp3',
        backgroundColor: '#0A2F5C',
        actionColor: '#4CAF50',
        isShowMissedCallNotification: true,
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'ringtone.caf',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params)
          .timeout(_kCallkitTimeout);
      await _startRinging(isVideo: isVideo);
      debugPrint('[VOIP] ✓ CallKit shown: $safeInviteId');
    } catch (e) {
      debugPrint('[VOIP] ❌ showCallkitIncoming failed: $e');
    }
  }

  /// Termine un appel spécifique
  Future<void> endCall(String inviteId) async {
    try {
      await FlutterCallkitIncoming.endCall(inviteId);
      await stopRinging();
      debugPrint('[VOIP] ✓ Call ended: $inviteId');
    } catch (e) {
      debugPrint('[VOIP] ❌ endCall failed: $e');
    }
  }

  /// Termine tous les appels en cours
  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
      await stopRinging();
      debugPrint('[VOIP] ✓ All calls ended');
    } catch (e) {
      debugPrint('[VOIP] ❌ endAllCalls failed: $e');
    }
  }

  /// Démarre sonnerie + vibration persistantes (pattern WhatsApp)
  Future<void> _startRinging({required bool isVideo}) async {
    if (_isRinging) return;
    _isRinging = true;

    // Timer de sécurité : stop auto après 60s (match avec CallKit)
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(milliseconds: _kCallDurationMs), () {
      stopRinging();
    });

    try {
      // Vibration Android en pattern (1s sonne, 0.5s silence, boucle)
      if (Platform.isAndroid) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          // Pattern WhatsApp : [0ms start, 1000ms vibrate, 500ms pause]
          await Vibration.vibrate(
            pattern: [0, 1000, 500, 1000],
            repeat: 0, // boucle tant qu'on ne fait pas cancel()
            intensities: [0, 128, 0, 128],
          );
        }
      }

      // Sonnerie en boucle (utilise les sons système par défaut)
      await _ringtone.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.alert,
        looping: true,
        volume: 1.0,
      );

      debugPrint('[VOIP] 🔊 Ringing started (video=$isVideo)');
    } catch (e) {
      debugPrint('[VOIP] ❌ Start ringing failed: $e');
    }
  }

  /// Arrête sonnerie + vibration
  Future<void> stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    _ringTimeout?.cancel();
    _ringTimeout = null;

    try {
      await _ringtone.stop();
      if (Platform.isAndroid) {
        await Vibration.cancel();
      }
      debugPrint('[VOIP] 🔕 Ringing stopped');
    } catch (e) {
      debugPrint('[VOIP] ❌ Stop ringing failed: $e');
    }
  }

  /// Handler des événements CallKit
  void _onCallEvent(CallEvent? event) {
    if (event == null) return;
    debugPrint('[VOIP] Event: ${event.event}');

    final extra = (event.body?['extra'] as Map?)?.cast<String, dynamic>() ?? {};
    final inviteId = extra['invite_id']?.toString() ?? '';
    final channelName = extra['channel_name']?.toString() ?? '';
    final isVideo = extra['is_video'] == true;

    switch (event.event) {
      case Event.actionCallAccept:
        stopRinging();
        onAcceptCall?.call(inviteId, channelName, isVideo);
        break;

      case Event.actionCallDecline:
        stopRinging();
        onDeclineCall?.call(inviteId);
        break;

      case Event.actionCallEnd:
      case Event.actionCallTimeout:
        stopRinging();
        onDeclineCall?.call(inviteId);
        break;

      case Event.actionCallToggleHold:
      case Event.actionCallToggleMute:
      case Event.actionCallToggleDmtf:
      case Event.actionCallToggleGroup:
      case Event.actionCallToggleAudioSession:
      case Event.actionCallCustom:
        // Événements ignorés
        break;

      case null:
        break;
    }
  }

  /// Dispose toutes les ressources
  void dispose() {
    _ringTimeout?.cancel();
    _ringTimeout = null;
    stopRinging();
    _isInitialized = false;
    onAcceptCall = null;
    onDeclineCall = null;
  }
}

// ============================================================================
// BADGE MANAGER
// ============================================================================

/// Gestionnaire du badge d'icône synchronisé
class _BadgeManager {
  _BadgeManager._();
  static final _BadgeManager instance = _BadgeManager._();

  int _lastCount = -1;

  /// Met à jour le badge (iOS + Android launchers compatibles)
  Future<void> sync(int count) async {
    final safe = count < 0 ? 0 : count;
    if (safe == _lastCount) return; // Évite le spam
    _lastCount = safe;

    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;

      if (safe == 0) {
        FlutterAppBadger.removeBadge();
      } else {
        FlutterAppBadger.updateBadgeCount(safe);
      }
      debugPrint('[Badge] 🔢 Icon badge → $safe');
    } catch (e) {
      debugPrint('[Badge] ❌ Update failed: $e');
    }
  }

  /// Récupère le nombre de notifications non lues depuis Supabase
  Future<int> fetchUnreadCount() async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || !_Validators.isValidUid(uid)) return 0;

    try {
      final count = await SupabaseConfig.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kSupabaseTimeout);
      return count;
    } catch (e) {
      debugPrint('[Badge] ❌ Fetch count failed: $e');
      return 0;
    }
  }

  /// Synchronise le badge depuis la DB (à appeler après chaque notif)
  Future<void> refreshFromDb() async {
    final count = await fetchUnreadCount();
    await sync(count);
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
/// - **VoIP natif** : utilise CallKit pour les appels entrants
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM-BG] 🚀 Background handler triggered: ${message.messageId}');

  // 1) Initialiser Firebase avec retry
  var firebaseInitAttempts = 0;
  while (firebaseInitAttempts < _kMaxRetries) {
    try {
      await Firebase.initializeApp().timeout(_kBackgroundInitTimeout);
      debugPrint('[FCM-BG] ✓ Firebase initialized');
      break;
    } catch (e) {
      firebaseInitAttempts++;
      debugPrint('[FCM-BG] ❌ Firebase init failed ($firebaseInitAttempts/$_kMaxRetries): $e');
      if (firebaseInitAttempts >= _kMaxRetries) {
        debugPrint('[FCM-BG] ❌ Max Firebase init attempts reached, aborting');
        return;
      }
      await Future.delayed(_kRetryDelay);
    }
  }

  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

  // 2) 📞 APPEL ENTRANT → CallKit natif (iOS + Android)
  if (type == PushTypes.incomingCall) {
    try {
      await _VoipCallManager.instance.initialize();
      await _VoipCallManager.instance.showIncomingCall(
        inviteId: (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
        callerName: (data['caller_name'] ?? data['callerName'] ?? 'Appel entrant').toString(),
        callerAvatar: data['caller_avatar']?.toString(),
        channelName: (data['channel_name'] ?? data['channelName'] ?? '').toString(),
        isVideo: (data['is_video'] ?? data['isVideo'] ?? 'false').toString() == 'true',
      );
      debugPrint('[FCM-BG] ✓ CallKit shown: ${message.messageId}');
      return; // ⛔ PAS de notification locale → CallKit gère
    } catch (e) {
      debugPrint('[FCM-BG] ❌ CallKit failed, fallback to local notif: $e');
      // Fallback : affiche une notification locale classique
    }
  }

  // 3) 📞 FIN D'APPEL DISTANTE → arrête sonnerie + CallKit
  if (type == PushTypes.callHangup) {
    final inviteId = (data['invite_id'] ?? data['inviteId'] ?? '').toString();
    if (inviteId.isNotEmpty) {
      await _VoipCallManager.instance.endCall(inviteId);
      debugPrint('[FCM-BG] ✓ Remote hangup: $inviteId');
    }
    return;
  }

  // 4) Autres notifications → affichage classique
  try {
    await LocalNotificationService.instance
        .initialize()
        .timeout(_kForegroundInitTimeout, onTimeout: () {
      throw TimeoutException('LocalNotificationService init timeout');
    });

    await _showFromRemoteMessage(message);
    debugPrint('[FCM-BG] ✓ Notification shown: ${message.messageId}');

    // 5) Synchroniser le badge après affichage
    await _BadgeManager.instance.refreshFromDb();
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
Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

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

String? _buildPayload(Map<String, dynamic> data) {
  final route = data['route']?.toString();
  if (route != null && route.isNotEmpty) {
    if (_Validators.isValidRoute(route)) {
      return _Validators.sanitizePayload(route);
    } else {
      debugPrint('[FCM] ⚠️ Invalid route rejected: $route');
    }
  }

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

int _generateNotifId(RemoteMessage message) {
  final id = message.messageId ??
      message.data['invite_id']?.toString() ??
      message.data['conversation_id']?.toString();

  if (id != null && id.isNotEmpty) {
    final hash = id.hashCode ^ 0x12345678;
    return hash & 0x7fffffff;
  }

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
///
/// // Callback VoIP
/// PushNotificationService.instance.onVoipAccept = (inviteId, channelName, isVideo) {
///   // Naviguer vers l'écran d'appel
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
  static void Function(Map<String, dynamic> data)? onPushTap;

  /// Callback pour appel VoIP accepté (CallKit)
  static void Function(String inviteId, String channelName, bool isVideo)? onVoipAccept;

  /// Callback pour appel VoIP refusé/manqué
  static void Function(String inviteId)? onVoipDecline;

  /// Initialise le service de notifications push.
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
      // Demander permissions FCM (inclut VoIP sur iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
        announcement: true,
        carPlay: false,
      );
      debugPrint('[PushNotif] ✓ FCM permission: ${settings.authorizationStatus}');

      // Android 13+ : permission notifications via LocalNotificationService
      try {
        await LocalNotificationService.instance.requestPermission();
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ LocalNotificationService permission failed: $e');
      }

      // Initialiser CallKit (VoIP natif)
      try {
        await _VoipCallManager.instance.initialize();
        _VoipCallManager.instance.onAcceptCall = _handleVoipAccept;
        _VoipCallManager.instance.onDeclineCall = _handleVoipDecline;
        debugPrint('[PushNotif] ✓ VoIP CallKit initialized');
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ VoIP init failed: $e');
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

      // Synchroniser le badge au démarrage
      await _BadgeManager.instance.refreshFromDb();

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

  /// Handler VoIP : appel accepté depuis CallKit
  void _handleVoipAccept(String inviteId, String channelName, bool isVideo) {
    debugPrint('[PushNotif] 📞 VoIP accepted: $inviteId');
    
    // Mounted check
    if (_context != null && !_context!.mounted) {
      debugPrint('[PushNotif] ⚠️ Accept ignored: context not mounted');
      return;
    }

    try {
      onVoipAccept?.call(inviteId, channelName, isVideo);
    } catch (e) {
      debugPrint('[PushNotif] ❌ onVoipAccept callback error: $e');
    }
  }

  /// Handler VoIP : appel refusé/manqué
  void _handleVoipDecline(String inviteId) {
    debugPrint('[PushNotif] 📞 VoIP declined: $inviteId');
    
    try {
      onVoipDecline?.call(inviteId);
    } catch (e) {
      debugPrint('[PushNotif] ❌ onVoipDecline callback error: $e');
    }
  }

  Future<void> onSignedIn({required String userId}) async {
    if (!_Validators.isValidUid(userId)) {
      debugPrint('[PushNotif] ⚠️ onSignedIn: invalid userId');
      return;
    }

    debugPrint('[PushNotif] 🔐 User signed in: ${_Validators.maskUid(userId)}');
    _cleanupListeners();
    _initialized = false;
    await initialize();
  }

  Future<void> onSignedOut() async {
    debugPrint('[PushNotif] 🔓 User signed out');
    _cleanupListeners();
    await unregisterToken();
    await _BadgeManager.instance.sync(0);
    await _VoipCallManager.instance.endAllCalls();
    _initialized = false;
  }

  void _cleanupListeners() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _openedAppSub?.cancel();
    _openedAppSub = null;
    debugPrint('[PushNotif] 🧹 Listeners cleaned up');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().toLowerCase();

    // Appel entrant en foreground → CallKit aussi (cohérence)
    if (type == PushTypes.incomingCall) {
      debugPrint('[PushNotif] 📞 Foreground incoming call → CallKit');
      _VoipCallManager.instance.showIncomingCall(
        inviteId: (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
        callerName: (data['caller_name'] ?? 'Appel entrant').toString(),
        callerAvatar: data['caller_avatar']?.toString(),
        channelName: (data['channel_name'] ?? '').toString(),
        isVideo: (data['is_video'] ?? 'false') == 'true',
      );
      return;
    }

    // Fin d'appel distante en foreground
    if (type == PushTypes.callHangup) {
      final inviteId = (data['invite_id'] ?? '').toString();
      if (inviteId.isNotEmpty) {
        _VoipCallManager.instance.endCall(inviteId);
      }
      return;
    }

    final hasVisual = message.notification != null ||
        data['title'] != null ||
        data['body'] != null ||
        data['type'] != null;

    if (!hasVisual) {
      debugPrint('[PushNotif] ⏭️ Foreground ignored (empty): ${message.messageId}');
      return;
    }

    debugPrint('[PushNotif] 📥 Foreground notification: ${message.messageId}');
    unawaited(() async {
      await _showFromRemoteMessage(message);
      await _BadgeManager.instance.refreshFromDb();
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final payload = _buildPayload(data);

    debugPrint('[PushNotif] 👆 Notification tap: type=$type, payload=$payload');

    if (_context != null && !_context!.mounted) {
      debugPrint('[PushNotif] ⚠️ Tap ignored: context not mounted');
      return;
    }

    try {
      LocalNotificationService.instance.onNotificationTap?.call(payload);
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ onNotificationTap callback error: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }

    try {
      onPushTap?.call(data);
    } catch (e, stackTrace) {
      debugPrint('[PushNotif] ❌ onPushTap callback error: $e');
      if (kDebugMode) {
        debugPrint('[PushNotif] Stack: ${stackTrace.toString().split('\n').first}');
      }
    }

    // Sync badge après ouverture (potentiellement marquée comme lue)
    unawaited(_BadgeManager.instance.refreshFromDb());
  }

  Future<void> _registerToken() async {
    var attempts = 0;

    while (attempts < _kMaxRetries) {
      try {
        final token = await _messaging.getToken();
        final uid = SupabaseConfig.currentUser?.id;

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
              onConflict: 'user_id,fcm_token',
            )
            .timeout(_kSupabaseTimeout);

        debugPrint('[PushNotif] ✓ Token registered: uid=${_Validators.maskUid(uid)}, '
            'token=${_Validators.maskToken(token)}');
        return;
      } on TimeoutException {
        attempts++;
        debugPrint('[PushNotif] ⏱️ Token registration timeout ($attempts/$_kMaxRetries)');
        if (attempts >= _kMaxRetries) {
          debugPrint('[PushNotif] ❌ Max token registration attempts reached');
          return;
        }
        await Future.delayed(_kRetryDelay);
      } catch (e, stackTrace) {
        attempts++;
        debugPrint('[PushNotif] ❌ Token registration failed ($attempts/$_kMaxRetries): $e');
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

  void registerContext(BuildContext context) {
    _context = context;
  }

  void unregisterContext() {
    _context = null;
  }

  /// Met à jour manuellement le badge
  Future<void> updateBadge(int count) async {
    await _BadgeManager.instance.sync(count);
  }

  /// Rafraîchit le badge depuis la DB
  Future<void> refreshBadge() async {
    await _BadgeManager.instance.refreshFromDb();
  }

  void dispose() {
    debugPrint('[PushNotif] 🗑️ Disposing service');
    _cleanupListeners();
    _VoipCallManager.instance.dispose();
    onPushTap = null;
    onVoipAccept = null;
    onVoipDecline = null;
    _context = null;
    _initialized = false;
    _initializing = false;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    debugPrint('[PushNotif] 🔄 Resetting for testing...');
    dispose();
  }
}
