// lib/main.dart
//
// THIX ID CENTRAL — Point d'entrée (Production Enterprise)
//  localeControllerProvider injecté via ProviderScope (fix UnimplementedError)
//  Coexistence Provider (legacy listeners) + Riverpod
//  Erreurs UI visibles (plus jamais d'écran gris silencieux)
// Gardes kIsWeb (Firebase/push non supportés sur Web)
//  Timeouts sur toutes les initialisations
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
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/presentation/chat/call/global_call_listener.dart';
import 'package:thix_id/presentation/common/global_notification_listener.dart';
import 'package:thix_id/presentation/thix_sos/widgets/global_sos_listener.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kInitTimeout = Duration(seconds: 10);

void _log(String message) => debugPrint('[MAIN] $message');

//  Instance GLOBALE créée AVANT runApp, injectée dans Riverpod
late final LocaleController _localeController;

// ============================================================================
// MAIN
// ============================================================================

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      //  Erreurs de build affichées À L'ÉCRAN (rouge) au lieu d'écran gris
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

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _log('❌ FlutterError: ${details.exception}');
      };

      // WEB : FCM n'existe pas sur Web → skip
      if (!kIsWeb) {
        try {
          await Firebase.initializeApp().timeout(_kInitTimeout);
          FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler,
          );
          _log('✓ Firebase OK');
        } catch (e) {
          _log('⚠️ Firebase: $e');
        }
      } else {
        _log('ℹ️ Web: Firebase push skipped');
      }

      try {
        await SupabaseConfig.initialize().timeout(_kInitTimeout);
        _log('✓ Supabase OK');
      } catch (e) {
        _log('⚠️ Supabase: $e');
      }

      try {
        await LocalNotificationService.instance
            .initialize()
            .timeout(_kInitTimeout);
        _log('✓ LocalNotif OK');
      } catch (e) {
        _log('⚠️ LocalNotif: $e');
      }

      //  CRÉÉ AVANT runApp (c'est ça qui fixe l'UnimplementedError)
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

      runApp(
        ProviderScope(
          // INJECTION : le provider reçoit la vraie instance
          overrides: [
            localeControllerProvider.overrideWithValue(_localeController),
          ],
          child: const ThixApp(),
        ),
      );
      _log('✓ runApp called');
    },
    (error, stack) {
      _log('❌ Uncaught: $error');
      runApp(MaterialApp(
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

class _ThixAppState extends ConsumerState<ThixApp> {
  late final AuthController _auth;
  late final LocaleController _locale;

  GoRouter? _router;
  bool _ready = false;
  bool _pushRegistered = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthController.instance;
    //  LIT l'instance INJECTÉE (plus de `LocaleController()..init()` ici)
    _locale = ref.read(localeControllerProvider);
    _init();
  }

  Future<void> _init() async {
    // Router (les controllers sont déjà initialisés dans main)
    try {
      _router = AppRouter.create(
        _auth,
        extraRefreshListenable: Listenable.merge([_auth, _locale]),
        navigatorKey: rootNavigatorKey,
      );
      _log('✓ Router OK');
    } catch (e) {
      _log('❌ Router: $e');
    }

    // Sync push ↔ auth
    _auth.addListener(_syncPush);
    _syncPush();

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  /// Enregistre / retire le token FCM selon l'état de connexion.
  Future<void> _syncPush() async {
    if (kIsWeb) return; //  push non géré sur Web

    final isAuthenticated = _auth.isAuthenticated;

    try {
      if (isAuthenticated && !_pushRegistered) {
        _pushRegistered = true;
        await PushNotificationService.instance.initialize();
        _log('✓ Push registered');
      } else if (!isAuthenticated && _pushRegistered) {
        _pushRegistered = false;
        await PushNotificationService.instance.unregisterToken();
        _log('✓ Push unregistered');
      }
    } catch (e) {
      _log('⚠️ Push: $e');
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncPush);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThixPolicy.lightTheme(),
        darkTheme: ThixPolicy.darkTheme(),
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return app_provider.MultiProvider(
      //  COMPAT : les 3 listeners globaux legacy utilisent package:provider
      providers: [
        app_provider.ChangeNotifierProvider<AuthController>.value(
          value: _auth,
        ),
        app_provider.ChangeNotifierProvider<LocaleController>.value(
          value: _locale,
        ),
        app_provider.Provider<ProfileService>(
          create: (_) => ProfileService(),
        ),
      ],
      child: MaterialApp.router(
        title: 'THIX ID CENTRAL',
        debugShowCheckedModeBanner: false,
        theme: ThixPolicy.lightTheme(),
        darkTheme: ThixPolicy.darkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: _router!,
        locale: _locale.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => GlobalNotificationListener(
          child: GlobalSosListener(
            child: GlobalCallListener(
              navigatorKey: rootNavigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
