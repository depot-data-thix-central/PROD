// lib/presentation/chat/providers/presence_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fournit un Set<String> contenant les IDs (UUIDs) de tous les utilisateurs actuellement en ligne
final presenceProvider = StateNotifierProvider<PresenceNotifier, Set<String>>((ref) {
  return PresenceNotifier();
});

class PresenceNotifier extends StateNotifier<Set<String>> {
  late final RealtimeChannel _channel;
  final _supabase = Supabase.instance.client;

  PresenceNotifier() : super({}) {
    _initPresence();
  }

  void _initPresence() {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    // 1. On rejoint un salon virtuel global pour le chat
    _channel = _supabase.channel('thix-global-presence');

    // 2. On écoute les entrées/sorties en temps réel
    _channel.onPresenceSync((_) {
      final newState = <String>{};
      
      // La nouvelle API Supabase renvoie une List<SinglePresenceState>
      final List<dynamic> presences = _channel.presenceState();
      
      for (final dynamic stateItem in presences) {
        try {
          // stateItem contient une liste nommée 'presences'
          final List<dynamic> innerPresences = stateItem.presences;
          
          for (final dynamic presence in innerPresences) {
            // On extrait le JSON (payload) configuré dans track()
            final payload = presence.payload;
            if (payload != null && payload['user_id'] != null) {
              newState.add(payload['user_id'].toString());
            }
          }
        } catch (e) {
          // Try-catch de sécurité pour prévenir tout futur crash de structure
        }
      }
      
      // Met à jour l'interface Flutter automatiquement
      state = newState;
    }).subscribe((status, [error]) async {
      // 3. Dès qu'on est connecté au websocket, on s'annonce aux autres
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel.track({'user_id': myUserId});
      }
    });
  }

  @override
  void dispose() {
    // On se déconnecte proprement quand l'utilisateur quitte l'app
    _channel.unsubscribe();
    super.dispose();
  }
}
