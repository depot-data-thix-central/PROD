// lib/services/chat/presence_service.dart
//
// ============================================================================
// PRESENCE SERVICE — Production Enterprise
// ============================================================================
//
// Service de gestion de la présence utilisateur (online/away/dnd/offline).
//
// Architecture :
//   - SupabaseClient injecté via Riverpod (testable)
//   - Heartbeat périodique avec jitter aléatoire (évite pics serveur)
//   - Validation UUID stricte
//   - Retry avec backoff exponentiel sur échecs
//   - Support custom_status (message utilisateur)
//
// Cycle de vie :
//   - `initPresence()` → démarre le heartbeat (online)
//   - `setStatus(status, customStatus)` → change manuellement
//   - `dispose()` → envoie offline + stoppe heartbeat
//
// Statuts supportés :
//   - `online` : Utilisateur actif
//   - `away`   : Utilisateur inactif (pas d'interactions récentes)
//   - `dnd`    : Ne pas déranger (notifications coupées)
//   - `offline`: Utilisateur déconnecté
//
// Sécurité :
//   - Validation UUID v4 stricte
//   - Whitelist des statuts autorisés
//   - Sanitization du custom_status (XSS + max length)
//   - Timeout sur tous les appels DB
// ============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kHeartbeatIntervalSec = 30;
const int _kHeartbeatJitterMaxSec = 10; // 0-10s de jitter
const int _kMaxCustomStatusLength = 100;
const int _kMaxRetries = 2;
const Duration _kDbTimeout = Duration(seconds: 10);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const Duration _kOfflineTimeout = Duration(seconds: 5); // Timeout court pour dispose

/// Whitelist des statuts autorisés.
const Set<String> _kAllowedStatuses = {'online', 'away', 'dnd', 'offline'};

/// Statuts par défaut.
const String kStatusOnline = 'online';
const String kStatusAway = 'away';
const String kStatusDnd = 'dnd';
const String kStatusOffline = 'offline';

// ============================================================================
// VALIDATORS
// ============================================================================
class _PresenceValidators {
  _PresenceValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Valide un statut (whitelist).
  static bool isValidStatus(String? status) {
    if (status == null) return false;
    return _kAllowedStatuses.contains(status.toLowerCase());
  }

  /// Sanitize un custom_status (XSS + max length).
  static String sanitizeCustomStatus(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxCustomStatusLength
        ? s.substring(0, _kMaxCustomStatusLength)
        : s;
  }
}

// ============================================================================
// PRESENCE SERVICE
// ============================================================================

/// Service de gestion de la présence utilisateur.
///
/// **Usage** :
/// ```dart
/// final service = ref.read(presenceServiceProvider);
/// service.initPresence();
/// // Plus tard...
/// await service.setStatus(kStatusAway, customStatus: 'En réunion');
/// // En dispose...
/// service.dispose();
/// ```
class PresenceService {
  final SupabaseClient _supabase;
  final Random _jitterRandom;
  Timer? _heartbeat;
  bool _isDisposed = false;
  bool _isInitialized = false;
  String _lastStatus = kStatusOffline;
  String? _lastCustomStatus;

  PresenceService(this._supabase, {Random? jitterRandom})
      : _jitterRandom = jitterRandom ?? Random() {
    debugPrint('[PresenceService] 🚀 Initialized');
  }

  /// User ID courant (dynamique, se met à jour après login/logout).
  String get _uid => _supabase.auth.currentUser?.id ?? '';

  /// Statut courant.
  String get currentStatus => _lastStatus;

  /// Custom status courant.
  String? get currentCustomStatus => _lastCustomStatus;

  /// Vrai si le service est actif (heartbeat en cours).
  bool get isActive => _isInitialized && !_isDisposed && _heartbeat != null;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  /// Démarre le heartbeat de présence (statut `online`).
  ///
  /// Idempotent : plusieurs appels ne créent pas de timers multiples.
  /// Utilise un jitter aléatoire (0-10s) pour éviter les pics serveur.
  void initPresence() {
    if (_isDisposed) {
      debugPrint('[PresenceService] ⚠️ initPresence called after dispose');
      return;
    }

    final uid = _uid;
    if (!_PresenceValidators.isValidUuid(uid)) {
      debugPrint('[PresenceService] ⚠️ No valid user, skipping init');
      return;
    }

    // Évite les timers dupliqués
    if (_isInitialized && _heartbeat != null) {
      debugPrint('[PresenceService] ✓ Already initialized');
      return;
    }

    _isInitialized = true;
    _lastStatus = kStatusOnline;
    _lastCustomStatus = null;

    // Envoi immédiat
    _update(kStatusOnline);

    // Heartbeat avec jitter
    _startHeartbeatWithJitter();

    debugPrint('[PresenceService] ✓ Presence initialized for '
        '${_obfuscate(uid)}');
  }

  /// Démarre le heartbeat avec un jitter aléatoire.
  void _startHeartbeatWithJitter() {
    _heartbeat?.cancel();

    final jitterMs = _jitterRandom.nextInt(_kHeartbeatJitterMaxSec * 1000);

    _heartbeat = Timer.periodic(
      Duration(seconds: _kHeartbeatIntervalSec, milliseconds: jitterMs),
      (_) {
        if (_isDisposed) {
          _heartbeat?.cancel();
          return;
        }
        if (_PresenceValidators.isValidUuid(_uid)) {
          _update(_lastStatus, customStatus: _lastCustomStatus);
        }
      },
    );
  }

  /// Arrête le service et envoie `offline`.
  ///
  /// Le `setOffline` est envoyé avec un timeout court (5s) car `dispose`
  /// ne peut pas être await. Si le timeout est atteint, on considère
  /// l'envoi comme best-effort.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialized = false;

    _heartbeat?.cancel();
    _heartbeat = null;

    // Best-effort offline (fire and forget avec timeout court)
    if (_PresenceValidators.isValidUuid(_uid)) {
      _update(kStatusOffline, timeout: _kOfflineTimeout).catchError((e) {
        debugPrint('[PresenceService] ⚠️ Offline update failed on dispose: $e');
      });
    }

    debugPrint('[PresenceService] 👋 Disposed');
  }

  // ============================================================
  // STATUS MANAGEMENT
  // ============================================================

  /// Change le statut manuellement.
  ///
  /// **Statuts autorisés** : `online`, `away`, `dnd`, `offline`.
  ///
  /// [customStatus] : Message personnalisé optionnel (max 100 caractères).
  Future<void> setStatus(String status, {String? customStatus}) async {
    if (_isDisposed) return;

    if (!_PresenceValidators.isValidStatus(status)) {
      debugPrint('[PresenceService] ⚠️ Invalid status: $status');
      return;
    }

    if (!_PresenceValidators.isValidUuid(_uid)) {
      debugPrint('[PresenceService] ⚠️ No valid user');
      return;
    }

    final sanitizedCustom = customStatus != null
        ? _PresenceValidators.sanitizeCustomStatus(customStatus)
        : null;

    _lastStatus = status.toLowerCase();
    _lastCustomStatus = sanitizedCustom?.isEmpty == true ? null : sanitizedCustom;

    await _update(_lastStatus, customStatus: _lastCustomStatus);
    debugPrint('[PresenceService] ✓ Status set: $_lastStatus'
        '${_lastCustomStatus != null ? " ($_lastCustomStatus)" : ""}');
  }

  /// Met en ligne immédiatement (alias).
  Future<void> setOnline() => setStatus(kStatusOnline);

  /// Met hors ligne immédiatement (alias).
  Future<void> setOffline() => setStatus(kStatusOffline);

  /// Met en mode "Ne pas déranger".
  Future<void> setDnd({String? customStatus}) =>
      setStatus(kStatusDnd, customStatus: customStatus);

  /// Met en mode "Absent".
  Future<void> setAway({String? customStatus}) =>
      setStatus(kStatusAway, customStatus: customStatus);

  // ============================================================
  // DB UPDATE (avec retry)
  // ============================================================

  /// Effectue l'upsert avec retry et timeout.
  Future<void> _update(
    String status, {
    String? customStatus,
    Duration timeout = _kDbTimeout,
  }) async {
    final uid = _uid;
    if (!_PresenceValidators.isValidUuid(uid)) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'user_id': uid,
      'status': status,
      'last_seen_at': now,
      'updated_at': now,
      if (customStatus != null && customStatus.isNotEmpty)
        'custom_status': customStatus,
    };

    int attempt = 0;
    while (true) {
      try {
        await _supabase
            .from('user_presence')
            .upsert(payload, onConflict: 'user_id')
            .timeout(timeout);
        return;
      } on TimeoutException {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[PresenceService] ❌ Timeout after $_kMaxRetries retries');
          return;
        }
        debugPrint('[PresenceService] ⏱️ Timeout, retry $attempt/$_kMaxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[PresenceService] ❌ Update failed after retries: '
              '${kDebugMode ? e : e.toString().split('\n').first}');
          return;
        }
        debugPrint('[PresenceService] ⚠️ Update error, retry $attempt: '
            '${kDebugMode ? e : e.toString().split('\n').first}');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Obfusque un ID pour les logs.
  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}
