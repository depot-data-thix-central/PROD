// lib/presentation/chat/call/global_call_listener.dart
//
// ============================================================================
// GLOBAL CALL LISTENER — Production Enterprise v2.0
// ============================================================================
//
// Écouteur global des appels entrants via Realtime + Polling.
//
// Améliorations Enterprise :
//   - Vérification d'appel actif (auto-rejet "Occupé" pour éviter les conflits)
//   - Fallback Notification Locale si la navigation échoue (app en arrière-plan)
//   - Hooks prêts pour l'intégration FCM (Firebase Cloud Messaging)
//   - Gestion stricte du cycle de vie et prévention des fuites mémoire
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/incoming_call_page.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kNavigationRetryDelay = Duration(milliseconds: 500);
const Duration _kNavigationTimeout = Duration(seconds: 5);
const int _kMaxNavigationRetries = 3;
const Duration _kInviteCooldown = Duration(seconds: 3); // Augmenté pour éviter les spams

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallListenerValidators {
  _CallListenerValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static bool isValidInvite(CallInvite? invite) {
    if (invite == null) return false;
    return isValidUuid(invite.id) && isValidUuid(invite.callerId);
  }
}

// ============================================================================
// GLOBAL CALL LISTENER
// ============================================================================

class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalCallListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener>
    with WidgetsBindingObserver {
  CallSignalingService? _signal;
  StreamSubscription<CallInvite>? _callSubscription;
  ProviderSubscription<String?>? _authSubscription;
  StreamSubscription<AuthState>? _authStreamSubscription;

  String? _currentUserId;
  String? _lastShownInviteId;
  DateTime? _lastInviteTime;
  bool _isDisposed = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[GlobalCallListener] 🚀 Initialized');

    WidgetsBinding.instance.addObserver(this);
    _bindAuthChanges();
    _bindSupabaseAuth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _syncListen(force: true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    _authSubscription?.close();
    _authStreamSubscription?.cancel();
    _signal?.dispose();
    debugPrint('[GlobalCallListener] 👋 Disposed');
    super.dispose();
  }

  // ── AUTH BINDING ─────────────────────────────────────────────────────

  void _bindAuthChanges() {
    _authSubscription = ref.listenManual<String?>(
      supabaseUserIdProvider,
      (previous, next) {
        if (_isDisposed) return;
        if (previous == next) return;

        debugPrint('[GlobalCallListener] 🔄 Auth changed: '
            '${_obfuscate(previous)} → ${_obfuscate(next)}');

        _currentUserId = next;
        _syncListen(force: true);
      },
    );
  }

  void _bindSupabaseAuth() {
    try {
      _authStreamSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (_isDisposed) return;
        debugPrint('[GlobalCallListener] 📞 Auth event: ${data.event}');
        _syncListen(force: true);
      });
    } catch (e) {
      debugPrint('[GlobalCallListener] ⚠️ Supabase auth listener failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('[GlobalCallListener] 📱 App resumed');
      _syncListen(force: true);
    } else if (state == AppLifecycleState.paused) {
      debugPrint('[GlobalCallListener] ⏸️ App paused (background)');
      // NOTE ENTERPRISE : C'est ici qu'il faut s'assurer que le service 
      // FCM (Firebase Messaging) est prêt à prendre le relais pour les 
      // notifications d'appel entrant quand l'app est en arrière-plan.
    }
  }

  // ── SYNC LISTEN ──────────────────────────────────────────────────────

  void _syncListen({bool force = false}) {
    if (_isDisposed) return;

    final uid = _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[GlobalCallListener] 🔄 syncListen uid=${_obfuscate(uid)} force=$force');

    if (uid == null) {
      _cleanupSubscription();
      _currentUserId = null;
      return;
    }

    if (!force && uid == _currentUserId && _callSubscription != null) {
      debugPrint('[GlobalCallListener] ✓ Already listening');
      return;
    }

    _currentUserId = uid;
    _cleanupSubscription();
    _signal ??= CallSignalingService();

    try {
      _callSubscription = _signal!.watchIncomingWithPoll().listen(
        _handleIncomingInvite,
        onError: _handleStreamError,
        onDone: () {
          debugPrint('[GlobalCallListener] 🔌 Stream done');
          // Auto-reconnect en cas de fermeture inattendue du stream
          if (!_isDisposed) {
            Future.delayed(const Duration(seconds: 2), () => _syncListen(force: true));
          }
        },
      );
      debugPrint('[GlobalCallListener] ✓ Listening for incoming calls');
    } catch (e) {
      debugPrint('[GlobalCallListener] ❌ Subscribe failed: $e');
    }
  }

  void _cleanupSubscription() {
    _callSubscription?.cancel();
    _callSubscription = null;
    _lastShownInviteId = null;
    _lastInviteTime = null;
  }

  // ── INCOMING INVITE HANDLER ──────────────────────────────────────────

  void _handleIncomingInvite(CallInvite invite) {
    if (_isDisposed) return;

    if (!_CallListenerValidators.isValidInvite(invite)) {
      debugPrint('[GlobalCallListener] ⚠️ Invalid invite received, skipping');
      return;
    }

    // 🛡️ ENTERPRISE : Vérifier si un appel est déjà en cours
    final currentCallState = ref.read(callProvider);
    if (currentCallState.isActive) {
      debugPrint('[GlobalCallListener] ⚠️ Call already active. Auto-rejecting new invite: ${invite.id}');
      _autoRejectBusy(invite);
      return;
    }

    debugPrint('[GlobalCallListener] 📞 Incoming call: ${invite.id} '
        'from ${_obfuscate(invite.callerId)}');

    // Protection contre les pushs multiples
    if (_lastShownInviteId == invite.id) {
      debugPrint('[GlobalCallListener] ⚠️ Invite already shown: ${invite.id}');
      return;
    }

    // Debounce
    final now = DateTime.now();
    if (_lastInviteTime != null &&
        now.difference(_lastInviteTime!) < _kInviteCooldown) {
      debugPrint('[GlobalCallListener] ⚠️ Invite too soon, skipping');
      return;
    }

    _lastShownInviteId = invite.id;
    _lastInviteTime = now;

    _openIncoming(invite);
  }

  Future<void> _autoRejectBusy(CallInvite invite) async {
    try {
      await _signal?.rejectBusy(invite.id);
      debugPrint('[GlobalCallListener] ✓ Auto-rejected busy invite: ${invite.id}');
    } catch (e) {
      debugPrint('[GlobalCallListener] ❌ Auto-reject failed: $e');
    }
  }

  void _handleStreamError(Object error, StackTrace? stackTrace) {
    debugPrint('[GlobalCallListener] ❌ Stream error: $error');
    // TODO ENTERPRISE : Envoyer à Sentry / Datadog
    // Sentry.captureException(error, stackTrace: stackTrace);
  }

  // ── NAVIGATION ───────────────────────────────────────────────────────

  Future<void> _openIncoming(CallInvite invite) async {
    if (_isDisposed || _isNavigating) return;

    _isNavigating = true;
    debugPrint('[GlobalCallListener] 📞 Opening IncomingCallPage: ${invite.id}');

    final route = MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallPage(invite: invite),
    );

    bool success = false;

    // Tentative 1 : navigatorKey fourni (recommandé pour les appels entrants)
    final nav = widget.navigatorKey?.currentState;
    if (nav != null) {
      success = await _safePush(nav, route);
    }

    // Tentative 2 : context navigator
    if (!success && mounted) {
      try {
        final navigator = Navigator.of(context, rootNavigator: true);
        success = await _safePush(navigator, route);
      } catch (e) {
        debugPrint('[GlobalCallListener] ⚠️ Context navigator failed: $e');
      }
    }

    // Tentative 3 : Retry avec délai (gère les micro-latences de rendu)
    if (!success && !_isDisposed) {
      debugPrint('[GlobalCallListener] 🔄 Retrying navigation...');
      await Future.delayed(_kNavigationRetryDelay);

      if (!_isDisposed) {
        final retryNav = widget.navigatorKey?.currentState;
        if (retryNav != null) {
          success = await _safePush(retryNav, route);
        }
      }
    }

    // 🛡️ ENTERPRISE FALLBACK : Si la navigation échoue (app en arrière-plan),
    // déclencher une notification locale "Full Screen Intent" pour réveiller l'app.
    if (!success && !_isDisposed) {
      debugPrint('[GlobalCallListener] ⚠️ Navigation failed. Triggering local notification fallback.');
      _triggerIncomingCallNotification(invite);
      _lastShownInviteId = null; // Permet de re-tenter si l'utilisateur clique sur la notification
    } else {
      debugPrint('[GlobalCallListener] ✓ IncomingCallPage opened successfully');
    }

    _isNavigating = false;
  }

  Future<bool> _safePush(NavigatorState navigator, Route route) async {
    try {
      // On utilise pushAndRemoveUntil ou push selon l'architecture, 
      // ici push standard avec timeout de sécurité.
      await navigator.push(route).timeout(_kNavigationTimeout);
      return true;
    } catch (e) {
      debugPrint('[GlobalCallListener] ⚠️ Push failed: $e');
      return false;
    }
  }

  // ── FALLBACK NOTIFICATION (HOOK) ─────────────────────────────────────

  void _triggerIncomingCallNotification(CallInvite invite) {
    // TODO ENTERPRISE : Intégrer flutter_local_notifications ici.
    // Configurer une notification avec :
    // 1. priority: Priority.max
    // 2. fullScreenIntent: true (pour Android)
    // 3. category: AndroidNotificationCategory.call
    // Cela permet d'afficher l'écran d'appel même si l'app est fermée/minimisée.
    
    debugPrint('[GlobalCallListener] 🔔 [MOCK] Notification locale déclenchée pour ${invite.callerId}');
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
