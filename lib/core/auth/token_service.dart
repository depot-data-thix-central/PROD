// lib/core/auth/token_service.dart
// Fournit le token d'accès (JWT Supabase) utilisé pour authentifier
// les appels aux Edge Functions (Bearer token).

import 'package:supabase_flutter/supabase_flutter.dart';

class TokenService {
  TokenService._();

  /// Retourne un access_token valide, en le rafraîchissant si besoin.
  static Future<String> getToken() async {
    final client = Supabase.instance.client;
    var session = client.auth.currentSession;

    if (session == null) {
      throw Exception('Utilisateur non connecté : aucune session active.');
    }

    // Si le token est expiré (ou proche de l'être), on le rafraîchit
    final expiresAt = session.expiresAt;
    final isExpiredOrExpiringSoon = expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= (expiresAt - 30);

    if (isExpiredOrExpiringSoon) {
      final response = await client.auth.refreshSession();
      session = response.session;
      if (session == null) {
        throw Exception('Impossible de rafraîchir la session utilisateur.');
      }
    }

    return session.accessToken;
  }

  /// ID de l'utilisateur actuellement connecté, ou null.
  static String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// true si un utilisateur est connecté avec une session valide.
  static bool get isAuthenticated => Supabase.instance.client.auth.currentSession != null;
}
