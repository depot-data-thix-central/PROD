// lib/presentation/chat/call/callkit_call_handler.dart
//
// Gère un appel DÉCROCHÉ depuis CallKit (écran verrouillé / notification) ou
// une notification d'appel touchée.
//
// v2 (réseau faible) :
//   ✅ accept() LÈVE une exception si le contexte / la session / le réseau
//      ne sont pas prêts → le retry de main.dart fonctionne
//   ✅ verrou par appel (plus de _busy global bloquant)
//   ✅ session : attente jusqu'à 10 s, refreshSession seulement si absente
//   ✅ erreur réseau ≠ « appel terminé » (CallKit n'est plus fermé à tort)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/chat/call/call_ui_state.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/services/chat/call_handled_registry.dart';
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class CallKitCallHandler {
  CallKitCallHandler._();

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _sessionWait = Duration(seconds: 10);

  static final Set<String> _inProgress = <String>{};

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isUuid(String? id) => id != null && _uuid.hasMatch(id);

  /// Identifiant de l'utilisateur connecté.
  /// La session locale se restaure souvent seule : on attend d'abord,
  /// puis on tente un refresh uniquement si elle reste absente.
  static Future<String?> _myId() async {
    var id = SupabaseConfig.currentUser?.id;
    if (id != null) return id;

    final deadline = DateTime.now().add(_sessionWait);
    while (id == null && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
      id = SupabaseConfig.currentUser?.id;
    }
    if (id != null) return id;

    try {
      await SupabaseConfig.auth.refreshSession().timeout(_timeout);
    } catch (e) {
      debugPrint('[CallKitHandler] ⚠️ refreshSession: $e');
    }
    return SupabaseConfig.currentUser?.id;
  }

  /// Lit l'invitation.
  /// - null  : l'appel n'existe vraiment pas
  /// - throw : erreur réseau (l'appelant doit réessayer)
  static Future<CallInvite?> _fetchInvite(String inviteId) async {
    final row = await SupabaseConfig.client
        .from(AppRoutes.tableCallInvites)
        .select()
        .eq('id', inviteId)
        .maybeSingle()
        .timeout(_timeout);
    if (row == null) return null;
    return CallInvite.fromJson(Map<String, dynamic>.from(row));
  }

  /// Appel décroché depuis CallKit.
  /// Lève une exception si l'appel n'a pas pu être pris en charge
  /// (contexte non prêt, pas de session, erreur réseau) : l'appelant réessaie.
  static Future<void> accept(String inviteId) async {
    if (!_isUuid(inviteId)) {
      debugPrint('[CallKitHandler] ⚠️ inviteId invalide');
      return;
    }
    if (!_inProgress.add(inviteId)) {
      debugPrint('[CallKitHandler] ℹ️ accept déjà en cours: $inviteId');
      return;
    }

    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) {
        throw StateError('navigator not ready');
      }

      final container = ProviderScope.containerOf(ctx);
      final current = container.read(callProvider);

      // Déjà en cours sur cette invitation : on rouvre simplement l'écran
      if (current.isActive && current.inviteId == inviteId) {
        _openCallPage();
        return;
      }

      final myId = await _myId();
      if (myId == null) {
        debugPrint('[CallKitHandler] ❌ Aucune session');
        throw StateError('no session');
      }

      final invite = await _fetchInvite(inviteId); // peut lever (réseau)
      if (invite == null || invite.status.isFinished) {
        debugPrint('[CallKitHandler] ℹ️ Appel déjà terminé ou introuvable');
        CallHandledRegistry.markEnded(inviteId);
        await PushNotificationService.instance.endAllVoipCalls();
        return;
      }

      await container.read(callProvider.notifier).acceptIncoming(
            invite: invite,
            myUserId: myId,
          );

      _openCallPage();
    } finally {
      _inProgress.remove(inviteId);
    }
  }

  /// Notification d'appel touchée : affiche la page d'appel entrant si l'appel
  /// sonne encore.
  static Future<void> showIncoming(String inviteId) async {
    if (!_isUuid(inviteId)) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    CallInvite? invite;
    try {
      invite = await _fetchInvite(inviteId);
    } catch (e) {
      debugPrint('[CallKitHandler] ⚠️ showIncoming fetch: $e');
      return;
    }
    if (invite == null || invite.status != CallStatus.ringing) return;

    final c = rootNavigatorKey.currentContext;
    if (c == null || !c.mounted) return;
    c.push(AppRoutes.callIncoming, extra: invite);
  }

  static void _openCallPage() {
    // La page d'appel est déjà ouverte : rien à faire
    if (callPageOpenCount.value > 0) return;
    final c = rootNavigatorKey.currentContext;
    if (c == null || !c.mounted) return;
    c.push(AppRoutes.callOngoing);
  }
}
