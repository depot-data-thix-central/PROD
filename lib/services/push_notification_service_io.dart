// lib/services/push_notification_service_io.dart
//
// Push Notification Service IO v8.1 (Production)
// FIX : CallKit gère seul sonnerie + vibration (plus de doublon)
// FIX : ringtonePath = sonnerie système (pas de fichier res/raw requis)
// FIX : permission plein écran Android 14+
// FIX : types like / follow / comment / connection autorisés
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';

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

  static const String chatMessage = 'chat_message';
  static const String incomingCall = 'incoming_call';
  static const String callHangup = 'call_hangup';
  static const String notification = 'notification';
  static const String sos = 'sos';
  static const String like = 'like';
  static const String follow = 'follow';
  static const String comment = 'comment';
  static const String connection = 'connection';

  static const Set<String> allowed = <String>{
    chatMessage,
    incomingCall,
    callHangup,
    notification,
    sos,
    like,
    follow,
    comment,
    connection,
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
    if (uid.length < _kMinUidLength || uid.length > _kMaxUidLength) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(uid);
  }

  static bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length > _kMaxTokenLength) return false;
    return RegExp(r'^[A-Za-z0-9_\-:]+$').hasMatch(token);
  }

  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';

    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();

    if (s.length > maxLength) {
      return '${s.substring(0, maxLength)}…';
    }
    return s;
  }

  static bool isValidRoute(String? route) {
    if (route == null || route.isEmpty || route.length > _kMaxPayloadLength) {
      return false;
    }

    const prefixes = <String>[
      'call:',
      'chat:',
      '/chat',
      '/profile',
      '/notification',
      '/sos',
      '/event',
      '/call',
    ];

    for (final prefix in prefixes) {
      if (route.startsWith(prefix)) return true;
    }
    return false;
  }

  static String? sanitizePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return sanitizeString(payload, maxLength: _kMaxPayloadLength);
  }

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.isEmpty || url.length > 500) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }
    return url;
  }
}

// ============================================================================
// VOIP CALL MANAGER (CallKit gère sonnerie + vibration nativement)
// ============================================================================

class _VoipCallManager {
  _VoipCallManager._();

  static final _VoipCallManager instance = _VoipCallManager._();

  StreamSubscription<CallEvent?>? _eventSub;
  bool _isInitialized = false;

  void Function(String inviteId, String channelName, bool isVideo)?
      onAcceptCall;
  void Function(String inviteId)? onDeclineCall;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _eventSub?.cancel();
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
    if (!_isInitialized) {
      await initialize();
    }

    final safeInviteId = _Validators.isValidUuid(inviteId) ? inviteId : '';
    final safeChannel =
        _Validators.sanitizeString(channelName, maxLength: 64);
    final safeName = _Validators.sanitizeString(callerName, maxLength: 50);

    if (safeInviteId.isEmpty || safeChannel.isEmpty) return;

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
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0A2F5C',
        actionColor: '#4CAF50',
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params)
          .timeout(_kCallkitTimeout);
      debugPrint('[VOIP] ✓ CallKit shown: $safeInviteId');
    } catch (e) {
      debugPrint('[VOIP] ❌ showCallkitIncoming failed: $e');
    }
  }

  Future<void> endCall(String inviteId) async {
    try {
      await FlutterCallkitIncoming.endCall(inviteId);
    } catch (e) {
      debugPrint('[VOIP] ❌ endCall: $e');
    }
  }

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[VOIP] ❌ endAllCalls: $e');
    }
  }

  void _onCallEvent(CallEvent? event) {
    if (event == null) return;

    final type = event.event;

    final extra = (event.body?['extra'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final inviteId = extra['invite_id']?.toString() ?? '';
    final channelName = extra['channel_name']?.toString() ?? '';
    final isVideo = extra['is_video'] == true;

    if (type == Event.actionCallAccept) {
      onAcceptCall?.call(inviteId, channelName, isVideo);
    } else if (type == Event.actionCallDecline ||
        type == Event.actionCallTimeout) {
      onDeclineCall?.call(inviteId);
    }
  }

  void dispose() {
    unawaited(_eventSub?.cancel());
    _eventSub = null;
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
    } catch (e) {
      debugPrint('[Badge] ❌ $e');
    }
  }

  Future<int> fetchUnreadCount() async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || !_Validators.isValidUid(uid)) return 0;

    try {
      return await SupabaseConfig.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kSupabaseTimeout);
    } catch (_) {
      return 0;
    }
  }

  Future<void> refreshFromDb() async {
    final count = await fetchUnreadCount();
    await sync(count);
  }
}

// ============================================================================
// BACKGROUND HANDLER (à enregistrer dans main.dart)
// ============================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

  if (type == PushTypes.incomingCall) {
    try {
      await _VoipCallManager.instance.initialize();
      await _VoipCallManager.instance.showIncomingCall(
        inviteId: (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
        callerName:
            (data['caller_name'] ?? data['callerName'] ?? 'Appel entrant')
                .toString(),
        callerAvatar: data['caller_avatar']?.toString(),
        channelName:
            (data['channel_name'] ?? data['channelName'] ?? '').toString(),
        isVideo:
            (data['is_video'] ?? data['isVideo'] ?? 'false').toString() ==
                'true',
      );
      return;
    } catch (e) {
      debugPrint('[FCM-BG] ❌ incoming_call: $e');
    }
  }

  if (type == PushTypes.callHangup) {
    final id = (data['invite_id'] ?? data['inviteId'] ?? '').toString();
    if (id.isNotEmpty) {
      await _VoipCallManager.instance.endCall(id);
    }
    return;
  }

  try {
    await LocalNotificationService.instance
        .initialize()
        .timeout(_kForegroundInitTimeout);

    await _showFromRemoteMessage(message);
    await _BadgeManager.instance.refreshFromDb();
  } catch (e) {
    debugPrint('[FCM-BG] ❌ $e');
  }
}

// ============================================================================
// HELPERS
// ============================================================================

Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

  if (!PushTypes.isAllowed(type)) return;

  try {
    final title = _Validators.sanitizeString(
      message.notification?.title ??
          data['title']?.toString() ??
          _defaultTitle(type),
      maxLength: _kMaxTitleLength,
    );

    final body = _Validators.sanitizeString(
      message.notification?.body ??
          data['body']?.toString() ??
          data['message']?.toString() ??
          'Notification',
      maxLength: _kMaxBodyLength,
    );

    await LocalNotificationService.instance.show(
      id: _generateNotifId(message),
      title: title,
      body: body,
      payload: _buildPayload(data),
      channelId: _getChannelForType(type),
    );
  } catch (_) {}
}

String _getChannelForType(String type) {
  if (type == PushTypes.incomingCall) {
    return LocalNotificationService.channelCalls;
  }
  if (type == PushTypes.chatMessage) {
    return LocalNotificationService.channelChat;
  }
  return LocalNotificationService.channelDefault;
}

String _defaultTitle(String type) {
  switch (type) {
    case PushTypes.incomingCall:
      return 'Appel entrant';
    case PushTypes.chatMessage:
      return 'Nouveau message';
    case PushTypes.sos:
      return 'Alerte SOS';
    case PushTypes.like:
      return 'Nouveau like';
    case PushTypes.follow:
      return 'Nouvel abonné';
    case PushTypes.comment:
      return 'Nouveau commentaire';
    case PushTypes.connection:
      return 'Nouvelle connexion';
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
  }

  if (type == PushTypes.chatMessage) {
    final convId = _Validators.sanitizeString(
      (data['conversation_id'] ?? data['conversationId'] ?? '').toString(),
      maxLength: 64,
    );

    if (convId.isNotEmpty) return 'chat:$convId';
    return null;
  }

  final id = data['notification_id']?.toString() ?? data['id']?.toString();
  return id != null ? _Validators.sanitizePayload(id) : null;
}

int _generateNotifId(RemoteMessage message) {
  final id = message.messageId ??
      message.data['invite_id']?.toString() ??
      message.data['conversation_id']?.toString();

  if (id != null && id.isNotEmpty) {
    return (id.hashCode ^ 0x12345678) & 0x7fffffff;
  }

  final now = DateTime.now().microsecondsSinceEpoch;
  return (now ^ (now >> 16)) & 0x7fffffff;
}

// ============================================================================
// PUSH NOTIFICATION SERVICE
// ============================================================================

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _tokensTable = 'user_device_tokens';

  bool _initialized = false;
  bool _initializing = false;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  BuildContext? _context;

  /// Callback global pour l'ouverture d'une notification.
  static void Function(Map<String, dynamic> data)? onPushTap;

  /// Callbacks d'instance (câblés dans main.dart).
  void Function(String inviteId, String channelName, bool isVideo)?
      onVoipAccept;
  void Function(String inviteId)? onVoipDecline;

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

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
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      try {
        await LocalNotificationService.instance.requestPermission();
      } catch (_) {}

      // Android 14+ : autorisation d'afficher l'appel plein écran
      try {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ FullIntent: $e');
      }

      try {
        await _VoipCallManager.instance.initialize();
        _VoipCallManager.instance.onAcceptCall = _handleVoipAccept;
        _VoipCallManager.instance.onDeclineCall = _handleVoipDecline;
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ VoIP: $e');
      }

      await _registerToken();

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((_) {
        unawaited(_registerToken());
      });

      await _foregroundSub?.cancel();
      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      await _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp
          .listen(_handleNotificationTap);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleNotificationTap(initial);
      }

      await _BadgeManager.instance.refreshFromDb();

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotif] ❌ Init failed: $e');
    } finally {
      _initializing = false;
    }
  }

  // ==========================================================================
  // VOIP CALLBACK HANDLERS
  // ==========================================================================

  void _handleVoipAccept(String id, String ch, bool v) {
    if (_context != null && !_context!.mounted) return;

    try {
      onVoipAccept?.call(id, ch, v);
    } catch (_) {}
  }

  void _handleVoipDecline(String id) {
    try {
      onVoipDecline?.call(id);
    } catch (_) {}
  }

  // ==========================================================================
  // VOIP PUBLIC METHODS
  // ==========================================================================

  Future<void> endVoipCall(String inviteId) async {
    await _VoipCallManager.instance.endCall(inviteId);
  }

  Future<void> endAllVoipCalls() async {
    await _VoipCallManager.instance.endAllCalls();
  }

  // ==========================================================================
  // AUTH
  // ==========================================================================

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

  // ==========================================================================
  // LISTENERS
  // ==========================================================================

  void _cleanupListeners() {
    unawaited(_tokenRefreshSub?.cancel());
    _tokenRefreshSub = null;

    unawaited(_foregroundSub?.cancel());
    _foregroundSub = null;

    unawaited(_openedAppSub?.cancel());
    _openedAppSub = null;
  }

  // ==========================================================================
  // FOREGROUND MESSAGE
  // ==========================================================================

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().toLowerCase();

    if (type == PushTypes.incomingCall) {
      unawaited(
        _VoipCallManager.instance.showIncomingCall(
          inviteId: (data['invite_id'] ?? data['inviteId'] ?? '').toString(),
          callerName: (data['caller_name'] ?? 'Appel entrant').toString(),
          callerAvatar: data['caller_avatar']?.toString(),
          channelName: (data['channel_name'] ?? '').toString(),
          isVideo: (data['is_video'] ?? 'false').toString() == 'true',
        ),
      );
      return;
    }

    if (type == PushTypes.callHangup) {
      final id = (data['invite_id'] ?? '').toString();
      if (id.isNotEmpty) {
        unawaited(_VoipCallManager.instance.endCall(id));
      }
      return;
    }

    final hasVisual = message.notification != null ||
        data['title'] != null ||
        data['body'] != null ||
        data['type'] != null;

    if (!hasVisual) return;

    Future<void> work() async {
      await _showFromRemoteMessage(message);
      await _BadgeManager.instance.refreshFromDb();
    }

    unawaited(work());
  }

  // ==========================================================================
  // NOTIFICATION TAP
  // ==========================================================================

  void _handleNotificationTap(RemoteMessage message) {
    if (_context != null && !_context!.mounted) return;

    final payload = _buildPayload(message.data);

    try {
      LocalNotificationService.instance.onNotificationTap?.call(payload);
    } catch (_) {}

    try {
      onPushTap?.call(message.data);
    } catch (_) {}

    unawaited(_BadgeManager.instance.refreshFromDb());
  }

  // ==========================================================================
  // FCM TOKEN
  // ==========================================================================

  Future<void> _registerToken() async {
    var attempts = 0;

    while (attempts < _kMaxRetries) {
      try {
        final token = await _messaging.getToken();
        final uid = SupabaseConfig.currentUser?.id;

        if (token == null || !_Validators.isValidToken(token)) return;
        if (uid == null || !_Validators.isValidUid(uid)) return;

        await SupabaseConfig.client.from(_tokensTable).upsert(
          {
            'user_id': uid,
            'fcm_token': token,
            'platform': defaultTargetPlatform.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,fcm_token',
        ).timeout(_kSupabaseTimeout);

        return;
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

  // ==========================================================================
  // CONTEXT
  // ==========================================================================

  void registerContext(BuildContext context) {
    _context = context;
  }

  void unregisterContext() {
    _context = null;
  }

  // ==========================================================================
  // BADGE
  // ==========================================================================

  Future<void> updateBadge(int count) async {
    await _BadgeManager.instance.sync(count);
  }

  Future<void> refreshBadge() async {
    await _BadgeManager.instance.refreshFromDb();
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

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
}
