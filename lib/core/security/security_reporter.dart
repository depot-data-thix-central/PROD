import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🛡️ THIX Security Reporter — embarqué dans l'APPLICATION mobile
/// Remonte vers Supabase : échecs de login, crashs, abus, activités suspectes.
/// Aucune donnée sensible envoyée : uniquement des événements de sécurité.
class SecurityReporter {
  SecurityReporter._();

  static const String kSource = 'mobile_app';
  static const String kTable = 'security_events';

  static DateTime? _lastClientError;
  static bool _sending = false;

  /// 🔑 Échec de connexion (tentative d'accès forcé)
  static void reportLoginFailure({
    required String identifier,
    required String reason,
  }) {
    _send(
      eventType: 'login_failed',
      severity: 'medium',
      identifier: identifier,
      message: 'Échec de connexion : $reason',
    );
  }

  /// 🚫 Compte bloqué / suspendu qui tente de se connecter
  static void reportLoginBlocked({
    required String identifier,
    required String reason,
  }) {
    _send(
      eventType: 'login_blocked',
      severity: 'high',
      identifier: identifier,
      message: 'Connexion bloquée : $reason',
    );
  }

  /// 🐛 Crash / erreur applicative (throttlé : max 1 / 10 s)
  static void reportClientError({
    required String source,
    required String message,
  }) {
    final now = DateTime.now();
    if (_lastClientError != null &&
        now.difference(_lastClientError!).inSeconds < 10) {
      return;
    }
    _lastClientError = now;
    _send(
      eventType: 'client_error',
      severity: 'medium',
      identifier: source,
      message: message.length > 480 ? message.substring(0, 480) : message,
    );
  }

  /// ⚡ Abus / limite de débit (spam, requêtes massives)
  static void reportRateLimit({
    required String identifier,
    String? message,
  }) {
    _send(
      eventType: 'rate_limit',
      severity: 'high',
      identifier: identifier,
      message: message ?? 'Limite de débit dépassée',
    );
  }

  /// 🕵️ Activité suspecte (accès refusé à une ressource, token invalide…)
  static void reportSuspicious({
    required String identifier,
    required String message,
    String severity = 'high',
  }) {
    _send(
      eventType: 'suspicious',
      severity: severity,
      identifier: identifier,
      message: message,
    );
  }

  /// 📤 Envoi fire-and-forget (jamais bloquant, jamais crashant)
  static Future<void> _send({
    required String eventType,
    required String severity,
    required String identifier,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    if (_sending) return;
    _sending = true;
    try {
      await Supabase.instance.client.from(kTable).insert({
        'event_type': eventType,
        'severity': severity,
        'source': kSource,
        'identifier':
            identifier.length > 200 ? identifier.substring(0, 200) : identifier,
        'message': message,
        'metadata': {
          ...?metadata,
          'app': 'thix_mobile',
          'platform': defaultTargetPlatform.name,
        },
      });
    } catch (e) {
      // Silencieux : la sécurité ne doit jamais casser l'app
      if (kDebugMode) debugPrint('⚠️ [SecurityReporter] envoi ignoré : $e');
    } finally {
      _sending = false;
    }
  }
}
