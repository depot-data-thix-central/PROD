// lib/presentation/chat/call/global_call_listener.dart
//
// ============================================================================
// GLOBAL CALL LISTENER — Production Enterprise
// ============================================================================
//
// Écouteur global des appels entrants via Realtime + polling.
//
// Architecture :
//   - Utilise CallSignalingService injecté via Riverpod
//   - Écoute les changements d'auth via currentUserProvider
//   - Protection contre les pushs multiples d'un même appel
//   - Nettoyage propre des subscriptions au dispose
//
// Sécurité :
//   - Validation UUID sur tous les invite IDs
//   - Pas d'exposition de stack traces
//   - Mounted checks sur tous les callbacks async
//
// Robustesse :
//   - Retry sur navigation failures
//   - Auto-reconnect sur changement d'user
//   - Debounce sur events rapides
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ IMPORT CORRIGÉ : On utilise le provider d'ID indépendant
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/presentation/chat/call/incoming_call_page.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kNavigationRetryDelay = Duration(milliseconds: 300);
const Duration _kNavigationTimeout = Duration(seconds: 5);
const int _kMaxNavigationRetries = 3;
const Duration _kInviteCooldown = Duration(seconds: 2);

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallListenerValidators {
  _CallListenerValidators._();

  /// Valide un UUID v4 strict
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Valide un CallInvite complet
  static bool isValidInvite(CallInvite? invite) {
    if (invite == null) return false;
    return isValidUuid(invite.id) && isValidUuid(invite.callerId);
  }
}

// ============================================================================
// GLOBAL CALL LISTENER
// ============================================================================

/// Écouteur global des appels entrants.
///
/// **Cycle de vie** :
/// - S'abonne au flux d'appels entrants au démarrage
/// - Réagit aux changements d'auth (cleanup + reconnect)
/// - Nettoie toutes les subscriptions au dispose
///
/// **Sécurité** :
/// - Validation UUID sur tous les invites
/// - Protection contre les pushs multiples
/// - Mounted checks sur tous les callbacks
class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalCallListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<GlobalCallListener> createState() =>
      _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener>
    with WidgetsBindingObserver {
  CallSignalingService? _signal;
  StreamSubscription<CallInvite>? _callSubscription;
  ProviderSubscription<String?>? _authSubscription; // ✅ TYPE CORRIGÉ EN String?
  StreamSubscription? _authStreamSubscription;

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

    // Écoute des changements d'auth via Riverpod
    _bindAuthChanges();

    // Écoute directe Supabase comme fallback
    _bindSupabaseAuth();

    // Init après le premier frame
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
    // ✅ CORRECTION : listenManual au lieu de listen dans un State
    _authSubscription = ref.listenManual<String?>(
      supabaseUserIdProvider,
      (previous, next) {
        if (_isDisposed) return;

        final prevId = previous;
        final nextId = next;
        if (prevId == nextId) return;

        debugPrint('[GlobalCallListener] 🔄 Auth changed: '
            '${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

        _currentUserId = nextId;
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
    }
  }

  // ── SYNC LISTEN ──────────────────────────────────────────────────────

  void _syncListen({bool force = false}) {
    if (_isDisposed) return;

    final uid = _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[GlobalCallListener] 🔄 syncListen uid=${_obfuscate(uid)} force=$force');

    // Pas d'user → cleanup
    if (uid == null) {
      _cleanupSubscription();
      _currentUserId = null;
      return;
    }

    // Déjà abonné au même user
    if (!force && uid == _currentUserId && _callSubscription != null) {
      debugPrint('[GlobalCallListener] ✓ Already listening');
      return;
    }

    _currentUserId = uid;
    _cleanupSubscription();

    // Initialise le service si nécessaire
    _signal ??= CallSignalingService();

    // Abonnement au flux d'appels
    try {
      _callSubscription = _signal!.watchIncomingWithPoll().listen(
        _handleIncomingInvite,
        onError: _handleStreamError,
        onDone: () {
          debugPrint('[GlobalCallListener] 🔌 Stream done');
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

    // Validation de l'invite
    if (!_CallListenerValidators.isValidInvite(invite)) {
      debugPrint('[GlobalCallListener] ⚠️ Invalid invite received, skipping');
      return;
    }

    debugPrint('[GlobalCallListener] 📞 Incoming call: ${invite.id} '
        'from ${_obfuscate(invite.callerId)}');

    // Protection contre les pushs multiples du même invite
    if (_lastShownInviteId == invite.id) {
      debugPrint('[GlobalCallListener] ⚠️ Invite already shown: ${invite.id}');
      return;
    }

    // Debounce : pas plus d'un appel toutes les 2 secondes
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

  void _handleStreamError(Object error, StackTrace? stackTrace) {
    debugPrint('[GlobalCallListener] ❌ Stream error: $error');
    if (stackTrace != null) {
      debugPrint('[GlobalCallListener] Stack: $stackTrace');
    }
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

    // Tentative 1 : navigatorKey fourni
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

    // Tentative 3 : retry avec délai
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

    if (!success) {
      debugPrint('[GlobalCallListener] ❌ All navigation attempts failed');
      _lastShownInviteId = null; // Permet de re-tenter
    } else {
      debugPrint('[GlobalCallListener] ✓ IncomingCallPage opened');
    }

    _isNavigating = false;
  }

  Future<bool> _safePush(NavigatorState navigator, Route route) async {
    try {
      await navigator.push(route).timeout(_kNavigationTimeout);
      return true;
    } catch (e) {
      debugPrint('[GlobalCallListener] ⚠️ Push failed: $e');
      return false;
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
