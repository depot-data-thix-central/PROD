// lib/services/push_notification_service_io.dart
//
// Push Notification Service IO v5 (Production)
// ✅ Compatible flutter_callkit_incoming 2.5.8
// ✅ Compatible flutter_ringtone_player 4.0.0
// ✅ Compatible supabase_flutter 2.8 (CountOption.exact)
//
// Architecture :
// - Background handler isolé (FirebaseMessaging)
// - Foreground handler
// - Token management Supabase
// - VoIP natif : CallKit (iOS) + Telecom Manager (Android)
// - Sonnerie + vibration persistantes
// - Badge synchronisé via flutter_app_badger

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
const int _kCallDurationMs = 60000;

// ============================================================================
// TYPES
// ============================================================================

class PushTypes {
  PushTypes._();
  static const chatMessage = 'chat_message';
  static const incomingCall = 'incoming_call';
  static const callHangup = 'call_hangup';
  static const notification = 'notification';
  static const sos = 'sos';

  static const Set<String> allowed = {
    chatMessage, incomingCall, callHangup, notification, sos,
  };

  static bool isAllowed(String type) => allowed.contains(type);
}

// ============================================================================
// VALIDATORS
// ============================================================================

class _Validators {
  _Validators._();

  static bool isValidUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid.length < _kMinUidLength || uid.length > _kMaxUidLength) return false;
    return RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(uid);
  }

  static bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length > _kMaxTokenLength) return false;
    return RegExp(r'^[A-Za-z0-9_\-:]+$').hasMatch(token);
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
      'call:', 'chat:', '/chat', '/profile',
      '/notification', '/sos', '/event', '/call',
    ];
    return allowedPrefixes.any((prefix) => route.startsWith(prefix));
  }

  static String? sanitizePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return sanitizeString(payload, maxLength: _kMaxPayloadLength);
  }

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

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

class _VoipCallManager {
  _VoipCallManager._();
  static final _VoipCallManager instance = _VoipCallManager._();

  final FlutterRingtonePlayer _ringtone = FlutterRingtonePlayer();
  StreamSubscription<CallEvent?>? _eventSub;
  bool _isInitialized = false;
  bool _isRinging = false;
  Timer? _ringTimeout;

  void Function(String inviteId, String channelName, bool isVideo)? onAcceptCall;
  void Function(String inviteId)? onDeclineCall;

  /// ✅ v2.5.8 : on subscribe directement au stream, pas de init() nécessaire
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _eventSub?.cancel();
      _eventSub = FlutterCallkitIncoming.onEvent.listen(_onCallEvent);
      _isInitialized = true;
      debugPrint('[VOIP] ✓ CallKit listener attached');
    } catch (e) {
      debugPrint('[VOIP] ❌ Init failed: $e');
    }
  }

  Future<void> showIncomingCall({
    required String inviteId,
    required String callerName,
    String? callerAvatar,
    required String channelName,
    bool isVideo = false,
  }) async {
    if (!_isInitialized) await initialize();

    final safeInviteId = _Validators.isValidUuid(inviteId) ? inviteId : '';
    final safeChannel = _Validators.sanitizeString(channelName, maxLength: 64);
    final safeName = _Validators.sanitizeString(callerName, maxLength: 50);

    if (safeInviteId.isEmpty || safeChannel.isEmpty) {
      debugPrint('[VOIP] ⚠️ Invalid invite/channel, skipping');
      return;
    }

    // ✅ API v2.5.8 : CallKitParams minimale, sans textMissedCall / audioSessionMode
    final params = CallKitParams(
      id: safeInviteId,
      nameCaller: safeName,
      appName: 'THIX Hub',
      avatar: _Validators.sanitizeUrl(callerAvatar) ?? '',
      handle: safeName,
      type: isVideo ? 1 : 0,
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
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'ringtone.caf',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params).timeout(_kCallkitTimeout);
      await _startRinging();
      debugPrint('[VOIP] ✓ CallKit shown: $safeInviteId');
    } catch (e) {
      debugPrint('[VOIP] ❌ showCallkitIncoming failed: $e');
    }
  }

  Future<void> endCall(String inviteId) async {
    try {
      await FlutterCallkitIncoming.endCall(inviteId);
    } catch (e) {
      debugPrint('[VOIP] ❌ endCall failed: $e');
    }
    await stopRinging();
  }

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[VOIP] ❌ endAllCalls failed: $e');
    }
    await stopRinging();
  }

  Future<void> _startRinging() async {
    if (_isRinging) return;
    _isRinging = true;

    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(milliseconds: _kCallDurationMs), stopRinging);

    try {
      if (Platform.isAndroid) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          await Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
        }
      }
      // ✅ iOS : CallKit gère déjà la sonnerie via ringtone.caf.
      // On joue uniquement sur Android (AndroidSounds.ringtone).
      await _ringtone.play(
        android: AndroidSounds.ringtone,
        looping: true,
        volume: 1.0,
      );
      debugPrint('[VOIP] 🔊 Ringing started');
    } catch (e) {
      debugPrint('[VOIP] ❌ Start ringing failed: $e');
    }
  }

  Future<void> stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    try {
      await _ringtone.stop();
      if (Platform.isAndroid) await Vibration.cancel();
      debugPrint('[VOIP] 🔕 Ringing stopped');
    } catch (e) {
      debugPrint('[VOIP] ❌ Stop ringing failed: $e');
    }
  }

  /// ✅ if/else au lieu de switch : insensible aux évolutions de l'enum Event.
  void _onCallEvent(CallEvent? event) {
    if (event == null) return;
    final type = event.event;
    debugPrint('[VOIP] Event: $type');

    final extra = (event.body?['extra'] as Map?)?.cast<String, dynamic>() ?? {};
    final inviteId = extra['invite_id']?.toString() ?? '';
    final channelName = extra['channel_name']?.toString() ?? '';
    final isVideo = extra['is_video'] == true;

    if (type == Event.actionCallAccept) {
      stopRinging();
      onAcceptCall?.call(inviteId, channelName, isVideo);
    } else if (type == Event.actionCallDecline || type == Event.actionCallTimeout) {
      stopRinging();
      onDeclineCall?.call(inviteId);
    }
    // Autres événements (hangup, toggleHold, etc.) : ignorés silencieusement
  }

  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
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

class _BadgeManager {
  _BadgeManager._();
  static final _BadgeManager instance = _BadgeManager._();
  int _lastCount = -1;

  Future<void> sync(int count) async {
    final safe = count < 0 ? 0 : count;
    if (safe == _lastCount) return;
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

  Future<void> refreshFromDb() async {
    await sync(await fetchUnreadCount());
  }
}

// ============================================================================
// BACKGROUND HANDLER
// ============================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM-BG] 🚀 Background handler: ${message.messageId}');

  var attempts = 0;
  while (attempts < _kMaxRetries) {
    try {
      await Firebase.initializeApp().timeout(_kBackgroundInitTimeout);
      break;
    } catch (e) {
      attempts++;
      if (attempts >= _kMaxRetries) return;
      await Future.delayed(_kRetryDelay);
    }
  }

  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

  // 📞 Appel entrant → CallKit natif
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
      return;
    } catch (e) {
      debugPrint('[FCM-BG] ❌ CallKit failed, fallback local: $e');
    }
  }

  // 📞 Fin d'appel distante
  if (type == PushTypes.callHangup) {
    final inviteId = (data['invite_id'] ?? data['inviteId'] ?? '').toString();
    if (inviteId.isNotEmpty) {
      await _VoipCallManager.instance.endCall(inviteId);
    }
    return;
  }

  // 🔔 Autres notifications
  try {
    await LocalNotificationService.instance
        .initialize()
        .timeout(_kForegroundInitTimeout,
            onTimeout: () => throw TimeoutException('LocalNotif init timeout'));
    await _showFromRemoteMessage(message);
    await _BadgeManager.instance.refreshFromDb();
  } on TimeoutException {
    debugPrint('[FCM-BG] ❌ Timeout');
  } catch (e) {
    debugPrint('[FCM-BG] ❌ Error: $e');
  }
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();
  if (!PushTypes.isAllowed(type)) return;

  final title = _Validators.sanitizeString(
    message.notification?.title ?? data['title']?.toString() ?? _defaultTitle(type),
    maxLength: _kMaxTitleLength,
  );
  final body = _Validators.sanitizeString(
    message.notification?.body ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        'Nouvelle notification',
    maxLength: _kMaxBodyLength,
  );

  try {
    await LocalNotificationService.instance.show(
      id: _generateNotifId(message),
      title: title,
      body: body,
      payload: _buildPayload(data),
      channelId: _getChannelForType(type),
    );
  } catch (e) {
    debugPrint('[FCM] ❌ Failed to show notification: $e');
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
  if (route != null && route.isNotEmpty && _Validators.isValidRoute(route)) {
    return _Validators.sanitizePayload(route);
  }
  final type = (data['type'] ?? '').toString().toLowerCase();
  if (type == PushTypes.incomingCall) {
    final inviteId = _Validators.sanitizeString(
        (data['invite_id'] ?? data['inviteId'] ?? '').toString(), maxLength: 64);
    final channel = _Validators.sanitizeString(
        (data['channel_name'] ?? data['channelName'] ?? '').toString(), maxLength: 64);
    if (inviteId.isNotEmpty && channel.isNotEmpty) return 'call:$inviteId:$channel';
    return null;
  }
  if (type == PushTypes.chatMessage) {
    final convId = _Validators.sanitizeString(
        (data['conversation_id'] ?? data['conversationId'] ?? '').toString(), maxLength: 64);
    if (convId.isNotEmpty) return 'chat:$convId';
    return null;
  }
  final notifId = data['notification_id']?.toString() ?? data['id']?.toString();
  return notifId != null ? _Validators.sanitizePayload(notifId) : null;
}

int _generateNotifId(RemoteMessage message) {
  final id = message.messageId ??
      message.data['invite_id']?.toString() ??
      message.data['conversation_id']?.toString();
  if (id != null && id.isNotEmpty) return (id.hashCode ^ 0x12345678) & 0x7fffffff;
  final now = DateTime.now().microsecondsSinceEpoch;
  return (now ^ (now >> 16)) & 0x7fffffff;
}

// ============================================================================
// PUSH NOTIFICATION SERVICE
// ============================================================================

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

  static void Function(Map<String, dynamic> data)? onPushTap;
  static void Function(String inviteId, String channelName, bool isVideo)? onVoipAccept;
  static void Function(String inviteId)? onVoipDecline;

  Future<void> initialize() async {
    if (_initialized) {
      await _registerToken();
      return;
    }
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializing = true;
    try {
      final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true, criticalAlert: true,
      );
      debugPrint('[PushNotif] ✓ FCM permission: ${settings.authorizationStatus}');

      try {
        await LocalNotificationService.instance.requestPermission();
      } catch (_) {}

      try {
        await _VoipCallManager.instance.initialize();
        _VoipCallManager.instance.onAcceptCall = _handleVoipAccept;
        _VoipCallManager.instance.onDeclineCall = _handleVoipDecline;
        debugPrint('[PushNotif] ✓ VoIP CallKit initialized');
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ VoIP init failed: $e');
      }

      await _registerToken();

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
        debugPrint('[PushNotif] 🔄 Token refreshed: ${_Validators.maskToken(token)}');
        unawaited(_registerToken());
      });

      _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);

      await _BadgeManager.instance.refreshFromDb();

      _initialized = true;
      debugPrint('[PushNotif] ✓ Initialized successfully');
    } catch (e) {
      debugPrint('[PushNotif] ❌ Initialization failed: $e');
    } finally {
      _initializing = false;
    }
  }

  void _handleVoipAccept(String inviteId, String channelName, bool isVideo) {
    if (_context != null && !_context!.mounted) return;
    try { onVoipAccept?.call(inviteId, channelName, isVideo); } catch (_) {}
  }

  void _handleVoipDecline(String inviteId) {
    try { onVoipDecline?.call(inviteId); } catch (_) {}
  }

  // ✅ Bridges VoIP exposés pour main.dart / CallScreen
  Future<void> endVoipCall(String inviteId) => _VoipCallManager.instance.endCall(inviteId);
  Future<void> endAllVoipCalls() => _VoipCallManager.instance.endAllCalls();

  Future<void> onSignedIn({required String userId}) async {
    if (!_Validators.isValidUid(userId)) return;
    _cleanupListeners();
    _initialized = false;
    await initialize();
  }

  Future<void> onSignedOut() async {
    _cleanupListeners();
    await unregisterToken();
    await _BadgeManager.instance.sync(0);
    await _VoipCallManager.instance.endAllCalls();
    _initialized = false;
  }

  void _cleanupListeners() {
    _tokenRefreshSub?.cancel(); _tokenRefreshSub = null;
    _foregroundSub?.cancel(); _foregroundSub = null;
    _openedAppSub?.cancel(); _openedAppSub = null;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().toLowerCase();

    if (type == PushTypes.incomingCall) {
      unawaited(_VoipCallManager.instance.showIncomingCall(
        inviteId: (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
        callerName: (data['caller_name'] ?? 'Appel entrant').toString(),
        callerAvatar: data['caller_avatar']?.toString(),
        channelName: (data['channel_name'] ?? '').toString(),
        isVideo: (data['is_video'] ?? 'false').toString() == 'true',
      ));
      return;
    }

    if (type == PushTypes.callHangup) {
      final inviteId = (data['invite_id'] ?? '').toString();
      if (inviteId.isNotEmpty) unawaited(_VoipCallManager.instance.endCall(inviteId));
      return;
    }

    final hasVisual = message.notification != null ||
        data['title'] != null || data['body'] != null || data['type'] != null;
    if (!hasVisual) return;

    // ✅ Fonction nommée → unawaited reçoit bien un Future<void>
    Future<void> work() async {
      await _showFromRemoteMessage(message);
      await _BadgeManager.instance.refreshFromDb();
    }
    unawaited(work());
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final payload = _buildPayload(data);

    debugPrint('[PushNotif] 👆 Tap: type=$type, payload=$payload');

    if (_context != null && !_context!.mounted) return;

    try { LocalNotificationService.instance.onNotificationTap?.call(payload); } catch (_) {}
    try { onPushTap?.call(data); } catch (_) {}

    unawaited(_BadgeManager.instance.refreshFromDb());
  }

  Future<void> _registerToken() async {
    var attempts = 0;
    while (attempts < _kMaxRetries) {
      try {
        final token = await _messaging.getToken();
        final uid = SupabaseConfig.currentUser?.id;
        if (token == null || !_Validators.isValidToken(token)) return;
        if (uid == null || !_Validators.isValidUid(uid)) return;

        await SupabaseConfig.client.from(_tokensTable).upsert({
          'user_id': uid,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,fcm_token').timeout(_kSupabaseTimeout);

        debugPrint('[PushNotif] ✓ Token registered: uid=${_Validators.maskUid(uid)}');
        return;
      } on TimeoutException {
        attempts++;
        if (attempts >= _kMaxRetries) return;
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempts++;
        if (attempts >= _kMaxRetries) return;
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || !_Validators.isValidToken(token)) return;
      await SupabaseConfig.client
          .from(_tokensTable)
          .delete()
          .eq('fcm_token', token)
          .timeout(_kSupabaseTimeout);
    } catch (_) {}
  }

  void registerContext(BuildContext context) => _context = context;
  void unregisterContext() => _context = null;

  Future<void> updateBadge(int count) => _BadgeManager.instance.sync(count);
  Future<void> refreshBadge() => _BadgeManager.instance.refreshFromDb();

  void dispose() {
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
    dispose();
  }
}
