// lib/main.dart
//
// THIX ID CENTRAL — Point d'entrée (Production Enterprise v2.8)
//
// v2.8 : ✅ Actions de notification (Répondre, Marquer lu, Muet) branchées sur Supabase
// ============================================================================
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
import 'package:thix_id/services/notifications/app_badge_sync_service.dart';
import 'package:thix_id/presentation/notifications/widgets/notif_banner_listener.dart';
import 'package:thix_id/presentation/chat/call/callkit_call_handler.dart';
import 'package:thix_id/presentation/chat/call/global_call_listener.dart';
import 'package:thix_id/presentation/thix_sos/widgets/global_sos_listener.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thix_id/data/offline/chat_offline_cache.dart';
import 'package:thix_id/core/security/security_reporter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
// Action IDs
const String kActionOpen = 'OPEN';
const String kActionReply = 'REPLY';
const String kActionMarkAsRead = 'MARK_AS_READ';
const String kActionMute = 'MUTE';
const Duration _kInitTimeout = Duration(seconds: 10);

void _log(String message) => debugPrint('[MAIN] $message');

late final LocaleController _localeController;
bool _appLaunched = false;

// ============================================================================
// NAVIGATION EN ATTENTE (cold start : le routeur n'existe pas encore)
// ============================================================================
bool _routerReady = false;

String? _pendingCallId;
({String payload, String? actionId})? _pendingTap;

void _openCall(String inviteId, String channelName, bool isVideo) {
  if (inviteId.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (!_routerReady || ctx == null || !ctx.mounted) {
    _pendingCallId = inviteId;
    _log('📞 Appel accepté mis en attente (routeur pas prêt)');
    return;
  }

  _pendingCallId = null;
  _log('📞 Appel accepté → ouverture de l\'appel');
  unawaited(CallKitCallHandler.accept(inviteId));
}

void _flushPendingNav() {
  if (!_routerReady) return;

  final callId = _pendingCallId;
  if (callId != null) {
    _openCall(callId, '', false);
  }

  final tap = _pendingTap;
  if (tap != null) {
    _pendingTap = null;
    _handleLocalNotificationTap(tap.payload, actionId: tap.actionId);
  }
}

// ============================================================================
// ACTIONS DE NOTIFICATION (Répondre, Lu, Muet)
// ============================================================================

Future<void> _handleNotificationAction(String? payload, String actionId, String? input) async {
  if (payload == null || !payload.startsWith('chat:')) return;

  final convId = payload.substring(5);
  if (convId.isEmpty) return;

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
      LocalNotificationService.instance.cancelAll();
    } 
    else if (actionId == kActionMarkAsRead) {
      _log('👁️ Marquer comme lu pour conv: $convId');
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', convId)
          .neq('sender_id', currentUserId);
      LocalNotificationService.instance.cancelAll();
    } 
    else if (actionId == kActionMute) {
      _log('🔇 Mute la conversation: $convId');
      await supabase
          .from('conversations')
          .update({'is_muted': true})
          .eq('id', convId);
      LocalNotificationService.instance.cancelAll();
    }
    
    // NOTE : Le badge est déjà mis à jour automatiquement par AppBadgeSyncService
    // (qui écoute Supabase en Realtime). Pas besoin d'appeler refreshBadge() ici.
    
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
        await Hive.initFlutter().timeout(_kInitTimeout);
        await ChatOfflineCache.init().timeout(_kInitTimeout);
        _log('✓ Offline cache OK');
      } catch (e) {
        _log('⚠️ Offline cache: $e');
      }

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

        // ✅ BRANCHEMENT DES ACTIONS ET DU TAP
        LocalNotificationService.instance.onNotificationTap =
            (payload, {actionId, input}) async {
          
          // 1. Gestion des actions spécifiques (Répondre, Lu, Muet)
          if (actionId == kActionReply || actionId == kActionMarkAsRead || actionId == kActionMute) {
             await _handleNotificationAction(payload, actionId!, input);
             return;
          }
          
          // 2. Ouverture classique (Clic sur la notification ou bouton "Ouvrir")
          _handleLocalNotificationTap(payload, actionId: actionId);
        };

        _log('✓ LocalNotif OK');
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
      Future.delayed(const Duration(milliseconds: 600), _flushPendingNav);
      Future.delayed(const Duration(milliseconds: 2500), _flushPendingNav);
    });
  }

  Future<void> _syncPush() async {
    if (kIsWeb) return;

    if (!_auth.isAuthenticated) {
      if (_pushRegistered) {
        _pushRegistered = false;
        AppBadgeSyncService.stopListening();
        unawaited(AppBadgeSyncService.sync(0));
        _log('ℹ️ Session absente : badge arrêté (token push conservé)');
      }
      return;
    }

    if (_pushRegistered) return;
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
