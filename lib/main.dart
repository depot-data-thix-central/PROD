// lib/main.dart
//
// THIX ID CENTRAL — Point d'entrée (Production Enterprise v2.5)
//
// FIX v2.4 : le token push n'est supprimé QUE sur une vraie déconnexion
//            (AuthChangeEvent.signedOut), plus jamais sur une coupure de
//            session temporaire.
// FIX v2.5 : appel accepté depuis l'écran verrouillé (app fermée) :
//            - callbacks VoIP branchés AVANT runApp (plus de course au démarrage)
//            - action gardée en attente tant que le routeur n'est pas prêt
//            - même mécanisme pour le tap sur une notification
// FIX      : _maskUid (log illisible)
// EXISTANT PRÉSERVÉ : Web safe, Riverpod + Provider, timeouts,
// runZonedGuarded sans second runApp, mode jour forcé.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'package:thix_id/presentation/notifications/widgets/notif_banner_listener.dart';
import 'package:thix_id/presentation/chat/call/global_call_listener.dart';
import 'package:thix_id/presentation/thix_sos/widgets/global_sos_listener.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thix_id/data/offline/chat_offline_cache.dart';
import 'package:thix_id/core/security/security_reporter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
// Action IDs (définis ici pour être visibles aussi sur Web)
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';
const Duration _kInitTimeout = Duration(seconds: 10);

void _log(String message) => debugPrint('[MAIN] $message');

late final LocaleController _localeController;
bool _appLaunched = false;

// ============================================================================
// NAVIGATION EN ATTENTE (cold start : le routeur n'existe pas encore)
// ============================================================================
bool _routerReady = false;

({String inviteId, String channelName, bool isVideo})? _pendingCall;
({String payload, String? actionId})? _pendingTap;

/// Ouvre l'écran d'appel. Si le routeur n'est pas prêt, l'action est gardée
/// et rejouée dès qu'il l'est (voir _flushPendingNav).
void _openCall(String inviteId, String channelName, bool isVideo) {
  if (inviteId.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (!_routerReady || ctx == null || !ctx.mounted) {
    _pendingCall = (
      inviteId: inviteId,
      channelName: channelName,
      isVideo: isVideo,
    );
    _log('📞 Appel accepté mis en attente (routeur pas prêt)');
    return;
  }

  _pendingCall = null;
  _log('📞 Navigation vers l\'écran d\'appel');
  ctx.push(
    '/call/$inviteId',
    extra: {
      'channelName': channelName,
      'isVideo': isVideo,
      'isIncoming': true,
    },
  );
}

/// Rejoue les navigations gardées en attente (appel accepté, tap notification).
void _flushPendingNav() {
  if (!_routerReady) return;

  final call = _pendingCall;
  if (call != null) {
    _openCall(call.inviteId, call.channelName, call.isVideo);
  }

  final tap = _pendingTap;
  if (tap != null) {
    _pendingTap = null;
    _handleLocalNotificationTap(tap.payload, actionId: tap.actionId);
  }
}

// ============================================================================
// NOTIFICATION TAP HANDLER (global)
// ============================================================================

void _handleLocalNotificationTap(String? payload, {String? actionId}) {
  if (payload == null || payload.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (!_routerReady || ctx == null || !ctx.mounted) {
    _pendingTap = (payload: payload, actionId: actionId);
    _log('NotifTap mis en attente (routeur pas prêt) payload=$payload');
    return;
  }

  _log('NotifTap action=$actionId payload=$payload');

  // ── Chat message ──────────────────────────────────────
  // payload format: "chat:CONVERSATION_ID"
  if (payload.startsWith('chat:')) {
    final convId = payload.substring(5);
    if (convId.isEmpty) return;

    if (actionId == kActionReply ||
        actionId == null ||
        actionId == kActionOpen) {
      ctx.push('/chat/$convId');
    }
    return;
  }

  // ── Appel ─────────────────────────────────────────────
  // payload format: "call:INVITE_ID:CHANNEL_NAME"
  if (payload.startsWith('call:')) {
    final parts = payload.split(':');
    if (parts.length >= 3) {
      final inviteId = parts[1];
      final channelName = parts[2];
      ctx.push(
        '/call/$inviteId',
        extra: {
          'channelName': channelName,
          'isVideo': false,
          'isIncoming': true,
        },
      );
    }
    return;
  }

  // ── Network (like, comment, follow, etc.) ─────────────
  if (payload.startsWith('/network')) {
    ctx.push(payload);
    return;
  }

  // ── Routes génériques ─────────────────────────────────
  if (payload.startsWith('/')) {
    ctx.push(payload);
    return;
  }

  // Fallback
  ctx.push('/notifications');
}

// ============================================================================
// MAIN
// ============================================================================

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Offline cache ──────────────────────────────────────────────
      try {
        await Hive.initFlutter().timeout(_kInitTimeout);
        await ChatOfflineCache.init().timeout(_kInitTimeout);
        _log('✓ Offline cache OK');
      } catch (e) {
        _log('⚠️ Offline cache: $e');
      }

      // ── ErrorWidget visible ────────────────────────────────────────
      ErrorWidget.builder = (details) => Material(
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

      // ── FlutterError filter ────────────────────────────────────────
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString().toLowerCase();
        final isNetworkAuthError = msg.contains('authretryablefetchexception') ||
            msg.contains('socketexception') ||
            msg.contains('connection reset') ||
            msg.contains('stream has already been listened');

        if (isNetworkAuthError) {
          _log('⚠️ FlutterError network/stream ignored: ${details.exception}');
          return;
        }

        FlutterError.presentError(details);
        SecurityReporter.reportClientError(
          source: 'flutter_error',
          message: '${details.exception}',
        );
        _log('❌ FlutterError: ${details.exception}');
      };

      // ── MOBILE ONLY : Firebase + handler background + Badge ───────
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

      // ── Supabase ───────────────────────────────────────────────────
      try {
        await SupabaseConfig.initialize().timeout(_kInitTimeout);
        _log('✓ Supabase OK');
      } catch (e) {
        _log('⚠️ Supabase: $e');
      }

      // ── Local notifications ────────────────────────────────────────
      try {
        await LocalNotificationService.instance
            .initialize()
            .timeout(_kInitTimeout);

        // Câbler le tap / actions (Ouvrir, Répondre)
        LocalNotificationService.instance.onNotificationTap =
            (payload, {actionId}) {
          _handleLocalNotificationTap(payload, actionId: actionId);
        };

        _log('✓ LocalNotif OK');
      } catch (e) {
        _log('⚠️ LocalNotif: $e');
      }

      // ── Locale controller ──────────────────────────────────────────
      _localeController = LocaleController();
      try {
        await _localeController.init().timeout(_kInitTimeout);
        _log('✓ Locale OK: ${_localeController.locale.languageCode}');
      } catch (e) {
        _log('⚠️ Locale: $e');
      }

      // ── Auth ───────────────────────────────────────────────────────
      try {
        await AuthController.instance.init().timeout(_kInitTimeout);
        _log('✓ Auth OK');
      } catch (e) {
        _log('⚠️ Auth: $e');
      }

      // ── VoIP + Push (après Supabase/Auth) ──────────────────────────
      if (!kIsWeb) {
        // ✅ Callbacks branchés AVANT initialize() : un appel accepté depuis
        // l'écran verrouillé (app fermée) ne peut plus être perdu.
        PushNotificationService.instance.onVoipAccept =
            (inviteId, channelName, isVideo) {
          _log('📞 VoIP accepted');
          _openCall(inviteId, channelName, isVideo);
        };
        PushNotificationService.instance.onVoipDecline = (inviteId) {
          _log('📞 VoIP declined: $inviteId');
        };

        try {
          await PushNotificationService.instance
              .initialize()
              .timeout(_kInitTimeout);

          _log('✓ Push/VoIP OK');
        } catch (e) {
          _log('⚠️ Push/VoIP init: $e');
        }
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
      final isNetworkAuthError =
          errorStr.contains('authretryablefetchexception') ||
              errorStr.contains('socketexception') ||
              errorStr.contains('connection reset') ||
              errorStr.contains('clientexception') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('network is unreachable');

      if (_appLaunched && isNetworkAuthError) {
        _log(
            '⚠️ Network/Auth error ignored (app already running, likely offline)');
        return;
      }

      if (!_appLaunched) {
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
      }
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
  StreamSubscription<AuthState>? _authSub;

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
      if (!kIsWeb && _pushRegistered) {
        unawaited(AppBadgeSyncService.refreshNow());
      }
      // Rejoue une action (appel accepté / tap notification) restée en attente
      _flushPendingNav();
    }
  }

  Future<void> _init() async {
    // ── Router ───────────────────────────────────────────────────────
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

    // ── Déconnexion RÉELLE uniquement (jamais une simple perte de session) ──
    if (!kIsWeb) {
      try {
        _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen((s) {
          if (s.event == AuthChangeEvent.signedOut) {
            unawaited(_handleSignedOut());
          }
        });
      } catch (e) {
        _log('⚠️ Auth state listener: $e');
      }
    }

    // ── Sync push ↔ auth (enregistrement uniquement) ────────────────
    _auth.addListener(_syncPush);
    _syncPush();

    if (mounted) setState(() => _ready = true);

    // Routeur monté après le prochain frame : on rejoue les actions en attente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routerReady = true;
      Future.delayed(const Duration(milliseconds: 600), _flushPendingNav);
      Future.delayed(const Duration(milliseconds: 2500), _flushPendingNav);
    });
  }

  /// Enregistre le push quand l'utilisateur est connecté.
  /// NE désenregistre JAMAIS : voir _handleSignedOut().
  Future<void> _syncPush() async {
    if (kIsWeb) return;
    if (!_auth.isAuthenticated || _pushRegistered) return;

    _pushRegistered = true;
    try {
      await PushNotificationService.instance.initialize();
      _log('✓ Push registered');

      final uid = SupabaseConfig.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await AppBadgeSyncService.startListening(uid);
        _log('✓ Badge Realtime started for ${_maskUid(uid)}');
      }
    } catch (e) {
      _pushRegistered = false;
      _log('⚠️ Push sync: $e');
    }
  }

  /// Vraie déconnexion (bouton "Se déconnecter") : on nettoie tout.
  Future<void> _handleSignedOut() async {
    if (kIsWeb || !_pushRegistered) return;
    _pushRegistered = false;

    try {
      await PushNotificationService.instance.unregisterToken();
      await PushNotificationService.instance.endAllVoipCalls();
      AppBadgeSyncService.stopListening();
      await AppBadgeSyncService.sync(0);
      _log('✓ Push/Badge unregistered (signedOut)');
    } catch (e) {
      _log('⚠️ Sign-out cleanup: $e');
    }
  }

  String _maskUid(String uid) => uid.length <= 8
      ? '***'
      : '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';

  @override
  void dispose() {
    _authSub?.cancel();
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
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
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
