// lib/presentation/thix_media/live/services/live_service.dart
//
// LiveService v3.0 — Production Enterprise (TikTok/IG Live backend)
//
// Améliorations v3.0 :
// ✅ promoteToGuest() : RPC serveur → token Agora guest
// ✅ demoteToViewer() : kick guest côté serveur
// ✅ sendMessage avec targetUserId (invite/promote/kick ciblés)
// ✅ LiveSession avec hostUsername + hostAvatarUrl (JOIN profiles)
// ✅ LiveGuest complet avec LiveRole (co-host support)
// ✅ Sanitization renforcée (décodage itératif anti-XSS)
// ✅ Chat throttle 600ms → 80ms (TikTok-speed)
// ✅ Validation stricte (UUID, role, audience, status)
// ✅ Double vérification live_status sur accept invite
// ✅ Rate limiter par user renforcé
//
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/live_model.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kTokenCacheTTL = Duration(minutes: 50);
const Duration _kChatThrottle = Duration(milliseconds: 80); // TikTok-speed
const Duration _kActionThrottle = Duration(milliseconds: 250);
const int _kMaxTitleLength = 80;
const int _kMaxCategoryLength = 40;
const int _kMaxChatLength = 200;
const int _kMaxUsernameLength = 24;
const int _kDefaultListLimit = 30;
const int _kMaxListLimit = 100;
const int _kMaxGuestsPerLive = 4;
const int _kMaxChatThrottleEntries = 500;
const Duration _kChatThrottleWindow = Duration(seconds: 5);
const int _kMaxMessagesPerWindow = 10;

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
// VALIDATORS / SANITIZERS (renforcés v3.0)
// ============================================================================

class _LiveValidators {
  _LiveValidators._();

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);

  static const List<String> allowedMessageTypes = [
    'chat', 'reaction', 'gift', 'invite', 'request_join',
    'promote', 'demote', 'kick', 'join', 'leave', 'system',
  ];

  static const List<String> allowedAudiences = [
    'public', 'followers', 'private',
  ];

  /// Sanitization renforcée : décodage itératif + blacklist XSS étendue
  static String sanitizeText(String? input, {required int maxLength}) {
    if (input == null) return '';
    var s = input;

    // Décodage itératif contre attaques multi-couches
    String prev;
    int iterations = 0;
    do {
      prev = s;
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
      s = s.replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), '');
      iterations++;
    } while (s != prev && iterations < 5);

    // Blacklist XSS étendue
    s = s
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:(?!image\/)', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'expression\s*\(', caseSensitive: false), '')
        .replaceAll(RegExp(r'url\s*\(', caseSensitive: false), '')
        .replaceAll(RegExp(r'@import', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
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

  static String sanitizeUsername(String? input) {
    final s = sanitizeText(input, maxLength: _kMaxUsernameLength);
    return s.isEmpty ? 'User' : s;
  }

  static String sanitizeMessageType(String? input) {
    final t = (input ?? 'chat').trim().toLowerCase();
    return allowedMessageTypes.contains(t) ? t : 'chat';
  }

  static String sanitizeAudience(String? input) {
    final a = (input ?? 'public').trim().toLowerCase();
    return allowedAudiences.contains(a) ? a : 'public';
  }
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

class LiveGuestLimitException extends LiveException {
  LiveGuestLimitException()
      : super('guest_limit', 'Maximum number of guests reached');
}

class LiveGuestAlreadyOnStageException extends LiveException {
  LiveGuestAlreadyOnStageException()
      : super('already_on_stage', 'Guest is already on stage');
}

class LiveInviteNotFoundException extends LiveException {
  LiveInviteNotFoundException()
      : super('invite_not_found', 'No pending invite for this live');
}

class LiveRateLimitException extends LiveException {
  LiveRateLimitException()
      : super('rate_limited', 'Too many actions, please slow down');
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
// RATE LIMITER (par user, pour chat ET actions)
// ============================================================================

class _UserRateLimiter {
  final Map<String, List<DateTime>> _windows = {};

  bool allow(String key, {int max = _kMaxMessagesPerWindow,
      Duration window = _kChatThrottleWindow}) {
    final now = DateTime.now();
    _windows[key] ??= [];
    _windows[key]!.removeWhere((t) => now.difference(t) > window);
    if (_windows[key]!.length >= max) return false;
    _windows[key]!.add(now);
    return true;
  }

  void cleanup() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _windows.removeWhere((_, v) => v.isEmpty || v.last.isBefore(cutoff));
  }
}

// ============================================================================
// SERVICE
// ============================================================================

class LiveService {
  LiveService();

  final _client = Supabase.instance.client;
  final _tokenCache = _AgoraTokenCache();
  final _chatLimiter = _UserRateLimiter();
  final _actionLimiter = _UserRateLimiter();

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  String _getUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw LiveNotAuthenticatedException();
    return user.id;
  }

  String _generateChannelName(String hostId) {
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
        _LiveServiceLogger.warn('Attempt failed', {
          'context': context,
          'attempt': attempt,
          'error': '$e',
        });
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    throw lastError ?? LiveException('retry_exhausted', 'All attempts failed');
  }

  /// Vérifie que l'user peut faire une action (rate limit global)
  void _checkActionLimit(String action) {
    final userId = _getUserId();
    if (!_actionLimiter.allow('$action::$userId', max: 20)) {
      throw LiveRateLimitException();
    }
  }

  // ════════════════════════════════════════════════════════════
  // START LIVE
  // ════════════════════════════════════════════════════════════

  Future<({LiveSession session, AgoraCredentials creds})> startLive({
    required String title,
    String category = 'general',
    String? description,
    String? tags,
    String audience = 'public',
  }) async {
    final userId = _getUserId();
    _checkActionLimit('start_live');

    final safeTitle = _LiveValidators.sanitizeTitle(title);
    final safeCategory = _LiveValidators.sanitizeCategory(category);
    final safeDescription = description != null
        ? _LiveValidators.sanitizeText(description, maxLength: 500)
        : null;
    final safeTags = tags != null
        ? _LiveValidators.sanitizeText(tags, maxLength: 120)
        : null;
    final safeAudience = _LiveValidators.sanitizeAudience(audience);

    if (safeTitle.isEmpty) {
      throw LiveException('invalid_title', 'Title cannot be empty');
    }

    _LiveServiceLogger.info('Starting live', {
      'userId': userId,
      'category': safeCategory,
      'audience': safeAudience,
    });

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
        _LiveServiceLogger.warn('User already has active live', {
          'userId': userId,
          'existingId': existing['id'],
        });
        throw LiveAlreadyActiveException();
      }
    } catch (e) {
      if (e is LiveAlreadyActiveException) rethrow;
      _LiveServiceLogger.warn('Active live check failed', {'error': '$e'});
    }

    final channel = _generateChannelName(userId);

    final insertData = <String, dynamic>{
      'host_id': userId,
      'title': safeTitle,
      'category': safeCategory,
      'status': 'live',
      'channel_name': channel,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'audience': safeAudience,
    };
    if (safeDescription != null && safeDescription.isNotEmpty) {
      insertData['description'] = safeDescription;
    }
    if (safeTags != null && safeTags.isNotEmpty) {
      insertData['tags'] = safeTags;
    }

    final row = await _withRetry(
      () => _withTimeout(
        _client.from('lives').insert(insertData).select().single(),
        context: 'insert_live',
      ),
      context: 'insert_live',
    );

    final creds = await fetchAgoraToken(
      channelName: channel,
      role: 'host',
      cacheResult: true,
    );

    final session = LiveSession.fromMap(row);
    _LiveServiceLogger.info('Live started',
        {'liveId': session.id, 'channel': channel});

    return (session: session, creds: creds);
  }

  // ════════════════════════════════════════════════════════════
  // JOIN LIVE (viewer rejoint en audience)
  // ════════════════════════════════════════════════════════════

  Future<({LiveSession session, AgoraCredentials creds})> joinLive(
    String liveId,
  ) async {
    _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    _LiveServiceLogger.info('Joining live', {'liveId': liveId});

    // JOIN avec profiles pour récupérer host_username + avatar
    final row = await _withRetry(
      () => _withTimeout(
        _client
            .from('lives')
            .select('*, host_profile:host_id(username, avatar_url)')
            .eq('id', liveId)
            .single(),
        context: 'fetch_live_with_host',
      ),
      context: 'fetch_live_with_host',
    );

    // Flatten host profile
    final hostProfile = row['host_profile'] as Map<String, dynamic>?;
    if (hostProfile != null) {
      row['host_username'] = hostProfile['username'];
      row['host_avatar_url'] = hostProfile['avatar_url'];
    } else {
      row['host_username'] = 'Host';
      row['host_avatar_url'] = null;
    }

    final session = LiveSession.fromMap(row);

    if (session.status != 'live') {
      _LiveServiceLogger.warn('Live not active', {
        'liveId': liveId,
        'status': session.status,
      });
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
  // FETCH AGORA TOKEN
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
          AgoraCredentials.fromMap(Map<String, dynamic>.from(data));

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
      _LiveServiceLogger.error('Token fetch failed', {
        'channel': channelName,
        'role': role,
        'error': '$e',
      });
      if (e is LiveTokenException) rethrow;
      throw LiveTokenException('$e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // END LIVE
  // ════════════════════════════════════════════════════════════

  Future<void> endLive(String liveId) async {
    final userId = _getUserId();
    _checkActionLimit('end_live');
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    _LiveServiceLogger.info('Ending live',
        {'liveId': liveId, 'userId': userId});

    final row = await _withTimeout(
      _client.from('lives').select('host_id').eq('id', liveId).maybeSingle(),
      context: 'fetch_live_for_end',
    );

    if (row == null) throw LiveNotFoundException(liveId);

    final hostId = row['host_id'] as String?;
    if (hostId != userId) {
      _LiveServiceLogger.warn('End live denied: not owner', {
        'liveId': liveId,
        'userId': userId,
        'hostId': hostId,
      });
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
            .select('*, host_profile:host_id(username, avatar_url)')
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
          final map = Map<String, dynamic>.from(row);
          final hostProfile = map['host_profile'] as Map<String, dynamic>?;
          if (hostProfile != null) {
            map['host_username'] = hostProfile['username'];
            map['host_avatar_url'] = hostProfile['avatar_url'];
          } else {
            map['host_username'] = 'Host';
            map['host_avatar_url'] = null;
          }
          final s = LiveSession.fromMap(map);
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
  // SEND CHAT MESSAGE (avec targetUserId optionnel)
  // ════════════════════════════════════════════════════════════

  Future<void> sendMessage({
    required String liveId,
    required String text,
    required String username,
    String type = 'chat',
    String? targetUserId,
  }) async {
    final userId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }
    if (targetUserId != null && !_LiveValidators.isValidUuid(targetUserId)) {
      throw LiveException('invalid_target', 'Invalid target user ID');
    }

    // Rate limit par user
    final limiterKey = '$liveId::$userId';
    if (!_chatLimiter.allow(limiterKey)) {
      throw LiveException('throttled', 'Please wait before sending again');
    }

    final safeText = _LiveValidators.sanitizeChat(text);
    if (safeText.isEmpty && type == 'chat') {
      throw LiveException('empty_message', 'Message cannot be empty');
    }

    final safeUsername = _LiveValidators.sanitizeUsername(username);
    final safeType = _LiveValidators.sanitizeMessageType(type);

    // Cleanup périodique
    if (_chatLimiter._windows.length > _kMaxChatThrottleEntries) {
      _chatLimiter.cleanup();
    }

    try {
      final payload = <String, dynamic>{
        'live_id': liveId,
        'user_id': userId,
        'username': safeUsername,
        'text': safeText,
        'type': safeType,
      };
      if (targetUserId != null) {
        payload['target_user_id'] = targetUserId;
      }

      await _withTimeout(
        _client.from('live_messages').insert(payload),
        context: 'send_message',
      );
      _LiveServiceLogger.info('Message sent', {
        'liveId': liveId,
        'type': safeType,
        'len': safeText.length,
        'target': targetUserId,
      });
    } catch (e) {
      _LiveServiceLogger.error('Send message failed', {
        'liveId': liveId,
        'error': '$e',
      });
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // LIKES BATCH (atomique via RPC)
  // ════════════════════════════════════════════════════════════

  Future<void> sendLikeBatch({
    required String liveId,
    required int count,
    required String username,
  }) async {
    if (count <= 0) return;
    if (count > 1000) count = 1000; // Guard anti-abus

    final userId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      _LiveServiceLogger.warn('Invalid live ID for likes', {'liveId': liveId});
      return;
    }

    try {
      await _withTimeout(
        _client.rpc(
          'increment_live_likes',
          params: {
            'p_live_id': liveId,
            'p_count': count,
            'p_user_id': userId,
          },
        ),
        context: 'send_like_batch',
      );

      _LiveServiceLogger.info('Like batch sent', {
        'liveId': liveId,
        'count': count,
      });
    } catch (e) {
      _LiveServiceLogger.error('Send like batch failed', {
        'liveId': liveId,
        'count': count,
        'error': '$e',
      });
    }
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 GUESTS (multi-guest v3.0 complet)
  // ════════════════════════════════════════════════════════════

  /// Host invite un spectateur à monter (envoi broadcast + insert DB)
  Future<void> sendGuestInvite({
    required String liveId,
    required String guestUserId,
    required String guestUsername,
  }) async {
    final hostId = _getUserId();
    _checkActionLimit('invite');
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }
    if (!_LiveValidators.isValidUuid(guestUserId)) {
      throw LiveException('invalid_guest_id', 'Invalid guest user ID');
    }

    final liveRow = await _withTimeout(
      _client
          .from('lives')
          .select('host_id, status, channel_name, title')
          .eq('id', liveId)
          .maybeSingle(),
      context: 'verify_host_for_invite',
    );

    if (liveRow == null) throw LiveNotFoundException(liveId);
    if (liveRow['host_id'] != hostId) throw LiveNotOwnerException();
    if (liveRow['status'] != 'live') throw LiveTerminatedException();

    final guestsRows = await _withTimeout(
      _client
          .from('live_guests')
          .select('user_id, status')
          .eq('live_id', liveId)
          .inFilter('status', ['invited', 'accepted', 'on_stage']),
      context: 'check_guest_limit',
    );

    if (guestsRows is List) {
      final activeGuests = guestsRows.where((g) {
        final s = g['status']?.toString();
        return s == 'accepted' || s == 'on_stage';
      }).length;
      if (activeGuests >= _kMaxGuestsPerLive) {
        throw LiveGuestLimitException();
      }
      final alreadyInvited = guestsRows.any((g) => g['user_id'] == guestUserId);
      if (alreadyInvited) {
        throw LiveGuestAlreadyOnStageException();
      }
    }

    final safeUsername = _LiveValidators.sanitizeUsername(guestUsername);

    await _withRetry(
      () => _withTimeout(
        _client.from('live_guests').insert({
          'live_id': liveId,
          'user_id': guestUserId,
          'username': safeUsername,
          'status': 'invited',
          'invited_at': DateTime.now().toUtc().toIso8601String(),
        }),
        context: 'insert_guest_invite',
      ),
      context: 'insert_guest_invite',
    );

    // Broadcast temps réel
    try {
      final inviteChannel = _client.channel('live_invite_$guestUserId');
      await inviteChannel.sendBroadcastMessage(
        event: 'guest_invite',
        payload: {
          'live_id': liveId,
          'host_id': hostId,
          'host_username': safeUsername,
          'channel_name': liveRow['channel_name']?.toString() ?? '',
          'live_title': liveRow['title']?.toString() ?? '',
          'invited_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      _LiveServiceLogger.warn('Invite broadcast failed (non-critical)',
          {'error': '$e'});
    }

    _LiveServiceLogger.info('Guest invite sent', {
      'liveId': liveId,
      'guestId': guestUserId,
    });
  }

  /// 🎯 Spectateur accepte → RPC serveur → retourne token Agora broadcaster
  Future<AgoraCredentials> acceptGuestInvite(String liveId) async {
    final userId = _getUserId();
    _checkActionLimit('accept_invite');
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    // 1. Vérifier l'invite existe
    final inviteRow = await _withTimeout(
      _client
          .from('live_guests')
          .select()
          .eq('live_id', liveId)
          .eq('user_id', userId)
          .eq('status', 'invited')
          .maybeSingle(),
      context: 'verify_invite',
    );

    if (inviteRow == null) {
      throw LiveInviteNotFoundException();
    }

    // 2. Double vérification : live toujours actif
    final liveRow = await _withTimeout(
      _client
          .from('lives')
          .select('channel_name, status, host_id')
          .eq('id', liveId)
          .maybeSingle(),
      context: 'fetch_live_for_accept',
    );

    if (liveRow == null) throw LiveNotFoundException(liveId);
    if (liveRow['status'] != 'live') throw LiveTerminatedException();

    // 3. Re-check guest count (race condition protection)
    final guestsRows = await _withTimeout(
      _client
          .from('live_guests')
          .select('user_id')
          .eq('live_id', liveId)
          .inFilter('status', ['accepted', 'on_stage']),
      context: 'recheck_guest_limit',
    );
    if (guestsRows is List && guestsRows.length >= _kMaxGuestsPerLive) {
      throw LiveGuestLimitException();
    }

    // 4. Update status → accepted
    await _withRetry(
      () => _withTimeout(
        _client.from('live_guests').update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('live_id', liveId).eq('user_id', userId),
        context: 'update_guest_accept',
      ),
      context: 'update_guest_accept',
    );

    // 5. Fetch token broadcaster (non-cached car uid unique par guest)
    final creds = await fetchAgoraToken(
      channelName: liveRow['channel_name'] as String,
      role: 'broadcaster',
      cacheResult: false,
    );

    _LiveServiceLogger.info('Guest accepted invite', {
      'liveId': liveId,
      'userId': userId,
      'agoraUid': creds.uid,
    });

    return creds;
  }

  /// Spectateur refuse l'invitation
  Future<void> rejectGuestInvite(String liveId) async {
    final userId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    await _withRetry(
      () => _withTimeout(
        _client.from('live_guests').update({
          'status': 'rejected',
          'rejected_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('live_id', liveId).eq('user_id', userId),
        context: 'update_guest_reject',
      ),
      context: 'update_guest_reject',
    );

    _LiveServiceLogger.info('Guest rejected invite', {
      'liveId': liveId,
      'userId': userId,
    });
  }

  /// 🎯 Host kick un guest (retour audience)
  Future<void> demoteToViewer(String liveId, String guestUserId) async {
    final hostId = _getUserId();
    _checkActionLimit('demote');
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }
    if (!_LiveValidators.isValidUuid(guestUserId)) {
      throw LiveException('invalid_guest_id', 'Invalid guest user ID');
    }

    final liveRow = await _withTimeout(
      _client.from('lives').select('host_id').eq('id', liveId).maybeSingle(),
      context: 'verify_host_for_demote',
    );

    if (liveRow == null) throw LiveNotFoundException(liveId);
    if (liveRow['host_id'] != hostId) throw LiveNotOwnerException();

    await _withRetry(
      () => _withTimeout(
        _client.from('live_guests').update({
          'status': 'removed',
          'removed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('live_id', liveId).eq('user_id', guestUserId),
        context: 'update_guest_demote',
      ),
      context: 'update_guest_demote',
    );

    // Message système pour informer le guest
    try {
      await sendMessage(
        liveId: liveId,
        text: 'demoted',
        username: 'System',
        type: 'demote',
        targetUserId: guestUserId,
      );
    } catch (e) {
      _LiveServiceLogger.warn('Demote notification failed (non-critical)',
          {'error': '$e'});
    }

    _LiveServiceLogger.info('Guest demoted to viewer', {
      'liveId': liveId,
      'guestId': guestUserId,
    });
  }

  /// Alias pour rétrocompatibilité
  Future<void> removeGuest(String liveId, String guestUserId) =>
      demoteToViewer(liveId, guestUserId);

  /// 🎯 Host promote → RPC serveur → retourne credentials guest
  /// Utilisé pour le multi-guest (spectateur → broadcaster via RPC)
  Future<AgoraCredentials> promoteToGuest({
    required String liveId,
    required String guestUserId,
  }) async {
    final hostId = _getUserId();
    _checkActionLimit('promote');
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }
    if (!_LiveValidators.isValidUuid(guestUserId)) {
      throw LiveException('invalid_guest_id', 'Invalid guest user ID');
    }

    final liveRow = await _withTimeout(
      _client.from('lives').select('host_id, channel_name').eq('id', liveId).maybeSingle(),
      context: 'verify_host_for_promote',
    );

    if (liveRow == null) throw LiveNotFoundException(liveId);
    if (liveRow['host_id'] != hostId) throw LiveNotOwnerException();

    // RPC serveur : insère dans live_guests + génère agora_uid + retourne credentials
    try {
      final result = await _withRetry(
        () => _withTimeout(
          _client.rpc(
            'rpc_promote_guest',
            params: {
              'p_live_id': liveId,
              'p_guest_user_id': guestUserId,
            },
          ),
          context: 'rpc_promote_guest',
        ),
        context: 'rpc_promote_guest',
      );

      if (result == null) {
        throw LiveException('rpc_failed', 'Promote RPC returned null');
      }

      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : (result is List && result.isNotEmpty
              ? Map<String, dynamic>.from(result.first as Map)
              : <String, dynamic>{});

      final creds = AgoraCredentials.fromMap(map);
      if (!creds.isValid) {
        throw LiveException('invalid_creds', 'RPC returned invalid credentials');
      }

      // Message système
      try {
        await sendMessage(
          liveId: liveId,
          text: 'promoted',
          username: 'System',
          type: 'promote',
          targetUserId: guestUserId,
        );
      } catch (e) {
        _LiveServiceLogger.warn('Promote notification failed', {'error': '$e'});
      }

      _LiveServiceLogger.info('Guest promoted via RPC', {
        'liveId': liveId,
        'guestId': guestUserId,
        'agoraUid': creds.uid,
      });

      return creds;
    } catch (e) {
      _LiveServiceLogger.error('promoteToGuest failed', {
        'liveId': liveId,
        'guestId': guestUserId,
        'error': '$e',
      });
      rethrow;
    }
  }

  /// Legacy method (rétrocompatibilité)
  Future<void> promoteToBroadcaster(
      String liveId, String guestUserId, int agoraUid) async {
    final hostId = _getUserId();
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    final liveRow = await _withTimeout(
      _client.from('lives').select('host_id').eq('id', liveId).maybeSingle(),
      context: 'verify_host_for_promote',
    );

    if (liveRow == null) throw LiveNotFoundException(liveId);
    if (liveRow['host_id'] != hostId) throw LiveNotOwnerException();

    await _withRetry(
      () => _withTimeout(
        _client.from('live_guests').update({
          'status': 'on_stage',
          'agora_uid': agoraUid,
          'promoted_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('live_id', liveId).eq('user_id', guestUserId),
        context: 'update_guest_promote',
      ),
      context: 'update_guest_promote',
    );
  }

  /// 🎯 Récupérer tous les guests actifs (JOIN profiles pour avatars)
  Future<List<LiveGuest>> getLiveGuests(String liveId) async {
    if (!_LiveValidators.isValidUuid(liveId)) {
      throw LiveException('invalid_id', 'Invalid live ID format');
    }

    try {
      final rows = await _withTimeout(
        _client
            .from('live_guests')
            .select('*, profile:user_id(username, avatar_url)')
            .eq('live_id', liveId)
            .inFilter('status', ['invited', 'accepted', 'on_stage'])
            .order('invited_at', ascending: true),
        context: 'get_live_guests',
      );

      if (rows is! List) return [];

      return rows.map((r) {
        if (r is! Map) return null;
        final map = Map<String, dynamic>.from(r);
        final profile = map['profile'] as Map<String, dynamic>?;
        if (profile != null) {
          map['username'] = profile['username'] ?? map['username'];
          map['avatar_url'] = profile['avatar_url'];
        }
        return LiveGuest.fromMap(map);
      }).whereType<LiveGuest>().toList();
    } catch (e) {
      _LiveServiceLogger.error('Get live guests failed', {
        'liveId': liveId,
        'error': '$e',
      });
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════

  void clearCache() {
    _tokenCache.clear();
    _chatLimiter.cleanup();
    _actionLimiter.cleanup();
    _LiveServiceLogger.info('Cache cleared');
  }
}
