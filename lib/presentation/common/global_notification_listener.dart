// lib/presentation/common/global_notification_listener.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/services/notification_service.dart';

/// Écoute en continu les notifications de l'utilisateur connecté, peu
/// importe l'écran affiché, pour déclencher le pop local dès qu'une
/// notification non lue arrive (la logique de pop vit déjà dans
/// NotificationService.streamForUser → _maybeShowPop ; ce widget sert
/// uniquement à garder ce stream actif en permanence, plutôt que
/// seulement quand NotificationsSheet est ouvert).
class GlobalNotificationListener extends StatefulWidget {
  final Widget child;
  const GlobalNotificationListener({super.key, required this.child});

  @override
  State<GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends State<GlobalNotificationListener> {
  final NotificationService _notifications = NotificationService();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _listeningForUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.id;

    if (uid != _listeningForUid) {
      _sub?.cancel();
      _sub = null;
      _listeningForUid = uid;

      if (uid != null) {
        _sub = _notifications.streamForUser(uid).listen((_) {
          // Rien à faire ici : le pop est déjà déclenché à l'intérieur
          // de streamForUser (_maybeShowPop). Ce listener existe pour
          // garder le stream vivant en permanence.
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
