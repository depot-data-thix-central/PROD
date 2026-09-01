// lib/services/chat/call_token_service.dart
//
// ============================================================================
// CALL TOKEN SERVICE — Production Enterprise
// ============================================================================
//
// Service de récupération de tokens Agora via Edge Function Supabase.
//
// Architecture :
//   - SupabaseClient injectable (testable via mocks)
//   - Validation stricte des inputs (channel, uid)
//   - Timeout + retry sur appels Edge Function
//   - Sanitization des réponses serveur
//
// Sécurité :
//   - Validation regex sur channel (alphanum + _ -)
//   - Validation uid (entier positif)
//   - Sanitization token (trim + max length)
//   - Stack traces masquées en production (kDebugMode)
//   - Pas d'exposition de données sensibles dans logs
//
// Robustesse :
//   - Timeout 20s sur Edge Function
//   - Retry automatique (2 tentatives, 500ms délai)
//   - _isDisposed guard sur toutes les méthodes
//   - Exception custom pour erreurs spécifiques
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMinAppIdLength = 10;
const int _kMaxChannelLength = 100;
const int _kMaxTokenLength = 2048;
const Duration _kEdgeFunctionTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;
const String _kEdgeFunctionName = 'agora-token';

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallTokenValidators {
  _CallTokenValidators._();

  /// Valide un channel name Agora (alphanumérique + underscore + tiret).
  ///
  /// Règles :
  ///   - Non null, non vide après trim
  ///   - Longueur max [_kMaxChannelLength] (100 caractères)
  ///   - Caractères autorisés : `a-z`, `A-Z`, `0-9`, `_`, `-`
  static bool isValidChannel(String? channel) {
    if (channel == null) return false;
    final trimmed = channel.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  /// Valide un UID Agora (entier positif non-nul).
  ///
  /// Note : uid=0 est réservé par Agora pour auto-assignation,
  /// mais nous exigeons un uid explicite pour la traçabilité.
  static bool isValidUid(int uid) {
    return uid > 0 && uid <= 0x7FFFFFFF; // Max int32 positif
  }

  /// Valide un appId Agora (non vide, longueur min, alphanumérique).
  static bool isValidAppId(String? appId) {
    if (appId == null) return false;
    final trimmed = appId.trim();
    if (trimmed.length < _kMinAppIdLength) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
  }

  /// Sanitize un token (trim + max length).
  ///
  /// Les tokens Agora (JWT) peuvent être longs, on limite à 2KB pour
  /// éviter les abus.
  static String sanitizeToken(String? token) {
    if (token == null) return '';
    final trimmed = token.trim();
    return trimmed.length > _kMaxTokenLength
        ? trimmed.substring(0, _kMaxTokenLength)
        : trimmed;
  }

  /// Obfusque un channel pour les logs.
  static String obfuscateChannel(String? channel) {
    if (channel == null || channel.length <= 8) return '***';
    return '${channel.substring(0, 4)}...${channel.substring(channel.length - 4)}';
  }

  /// Obfusque un appId pour les logs.
  static String obfuscateAppId(String? appId) {
    if (appId == null || appId.length <= 6) return '***';
    return '${appId.substring(0, 6)}...';
  }
}

// ============================================================================
// CALL TOKEN RESULT
// ============================================================================

/// Résultat de la récupération d'un token Agora.
class CallTokenResult {
  /// Token RTC (JWT signé par Agora)
  final String token;

  /// App ID Agora (32 caractères)
  final String appId;

  /// Nom du canal Agora
  final String channel;

  /// UID numérique de l'utilisateur
  final int uid;

  const CallTokenResult({
    required this.token,
    required this.appId,
    required this.channel,
    required this.uid,
  });

  /// Vrai si le token est valide (non vide + appId valide).
  bool get isValid =>
      token.isNotEmpty && _CallTokenValidators.isValidAppId(appId);

  @override
  String toString() {
    return 'CallTokenResult('
        'channel=${_CallTokenValidators.obfuscateChannel(channel)}, '
        'appId=${_CallTokenValidators.obfuscateAppId(appId)}, '
        'uid=$uid, '
        'tokenLen=${token.length}'
        ')';
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception levée quand la récupération du token échoue.
class CallTokenException implements Exception {
  final String message;
  final Object? cause;

  const CallTokenException(this.message, [this.cause]);

  @override
  String toString() => 'CallTokenException: $message';
}

// ============================================================================
// CALL TOKEN SERVICE
// ============================================================================

/// Service de récupération de tokens Agora via Edge Function Supabase.
///
/// **Usage** :
/// ```dart
/// final service = CallTokenService(client: supabaseClient);
/// final result = await service.getToken(channel: 'live_123', uid: 456);
/// ```
///
/// **Via Riverpod** :
/// ```dart
/// final callTokenServiceProvider = Provider<CallTokenService>((ref) {
///   final client = ref.watch(supabaseClientProvider);
///   return CallTokenService(client: client);
/// });
/// ```
class CallTokenService {
  final SupabaseClient _client;
  bool _isDisposed = false;

  /// Crée une instance du service.
  ///
  /// [client] : SupabaseClient injecté (ou utilise `Supabase.instance.client` par défaut).
  CallTokenService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    debugPrint('[CallTokenService] 🚀 Initialized');
  }

  // ============================================================
  // GET TOKEN
  // ============================================================

  /// Récupère un token Agora pour rejoindre un canal.
  ///
  /// **Validation** :
  ///   - `channel` doit être alphanumérique + underscore + tiret (max 100 chars)
  ///   - `uid` doit être un entier positif (> 0)
  ///
  /// **Comportement** :
  ///   - Timeout : 20 secondes
  ///   - Retry : 2 tentatives avec délai de 500ms
  ///
  /// **Throws** :
  ///   - [ArgumentError] si les inputs sont invalides
  ///   - [CallTokenException] si la récupération échoue
  ///   - [TimeoutException] si l'Edge Function timeout
  ///   - [StateError] si le service est disposé
  Future<CallTokenResult> getToken({
    required String channel,
    required int uid,
  }) async {
    if (_isDisposed) {
      throw StateError('CallTokenService disposed');
    }

    // Validation inputs
    if (!_CallTokenValidators.isValidChannel(channel)) {
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallTokenValidators.isValidUid(uid)) {
      throw ArgumentError('Invalid uid (must be positive)');
    }

    debugPrint('[CallTokenService] 🎫 getToken '
        '(channel=${_CallTokenValidators.obfuscateChannel(channel)}, uid=$uid)');

    // Retry avec timeout
    int attempt = 0;
    Object? lastError;

    while (attempt <= _kMaxRetries) {
      try {
        final result = await _fetchToken(channel: channel, uid: uid);
        debugPrint('[CallTokenService] ✓ Token obtained: $result');
        return result;
      } on TimeoutException catch (e) {
        lastError = e;
        attempt++;
        if (attempt <= _kMaxRetries) {
          debugPrint('[CallTokenService] ⏱️ Timeout, '
              'retry $attempt/$_kMaxRetries');
          await Future.delayed(_kRetryDelay);
        }
      } on CallTokenException catch (e) {
        // Erreur métier : pas de retry
        debugPrint('[CallTokenService] ❌ Token error: $e');
        rethrow;
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt <= _kMaxRetries) {
          debugPrint('[CallTokenService] ⚠️ Error, '
              'retry $attempt/$_kMaxRetries: '
              '${kDebugMode ? e : e.toString().split('\n').first}');
          await Future.delayed(_kRetryDelay);
        }
      }
    }

    // Toutes les tentatives ont échoué
    final message = kDebugMode
        ? 'Token retrieval failed after $_kMaxRetries attempts: $lastError'
        : 'Token retrieval failed';
    throw CallTokenException(message, lastError);
  }

  /// Appel interne à l'Edge Function avec timeout.
  Future<CallTokenResult> _fetchToken({
    required String channel,
    required int uid,
  }) async {
    final res = await _client.functions
        .invoke(
          _kEdgeFunctionName,
          body: {
            'channelName': channel,
            'uid': uid,
          },
        )
        .timeout(_kEdgeFunctionTimeout);

    // Validation status HTTP
    if (res.status != 200) {
      final errorData = kDebugMode ? res.data : '[hidden]';
      throw CallTokenException(
        'Edge Function returned status ${res.status}',
        errorData,
      );
    }

    // Parsing réponse
    if (res.data == null) {
      throw const CallTokenException('Empty response from Edge Function');
    }

    final Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw CallTokenException('Invalid response format', e);
    }

    // Extraction et validation des champs
    final token = _CallTokenValidators.sanitizeToken(
      data['token']?.toString(),
    );
    final appId = (data['appId']?.toString() ?? '').trim();
    final returnedChannel = (data['channelName']?.toString() ?? channel).trim();
    final returnedUid = (data['uid'] as num?)?.toInt() ?? uid;

    // Validation du token reçu
    if (token.isEmpty) {
      throw const CallTokenException('Empty token received');
    }
    if (!_CallTokenValidators.isValidAppId(appId)) {
      throw const CallTokenException('Invalid appId received');
    }
    if (!_CallTokenValidators.isValidChannel(returnedChannel)) {
      throw const CallTokenException('Invalid channelName received');
    }

    return CallTokenResult(
      token: token,
      appId: appId,
      channel: returnedChannel,
      uid: returnedUid,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  /// Marque le service comme disposé.
  ///
  /// Après appel, toutes les méthodes lèveront [StateError].
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('[CallTokenService] 👋 Disposed');
  }
}
