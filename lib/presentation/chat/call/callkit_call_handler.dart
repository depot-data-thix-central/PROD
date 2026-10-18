// lib/presentation/chat/call/callkit_call_handler.dart
//
// Gère un appel DÉCROCHÉ depuis CallKit (écran verrouillé / notification) ou
// une notification d'appel touchée.
//
// Avant : main.dart poussait '/call/<id>' → cette route n'existe pas
// (« Route non trouvée »). Ici on :
//   1. relit l'invitation dans call_invites
//   2. appelle callProvider.acceptIncoming() (RPC accept + connexion Agora)
//   3. ouvre l'écran d'appel (AppRoutes.callOngoing)
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
  static bool _busy = false;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isUuid(String? id) => id != null && _uuid.hasMatch(id);

  /// Identifiant de l'utilisateur connecté (tente un renouvellement si la
  /// session n'est pas encore restaurée).
  static Future<String?> _myId() async {
    final id = SupabaseConfig.currentUser?.id;
    if (id != null) return id;
    try {
      await SupabaseConfig.auth.refreshSession().timeout(_timeout);
    } catch (e) {
      debugPrint('[CallKitHandler] ⚠️ refreshSession: $e');
    }
    return SupabaseConfig.currentUser?.id;
  }

  static Future<CallInvite?> _fetchInvite(String inviteId) async {
    try {
      final row = await SupabaseConfig.client
          .from(AppRoutes.tableCallInvites)
          .select()
          .eq('id', inviteId)
          .maybeSingle()
          .timeout(_timeout);
      if (row == null) return null;
      return CallInvite.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[CallKitHandler] ❌ fetch invite: $e');
      return null;
    }
  }

  /// Appel décroché depuis CallKit.
  static Future<void> accept(String inviteId) async {
    if (!_isUuid(inviteId)) {
      debugPrint('[CallKitHandler] ⚠️ inviteId invalide');
      return;
    }
    if (_busy) return;
    _busy = true;

    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final container = ProviderScope.containerOf(ctx);
      final current = container.read(callProvider);

      // Déjà en cours sur cette invitation : on rouvre simplement l'écran d'appel
      if (current.isActive && current.inviteId == inviteId) {
        _openCallPage();
        return;
      }

      final myId = await _myId();
      if (myId == null) {
        debugPrint('[CallKitHandler] ❌ Aucune session : retour à la connexion');
        final c = rootNavigatorKey.currentContext;
        if (c != null && c.mounted) c.go(AppRoutes.login);
        return;
      }

      final invite = await _fetchInvite(inviteId);
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
    } catch (e) {
      debugPrint('[CallKitHandler] ❌ accept: $e');
    } finally {
      _busy = false;
    }
  }

  /// Notification d'appel touchée : affiche la page d'appel entrant si l'appel
  /// sonne encore.
  static Future<void> showIncoming(String inviteId) async {
    if (!_isUuid(inviteId)) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final invite = await _fetchInvite(inviteId);
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
