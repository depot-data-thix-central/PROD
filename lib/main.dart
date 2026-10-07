// lib/main.dart
//
// THIX ID CENTRAL — Point d'entrée (Production Enterprise v2.1)
//
// ✅ COMPATIBLE WEB : Toutes les APIs VoIP/Firebase/Badge wrappées dans !kIsWeb
// ✅ Utilise le stub conditionnel push_notification_service.dart (stub sur Web, io sur mobile)
// ✅ FIX : AuthController.userId → SupabaseConfig.currentUser?.id
// ✅ FIX : AppBadgeSyncService RealtimeChannel type error
//
// EXISTANT PRÉSERVÉ INTÉGRALEMENT :
//  localeControllerProvider injecté via ProviderScope (fix UnimplementedError)
//  Coexistence Provider (legacy listeners) + Riverpod
//  Erreurs UI visibles (plus jamais d'écran gris silencieux)
//  Timeouts sur toutes les initialisations
//  CORRECTIF ANR OFFLINE : runZonedGuarded ne relance plus runApp()
//  MODE JOUR FORCÉ : themeMode = ThemeMode.light
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/app_router.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/local_notification_service.dart';
// ✅ Stub conditionnel : _stub.dart sur Web (no-op), _io.dart sur mobile (VoIP+FCM)
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

const Duration _kInitTimeout = Duration(seconds: 10);

void _log(String message) => debugPrint('[MAIN] $message');

late final LocaleController _localeController;
bool _appLaunched = false;

// ============================================================================
// BACKGROUND HANDLER FCM (top-level, requis par Firebase)
// ============================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ce handler est enregistré uniquement sur mobile (voir main()).
  // Sur Web, il n'est jamais référencé donc pas de problème de compilation.
  await Firebase.initializeApp();
  debugPrint('[FCM-BG] 🚀 Background message: ${message.messageId}');
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

      // ── MOBILE ONLY : Firebase + VoIP + Badge ─────────────────────
      if (!kIsWeb) {
        try {
          await Firebase.initializeApp().timeout(_kInitTimeout);
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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

        // ✅ VoIP natif (CallKit + sonnerie) — mobile uniquement
        try {
          await PushNotificationService.instance.initialize();
          _log('✓ Push/VoIP OK');
        } catch (e) {
          _log('⚠️ Push/VoIP init: $e');
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
        await LocalNotificationService.instance.initialize().timeout(_kInitTimeout);
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
      SecurityReporter.reportClientError(source: 'zone_error', message: '$error');
      _log('❌ Uncaught (appLaunched=$_appLaunched): $error');

      final errorStr = error.toString().toLowerCase();
      final isNetworkAuthError = errorStr.contains('authretryablefetchexception') ||
          errorStr.contains('socketexception') ||
          errorStr.contains('connection reset') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network is unreachable');

      if (_appLaunched && isNetworkAuthError) {
        _log('⚠️ Network/Auth error ignored (app already running, likely offline)');
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
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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
      // ✅ Rafraîchir badge au retour premier plan (mobile uniquement)
      if (!kIsWeb && _pushRegistered) {
        unawaited(AppBadgeSyncService.refreshNow());
      }
    }

    // ✅ Cleanup VoIP si app suspendue (mobile uniquement)
    if (state == AppLifecycleState.paused && !kIsWeb) {
      unawaited(PushNotificationService.instance.endAllVoipCalls());
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

    // ✅ Câbler callbacks VoIP (MOBILE UNIQUEMENT)
    if (!kIsWeb) {
      PushNotificationService.instance.onVoipAccept = (inviteId, channelName, isVideo) {
        _log('📞 VoIP accepted → navigating to call screen');
        rootNavigatorKey.currentContext?.push(
          '/call/$inviteId',
          extra: {'channelName': channelName, 'isVideo': isVideo, 'isIncoming': true},
        );
      };
      PushNotificationService.instance.onVoipDecline = (inviteId) {
        _log('📞 VoIP declined: $inviteId');
      };
    }

    // ── Sync push ↔ auth ────────────────────────────────────────────
    _auth.addListener(_syncPush);
    _syncPush();

    if (mounted) setState(() => _ready = true);
  }

  /// Enregistre / retire token FCM + badge Realtime selon auth.
  Future<void> _syncPush() async {
    if (kIsWeb) return;

    final isAuthenticated = _auth.isAuthenticated;

    try {
      if (isAuthenticated && !_pushRegistered) {
        _pushRegistered = true;
        await PushNotificationService.instance.initialize();
        _log('✓ Push registered');

        // ✅ FIX : currentUser?.id au lieu de _auth.userId
        final uid = SupabaseConfig.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          await AppBadgeSyncService.startListening(uid);
          _log('✓ Badge Realtime started for ${_maskUid(uid)}');
        }
      } else if (!isAuthenticated && _pushRegistered) {
        _pushRegistered = false;
        await PushNotificationService.instance.unregisterToken();
        await PushNotificationService.instance.endAllVoipCalls();
        AppBadgeSyncService.stopListening();
        await AppBadgeSyncService.sync(0);
        _log('✓ Push/Badge unregistered');
      }
    } catch (e) {
      _log('⚠️ Push sync: $e');
    }
  }

  String _maskUid(String uid) =>
      uid.length <= 8 ? '***' : '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';

  @override
  void dispose() {
    _auth.removeListener(_syncPush);
    WidgetsBinding.instance.removeObserver(this);
    // ✅ Cleanup VoIP + badge (mobile uniquement)
    if (!kIsWeb) {
      unawaited(PushNotificationService.instance.endAllVoipCalls());
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
        app_provider.ChangeNotifierProvider<LocaleController>.value(value: localeController),
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
                if (supportedLocale.languageCode == locale.languageCode) return supportedLocale;
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
