/// Service de rate-limit SOS (30 min entre 2 déclenchements)
/// ✅ Double couche : cache local (UX instantanée) + vérif serveur (vraie sécu)
/// ✅ Résilient : fonctionne offline avec le cache local
/// ✅ Anti-manipulation : l'heure serveur Supabase fait foi
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosRateLimitService {
  SosRateLimitService._();
  static final SosRateLimitService instance = SosRateLimitService._();

  static const String _kPrefKey = 'thix_last_sos_timestamp_v1';
  static const Duration _kCooldown = Duration(minutes: 30);

  // ─────────────────────────────────────────────────────────────
  // CACHE LOCAL (UX instantanée)
  // ─────────────────────────────────────────────────────────────

  /// Récupère le timestamp du dernier SOS depuis le cache local.
  /// Null = jamais déclenché sur cet appareil.
  Future<DateTime?> getLastSosTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_kPrefKey);
      return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (e) {
      debugPrint('[SosRateLimit] ⚠️ Cache read failed: $e');
      return null;
    }
  }

  /// Temps restant avant de pouvoir relancer un SOS (basé sur cache local).
  /// Retourne `Duration.zero` si aucun cooldown actif.
  Future<Duration> remainingCooldown() async {
    final last = await getLastSosTime();
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= _kCooldown) return Duration.zero;
    return _kCooldown - elapsed;
  }

  /// Enregistre immédiatement le timestamp du SOS déclenché dans le cache.
  /// À appeler UNIQUEMENT après validation backend réussie.
  Future<void> recordLocalTrigger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[SosRateLimit] ✓ Local trigger recorded');
    } catch (e) {
      debugPrint('[SosRateLimit] ❌ Cache write failed: $e');
    }
  }

  /// Efface le cooldown local (utilisé en dev/debug, jamais en prod).
  @visibleForTesting
  Future<void> clearCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
  }

  // ─────────────────────────────────────────────────────────────
  // VÉRIFICATION BACKEND (vraie sécurité — heure serveur fait foi)
  // ─────────────────────────────────────────────────────────────

  /// Valide côté serveur que l'utilisateur peut déclencher un SOS.
  /// Retourne un `RateLimitResult` :
  ///   - `allowed: true`  → le backend autorise, on peut déclencher
  ///   - `allowed: false` → le backend refuse, `retryAt` indique quand réessayer
  ///   - `serverError`    → pas de réseau / erreur serveur → fallback sur le cache local
  Future<RateLimitResult> checkWithBackend() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Non-auth → on applique juste le cache local (pas de backend possible)
      final remaining = await remainingCooldown();
      return RateLimitResult(
        allowed: remaining == Duration.zero,
        retryAt: remaining == Duration.zero
            ? null
            : DateTime.now().add(remaining),
        source: RateLimitSource.localOnly,
      );
    }

    try {
      // Appel RPC Supabase : vérifie la colonne `last_sos_at` + heure serveur
      final response = await Supabase.instance.client.rpc(
        'check_sos_rate_limit',
        params: {'user_id': user.id},
      ).timeout(const Duration(seconds: 8));

      if (response is Map && response['allowed'] == true) {
        debugPrint('[SosRateLimit] ✓ Backend allowed');
        return RateLimitResult(
          allowed: true,
          source: RateLimitSource.backend,
        );
      }

      final retryAtStr = response is Map ? response['retry_at'] : null;
      final retryAt = retryAtStr != null
          ? DateTime.tryParse(retryAtStr.toString())
          : null;

      debugPrint('[SosRateLimit] ❌ Backend refused: retry at $retryAt');
      return RateLimitResult(
        allowed: false,
        retryAt: retryAt,
        source: RateLimitSource.backend,
      );
    } catch (e) {
      // Erreur réseau ou serveur → FALLBACK sur le cache local
      // (on ne bloque pas l'utilisateur en cas d'indispo Supabase)
      debugPrint('[SosRateLimit] ⚠️ Backend check failed: $e → fallback local');
      final remaining = await remainingCooldown();
      return RateLimitResult(
        allowed: remaining == Duration.zero,
        retryAt: remaining == Duration.zero
            ? null
            : DateTime.now().add(remaining),
        source: RateLimitSource.localFallback,
      );
    }
  }

  /// Après un SOS validé par le backend, on met à jour la colonne serveur.
  /// Si ça échoue, on log mais on ne bloque pas — le cache local prend le relais.
  Future<void> recordBackendTrigger() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'last_sos_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id)
          .timeout(const Duration(seconds: 5));
      debugPrint('[SosRateLimit] ✓ Backend trigger recorded');
    } catch (e) {
      debugPrint('[SosRateLimit] ⚠️ Backend record failed (non-critical): $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────
// RESULT
// ─────────────────────────────────────────────────────────────

enum RateLimitSource { backend, localOnly, localFallback }

class RateLimitResult {
  final bool allowed;
  final DateTime? retryAt;
  final RateLimitSource source;

  const RateLimitResult({
    required this.allowed,
    this.retryAt,
    required this.source,
  });

  Duration get remaining => retryAt == null
      ? Duration.zero
      : retryAt!.difference(DateTime.now()).clamp(Duration.zero, const Duration(days: 1));

  String formattedRemaining() {
    final r = remaining;
    if (r == Duration.zero) return '';
    final m = r.inMinutes;
    final s = r.inSeconds % 60;
    return '${m}m ${s}s';
  }
}
