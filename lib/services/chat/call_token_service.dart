// lib/services/chat/call_token_service.dart
//
// ============================================================================
// CALL TOKEN SERVICE — v2.0 (réseau faible)
// ============================================================================
// Nouveau v2.0 :
//  ✅ Cache court (3 min) : le token pré-chargé pendant la sonnerie est
//     réutilisé au moment du join
//  ✅ Requêtes identiques regroupées (une seule requête réseau en vol)
//  ✅ prefetch() : pré-chargement silencieux
//  ✅ forceFresh : ignore le cache (renouvellement)
//  ✅ Timeout 12 s + 1 nouvelle tentative (les tentatives longues sont
//     gérées par CallMediaService)
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
const Duration _kEdgeFunctionTimeout = Duration(seconds: 12);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const Duration _kCacheTtl = Duration(minutes: 3);
const String _kEdgeFunctionName = 'agora-token';

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallTokenValidators {
  _CallTokenValidators._();

  static bool isValidChannel(String? channel) {
    if (channel == null) return false;
    final trimmed = channel.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  static bool isValidUid(int uid) {
    return uid > 0 && uid <= 0x7FFFFFFF;
  }

  static bool isValidAppId(String? appId) {
    if (appId == null) return false;
    final trimmed = appId.trim();
    if (trimmed.length < _kMinAppIdLength) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
  }

  static String sanitizeToken(String? token) {
    if (token == null) return '';
    final trimmed = token.trim();
    return trimmed.length > _kMaxTokenLength
        ? trimmed.substring(0, _kMaxTokenLength)
        : trimmed;
  }

  static String obfuscateChannel(String? channel) {
    if (channel == null || channel.length <= 8) return '***';
    return '${channel.substring(0, 4)}...${channel.substring(channel.length - 4)}';
  }

  static String obfuscateAppId(String? appId) {
    if (appId == null || appId.length <= 6) return '***';
    return '${appId.substring(0, 6)}...';
  }
}

// ============================================================================
// CALL TOKEN RESULT
// ============================================================================
class CallTokenResult {
  final String token;
  final String appId;
  final String channel;
  final int uid;

  const CallTokenResult({
    required this.token,
    required this.appId,
    required this.channel,
    required this.uid,
  });

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

class _CachedResult {
  final CallTokenResult result;
  final DateTime at;
  _CachedResult(this.result, this.at);
}

// ============================================================================
// EXCEPTIONS
// ============================================================================
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
class CallTokenService {
  final SupabaseClient _client;
  bool _isDisposed = false;

  // Partagés entre toutes les instances (le service est recréé à chaque appel)
  static final Map<String, _CachedResult> _cache = {};
  static final Map<String, Future<CallTokenResult>> _inflight = {};

  CallTokenService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Vide le cache (déconnexion de l'utilisateur par exemple).
  static void clearCache() {
    _cache.clear();
    _inflight.clear();
  }

  /// Pré-charge un token en silence (ex. pendant la sonnerie).
  Future<void> prefetch({required String channel, required int uid}) async {
    try {
      await getToken(channel: channel, uid: uid);
    } catch (e) {
      debugPrint('[CallTokenService] ⚠️ Prefetch failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  Future<CallTokenResult> getToken({
    required String channel,
    required int uid,
    bool forceFresh = false,
  }) async {
    if (_isDisposed) {
      throw StateError('CallTokenService disposed');
    }

    if (!_CallTokenValidators.isValidChannel(channel)) {
      throw ArgumentError('Invalid channel name');
    }
    if (!_CallTokenValidators.isValidUid(uid)) {
      throw ArgumentError('Invalid uid (must be positive)');
    }

    final key = '$channel:$uid';

    if (!forceFresh) {
      final cached = _cache[key];
      if (cached != null && DateTime.now().difference(cached.at) < _kCacheTtl) {
        debugPrint('[CallTokenService] ⚡ Token from cache');
        return cached.result;
      }
      final running = _inflight[key];
      if (running != null) {
        debugPrint('[CallTokenService] ⏳ Joining in-flight token request');
        return running;
      }
    }

    final future = _fetchWithRetry(channel: channel, uid: uid);
    _inflight[key] = future;

    try {
      final result = await future;
      _cache[key] = _CachedResult(result, DateTime.now());
      debugPrint('[CallTokenService] ✓ Token obtained: $result');
      return result;
    } finally {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    }
  }

  Future<CallTokenResult> _fetchWithRetry({
    required String channel,
    required int uid,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= _kMaxRetries) {
      try {
        return await _fetchToken(channel: channel, uid: uid);
      } on CallTokenException catch (e) {
        // Erreur métier (réponse invalide) : on retente une fois, sauf 4xx
        lastError = e;
        debugPrint('[CallTokenService] ❌ Token error: $e');
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('[CallTokenService] ⏱️ Timeout (try ${attempt + 1})');
      } catch (e) {
        lastError = e;
        debugPrint('[CallTokenService] ⚠️ Error (try ${attempt + 1}): '
            '${kDebugMode ? e : e.toString().split('\n').first}');
      }
      attempt++;
      if (attempt <= _kMaxRetries) await Future.delayed(_kRetryDelay);
    }

    final message = kDebugMode
        ? 'Token retrieval failed: $lastError'
        : 'Token retrieval failed';
    throw CallTokenException(message, lastError);
  }

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

    if (res.status != 200) {
      final errorData = kDebugMode ? res.data : '[hidden]';
      throw CallTokenException(
        'Edge Function returned status ${res.status}',
        errorData,
      );
    }

    if (res.data == null) {
      throw const CallTokenException('Empty response from Edge Function');
    }

    final Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw CallTokenException('Invalid response format', e);
    }

    final token = _CallTokenValidators.sanitizeToken(
      data['token']?.toString(),
    );
    final appId = (data['appId']?.toString() ?? '').trim();
    final returnedChannel = (data['channelName']?.toString() ?? channel).trim();
    final returnedUid = (data['uid'] as num?)?.toInt() ?? uid;

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

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
  }
}
