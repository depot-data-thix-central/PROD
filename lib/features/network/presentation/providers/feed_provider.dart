// lib/features/network/presentation/providers/feed_provider.dart
//
// FeedProvider — Production Enterprise (Riverpod AsyncNotifier)
//
// ✅ Timeouts + retry sur erreurs 5xx
// ✅ Logs structurés avec niveaux INFO/WARN/ERROR
// ✅ Validation des inputs et données reçues
// ✅ Throttling sur actions utilisateur
// ✅ Protection contre race conditions
// ✅ Error recovery robuste
// ✅ Observabilité complète
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_ranker.dart';
import 'package:thix_id/models/network_post.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxPostsInMemory = 500;
const int _kMaxRetryAttempts = 2;
const Duration _kNetworkTimeout = Duration(seconds: 15);
const Duration _kRetryBaseDelay = Duration(milliseconds: 500);
const Duration _kActionThrottle = Duration(milliseconds: 300);
const Duration _kConnectionCacheTTL = Duration(minutes: 5);

// ============================================================================
// LOGGING
// ============================================================================

class _FeedLogger {
  static const _tag = 'Feed';
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
// PROVIDER
// ============================================================================

final feedProvider = AsyncNotifierProvider<Feed, List<NetworkPost>>(Feed.new);

class Feed extends AsyncNotifier<List<NetworkPost>> {
  String _currentType = 'all';
  bool _hasMore = true;
  bool _isFetchingMore = false;
  Set<String> _connectionIds = {};
  DateTime? _lastPostDate;
  DateTime? _connectionsLastFetched;
  int _feedSeed = 0;

  // Throttling pour les actions utilisateur
  DateTime? _lastLikeAction;
  DateTime? _lastDeleteAction;

  bool get hasMore => _hasMore;
  String get currentType => _currentType;
  bool get isFetchingMore => _isFetchingMore;

  // ════════════════════════════════════════════════════════════════════
  // CONNEXIONS (avec cache TTL)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _ensureConnections({bool force = false}) async {
    final now = DateTime.now();
    final cacheExpired = _connectionsLastFetched == null ||
        now.difference(_connectionsLastFetched!) > _kConnectionCacheTTL;

    if (_connectionIds.isNotEmpty && !force && !cacheExpired) {
      return;
    }

    try {
      final service = ref.read(networkServiceProvider);
      _connectionIds = await service
          .getMyConnectionIds()
          .timeout(_kNetworkTimeout);
      _connectionsLastFetched = now;
      _FeedLogger.info('Connections loaded',
          {'count': _connectionIds.length});
    } catch (e) {
      _FeedLogger.error('Connections load failed', {'error': '$e'});
      _connectionIds = {};
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // RANKING
  // ════════════════════════════════════════════════════════════════════

  List<NetworkPost> _rank(List<NetworkPost> posts) {
    return FeedRanker.rank(
      posts: posts,
      connectionIds: _connectionIds,
      feedType: _currentType,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // MEMORY MANAGEMENT
  // ════════════════════════════════════════════════════════════════════

  /// Garde les posts les plus récents (au début de la liste)
  List<NetworkPost> _enforceMemoryLimit(List<NetworkPost> posts) {
    if (posts.length <= _kMaxPostsInMemory) return posts;
    _FeedLogger.warn('Memory limit exceeded, trimming',
        {'from': posts.length, 'to': _kMaxPostsInMemory});
    return posts.take(_kMaxPostsInMemory).toList();
  }

  // ════════════════════════════════════════════════════════════════════
  // VALIDATION
  // ════════════════════════════════════════════════════════════════════

  /// Valide la structure d'un NetworkPost
  bool _isValidPost(NetworkPost? post) {
    if (post == null) return false;
    if (post.id.isEmpty) return false;
    if (post.userId.isEmpty) return false;
    return true;
  }

  /// Filtre les posts invalides
  List<NetworkPost> _filterValidPosts(List<NetworkPost> posts) {
    final valid = posts.where(_isValidPost).toList();
    if (valid.length != posts.length) {
      _FeedLogger.warn('Invalid posts filtered',
          {'total': posts.length, 'valid': valid.length});
    }
    return valid;
  }

  // ════════════════════════════════════════════════════════════════════
  // FETCH WITH RETRY
  // ════════════════════════════════════════════════════════════════════

  Future<List<NetworkPost>> _fetchWithRetry<T>(
    Future<List<NetworkPost>> Function() fetcher, {
    int maxAttempts = _kMaxRetryAttempts,
  }) async {
    Object? lastError;
    for (int attempt = 0; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _kRetryBaseDelay * attempt;
          _FeedLogger.info('Retrying fetch',
              {'attempt': attempt, 'delay': '$delay'});
          await Future.delayed(delay);
        }
        return await fetcher().timeout(_kNetworkTimeout);
      } catch (e) {
        lastError = e;
        _FeedLogger.warn('Fetch attempt failed',
            {'attempt': attempt, 'error': '$e'});

        // Pas de retry sur erreurs client (4xx)
        if (e.toString().contains('400') ||
            e.toString().contains('401') ||
            e.toString().contains('403') ||
            e.toString().contains('404')) {
          break;
        }
      }
    }
    throw lastError ?? Exception('Fetch failed after retries');
  }

  // ════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════════════════

  @override
  Future<List<NetworkPost>> build() async {
    _hasMore = true;
    _lastPostDate = null;
    _isFetchingMore = false;
    _feedSeed = Random().nextInt(1000000000);

    _FeedLogger.info('Feed initialized', {'seed': _feedSeed});

    try {
      return await _fetch(offset: 0);
    } catch (e) {
      _FeedLogger.error('Initial fetch failed', {'error': '$e'});
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // LOAD FEED (pull-to-refresh)
  // ════════════════════════════════════════════════════════════════════

  Future<void> loadFeed({String? feedType, bool force = false}) async {
    if (feedType != null) _currentType = feedType;
    state = const AsyncLoading();

    try {
      if (force) {
        _connectionIds = {};
        _connectionsLastFetched = null;
      }

      _lastPostDate = null;
      // ✅ NOUVEAU seed à chaque refresh pour varier le contenu
      _feedSeed = Random().nextInt(1000000000);

      _FeedLogger.info('Loading feed',
          {'type': _currentType, 'force': force, 'seed': _feedSeed});

      final posts = await _fetch(offset: 0);
      state = AsyncData(posts);

      _FeedLogger.info('Feed loaded', {'count': posts.length});
    } catch (e, stack) {
      _FeedLogger.error('Load feed failed', {'error': '$e'});
      state = AsyncError(e, stack);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // ADD POST (nouveau post publié)
  // ════════════════════════════════════════════════════════════════════

  void addPostOnTop(NetworkPost post) {
    if (!_isValidPost(post)) {
      _FeedLogger.warn('Invalid post rejected', {'id': post.id});
      return;
    }

    final current = state.valueOrNull ?? [];

    // Anti-doublon
    if (current.any((p) => p.id == post.id)) {
      _FeedLogger.info('Post already exists, skipping', {'id': post.id});
      return;
    }

    final updated = [post, ...current];
    state = AsyncData(_enforceMemoryLimit(updated));

    _FeedLogger.info('Post added on top', {'id': post.id});
  }

  // ════════════════════════════════════════════════════════════════════
  // LOAD MORE (pagination)
  // ════════════════════════════════════════════════════════════════════

  Future<void> loadMore() async {
    // Protection contre appels concurrents
    if (!_hasMore || _isFetchingMore) {
      _FeedLogger.info('Load more skipped',
          {'hasMore': _hasMore, 'isFetchingMore': _isFetchingMore});
      return;
    }

    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    // Stop si limite mémoire atteinte
    if (current.length >= _kMaxPostsInMemory) {
      _FeedLogger.info('Memory limit reached, stopping pagination');
      _hasMore = false;
      return;
    }

    _isFetchingMore = true;

    try {
      // ✅ MÊME seed que le refresh initial → pagination cohérente
      final more = await _fetch(offset: current.length);

      // Anti-doublon
      final ids = current.map((p) => p.id).toSet();
      final unique = more.where((p) => !ids.contains(p.id)).toList();

      final updated = [...current, ...unique];
      state = AsyncData(_enforceMemoryLimit(updated));

      _FeedLogger.info('Load more completed',
          {'fetched': more.length, 'unique': unique.length, 'total': updated.length});
    } catch (e) {
      _FeedLogger.error('Load more failed', {'error': '$e'});
    } finally {
      _isFetchingMore = false;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // FETCH (centralisé)
  // ════════════════════════════════════════════════════════════════════

  Future<List<NetworkPost>> _fetch({required int offset}) async {
    await _ensureConnections();
    final service = ref.read(networkServiceProvider);

    // Limites dynamiques
    final limit = _currentType == 'all' ? (offset == 0 ? 50 : 30) : 20;

    if (_currentType == 'all') {
      // ✅ SMART FEED : La DB s'occupe du tri
      final posts = await _fetchWithRetry(
        () => service.getFeedPosts(
          feedType: 'all',
          limit: limit,
          offset: offset,
          seed: _feedSeed,
        ),
      );

      _hasMore = posts.length >= limit;
      return _enforceMemoryLimit(_filterValidPosts(posts));
    }

    // ── Autres onglets ──
    final posts = await _fetchWithRetry(
      () => service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        offset: offset,
        lastCreatedAt: _lastPostDate,
      ),
    );

    _hasMore = posts.length >= limit;
    if (posts.isNotEmpty) _lastPostDate = posts.last.createdAt;

    return _enforceMemoryLimit(_rank(_filterValidPosts(posts)));
  }

  // ════════════════════════════════════════════════════════════════════
  // DELETE POST (optimistic update + rollback)
  // ════════════════════════════════════════════════════════════════════

  Future<void> deletePost(String postId) async {
    if (postId.isEmpty) {
      _FeedLogger.warn('Delete rejected: empty postId');
      return;
    }

    // Throttling
    final now = DateTime.now();
    if (_lastDeleteAction != null &&
        now.difference(_lastDeleteAction!) < _kActionThrottle) {
      _FeedLogger.warn('Delete throttled', {'id': postId});
      return;
    }
    _lastDeleteAction = now;

    final current = state.valueOrNull ?? [];
    final original = current.firstWhere((p) => p.id == postId, orElse: () => throw Exception('Post not found'));

    // Optimistic update
    state = AsyncData(current.where((p) => p.id != postId).toList());
    _FeedLogger.info('Post deleted (optimistic)', {'id': postId});

    try {
      await ref
          .read(networkServiceProvider)
          .deletePost(postId)
          .timeout(_kNetworkTimeout);
      _FeedLogger.info('Post deleted (confirmed)', {'id': postId});
    } catch (e) {
      _FeedLogger.error('Delete failed, rollback', {'id': postId, 'error': '$e'});
      // Rollback
      state = AsyncData(current);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // TOGGLE LIKE (optimistic update + rollback)
  // ════════════════════════════════════════════════════════════════════

  Future<void> toggleLike(String postId) async {
    if (postId.isEmpty) {
      _FeedLogger.warn('Like rejected: empty postId');
      return;
    }

    // Throttling
    final now = DateTime.now();
    if (_lastLikeAction != null &&
        now.difference(_lastLikeAction!) < _kActionThrottle) {
      _FeedLogger.warn('Like throttled', {'id': postId});
      return;
    }
    _lastLikeAction = now;

    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) {
      _FeedLogger.warn('Like rejected: post not found', {'id': postId});
      return;
    }

    final old = current[idx];
    final wasLiked = old.isLiked;
    final oldCount = old.likesCount;

    // Optimistic update
    final optimistic = old.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    final list = [...current];
    list[idx] = optimistic;
    state = AsyncData(list);

    _FeedLogger.info('Like toggled (optimistic)',
        {'id': postId, 'wasLiked': wasLiked, 'newCount': optimistic.likesCount});

    try {
      final service = ref.read(networkServiceProvider);
      if (wasLiked) {
        await service.unlikePost(postId).timeout(_kNetworkTimeout);
      } else {
        await service.likePost(postId).timeout(_kNetworkTimeout);
      }
      _FeedLogger.info('Like confirmed', {'id': postId, 'liked': !wasLiked});
    } catch (e) {
      _FeedLogger.error('Like failed, rollback', {'id': postId, 'error': '$e'});
      // Rollback
      state = AsyncData(current);
    }
  }
}
