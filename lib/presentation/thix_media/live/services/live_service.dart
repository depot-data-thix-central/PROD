// lib/presentation/thix_media/live/services/live_service.dart
//
// LiveService — Production Enterprise (niveau TikTok/IG Live backend)
//
// Features production :
// - Logging structuré (INFO/WARN/ERROR)
// - Sanitization XSS sur tous les inputs
// - Validation UUID stricte
// - Vérification ownership sur endLive
// - Vérification doublons (un seul live actif par user)
// - Throttling chat (anti-spam)
// - Timeouts + retry sur appels critiques
// - Cache token Agora (TTL 50 min)
// - Modèles robustes avec fromJson safe
// - Anti-abus (rate limit client)
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kTokenCacheTTL = Duration(minutes: 50); // Agora token TTL ~60min
const Duration _kChatThrottle = Duration(milliseconds: 600);
const int _kMaxTitleLength = 80;
const int _kMaxCategoryLength = 40;
const int _kMaxChatLength = 200;
const int _kDefaultListLimit = 30;
const int _kMaxListLimit = 100;

// ============================================================================
// LOGGING
// ============================================================================

class _LiveServiceLogger {
  static const _tag = 'LiveService';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS / SANITIZERS
// ============================================================================

class _LiveValidators {
  _LiveValidators._();

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);

  static String sanitizeText(String? input, {required int maxLength}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }

  static String sanitizeTitle(String? input) =>
      sanitizeText(input, maxLength: _kMaxTitleLength);

  static String sanitizeCategory(String? input) =>
      sanitizeText(input, maxLength: _kMaxCategoryLength);

  static String sanitizeChat(String? input) =>
      sanitizeText(input, maxLength: _kMaxChatLength);
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class LiveException implements Exception {
  final String code;
  final String message;
  LiveException(this.code, this.message);
  @override
  String toString() => 'LiveException[$code]: $message';
}

class LiveNotAuthenticatedException extends LiveException {
  LiveNotAuthenticatedException()
      : super('not_authenticated', 'User not authenticated');
}

class LiveNotFoundException extends LiveException {
  LiveNotFoundException(String id) : super('not_found', 'Live $id not found');
}

class LiveAlreadyActiveException extends LiveException {
  LiveAlreadyActiveException()
      : super('already_active', 'You already have an active live');
}

class LiveNotOwnerException extends LiveException {
  LiveNotOwnerException()
      : super('not_owner', 'You are not the owner of this live');
}

class LiveTerminatedException extends LiveException {
  LiveTerminatedException()
      : super('terminated', 'This live has ended');
}

class LiveTokenException extends LiveException {
  LiveTokenException(String details)
      : super('token_error', 'Failed to get Agora token: $details');
}

// ============================================================================
// MODELS
// ============================================================================

class AgoraCredentials {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final String role;

  AgoraCredentials({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.role,
  });

  factory AgoraCredentials.fromJson(Map<String, dynamic> j) {
    return AgoraCredentials(
      token: (j['token'] as String?) ?? '',
      appId: (j['appId'] as String?) ?? '',
      channelName: (j['channelName'] as String?) ?? '',
      uid: (j['uid'] as num?)?.toInt() ?? 0,
      role: (j['role'] as String?) ?? 'audience',
    );
  }

  bool get isValid =>
      token.isNotEmpty && appId.isNotEmpty && channelName.isNotEmpty;
}

class LiveSession {
  final String id;
  final String hostId;
  final String title;
  final String category;
  final String status;
  final String channelName;
  final int viewerCount;
  final int likeCount;
  final String? coverUrl;
  final String? hostAvatarUrl;
  final String? hostDisplayName;
  final DateTime startedAt;

  LiveSession({
    required this.id,
    required this.hostId,
    required this.title,
    required this.category,
    required this.status,
    required this.channelName,
    this.viewerCount = 0,
    this.likeCount = 0,
    this.coverUrl,
    this.hostAvatarUrl,
    this.hostDisplayName,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  factory LiveSession.fromJson(Map<String, dynamic> j) {
    // Parsing robuste : skip champs manquants au lieu de crasher
    return LiveSession(
      id: (j['id'] as String?) ?? '',
      hostId: (j['host_id'] as String?) ?? '',
      title: (j['title'] as String?) ?? 'Live',
      category: (j['category'] as String?) ?? 'general',
      status: (j['status'] as String?) ?? 'live',
      channelName: (j['channel_name'] as String?) ?? '',
      viewerCount: (j['viewer_count'] as num?)?.toInt() ?? 0,
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      coverUrl: j['cover_url'] as String?,
      hostAvatarUrl: j['host_avatar_url'] as String?,
      hostDisplayName: j['host_display_name'] as String?,
      startedAt: j['started_at'] != null
          ? DateTime.tryParse(j['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isScheduled => status == 'scheduled';

  LiveSession copyWith({
    int? viewerCount,
    int? likeCount,
    String? status,
  }) {
    return LiveSession(
      id: id,
      hostId: hostId,
      title: title,
      category: category,
      status: status ?? this.status,
      channelName: channelName,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      coverUrl: coverUrl,
      hostAvatarUrl: hostAvatarUrl,
      hostDisplayName: hostDisplayName,
      startedAt: startedAt,
    );
  }
}

// ============================================================================
// TOKEN CACHE
// ============================================================================

class _TokenCacheEntry {
  final AgoraCredentials creds;
  final DateTime fetchedAt;
  _TokenCacheEntry(this.creds, this.fetchedAt);

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > _kTokenCacheTTL;
}

class _AgoraTokenCache {
  _AgoraTokenCache._();
  static final _AgoraTokenCache _i = _AgoraTokenCache._();
  factory _AgoraTokenCache() => _i;

  final Map<String, _TokenCacheEntry> _cache = {};

  AgoraCredentials? get(String channelName, String role) {
    final key = '$channelName::$role';
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.creds;
  }

  void set(String channelName, String role, AgoraCredentials creds) {
    final key = '$channelName::$role';
    _cache[key] = _TokenCacheEntry(creds, DateTime.now());
    // Limite mémoire : max 20 entrées
    if (_cache.length > 20) {
      final oldest = _cache.entries
          .reduce((a, b) =>
              a.value.fetchedAt.isBefore(b.value.fetchedAt) ? a : b)
          .key;
      _cache.remove(oldest);
    }
  }

  void invalidate(String channelName) {
    _cache.removeWhere((k, _) => k.startsWith('$channelName::'));
  }

  void clear() => _cache.clear();
}

// ============================================================================
// SERVICE
// ============================================================================

class LiveService {
  LiveService();

  final _client = Supabase.instance.client;
  final _tokenCache = _AgoraTokenCache();
  final Map<String, DateTime> _chatLastSend = {};

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  String _getUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw LiveNotAuthenticatedException();
    return user.id;
  }

  String _generateChannelName(String hostId) {
    // Channel name crypto-safe-ish : UUID host + random hex
    final short = hostId.replaceAll('-', '').substring(0, 8);
    final rnd = Random.secure();
    final suffix = List.generate(
      5,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
    return 'thix_${short}_$suffix';
  }

  Future<T> _withTimeout<T>(Future<T> future, {String? context}) async {
    try {
      return await future.timeout(_kRequestTimeout);
    } on TimeoutException {
      _LiveServiceLogger.error('Timeout', {'context': context ?? 'unknown'});
      throw LiveException('timeout', 'Request timed out');
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 2,
    String? context,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        _LiveServiceLogger.warn('Attempt failed',
            {'context': context, 'attempt': attempt, 'error': '$e'});
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    throw lastError ?? LiveException('retry_exhausted', 'All attempts failed');
  }

  // ════════════════════════════════════════════════════════════
  // START LIVE
  // ════════════════════════════════════════════════════════════

  /// Crée un live + récupère le token Agora (host).
  /// Lance [LiveAlreadyActiveException] si l'user a déjà un live actif.
  Future<({LiveSession session, AgoraCredentials creds})> startLive({
    required String title,
    String category = 'general',
  }) async {
    final userId = _getUserId();
    final safeTitle = _LiveValidators.sanitizeTitle(title);
    final safeCategory = _LiveValidators.sanitizeCategory(category);

    if (safeTitle.isEmpty) {
      throw LiveException('invalid_title', 'Title cannot be empty');
    }

    _LiveServiceLogger.info('Starting live',
        {'userId': userId, 'category': safeCategory});

    // Vérifier qu'aucun live actif n'existe pour ce user
    try {
      final existing = await _withTimeout(
        _client
            .from('lives')
            .select('id')
            .eq('host_id', userId)
            .eq('status', 'live')
            .maybeSingle(),
        context: 'check_active_live',
      );
      if (existing != null) {
        _LiveServiceLogger.warn('User already has active live',
            {'userId': userId, 'existingId': existing['id']});
        throw LiveAlreadyActiveException();
      }
    } catch (e) {
      if (e is LiveAlreadyActiveException) rethrow;
      // Erreur non bloquante : on continue
      _LiveServiceLogger.warn('Active live check failed', {'error': '$e'});
    }

    final channel = _generateChannelName(userId);

    final row = await _withRetry(
      () => _withTimeout(
        _client
            .from('lives')
            .insert({
              'host_id': userId,
              'title': safeTitle,
              'category': safeCategory,
              'status': 'live',
              'channel_name': channel,
              'started_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .single(),
        context: 'insert_live',
      ),
      context: 'insert_live',
    );

    final creds = await fetchAgoraToken(
      channelName: channel,
      role: 'host',
      cacheResult: true,
    );

    final session = LiveSession.fromJson(row);
    _LiveServiceLogger.info('Live started',
        {'liveId': session.id, 'channel': channel});

    return (session: session, creds: creds);
  }

  // ════════════════════════════════════════════════════════════
  // JOIN LIVE (audience)
  // ════════════════════════════════════════════════════════════

  Future<({LiveSession session, AgoraCredentials creds})> joinLive(
    String liveId,
  ) async {
    _getUserId(); // vérifie authentification
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    _LiveServiceLogger.info('Joining live', {'liveId': liveId});

    final row = await _withRetry(
      () => _withTimeout(
        _client.from('lives').select().eq('id', liveId).single(),
        context: 'fetch_live',
      ),
      context: 'fetch_live',
    );

    final session = LiveSession.fromJson(row);

    if (session.status != 'live') {
      _LiveServiceLogger.warn('Live not active',
          {'liveId': liveId, 'status': session.status});
      throw LiveTerminatedException();
    }

    final creds = await fetchAgoraToken(
      channelName: session.channelName,
      role: 'audience',
      cacheResult: true,
    );

    _LiveServiceLogger.info('Joined live',
        {'liveId': liveId, 'uid': creds.uid});

    return (session: session, creds: creds);
  }

  // ════════════════════════════════════════════════════════════
  // FETCH AGORA TOKEN (avec cache)
  // ════════════════════════════════════════════════════════════

  Future<AgoraCredentials> fetchAgoraToken({
    required String channelName,
    required String role,
    bool cacheResult = true,
  }) async {
    if (cacheResult) {
      final cached = _tokenCache.get(channelName, role);
      if (cached != null) {
        _LiveServiceLogger.info('Token cache hit',
            {'channel': channelName, 'role': role});
        return cached;
      }
    }

    try {
      final res = await _withRetry(
        () => _withTimeout(
          _client.functions.invoke(
            'thix-media-live-token',
            body: {
              'channelName': channelName,
              'role': role,
            },
          ),
          context: 'fetch_token',
        ),
        context: 'fetch_token',
      );

      if (res.status != 200 || res.data == null) {
        throw LiveTokenException('HTTP ${res.status}: ${res.data}');
      }

      final data = res.data;
      if (data is! Map) {
        throw LiveTokenException('Invalid response type');
      }

      final creds =
          AgoraCredentials.fromJson(Map<String, dynamic>.from(data));

      if (!creds.isValid) {
        throw LiveTokenException('Invalid credentials returned');
      }

      if (cacheResult) {
        _tokenCache.set(channelName, role, creds);
      }

      _LiveServiceLogger.info('Token fetched',
          {'channel': channelName, 'role': role, 'uid': creds.uid});

      return creds;
    } catch (e) {
      _LiveServiceLogger.error('Token fetch failed',
          {'channel': channelName, 'role': role, 'error': '$e'});
      if (e is LiveTokenException) rethrow;
      throw LiveTokenException('$e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // END LIVE (ownership vérifiée)
  // ════════════════════════════════════════════════════════════

  Future<void> endLive(String liveId) async {
    final userId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    _LiveServiceLogger.info('Ending live',
        {'liveId': liveId, 'userId': userId});

    // Récupérer le live pour vérifier ownership
    final row = await _withTimeout(
      _client.from('lives').select('host_id').eq('id', liveId).maybeSingle(),
      context: 'fetch_live_for_end',
    );

    if (row == null) {
      throw LiveNotFoundException(liveId);
    }

    final hostId = row['host_id'] as String?;
    if (hostId != userId) {
      _LiveServiceLogger.warn('End live denied: not owner',
          {'liveId': liveId, 'userId': userId, 'hostId': hostId});
      throw LiveNotOwnerException();
    }

    await _withRetry(
      () => _withTimeout(
        _client.from('lives').update({
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', liveId),
        context: 'update_live_ended',
      ),
      context: 'update_live_ended',
    );

    // Invalider le cache token pour ce channel
    _tokenCache.invalidate(liveId);

    _LiveServiceLogger.info('Live ended', {'liveId': liveId});
  }

  // ════════════════════════════════════════════════════════════
  // LIST ACTIVE LIVES
  // ════════════════════════════════════════════════════════════

  Future<List<LiveSession>> listActiveLives({int limit = 30}) async {
    final safeLimit = limit.clamp(1, _kMaxListLimit);

    try {
      final rows = await _withTimeout(
        _client
            .from('lives')
            .select()
            .eq('status', 'live')
            .order('viewer_count', ascending: false)
            .order('started_at', ascending: false)
            .limit(safeLimit),
        context: 'list_active_lives',
      );

      if (rows is! List) {
        _LiveServiceLogger.warn('listActiveLives: invalid response',
            {'type': rows.runtimeType.toString()});
        return [];
      }

      final sessions = <LiveSession>[];
      int invalidCount = 0;

      for (final row in rows) {
        try {
          if (row is! Map) {
            invalidCount++;
            continue;
          }
          final s = LiveSession.fromJson(Map<String, dynamic>.from(row));
          if (s.id.isEmpty || s.channelName.isEmpty) {
            invalidCount++;
            continue;
          }
          sessions.add(s);
        } catch (e) {
          invalidCount++;
          _LiveServiceLogger.warn('Invalid live skipped', {'error': '$e'});
        }
      }

      if (invalidCount > 0) {
        _LiveServiceLogger.warn('Lives filtered',
            {'invalid': invalidCount, 'valid': sessions.length});
      }

      _LiveServiceLogger.info('Active lives loaded',
          {'count': sessions.length});
      return sessions;
    } catch (e) {
      _LiveServiceLogger.error('listActiveLives failed', {'error': '$e'});
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // SEND CHAT MESSAGE (avec throttling + sanitization)
  // ════════════════════════════════════════════════════════════

  Future<void> sendMessage({
    required String liveId,
    required String text,
    required String username,
    String type = 'chat',
  }) async {
    final userId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    // Throttling par live + user
    final throttleKey = '$liveId::$userId';
    final lastSend = _chatLastSend[throttleKey];
    if (lastSend != null &&
        DateTime.now().difference(lastSend) < _kChatThrottle) {
      _LiveServiceLogger.warn('Chat throttled',
          {'liveId': liveId, 'userId': userId});
      throw LiveException('throttled', 'Please wait before sending again');
    }

    final safeText = _LiveValidators.sanitizeChat(text);
    if (safeText.isEmpty) {
      throw LiveException('empty_message', 'Message cannot be empty');
    }

    final safeUsername =
        _LiveValidators.sanitizeText(username, maxLength: 50);

    _chatLastSend[throttleKey] = DateTime.now();

    // Nettoyage périodique du cache de throttling
    if (_chatLastSend.length > 100) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
      _chatLastSend.removeWhere((_, v) => v.isBefore(cutoff));
    }

    try {
      await _withTimeout(
        _client.from('live_messages').insert({
          'live_id': liveId,
          'user_id': userId,
          'username': safeUsername.isEmpty ? 'User' : safeUsername,
          'text': safeText,
          'type': type,
        }),
        context: 'send_message',
      );
      _LiveServiceLogger.info('Message sent',
          {'liveId': liveId, 'type': type, 'len': safeText.length});
    } catch (e) {
      _LiveServiceLogger.error('Send message failed',
          {'liveId': liveId, 'error': '$e'});
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════

  /// Invalide le cache (ex: après logout)
  void clearCache() {
    _tokenCache.clear();
    _chatLastSend.clear();
    _LiveServiceLogger.info('Cache cleared');
  }
}
