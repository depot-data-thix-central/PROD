import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as app_provider; // ✅ coexistence temporaire
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

const Duration _kInitTimeout = Duration(seconds: 10);

void _log(String m) => debugPrint('[MAIN] $m');

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ✅ ERREURS UI VISIBLES (rouge à l'écran) au lieu d'écran gris/loader infini
      ErrorWidget.builder = (details) => Material(
        color: const Color(0xFF0A2F5C),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              '❌ ERREUR UI :\n\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.5),
            ),
          ),
        ),
      );

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _log('❌ FlutterError: ${details.exception}');
      };

      // ✅ WEB : pas de FCM sur Web → skip (évite hang/crash)
      if (!kIsWeb) {
        try {
          await Firebase.initializeApp().timeout(_kInitTimeout);
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          _log('✓ Firebase OK');
        } catch (e) {
          _log('⚠️ Firebase: $e');
        }
      }

      try {
        await SupabaseConfig.initialize().timeout(_kInitTimeout);
        _log('✓ Supabase OK');
      } catch (e) {
        _log('⚠️ Supabase: $e');
      }

      try {
        await LocalNotificationService.instance.initialize().timeout(_kInitTimeout);
        _log('✓ LocalNotif OK');
      } catch (e) {
        _log('⚠️ LocalNotif: $e');
      }

      runApp(const ProviderScope(child: ThixApp()));
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
    _locale = LocaleController();
    _init();
  }

  Future<void> _init() async {
    // ✅ Timeouts partout : plus jamais de hang silencieux
    try {
      await Future.wait([
        _auth.init().timeout(_kInitTimeout),
        _locale.init().timeout(_kInitTimeout),
      ]).timeout(const Duration(seconds: 20));
      _log('✓ Controllers OK');
    } catch (e) {
      _log('⚠️ Controllers dégradés: $e');
    }

    if (!mounted) return;

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

    _auth.addListener(_syncPush);
    _syncPush();

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _syncPush() async {
    if (kIsWeb) return; // ✅ push non géré sur Web
    final authed = _auth.isAuthenticated;
    try {
      if (authed && !_pushRegistered) {
        _pushRegistered = true;
        await PushNotificationService.instance.initialize();
      } else if (!authed && _pushRegistered) {
        _pushRegistered = false;
        await PushNotificationService.instance.unregisterToken();
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
        theme: ThixPolicy.lightTheme(),
        darkTheme: ThixPolicy.darkTheme(),
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return app_provider.MultiProvider(
      // ✅ COMPAT : les 3 listeners globaux (anciens) trouvent leurs providers
      providers: [
        app_provider.ChangeNotifierProvider<AuthController>.value(value: _auth),
        app_provider.ChangeNotifierProvider<LocaleController>.value(value: _locale),
        app_provider.Provider<ProfileService>(create: (_) => ProfileService()),
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
