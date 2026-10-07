// lib/presentation/chat/call/global_call_listener.dart
//
// ============================================================================
// GLOBAL CALL LISTENER — v2.1
// ============================================================================
// Corrections :
//  ✅ Plus de `await push().timeout()` : ce Future ne se termine qu'à la
//     fermeture de la page, le timeout empilait la MÊME route une 2e fois
//     (pile de navigation corrompue → écran noir)
//  ✅ Une seule page d'appel entrant à la fois (pas de doublon à la reprise
//     de l'app ou à chaque événement d'authentification)
//  ✅ La page d'appel entrant se ferme si l'appelant annule / manque l'appel
//  ✅ Plus de délai de 3 s qui ignorait silencieusement un appel
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
const int _kMaxNavigationRetries = 3;

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
  StreamSubscription<CallStatus>? _inviteStatusSub;
  ProviderSubscription<String?>? _authSubscription;
  StreamSubscription<AuthState>? _authStreamSubscription;

  String? _currentUserId;
  String? _lastShownInviteId;
  MaterialPageRoute<void>? _incomingRoute;
  bool _isDisposed = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindAuthChanges();
    _bindSupabaseAuth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) _syncListen(force: true);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    _inviteStatusSub?.cancel();
    _authSubscription?.close();
    _authStreamSubscription?.cancel();
    _signal?.dispose();
    super.dispose();
  }

  // ── AUTH BINDING ─────────────────────────────────────────────────────
  void _bindAuthChanges() {
    _authSubscription = ref.listenManual<String?>(
      supabaseUserIdProvider,
      (previous, next) {
        if (_isDisposed || previous == next) return;
        debugPrint('[GlobalCallListener] 🔄 Auth changed: ${_obfuscate(previous)} → ${_obfuscate(next)}');
        _currentUserId = next;
        _lastShownInviteId = null; // autre utilisateur : on repart de zéro
        _syncListen(force: true);
      },
    );
  }

  void _bindSupabaseAuth() {
    try {
      _authStreamSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (_isDisposed) return;
        // Non forcé : un simple rafraîchissement de token ne doit PAS
        // relancer l'écoute (sinon un appel en cours de sonnerie réapparaît)
        _syncListen();
      });
    } catch (e) {
      debugPrint('[GlobalCallListener] ⚠️ Supabase auth listener failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      // Les connexions realtime peuvent être mortes après l'arrière-plan
      _syncListen(force: true);
    }
    // NOTE : en arrière-plan, c'est FCM + notification plein écran qui doit
    // prendre le relais (voir _triggerIncomingCallNotification).
  }

  // ── SYNC LISTEN ──────────────────────────────────────────────────────
  void _syncListen({bool force = false}) {
    if (_isDisposed) return;

    final uid = _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;

    if (uid == null) {
      _cleanupSubscription();
      _currentUserId = null;
      return;
    }

    if (!force && uid == _currentUserId && _callSubscription != null) return;

    _currentUserId = uid;
    _cleanupSubscription();
    _signal ??= CallSignalingService();

    try {
      _callSubscription = _signal!.watchIncomingWithPoll().listen(
        _handleIncomingInvite,
        onError: _handleStreamError,
        onDone: () {
          if (!_isDisposed) {
            Future.delayed(const Duration(seconds: 2), () => _syncListen(force: true));
          }
        },
      );
    } catch (e) {
      debugPrint('[GlobalCallListener] ❌ Subscribe failed: $e');
    }
  }

  void _cleanupSubscription() {
    _callSubscription?.cancel();
    _callSubscription = null;
    // _lastShownInviteId volontairement CONSERVÉ : une ré-écoute ne doit pas
    // réafficher une page d'appel déjà montrée.
  }

  // ── INCOMING INVITE HANDLER ──────────────────────────────────────────
  void _handleIncomingInvite(CallInvite invite) {
    if (_isDisposed) return;

    if (!_CallListenerValidators.isValidInvite(invite)) {
      debugPrint('[GlobalCallListener] ⚠️ Invalid invite received, skipping');
      return;
    }

    // Même invitation déjà traitée (realtime + poll, ou ré-écoute)
    if (_lastShownInviteId == invite.id) return;

    // Occupé : appel en cours OU page d'appel entrant déjà affichée
    final busy = ref.read(callProvider).isActive || (_incomingRoute?.isActive ?? false);
    if (busy) {
      _lastShownInviteId = invite.id; // évite de rejeter plusieurs fois
      _autoRejectBusy(invite);
      return;
    }

    _lastShownInviteId = invite.id;
    _openIncoming(invite);
  }

  Future<void> _autoRejectBusy(CallInvite invite) async {
    try {
      await _signal?.reject(invite.id);
      debugPrint('[GlobalCallListener] ✓ Auto-rejected busy invite: ${invite.id}');
    } catch (e) {
      debugPrint('[GlobalCallListener] ❌ Auto-reject failed: $e');
    }
  }

  void _handleStreamError(Object error, StackTrace? stackTrace) {
    debugPrint('[GlobalCallListener] ❌ Stream error: $error');
    // TODO ENTERPRISE : Sentry.captureException(error, stackTrace: stackTrace);
  }

  // ── NAVIGATION ───────────────────────────────────────────────────────
  Future<void> _openIncoming(CallInvite invite) async {
    if (_isDisposed || _isNavigating) return;
    _isNavigating = true;

    try {
      MaterialPageRoute<void>? route;

      for (var attempt = 0; attempt <= _kMaxNavigationRetries && route == null; attempt++) {
        if (_isDisposed) return;
        if (attempt > 0) await Future.delayed(_kNavigationRetryDelay);

        final nav = widget.navigatorKey?.currentState ??
            (mounted ? Navigator.maybeOf(context, rootNavigator: true) : null);
        if (nav == null || !nav.mounted) continue;

        route = _pushIncoming(nav, invite);
      }

      if (route == null) {
        debugPrint('[GlobalCallListener] ⚠️ Navigation failed. Local notification fallback.');
        _triggerIncomingCallNotification(invite);
        _lastShownInviteId = null; // permet de retenter plus tard
        return;
      }

      _incomingRoute = route;
      _watchInviteEnd(invite, route);

      route.popped.whenComplete(() {
        if (identical(_incomingRoute, route)) _incomingRoute = null;
        _inviteStatusSub?.cancel();
        _inviteStatusSub = null;
      });
    } finally {
      _isNavigating = false;
    }
  }

  /// Pousse la page SANS attendre : le Future de push() ne se termine qu'à la
  /// fermeture de la page. Chaque tentative crée une NOUVELLE route.
  MaterialPageRoute<void>? _pushIncoming(NavigatorState nav, CallInvite invite) {
    try {
      final route = MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: 'incoming_call'),
        builder: (_) => IncomingCallPage(invite: invite),
      );
      unawaited(nav.push(route));
      return route;
    } catch (e) {
      debugPrint('[GlobalCallListener] ⚠️ Push failed: $e');
      return null;
    }
  }

  /// Ferme la page d'appel entrant si l'appelant annule ou si l'appel est manqué.
  void _watchInviteEnd(CallInvite invite, MaterialPageRoute<void> route) {
    _inviteStatusSub?.cancel();
    _inviteStatusSub = _signal?.watchInviteStatus(invite.id).listen((s) {
      if (_isDisposed) return;
      final over = s == CallStatus.canceled || s == CallStatus.missed || s == CallStatus.ended;
      if (over && route.isActive) {
        debugPrint('[GlobalCallListener] 🔚 Caller ended the invite → closing incoming page');
        route.navigator?.removeRoute(route);
      }
    });
  }

  // ── FALLBACK NOTIFICATION (HOOK) ─────────────────────────────────────
  void _triggerIncomingCallNotification(CallInvite invite) {
    // TODO ENTERPRISE : flutter_local_notifications avec
    // priority max, fullScreenIntent: true, category call.
    debugPrint('[GlobalCallListener] 🔔 [MOCK] Notification locale pour ${_obfuscate(invite.callerId)}');
  }

  // ── HELPERS ──────────────────────────────────────────────────────────
  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
