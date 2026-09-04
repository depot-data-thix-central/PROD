// lib/features/network/data/network_service_provider.dart
//
// Network Service Providers — Production Enterprise
//
// Providers Riverpod pour le service réseau THIX.
// Expose SupabaseClient et NetworkService via l'injection de dépendances.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/services/network_service.dart';

/// Provider global pour le client Supabase.
///
/// Singleton partagé par toute l'application.
/// Initialisé une seule fois au démarrage.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'supabaseClient',
);

/// Provider global pour le service réseau.
///
/// Utilise le SupabaseClient pour toutes les opérations réseau
/// (feed, posts, likes, follows, stories, etc.).
final networkServiceProvider = Provider<NetworkService>(
  (ref) {
    final client = ref.read(supabaseClientProvider);
    return NetworkService(client);
  },
  name: 'networkService',
);
