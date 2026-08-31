// lib/presentation/chat/providers/chat_providers.dart
//
// ============================================================================
// ⚠️ SOURCE UNIQUE — NE PAS REDÉFINIR CES PROVIDERS AILLEURS
// ============================================================================
//
// Tous les services de chat sont centralisés ici. Les widgets et autres
// providers doivent TOUJOURS utiliser ces providers via ref.watch/ref.read.
//
// Architecture :
//   supabaseClientProvider (injectable)
//       ↓
//   ┌─────────────┬────────────────┬──────────────┬──────────────┐
//   ↓             ↓                ↓              ↓              ↓
// ChatService  PresenceService  AudioService  GroupService  StatusService
//   (WebSocket) (Realtime)      (Record)      (DB+RPC)      (DB)
//
// Tous les services sont `keepAlive` (Provider standard) car ils maintiennent
// des connexions stateful (WebSocket, Realtime, audio recorder).
//
// Pour les tests : utiliser `overrides:` dans ProviderScope
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
///
/// Permet l'injection de mocks dans les tests :
/// ```dart
/// ProviderScope(
///   overrides: [
///     supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// ⚠️ Doit être utilisé par TOUS les services qui dépendent de Supabase,
/// au lieu d'accéder directement à `Supabase.instance.client`.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  debugPrint('[supabaseClientProvider] 🚀 Resolved');
  return Supabase.instance.client;
});

// ============================================================================
// CHAT SERVICES (stateful, keepAlive)
// ============================================================================

/// Service de chat principal (WebSocket, messages, conversations).
///
/// **Cycle de vie** : Créé au premier `ref.watch`, persiste jusqu'au
/// `ProviderScope.dispose()` (jamais auto-détruit).
///
/// **Usage** :
/// ```dart
/// final chatService = ref.read(chatServiceProvider);
/// final messages = await chatService.getMessages(conversationId);
/// ```
final chatServiceProvider = Provider<ChatService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[chatServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[chatServiceProvider] 👋 Disposed');
  });
  return ChatService(client);
}, name: 'chatServiceProvider', dependencies: [supabaseClientProvider]);

/// Service de présence (Realtime presence, online/offline).
///
/// **Cycle de vie** : Persistant (maintient un canal Realtime actif).
///
/// **Usage** :
/// ```dart
/// final presence = ref.read(presenceServiceProvider);
/// await presence.trackMyPresence();
/// ```
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[presenceServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[presenceServiceProvider] 👋 Disposed');
  });
  return PresenceService(client);
}, name: 'presenceServiceProvider', dependencies: [supabaseClientProvider]);

/// Service audio (enregistrement, lecture, upload).
///
/// **Cycle de vie** : Persistant (maintient des ressources natives audio).
///
/// **Usage** :
/// ```dart
/// final audio = ref.read(audioServiceProvider);
/// final url = await audio.recordAndUpload();
/// ```
final audioServiceProvider = Provider<AudioService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[audioServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[audioServiceProvider] 👋 Disposed');
  });
  return AudioService(client);
}, name: 'audioServiceProvider', dependencies: [supabaseClientProvider]);

/// Service de groupes (CRUD, membres, permissions).
///
/// **Cycle de vie** : Persistant.
///
/// **Usage** :
/// ```dart
/// final groups = ref.read(groupServiceProvider);
/// final info = await groups.getGroupInfo(groupId);
/// ```
final groupServiceProvider = Provider<GroupService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[groupServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[groupServiceProvider] 👋 Disposed');
  });
  return GroupService(client);
}, name: 'groupServiceProvider', dependencies: [supabaseClientProvider]);

/// Service de statuts/stories (création, vues, expiration).
///
/// **Cycle de vie** : Persistant.
///
/// **Usage** :
/// ```dart
/// final status = ref.read(statusServiceProvider);
/// final items = await status.getVisibleStatuses();
/// ```
final statusServiceProvider = Provider<StatusService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  debugPrint('[statusServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[statusServiceProvider] 👋 Disposed');
  });
  return StatusService(client);
}, name: 'statusServiceProvider', dependencies: [supabaseClientProvider]);

// ============================================================================
// CONNECTION SERVICE (stateless, utility)
// ============================================================================

/// Service de vérification de connexion réseau.
///
/// Contrairement aux autres services, celui-ci n'utilise pas Supabase
/// directement. Il vérifie la connectivité réseau (internet reachability).
///
/// **Cycle de vie** : Persistant (singleton-like).
///
/// **Usage** :
/// ```dart
/// final connection = ref.read(connectionServiceProvider);
/// final isOnline = await connection.isConnected();
/// ```
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  debugPrint('[connectionServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[connectionServiceProvider] 👋 Disposed');
  });
  return ConnectionService();
}, name: 'connectionServiceProvider');

// ============================================================================
// CONVENIENCE PROVIDERS (accès rapide)
// ============================================================================

/// Provider booléen : vrai si l'utilisateur est connecté au réseau.
///
/// Se base sur [connectionServiceProvider] avec rafraîchissement périodique.
///
/// **Usage** :
/// ```dart
/// final isOnline = ref.watch(isNetworkOnlineProvider);
/// if (!isOnline) showOfflineBanner();
/// ```
final isNetworkOnlineProvider = FutureProvider<bool>((ref) async {
  final connection = ref.watch(connectionServiceProvider);
  try {
    return await connection.isConnected();
  } catch (e) {
    debugPrint('[isNetworkOnlineProvider] ❌ Error: $e');
    return false;
  }
});

/// Provider pour l'ID de l'utilisateur courant connecté à Supabase.
///
/// Utile pour les services qui ont besoin de l'user ID sans passer par
/// le AuthController (ex: services de chat bas niveau).
///
/// ⚠️ Préférez `currentUserProvider` du auth_controller pour l'UI.
final supabaseUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser?.id;
});

// ============================================================================
// HELPERS POUR TESTS
// ============================================================================

/// Extensions pour faciliter l'override des providers dans les tests.
///
/// Exemple d'utilisation :
/// ```dart
/// testWidgets('chat page displays messages', (tester) async {
///   final mockChat = MockChatService();
///   when(mockChat.getMessages(any)).thenAnswer((_) async => mockMessages);
///
///   await tester.pumpWidget(
///     ProviderScope(
///       overrides: [
///         chatServiceProvider.overrideWithValue(mockChat),
///         supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
///       ],
///       child: const ChatPage(),
///     ),
///   );
/// });
/// ```
extension ChatProvidersTestOverrides on ProviderBase {
  /// Alias pour `overrideWithValue` spécifique aux providers de chat.
  Override chatOverride<T>(T value) => overrideWithValue(value);
}
