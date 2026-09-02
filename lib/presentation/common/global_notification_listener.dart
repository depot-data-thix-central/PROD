/// Global Notification Listener (Production Enterprise)
/// ✅ SÉCURISÉ : Riverpod, mounted checks, error handling
/// ✅ ROBUSTE : Throttling, logs structurés, cancelOnError
/// ✅ OBSERVABLE : Logs [GlobalNotif] avec emojis
///
/// Écoute en continu les notifications de l'utilisateur connecté,
/// peu importe l'écran affiché, pour garder le stream actif en permanence.
///
/// **Architecture** :
/// - Utilise Riverpod ConsumerStatefulWidget (cohérent avec le reste de l'app)
/// - Le pop local est déclenché par NotificationService._maybeShowPop
/// - Ce widget sert uniquement à garder le stream vivant
///
/// **Cycle de vie** :
/// - Active le stream quand l'utilisateur se connecte
/// - Désactive le stream quand l'utilisateur se déconnecte
/// - Reconnecte automatiquement si le stream échoue
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/services/notification_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kThrottleDelay = Duration(milliseconds: 500);
const Duration _kReconnectDelay = Duration(seconds: 5);

// ============================================================================
// GLOBAL NOTIFICATION LISTENER
// ============================================================================

/// Widget wrapper qui écoute les notifications en permanence.
///
/// Usage :
/// ```dart
/// MaterialApp(
///   home: GlobalNotificationListener(
///     child: MyApp(),
///   ),
/// )
/// ```
class GlobalNotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  
  const GlobalNotificationListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalNotificationListener> createState() =>
      _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState
    extends ConsumerState<GlobalNotificationListener> {
  final NotificationService _notifications = NotificationService();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _listeningForUid;
  DateTime? _lastEvent;
  Timer? _reconnectTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndSubscribe();
  }

  /// Vérifie l'état d'auth et (re)abonne au stream si nécessaire
  void _checkAndSubscribe() {
    final auth = ref.watch(authControllerProvider);
    final uid = auth.maybeWhen(
      data: (user) => user?.id,
      orElse: () => null,
    );

    if (uid != _listeningForUid) {
      _unsubscribe();
      _listeningForUid = uid;

      if (uid != null) {
        _subscribe(uid);
      } else {
        debugPrint('[GlobalNotif] ℹ️ No user, stream inactive');
      }
    }
  }

  /// Abonne au stream de notifications pour un UID donné
  void _subscribe(String uid) {
    debugPrint('[GlobalNotif] 🚀 Subscribing for $uid');

    _sub = _notifications.streamForUser(uid).listen(
      (notifications) {
        if (!mounted) {
          debugPrint('[GlobalNotif] ⚠️ Event received after dispose');
          return;
        }

        // Throttling pour éviter le spam
        final now = DateTime.now();
        if (_lastEvent != null &&
            now.difference(_lastEvent!) < _kThrottleDelay) {
          return;
        }
        _lastEvent = now;

        // Le pop est déjà déclenché par NotificationService._maybeShowPop
        // Ce listener existe pour garder le stream vivant en permanence
        debugPrint('[GlobalNotif] ✓ Stream alive (${notifications.length} notifs)');
      },
      onError: (error, stackTrace) {
        debugPrint('[GlobalNotif] ❌ Stream error: $error');
        
        if (!mounted) return;

        // Tentative de reconnexion après délai
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(_kReconnectDelay, () {
          if (mounted && _listeningForUid != null) {
            debugPrint('[GlobalNotif] 🔄 Reconnecting...');
            _subscribe(_listeningForUid!);
          }
        });
      },
      cancelOnError: false, // On veut garder le stream actif même en erreur
    );
  }

  /// Désabonne du stream actuel
  void _unsubscribe() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_sub != null) {
      debugPrint('[GlobalNotif] 🛑 Unsubscribing from $_listeningForUid');
      _sub!.cancel();
      _sub = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
