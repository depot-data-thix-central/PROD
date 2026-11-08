// lib/main.dart
//
// THIX ID CENTRAL — Point d'entrée (Production Enterprise v2.13)
//
// CHANGELOG v2.13 (offline-safe) :
//   ✅ Supabase init avec retry automatique au retour du réseau
//      (un cold-start offline ne laisse plus l'app dans un état cassé)
//   ✅ ErrorWidget.builder affiche "Pas de connexion" au lieu de l'écran
//      rouge pour les erreurs réseau (SocketException, RealtimeSubscribeException,
//      Failed host lookup…)
//   ✅ Handler de zone : AppConnectivity.instance.markBackendDown() sur
//      erreur réseau → le router affiche /no-connection au lieu de /login
//   ✅ Au resumed (AppLifecycleState.resumed), retry de Supabase init si
//      dernière tentative avait échoué
//
// CHANGELOG v2.12 :
//   ✅ Refus CallKit dédupliqué (CallHandledRegistry.markDeclineSent) :
//      un seul rpc_reject_call même si GlobalCallListener le fait aussi
//
// CHANGELOG v2.11 (réseau faible / appels) :
//   ✅ Refus CallKit : transmis à rpc_reject_call (3 tentatives)
//   ✅ Appel accepté au cold-start : attend la session (jusqu'à 20 s) +
//      3 tentatives sur CallKitCallHandler.accept
//   ✅ PushNotificationService.initialize() ne bloque plus runApp
//   ✅ Nouvel essai de la navigation en attente dès que la session est prête
//
// CHANGELOG v2.10 : JustAudioBackground.init()
// CHANGELOG v2.9  : buffer d'actions pending, CallPermissionHelper, `input`
// Conserve tous les correctifs v2.8.
// ============================================================================
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ NOUVEAU
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/app_router.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/services/notifications/app_badge_sync_service.dart';
import 'package:thix_id/services/chat/call_permission_helper.dart';
import 'package:thix_id/services/chat/call_handled_registry.dart';
import 'package:thix_id/presentation/notifications/widgets/notif_banner_listener.dart';
import 'package:thix_id/presentation/chat/call/callkit_call_handler.dart';
import 'package:thix_id/presentation/chat/call/global_call_listener.dart';
import 'package:thix_id/presentation/thix_sos/widgets/global_sos_listener.dart';
import 'package:thix_id/widgets/no_connection_overlay.dart'; // ✅ NOUVEAU
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thix_id/data/offline/chat_offline_cache.dart';
import 'package:thix_id/core/security/security_reporter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';
const String kActionMarkAsRead = 'MARK_AS_READ';
const String kActionMute = 'MUTE';
const Duration _kInitTimeout = Duration(seconds: 10);
const Duration _kRpcTimeout = Duration(seconds: 15);
const int _kCallRetries = 3;

void _log(String message) => debugPrint('[MAIN] $message');

late final LocaleController _localeController;
bool _appLaunched = false;

// ============================================================================
// ✅ NOUVEAU : détection centralisée d'erreur réseau
// ============================================================================

/// Détecte si un message d'erreur indique une panne réseau ou Supabase.
/// Utilisé par :
///   - ErrorWidget.builder (→ afficher "Pas de connexion" au lieu de l'écran rouge)
///   - FlutterError.onError (→ markBackendDown)
///   - runZonedGuarded (→ markBackendDown)
bool _isNetworkError(String msg) {
  final m = msg.toLowerCase();
  return m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('network is unreachable') ||
      m.contains('connection reset') ||
      m.contains('connection refused') ||
      m.contains('authretryablefetchexception') ||
      m.contains('realtimesubscribeexception') ||
      m.contains('websocketchannelexception') ||
      m.contains('channelerror') ||
      m.contains('handshakeexception') ||
      m.contains('timeoutexception');
}

/// ✅ NOUVEAU : tente de (ré)initialiser Supabase.
/// Appelé :
///   - au cold-start (depuis main())
///   - au retour du réseau (listener Connectivity)
///   - au resumed (AppLifecycleState) si dernière tentative avait échoué
Future<void> _tryInitSupabase({required String reason}) async {
  if (SupabaseConfig.isInitialized) return;
  _log('🔄 Trying Supabase init ($reason)…');
  try {
    await SupabaseConfig.initialize().timeout(_kInitTimeout);
    _log('✅ Supabase init succeeded ($reason)');
    AppConnectivity.instance.markBackendUp();
    // Relance AuthController.init() pour hydrater la session depuis le snapshot
    try {
      await AuthController.instance.init().timeout(_kInitTimeout);
      _log('✓ Auth hydrated after late Supabase init');
    } catch (e) {
      _log('⚠️ Auth init after Supabase: $e');
    }
  } catch (e) {
    _log('⚠️ Supabase init still failing ($reason): $e');
    AppConnectivity.instance.markBackendDown();
  }
}

// ============================================================================
// NAVIGATION EN ATTENTE (cold start : le routeur n'existe pas encore)
// ============================================================================
bool _routerReady = false;

String? _pendingCallId;
({String payload, String? actionId, String? input})? _pendingTap;

/// Appel accepté depuis CallKit.
/// Si le routeur ou la session ne sont pas prêts (cold start, réseau lent),
/// l'appel reste en attente et est rejoué par _flushPendingNav.
void _openCall(String inviteId, String channelName, bool isVideo) {
  if (inviteId.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (!_routerReady || ctx == null || !ctx.mounted) {
    _pendingCallId = inviteId;
    _log('📞 Appel accepté mis en attente (routeur pas prêt)');
    return;
  }

  if (!AuthController.instance.isAuthenticated) {
    _pendingCallId = inviteId;
    _log('📞 Appel accepté mis en attente (session pas prête)');
    return;
  }

  _pendingCallId = null;
  _log('📞 Appel accepté → ouverture de l\'appel');
  unawaited(_acceptWithRetry(inviteId));
}

/// 3 tentatives : un échec réseau passager ne perd plus l'appel accepté.
Future<void> _acceptWithRetry(String inviteId) async {
  for (var attempt = 1; attempt <= _kCallRetries; attempt++) {
    try {
      await CallKitCallHandler.accept(inviteId);
      return;
    } catch (e) {
      _log('⚠️ CallKit accept $attempt/$_kCallRetries: $e');
      if (attempt < _kCallRetries) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
  _log('❌ CallKit accept abandonné: $inviteId');
}

/// Refus depuis CallKit : prévient l'appelant (3 tentatives).
/// Dédupliqué : si GlobalCallListener l'a déjà envoyé, on ne le refait pas.
Future<void> _rejectInvite(String inviteId) async {
  if (inviteId.isEmpty) return;

  if (!CallHandledRegistry.markDeclineSent(inviteId)) return;

  for (var attempt = 1; attempt <= _kCallRetries; attempt++) {
    try {
      await SupabaseConfig.client
          .rpc('rpc_reject_call', params: {'p_invite_id': inviteId})
          .timeout(_kRpcTimeout);
      _log('✓ Refus transmis: $inviteId');
      return;
    } catch (e) {
      _log('⚠️ Refus $attempt/$_kCallRetries: $e');
      if (attempt < _kCallRetries) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
  CallHandledRegistry.clearDeclineSent(inviteId);
  _log('❌ Refus non transmis: $inviteId');
}

void _flushPendingNav() {
  if (!_routerReady) return;

  final callId = _pendingCallId;
  if (callId != null) {
    // _openCall remet l'appel en attente si la session n'est pas prête
    _openCall(callId, '', false);
  }

  final tap = _pendingTap;
  if (tap != null) {
    _pendingTap = null;
    _handleLocalNotificationTap(
      tap.payload,
      actionId: tap.actionId,
      input: tap.input,
    );
  }
}

// ============================================================================
// ACTIONS DE NOTIFICATION (Répondre, Lu, Muet)
// ============================================================================

Future<void> _handleNotificationAction(
  String? payload,
  String actionId,
  String? input,
) async {
  if (payload == null || !payload.startsWith('chat:')) return;

  final convId = payload.substring(5);
  if (convId.isEmpty) return;

  // ✅ FIX : vérifier que Supabase est initialisé avant d'accéder à .client
  if (!SupabaseConfig.isInitialized) {
    _log('⚠️ Notification action ignored (Supabase not initialized): $actionId');
    return;
  }

  final supabase = SupabaseConfig.client;
  final currentUserId = SupabaseConfig.currentUser?.id;

  if (currentUserId == null) return;

  try {
    if (actionId == kActionReply && input != null && input.trim().isNotEmpty) {
      _log('💬 Quick Reply pour conv: $convId');
      await supabase.from('messages').insert({
        'conversation_id': convId,
        'sender_id': currentUserId,
        'content': input.trim(),
        'type': 'text',
      });
    } else if (actionId == kActionMarkAsRead) {
      _log('👁️ Marquer comme lu pour conv: $convId');
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', convId)
          .neq('sender_id', currentUserId);
    } else if (actionId == kActionMute) {
      _log('🔇 Mute la conversation: $convId');
      await supabase
          .from('conversations')
          .update({'is_muted': true})
          .eq('id', convId);
    }
  } catch (e) {
    _log('❌ Erreur action notif: $e');
  }
}

// ============================================================================
// NORMALISATION DES ROUTES DE NOTIFICATION
// ============================================================================
const Map<String, String> _routeAliases = {
  '/money': '/thix-money/history',
  '/health': '/thix-sante/dashboard',
  '/country': '/mon-pays',
  '/sos': '/thix-sos',
  '/ia': '/thix-ia',
  '/doc': '/vault',
  '/media': '/thix-media',
  '/reservation': '/reservation',
  '/notifications': '/network/notifications',
  '/notification': '/network/notifications',
};

String _normalizeRoute(String route) {
  final r = route.trim();

  final chat = RegExp(r'^/chat/c/([^/?#]+)').firstMatch(r);
  if (chat != null) return '/chat/${chat.group(1)}';

  final event = RegExp(r'^/events/([^/?#]+)').firstMatch(r);
  if (event != null) return '/thix-event/event/${event.group(1)}';

  for (final entry in _routeAliases.entries) {
    if (r == entry.key || r.startsWith('${entry.key}/')) {
      return entry.value;
    }
  }
  return r;
}

// ============================================================================
// NOTIFICATION TAP HANDLER (global)
// ============================================================================

void _handleLocalNotificationTap(
  String? payload, {
  String? actionId,
  String? input,
}) {
  if (payload == null || payload.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (!_routerReady || ctx == null || !ctx.mounted) {
    _pendingTap = (payload: payload, actionId: actionId, input: input);
    _log('NotifTap mis en attente (routeur pas prêt) payload=$payload');
    return;
  }

  _log('NotifTap action=$actionId payload=$payload input=$input');

  // ── Chat message ──────────────────────────────────────
  if (payload.startsWith('chat:')) {
    final convId = payload.substring(5);
    if (convId.isEmpty) return;

    if (actionId == kActionOpen || actionId == null) {
      ctx.push('/chat/$convId');
    }
    return;
  }

  // ── Appel ─────────────────────────────────────────────
  if (payload.startsWith('call:')) {
    final parts = payload.split(':');
    if (parts.length >= 2) {
      unawaited(CallKitCallHandler.showIncoming(parts[1]));
    }
    return;
  }

  // ── Routes (network, chat, modules…) ────
  if (payload.startsWith('/')) {
    final route = _normalizeRoute(payload);
    if (route != payload) _log('Route normalisée: $payload → $route');
    ctx.push(route);
    return;
  }

  ctx.push('/network/notifications');
}

// ============================================================================
// MAIN
// ============================================================================

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        await JustAudioBackground.init(
          androidNotificationChannelId: 'com.thix.info.channel.audio',
          androidNotificationChannelName: 'THIX Info Lecture',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidNotificationOngoing: true,
        ).timeout(_kInitTimeout);
        _log('✓ JustAudioBackground OK');
      } catch (e) {
        _log('⚠️ JustAudioBackground: $e');
      }

      try {
        await Hive.initFlutter().timeout(_kInitTimeout);
        await ChatOfflineCache.init().timeout(_kInitTimeout);
        _log('✓ Offline cache OK');
      } catch (e) {
        _log('⚠️ Offline cache: $e');
      }

      // ✅ FIX UI : afficher "Pas de connexion" au lieu de l'écran rouge
      // pour les erreurs réseau. Les autres erreurs restent affichées en
      // debug (utile pour les bugs UI).
      ErrorWidget.builder = (details) {
        final msg = details.exceptionAsString().toLowerCase();
        if (_isNetworkError(msg)) {
          return const Material(
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [NoConnectionOverlay()],
              ),
            ),
          );
        }
        return Material(
          color: const Color(0xFF0A2F5C),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                '❌ ERREUR UI :\n\n${details.exceptionAsString()}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      };

      // ✅ FIX : sur erreur réseau, marquer le backend comme down pour
      // que le router affiche /no-connection au lieu de /login.
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString().toLowerCase();

        if (_isNetworkError(msg)) {
          AppConnectivity.instance.markBackendDown();
          _log('⚠️ FlutterError network → backend marked down: '
              '${details.exception}');
          return; // ne pas afficher la stacktrace
        }

        if (msg.contains('stream has already been listened')) {
          _log('⚠️ FlutterError stream ignored: ${details.exception}');
          return;
        }

        FlutterError.presentError(details);
        SecurityReporter.reportClientError(
          source: 'flutter_error',
          message: '${details.exception}',
        );
        _log('❌ FlutterError: ${details.exception}');
      };

      if (!kIsWeb) {
        try {
          await Firebase.initializeApp().timeout(_kInitTimeout);
          FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler);
          _log('✓ Firebase OK');
        } catch (e) {
          _log('⚠️ Firebase: $e');
        }

        try {
          await AppBadgeSyncService.init().timeout(_kInitTimeout);
          _log('✓ Badge sync OK');
        } catch (e) {
          _log('⚠️ Badge sync: $e');
        }
      } else {
        _log('ℹ️ Web: Firebase/VoIP/Badge skipped');
      }

      // ✅ FIX OFFLINE : premier essai Supabase (peut échouer si DNS mort)
      await _tryInitSupabase(reason: 'cold-start');

      // ✅ FIX OFFLINE : listener sur le retour du réseau.
      // Si Supabase n'était pas initialisé (DNS mort au cold-start),
      // on retente dès que le réseau revient.
      Connectivity().onConnectivityChanged.listen((results) async {
        final online = results.isNotEmpty &&
            results.any((r) => r != ConnectivityResult.none);
        if (online && !SupabaseConfig.isInitialized) {
          // Petit délai pour laisser le DNS se stabiliser
          await Future.delayed(const Duration(milliseconds: 800));
          await _tryInitSupabase(reason: 'connectivity-restored');
        }
      });

      try {
        await LocalNotificationService.instance
            .initialize()
            .timeout(_kInitTimeout);

        LocalNotificationService.instance.onNotificationTap =
            (payload, {actionId, input}) async {
          if (actionId == kActionReply ||
              actionId == kActionMarkAsRead ||
              actionId == kActionMute) {
            await _handleNotificationAction(payload, actionId!, input);
            return;
          }

          _handleLocalNotificationTap(payload, actionId: actionId, input: input);
        };

        _log('✓ LocalNotif OK (v3.1 with pending buffer)');
      } catch (e) {
        _log('⚠️ LocalNotif: $e');
      }

      _localeController = LocaleController();
      try {
        await _localeController.init().timeout(_kInitTimeout);
        _log('✓ Locale OK: ${_localeController.locale.languageCode}');
      } catch (e) {
        _log('⚠️ Locale: $e');
      }

      try {
        await AuthController.instance.init().timeout(_kInitTimeout);
        _log('✓ Auth OK');
      } catch (e) {
        _log('⚠️ Auth: $e');
      }

      if (!kIsWeb) {
        PushNotificationService.instance.onVoipAccept =
            (inviteId, channelName, isVideo) {
          _log('📞 VoIP accepted');
          _openCall(inviteId, channelName, isVideo);
        };
        PushNotificationService.instance.onVoipDecline = (inviteId) {
          _log('📞 VoIP declined: $inviteId');
          unawaited(_rejectInvite(inviteId));
        };

        // Ne bloque plus le démarrage (réseau faible).
        // _syncPush relance initialize() après la connexion de toute façon.
        unawaited(
          PushNotificationService.instance
              .initialize()
              .timeout(const Duration(seconds: 30))
              .then((_) => _log('✓ Push/VoIP OK'))
              .catchError((Object e) => _log('⚠️ Push/VoIP init: $e')),
        );
      }

      _appLaunched = true;

      runApp(
        ProviderScope(
          overrides: [
            localeControllerProvider.overrideWith((ref) => _localeController),
          ],
          child: const ThixApp(),
        ),
      );
      _log('✓ runApp called');
    },
    (error, stack) {
      SecurityReporter.reportClientError(
          source: 'zone_error', message: '$error');
      _log('❌ Uncaught (appLaunched=$_appLaunched): $error');

      final errorStr = error.toString().toLowerCase();

      // ✅ FIX : au lieu d'ignorer silencieusement les erreurs réseau,
      // on les signale à AppConnectivity pour que le router affiche
      // /no-connection au lieu de /login.
      if (_isNetworkError(errorStr)) {
        AppConnectivity.instance.markBackendDown();
        _log('⚠️ Network error in zone → backend marked down');
        return;
      }

      if (_appLaunched) {
        _log('⚠️ Non-network error ignored (app already running)');
        return;
      }

      runApp(MaterialApp(
        theme: ThixPolicy.lightTheme(),
        themeMode: ThemeMode.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                '❌ Erreur de démarrage :\n$error',
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
    },
  );
}

// ============================================================================
// APP
// ============================================================================

class ThixApp extends ConsumerStatefulWidget {
  const ThixApp({super.key});

  @override
  ConsumerState<ThixApp> createState() => _ThixAppState();
}

class _ThixAppState extends ConsumerState<ThixApp> with WidgetsBindingObserver {
  late final AuthController _auth;
  GoRouter? _router;
  bool _ready = false;
  bool _pushRegistered = false;
  bool _startupPermissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthController.instance;
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final localeController = ref.read(localeControllerProvider);
    if (locales != null && locales.isNotEmpty) {
      localeController.refreshSystemLocale(locales);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _log('Lifecycle: $state');

    if (state == AppLifecycleState.resumed) {
      _log('App resumed → session handled by AuthController (offline-safe)');

      // ✅ FIX OFFLINE : si Supabase n'a pas pu être initialisé
      // précédemment (DNS mort au cold-start), on retente au resumed.
      if (!SupabaseConfig.isInitialized || SupabaseConfig.lastAttemptFailed) {
        unawaited(_tryInitSupabase(reason: 'resumed'));
      }

      if (!kIsWeb && _pushRegistered) {
        unawaited(AppBadgeSyncService.refreshNow());
      }
      _flushPendingNav();
    }
  }

  Future<void> _init() async {
    try {
      final localeController = ref.read(localeControllerProvider);
      _router = AppRouter.create(
        _auth,
        extraRefreshListenable: Listenable.merge([_auth, localeController]),
        navigatorKey: rootNavigatorKey,
      );
      _log('✓ Router OK');
    } catch (e) {
      _log('❌ Router: $e');
    }

    _auth.addListener(_syncPush);
    _syncPush();

    if (mounted) setState(() => _ready = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routerReady = true;
      // Essais étalés jusqu'à 20 s (session lente à se restaurer)
      for (final ms in const [600, 2500, 6000, 12000, 20000]) {
        Future.delayed(Duration(milliseconds: ms), _flushPendingNav);
      }
    });
  }

  Future<void> _syncPush() async {
    if (kIsWeb) return;

    if (!_auth.isAuthenticated) {
      if (_pushRegistered) {
        _pushRegistered = false;
        _startupPermissionsRequested = false;
        AppBadgeSyncService.stopListening();
        unawaited(AppBadgeSyncService.sync(0));
        _log('ℹ️ Session absente : badge arrêté (token push conservé)');
      }
      return;
    }

    // Session prête → on rejoue l'appel / la navigation en attente
    _flushPendingNav();

    if (_pushRegistered) return;
    _pushRegistered = true;

    try {
      await PushNotificationService.instance.initialize();
      _log('✓ Push registered');

      // ✅ FIX : vérifier que Supabase est initialisé avant .currentUser
      final uid = SupabaseConfig.isInitialized
          ? SupabaseConfig.currentUser?.id
          : null;
      if (uid != null && uid.isNotEmpty) {
        await AppBadgeSyncService.startListening(uid);
        _log('✓ Badge Realtime started for ${_maskUid(uid)}');
      }

      if (!_startupPermissionsRequested && Platform.isAndroid && mounted) {
        _startupPermissionsRequested = true;
        unawaited(_requestStartupPermissions());
      }
    } catch (e) {
      _pushRegistered = false;
      _log('⚠️ Push sync: $e');
    }
  }

  Future<void> _requestStartupPermissions() async {
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) {
        _log('⚠️ Startup permissions: context not ready, skipping');
        return;
      }
      await CallPermissionHelper.ensureAtStartup(ctx);
      _log('✓ Startup permissions requested');
    } catch (e) {
      _log('⚠️ Startup permissions failed: $e');
    }
  }

  String _maskUid(String uid) => uid.length <= 8
      ? '***'
      : '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';

  @override
  void dispose() {
    _auth.removeListener(_syncPush);
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb) {
      AppBadgeSyncService.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = ref.watch(localeControllerProvider);

    if (!_ready || _router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThixPolicy.lightTheme(),
        darkTheme: ThixPolicy.darkTheme(),
        themeMode: ThemeMode.light,
        home:
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return app_provider.MultiProvider(
      providers: [
        app_provider.ChangeNotifierProvider<AuthController>.value(value: _auth),
        app_provider.ChangeNotifierProvider<LocaleController>.value(
            value: localeController),
        app_provider.Provider<ProfileService>(create: (_) => ProfileService()),
      ],
      child: MaterialApp.router(
        title: 'THIX ID CENTRAL',
        debugShowCheckedModeBanner: false,
        theme: ThixPolicy.lightTheme(),
        darkTheme: ThixPolicy.darkTheme(),
        themeMode: ThemeMode.light,
        routerConfig: _router!,
        locale: localeController.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeListResolutionCallback: (locales, supportedLocales) {
          if (locales != null && locales.isNotEmpty) {
            for (final locale in locales) {
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
            }
          }
          return supportedLocales.first;
        },
        builder: (context, child) {
          return Directionality(
            textDirection: localeController.textDirection,
            child: NotifBannerListener(
              child: GlobalSosListener(
                child: GlobalCallListener(
                  navigatorKey: rootNavigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
