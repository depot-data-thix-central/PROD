// lib/presentation/chat/providers/chat_providers.dart
//
// ============================================================================
// ⚠️ SOURCE UNIQUE — NE PAS REDÉFINIR CES PROVIDERS AILLEURS
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/services/chat/audio_service.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';
import 'package:thix_id/services/chat/group_service.dart';
import 'package:thix_id/services/chat/presence_service.dart';
import 'package:thix_id/services/chat/status_service.dart';

// ============================================================================
// SUPABASE CLIENT PROVIDER (injectable)
// ============================================================================

/// Provider racine pour le client Supabase.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  debugPrint('[supabaseClientProvider] 🚀 Resolved');
  return Supabase.instance.client;
});

// ============================================================================
// CHAT SERVICES (stateful, keepAlive)
// ============================================================================

/// Service de chat principal (WebSocket, messages, conversations).
final chatServiceProvider = Provider<ChatService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[chatServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[chatServiceProvider] 👋 Disposed');
  });
  return ChatService(client);
}, name: 'chatServiceProvider');

/// Service de présence (Realtime presence, online/offline).
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[presenceServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[presenceServiceProvider] 👋 Disposed');
  });
  return PresenceService(client);
}, name: 'presenceServiceProvider');

/// Service audio (enregistrement, lecture, upload).
final audioServiceProvider = Provider<AudioService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[audioServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[audioServiceProvider] 👋 Disposed');
  });
  return AudioService(client);
}, name: 'audioServiceProvider');

/// Service de groupes (CRUD, membres, permissions).
final groupServiceProvider = Provider<GroupService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[groupServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[groupServiceProvider] 👋 Disposed');
  });
  return GroupService(client);
}, name: 'groupServiceProvider');

/// Service de statuts/stories (création, vues, expiration).
final statusServiceProvider = Provider<StatusService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[statusServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[statusServiceProvider] 👋 Disposed');
  });
  return StatusService(client);
}, name: 'statusServiceProvider');

/// Service de connexion réseau.
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  debugPrint('[connectionServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[connectionServiceProvider] 👋 Disposed');
  });
  return ConnectionService();
}, name: 'connectionServiceProvider');

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider booléen : vrai si réseau disponible.
final isNetworkOnlineProvider = FutureProvider<bool>((ref) async {
  try {
    // Utilise Supabase comme probe de connectivité
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;
    // Simple test : si on peut lire l'auth, on est connecté
    return user != null || await _pingNetwork();
  } catch (e) {
    debugPrint('[isNetworkOnlineProvider] ❌ Error: $e');
    return false;
  }
});

/// Ping réseau simple via une requête HTTP légère
Future<bool> _pingNetwork() async {
  try {
    final uri = Uri.parse('https://www.google.com/generate_204');
    final client = await HttpClient().getUrl(uri).timeout(
      const Duration(seconds: 3),
    );
    final response = await client.close();
    return response.statusCode == 204;
  } catch (_) {
    return true; // Assume connecté si le test échoue
  }
}

/// Provider pour l'ID de l'utilisateur courant Supabase.
final supabaseUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser?.id;
});
