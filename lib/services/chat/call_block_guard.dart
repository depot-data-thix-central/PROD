///services/chat/call_block_guard.dart

// lib/services/chat/call_block_guard.dart
// ============================================================================
// CALL BLOCK GUARD — état « appels désactivés » partagé par TOUS les écrans
// ----------------------------------------------------------------------------
//  Réutilise exactement la logique de chat_screen : CallBlockService.fetch()
//  (table chat_call_blocks, blocage par conversation directe).
//  • statusOf(peerId)        → statut en cache (synchrone, pour l'UI)
//  • check(peerId)           → vérification FRAÎCHE côté serveur
//  • refreshPeers(peerIds)   → rafraîchit une liste de contacts (par lots)
//  • revision                → ValueNotifier : notifie les écrans à chaque changement
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/services/chat/call_block_service.dart';
import 'package:thix_id/services/chat/chat_service.dart';

@immutable
class CallBlockStatus {
  /// Id de l'utilisateur qui a désactivé les appels (null = appels actifs).
  final String? blockedBy;

  /// true si c'est l'utilisateur courant qui a désactivé les appels.
  final bool byMe;

  const CallBlockStatus({this.blockedBy, this.byMe = false});

  bool get blocked => blockedBy != null && blockedBy!.isNotEmpty;

  static const CallBlockStatus none = CallBlockStatus();
}

class CallBlockGuard {
  CallBlockGuard._();
  static final CallBlockGuard instance = CallBlockGuard._();

  static const int _concurrency = 4;

  final CallBlockService _svc = CallBlockService();
  final Map<String, String> _convByPeer = <String, String>{};
  final Map<String, String?> _blockedBy = <String, String?>{};
  final Map<String, Future<String?>> _convInflight = <String, Future<String?>>{};

  /// Incrémenté à chaque changement de statut : les pages s'y abonnent.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String get _me => Supabase.instance.client.auth.currentUser?.id ?? '';

  /// Mémorise une conversation déjà connue (évite un aller-retour réseau).
  void remember(String peerId, String conversationId) {
    if (peerId.isEmpty || conversationId.isEmpty) return;
    _convByPeer[peerId] = conversationId;
  }

  /// Statut en cache (synchrone).
  CallBlockStatus statusOf(String peerId) {
    final by = _blockedBy[peerId];
    if (by == null || by.isEmpty) return CallBlockStatus.none;
    return CallBlockStatus(blockedBy: by, byMe: by == _me);
  }

  Future<String?> _conversationId(String peerId) async {
    final cached = _convByPeer[peerId];
    if (cached != null) return cached;

    final running = _convInflight[peerId];
    if (running != null) return running;

    final future = () async {
      try {
        final conv = await ChatService(Supabase.instance.client)
            .createDirectConversation(peerId)
            .timeout(const Duration(seconds: 12));
        if (conv.id.isEmpty) return null;
        _convByPeer[peerId] = conv.id;
        return conv.id;
      } catch (e) {
        debugPrint('[CallBlockGuard] ⚠️ conversation introuvable pour $peerId: $e');
        return null;
      }
    }();

    _convInflight[peerId] = future;
    try {
      return await future;
    } finally {
      _convInflight.remove(peerId);
    }
  }

  void _set(String peerId, String? by) {
    final clean = (by == null || by.isEmpty) ? null : by;
    if (_blockedBy[peerId] == clean && _blockedBy.containsKey(peerId)) return;
    _blockedBy[peerId] = clean;
    revision.value++;
  }

  /// Vérification FRAÎCHE côté serveur pour un contact.
  Future<CallBlockStatus> check(String peerId, {Duration timeout = const Duration(seconds: 8)}) async {
    if (peerId.isEmpty) return CallBlockStatus.none;
    final convId = await _conversationId(peerId);
    if (convId == null) return statusOf(peerId);
    try {
      final by = await _svc.fetch(convId).timeout(timeout);
      _set(peerId, by);
    } catch (e) {
      debugPrint('[CallBlockGuard] ⚠️ fetch($peerId): $e');
    }
    return statusOf(peerId);
  }

  /// Rafraîchit plusieurs contacts (par lots pour ne pas saturer le réseau).
  Future<void> refreshPeers(Iterable<String> peerIds) async {
    final ids = peerIds.where((e) => e.isNotEmpty).toSet().toList();
    for (var i = 0; i < ids.length; i += _concurrency) {
      final chunk = ids.skip(i).take(_concurrency).toList();
      await Future.wait(chunk.map((id) => check(id)));
    }
  }
}
