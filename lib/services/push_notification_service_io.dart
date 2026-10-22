// lib/services/push_notification_service_io.dart
//
// Push Notification Service IO v8.8 (Production)
// FIX v8.8 : retour au flux v8.5 : CallKit s'affiche EN PREMIER (sonnerie +
//            vibration natives). Plus de lecteur audio / vibration locale
//            dans l'isolate d'arrière-plan (bloquait l'affichage de l'appel).
// Conserve tous les correctifs v8.4 / v8.5.
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

import 'package:thix_id/services/chat/call_handled_registry.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kSupabaseTimeout = Duration(seconds: 15);
const Duration _kBackgroundInitTimeout = Duration(seconds: 10);
const Duration _kForegroundInitTimeout = Duration(seconds: 5);
const Duration _kCallkitTimeout = Duration(seconds: 8);
const Duration _kInitialTapDelay = Duration(milliseconds: 1500);
const Duration _kForegroundCallFallbackDelay = Duration(milliseconds: 2500);
const Duration _kStaleCallPush = Duration(seconds: 90);

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
  static const String chat = 'chat';
  static const String message = 'message';
  static const String incomingCall = 'incoming_call';
  static const String callHangup = 'call_hangup';
  static const String notification = 'notification';
  static const String sos = 'sos';
  static const String like = 'like';
  static const String follow = 'follow';
  static const String comment = 'comment';
  static const String commentReply = 'comment_reply';
  static const String commentLike = 'comment_like';
  static const String repost = 'repost';
  static const String connection = 'connection';

  static const Set<String> allowed = <String>{
    chatMessage,
    chat,
    message,
    incomingCall,
    callHangup,
    notification,
    sos,
    like,
    follow,
    comment,
    commentReply,
    commentLike,
    repost,
    connection,
  };

  static bool isAllowed(String type) => allowed.contains(type);

  static bool isCallType(String type) =>
      type == incomingCall || type == callHangup;

  static bool isChatType(String type) =>
      type == chatMessage || type == chat || type == message;
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
      '/network',
      '/money',
      '/media',
      '/health',
      '/market',
      '/jobs',
      '/opportunities',
      '/education',
      '/reservation',
      '/country',
      '/doc',
      '/ia',
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
// VOIP CALL MANAGER
// ============================================================================

class _VoipCallManager {
  _VoipCallManager._();

  static final _VoipCallManager instance = _VoipCallManager._();

  StreamSubscription<CallEvent?>? _eventSub;
  bool _isInitialized = false;

  void Function(String inviteId, String channelName, bool isVideo)? onAcceptCall;
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

    if (safeInviteId.isEmpty || safeChannel.isEmpty) {
      debugPrint(
          '[VOIP] ⚠️ Appel ignoré : invite_id invalide ou channel_name vide '
          '(inviteId="$inviteId", channel="$channelName")');
      return;
    }

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
        ringtonePath: 'ringtone',
        backgroundColor: '#0A2F5C',
        actionColor: '#4CAF50',
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'ringtone',
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

  /// Appel accepté (évènement CallKit OU rattrapage au démarrage) :
  /// un même appel n'est transmis qu'une seule fois.
  void _emitAccept(String inviteId, String channelName, bool isVideo) {
    if (!CallHandledRegistry.markAccepted(inviteId)) {
      debugPrint('[VOIP] ℹ️ Acceptation en double ignorée: $inviteId');
      return;
    }
    onAcceptCall?.call(inviteId, channelName, isVideo);
  }

  /// App lancée par un appel accepté depuis l'écran verrouillé.
  Future<void> resumeAcceptedCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List) return;

      for (final c in calls) {
        if (c is! Map) continue;
        if (c['isAccepted'] != true) continue;

        final extra = (c['extra'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final inviteId = (extra['invite_id'] ?? c['id'] ?? '').toString();
        final channelName = (extra['channel_name'] ?? '').toString();
        final isVideo = extra['is_video'] == true;

        if (inviteId.isEmpty) continue;
        debugPrint('[VOIP] ↩️ Appel accepté rattrapé au démarrage: $inviteId');
        _emitAccept(inviteId, channelName, isVideo);
      }
    } catch (e) {
      debugPrint('[VOIP] ⚠️ resumeAcceptedCalls: $e');
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
      _emitAccept(inviteId, channelName, isVideo);
    } else if (type == Event.actionCallDecline) {
      CallHandledRegistry.emitDeclined(inviteId);
      onDeclineCall?.call(inviteId);
    } else if (type == Event.actionCallTimeout) {
      CallHandledRegistry.markEnded(inviteId);
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

  /// Retourne -1 si Supabase n'est pas disponible (ex. isolate d'arrière-plan)
  Future<int> fetchUnreadCount() async {
    try {
      final uid = SupabaseConfig.currentUser?.id;
      if (uid == null || !_Validators.isValidUid(uid)) return -1;

      return await SupabaseConfig.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kSupabaseTimeout);
    } catch (_) {
      return -1;
    }
  }

  Future<void> refreshFromDb() async {
    final count = await fetchUnreadCount();
    if (count < 0) return;
    await sync(count);
  }
}

// ============================================================================
// BACKGROUND HANDLER
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
  debugPrint('[FCM-BG] message reçu type="$type" hasNotification='
      '${message.notification != null}');

  if (type == PushTypes.incomingCall) {
    final sent = message.sentTime;
    if (sent != null && DateTime.now().difference(sent) > _kStaleCallPush) {
      debugPrint('[FCM-BG] ⏱️ incoming_call périmé ignoré');
      return;
    }

    try {
      // CallKit en premier : sonnerie + vibration + pop-up natifs
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
      CallHandledRegistry.markEnded(id);
      await _VoipCallManager.instance.endCall(id);
    }
    return;
  }

  try {
    await LocalNotificationService.instance
        .initialize()
        .timeout(_kForegroundInitTimeout);

    await _showFromRemoteMessage(message, skipIfSystemNotification: true);
  } catch (e) {
    debugPrint('[FCM-BG] ❌ $e');
  }

  try {
    await _BadgeManager.instance.refreshFromDb();
  } catch (_) {}
}

// ============================================================================
// HELPERS
// ============================================================================

Future<void> _showFromRemoteMessage(
  RemoteMessage message, {
  bool skipIfSystemNotification = false,
}) async {
  final data = message.data;
  final type = (data['type'] ?? '').toString().toLowerCase();

  if (PushTypes.isCallType(type)) return;

  final hasContent = message.notification != null ||
      data['title'] != null ||
      data['body'] != null ||
      data['message'] != null;
  if (!hasContent) {
    debugPrint('[Push] ℹ️ message sans contenu ignoré (type="$type")');
    return;
  }

  if (skipIfSystemNotification && message.notification != null) return;

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

    final payload = _buildPayload(data);
    final notifId = _generateNotifId(message);

    if (PushTypes.isChatType(type)) {
      await LocalNotificationService.instance.showChatMessage(
        id: notifId,
        title: title,
        body: body,
        payload: payload,
      );
    } else {
      await LocalNotificationService.instance.show(
        id: notifId,
        title: title,
        body: body,
        payload: payload,
        channelId: _getChannelForType(type),
      );
    }
  } catch (e) {
    debugPrint('[Push] ❌ affichage notification: $e');
  }
}

String _getChannelForType(String type) {
  if (type == PushTypes.incomingCall || type == PushTypes.sos) {
    return LocalNotificationService.channelCalls;
  }
  if (PushTypes.isChatType(type)) {
    return LocalNotificationService.channelChat;
  }
  return LocalNotificationService.channelDefault;
}

String _defaultTitle(String type) {
  switch (type) {
    case PushTypes.incomingCall:
      return 'Appel entrant';
    case PushTypes.chatMessage:
    case PushTypes.chat:
    case PushTypes.message:
      return 'Nouveau message';
    case PushTypes.sos:
      return 'Alerte SOS';
    case PushTypes.like:
      return 'Nouveau like';
    case PushTypes.follow:
      return 'Nouvel abonné';
    case PushTypes.comment:
      return 'Nouveau commentaire';
    case PushTypes.commentReply:
      return 'Réponse à votre commentaire';
    case PushTypes.commentLike:
      return 'Like sur votre commentaire';
    case PushTypes.repost:
      return 'Republication';
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

  if (PushTypes.isChatType(type)) {
    final convId = _Validators.sanitizeString(
      (data['conversation_id'] ?? data['conversationId'] ?? '').toString(),
      maxLength: 64,
    );

    if (convId.isNotEmpty) return 'chat:$convId';
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

  void Function(String inviteId, String channelName, bool isVideo)? onVoipAccept;
  void Function(String inviteId)? onVoipDecline;

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
      );

      try {
        await LocalNotificationService.instance.requestPermission();
      } catch (_) {}

      try {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      } catch (e) {
        debugPrint('[PushNotif] ⚠️ FullIntent: $e');
      }

      try {
        await _VoipCallManager.instance.initialize();
        _VoipCallManager.instance.onAcceptCall = _handleVoipAccept;
        _VoipCallManager.instance.onDeclineCall = _handleVoipDecline;
        await _VoipCallManager.instance.resumeAcceptedCalls();
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
      _openedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(_kInitialTapDelay, () => _handleNotificationTap(initial));
      }

      await _BadgeManager.instance.refreshFromDb();

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotif] ❌ Init failed: $e');
    } finally {
      _initializing = false;
    }
  }

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

  Future<void> endVoipCall(String inviteId) async {
    await _VoipCallManager.instance.endCall(inviteId);
  }

  Future<void> endAllVoipCalls() async {
    await _VoipCallManager.instance.endAllCalls();
  }

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
    unawaited(_tokenRefreshSub?.cancel());
    _tokenRefreshSub = null;
    unawaited(_foregroundSub?.cancel());
    _foregroundSub = null;
    unawaited(_openedAppSub?.cancel());
    _openedAppSub = null;
  }

  /// App ouverte : l'écran d'appel de l'app (GlobalCallListener) est prioritaire.
  /// CallKit n'intervient qu'en secours, si la page n'est pas apparue après 2,5 s.
  void _handleForegroundIncomingCall(Map<String, dynamic> data) {
    final inviteId = (data['invite_id'] ?? data['inviteId'] ?? '').toString();
    if (inviteId.isEmpty) return;

    final callerName = (data['caller_name'] ?? 'Appel entrant').toString();
    final callerAvatar = data['caller_avatar']?.toString();
    final channelName = (data['channel_name'] ?? '').toString();
    final isVideo = (data['is_video'] ?? 'false').toString() == 'true';

    Future<void>.delayed(_kForegroundCallFallbackDelay, () {
      if (CallHandledRegistry.isShownInApp(inviteId) ||
          CallHandledRegistry.isEnded(inviteId) ||
          CallHandledRegistry.isAccepted(inviteId)) {
        return;
      }
      unawaited(
        _VoipCallManager.instance.showIncomingCall(
          inviteId: inviteId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          channelName: channelName,
          isVideo: isVideo,
        ),
      );
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().toLowerCase();

    if (type == PushTypes.incomingCall) {
      _handleForegroundIncomingCall(data);
      return;
    }

    if (type == PushTypes.callHangup) {
      final id = (data['invite_id'] ?? data['inviteId'] ?? '').toString();
      if (id.isNotEmpty) {
        CallHandledRegistry.markEnded(id);
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

  // ──────────────────────────────────────────────────────────────
  // TOKEN FCM → SUPABASE
  // ──────────────────────────────────────────────────────────────
  Future<void> _registerToken() async {
    var attempts = 0;

    while (attempts < _kMaxRetries) {
      try {
        final token = await _messaging.getToken();
        final uid = SupabaseConfig.currentUser?.id;

        if (token == null || !_Validators.isValidToken(token)) {
          debugPrint('[PushNotif] ⚠️ Token FCM absent ou invalide '
              '(Google Play Services / google-services.json ?)');
          return;
        }
        if (uid == null || !_Validators.isValidUid(uid)) {
          debugPrint(
              '[PushNotif] ⚠️ Pas d\'utilisateur connecté : token non enregistré');
          return;
        }

        await _saveTokenRow(uid, token);
        debugPrint('[PushNotif] ✓ Token enregistré en base');
        return;
      } catch (e) {
        attempts++;
        debugPrint(
            '[PushNotif] ❌ Enregistrement token ($attempts/$_kMaxRetries): $e');
        if (attempts >= _kMaxRetries) return;
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  Future<void> _saveTokenRow(String uid, String token) async {
    final client = SupabaseConfig.client;

    // Un appareil = un seul compte
    try {
      await client
          .from(_tokensTable)
          .delete()
          .eq('fcm_token', token)
          .neq('user_id', uid)
          .timeout(_kSupabaseTimeout);
    } catch (_) {}

    final row = <String, dynamic>{
      'user_id': uid,
      'fcm_token': token,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await client
          .from(_tokensTable)
          .upsert(row, onConflict: 'user_id,fcm_token')
          .timeout(_kSupabaseTimeout);
    } catch (e) {
      debugPrint('[PushNotif] ⚠️ upsert échoué ($e) → plan B delete+insert');
      await client
          .from(_tokensTable)
          .delete()
          .eq('user_id', uid)
          .eq('fcm_token', token)
          .timeout(_kSupabaseTimeout);
      await client.from(_tokensTable).insert(row).timeout(_kSupabaseTimeout);
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
    } catch (e) {
      debugPrint('[PushNotif] ⚠️ unregisterToken: $e');
    }
  }

  void registerContext(BuildContext context) {
    _context = context;
  }

  void unregisterContext() {
    _context = null;
  }

  Future<void> updateBadge(int count) async {
    await _BadgeManager.instance.sync(count);
  }

  Future<void> refreshBadge() async {
    await _BadgeManager.instance.refreshFromDb();
  }

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
