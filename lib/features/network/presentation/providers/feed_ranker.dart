// lib/features/network/presentation/providers/feed_ranker.dart
//
// v2.1 :
//  ✅ FIX — Utilisation de records positionnels (NetworkPost, double)
//     au lieu de records nommés pour éviter les erreurs de type
//
// v2 : Smart Mix algorithm
// v1 : EdgeRank classique

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:thix_id/models/network_post.dart';

// ============================================================================
// LOGGING
// ============================================================================

class _FeedRankerLogger {
  static const _tag = 'FeedRanker';
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
// CONSTANTS
// ============================================================================

const double _kDecayHalfLifeHours = 48.0;
const Duration _kFreshnessWindow = Duration(hours: 4);
const double _kFreshnessBoost = 2.5;
const double _kAffinityConnection = 1.0;
const double _kAffinityStranger = 0.3;
const double _kCommentMultiplier = 2.0;
const double _kPinBoost = 10.0;
const double _kMediaBoost = 1.2;
const double _kMinScore = 0.0;
const double _kMaxScore = 1000.0;
const double _kRecentPostsRatio = 0.6;
const int _kBucketSize = 5;

// ============================================================================
// FEED RANKER (Production Enterprise v2.1 - Smart Mix)
// ============================================================================

class FeedRanker {
  FeedRanker._();

  static List<NetworkPost> rank({
    required List<NetworkPost> posts,
    required Set<String> connectionIds,
    required String feedType,
  }) {
    if (posts.isEmpty) {
      _FeedRankerLogger.info('Rank called on empty list',
          {'feedType': feedType});
      return posts;
    }

    _FeedRankerLogger.info('Ranking posts',
        {'count': posts.length, 'feedType': feedType, 'connections': connectionIds.length});

    try {
      switch (feedType) {
        case 'popular':
          return _rankByPopularity(posts);
        case 'recent':
          return _rankByRecency(posts);
        case 'network':
          return _rankByNetwork(posts, connectionIds);
        case 'smart':
        case 'edge_rank':
          return _rankBySmartMix(posts, connectionIds);
        case 'all':
        default:
          return _rankBySmartMix(posts, connectionIds);
      }
    } catch (e, stack) {
      _FeedRankerLogger.error('Ranking failed, returning original',
          {'feedType': feedType, 'error': '$e', 'stack': stack.toString()});
      return posts;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ SMART MIX ALGORITHM
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankBySmartMix(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    final validPosts = _filterValidPosts(posts);
    if (validPosts.isEmpty) {
      _FeedRankerLogger.warn('No valid posts after filtering',
          {'original': posts.length});
      return posts;
    }

    final pinnedPosts = validPosts.where((p) => p.isPinned).toList();
    final regularPosts = validPosts.where((p) => !p.isPinned).toList();

    // ✅ FIX : Utiliser des records positionnels (NetworkPost, double)
    final scored = regularPosts.map((post) {
      final score = _calculateScoreWithFreshness(post, connectionIds, now);
      return (post, score); // ← Record positionnel, pas nommé
    }).toList();

    final recentPosts = scored
        .where((e) => now.difference(e.$1.createdAt) < _kFreshnessWindow)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final olderPosts = scored
        .where((e) => now.difference(e.$1.createdAt) >= _kFreshnessWindow)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    _FeedRankerLogger.info('Smart Mix buckets',
        {'recent': recentPosts.length, 'older': olderPosts.length});

    final mixed = _smartMix(recentPosts, olderPosts);
    final result = [...pinnedPosts, ...mixed];

    _FeedRankerLogger.info('Smart Mix completed',
        {
          'total': result.length,
          'pinned': pinnedPosts.length,
          'recent': recentPosts.length,
          'older': olderPosts.length,
        });

    return result;
  }

  /// ✅ FIX : Signature avec record positionnel (NetworkPost, double)
  static List<NetworkPost> _smartMix(
    List<(NetworkPost, double)> recent,
    List<(NetworkPost, double)> older,
  ) {
    final result = <NetworkPost>[];
    int recentIdx = 0;
    int olderIdx = 0;

    final recentPerBucket = (_kBucketSize * _kRecentPostsRatio).round();
    final olderPerBucket = _kBucketSize - recentPerBucket;

    _FeedRankerLogger.info('Smart Mix config',
        {
          'bucketSize': _kBucketSize,
          'recentPerBucket': recentPerBucket,
          'olderPerBucket': olderPerBucket,
        });

    while (recentIdx < recent.length || olderIdx < older.length) {
      // ✅ FIX : Accéder aux éléments avec .$1 (NetworkPost) et .$2 (double)
      for (int i = 0; i < recentPerBucket && recentIdx < recent.length; i++) {
        result.add(recent[recentIdx].$1); // ← .$1 au lieu de .post
        recentIdx++;
      }

      for (int i = 0; i < olderPerBucket && olderIdx < older.length; i++) {
        result.add(older[olderIdx].$1); // ← .$1 au lieu de .post
        olderIdx++;
      }
    }

    return result;
  }

  static double _calculateScoreWithFreshness(
    NetworkPost post,
    Set<String> connectionIds,
    DateTime now,
  ) {
    final affinity = connectionIds.contains(post.userId)
        ? _kAffinityConnection
        : _kAffinityStranger;

    final engagementScore = _calculateEngagementScore(post);

    final ageInHours = now.difference(post.createdAt).inHours.toDouble();
    final safeAgeInHours = ageInHours < 0 ? 0.0 : ageInHours;
    final decay = exp(-safeAgeInHours / _kDecayHalfLifeHours);

    final age = now.difference(post.createdAt);
    final freshnessBoost = age < _kFreshnessWindow ? _kFreshnessBoost : 1.0;

    final pinBoost = post.isPinned ? _kPinBoost : 1.0;
    final mediaBoost = post.hasMedia ? _kMediaBoost : 1.0;

    var score = affinity * engagementScore * decay * freshnessBoost * pinBoost * mediaBoost;

    if (score.isNaN || score.isInfinite) {
      _FeedRankerLogger.warn('Invalid score detected, using fallback',
          {'postId': post.id, 'score': '$score'});
      score = 0.0;
    }

    return score.clamp(_kMinScore, _kMaxScore);
  }

  static double _calculateEngagementScore(NetworkPost post) {
    final likes = post.likesCount.toDouble();
    final comments = post.commentsCount.toDouble();
    return likes + (comments * _kCommentMultiplier);
  }

  static List<NetworkPost> _filterValidPosts(List<NetworkPost> posts) {
    final valid = <NetworkPost>[];
    int invalidCount = 0;

    for (final post in posts) {
      try {
        if (post.id.isEmpty) {
          invalidCount++;
          continue;
        }
        if (post.createdAt == null) {
          invalidCount++;
          continue;
        }
        valid.add(post);
      } catch (e) {
        invalidCount++;
        _FeedRankerLogger.warn('Invalid post skipped in ranking',
            {'error': '$e'});
      }
    }

    if (invalidCount > 0) {
      _FeedRankerLogger.warn('Invalid posts filtered in ranking',
          {'invalid': invalidCount, 'valid': valid.length});
    }

    return valid;
  }

  // ══════════════════════════════════════════════════════════════
  // POPULARITY RANKING
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByPopularity(List<NetworkPost> posts) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));

    _FeedRankerLogger.info('Popularity ranking completed',
        {'count': sorted.length, 'topLikes': sorted.first.likesCount});

    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  // RECENCY RANKING
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByRecency(List<NetworkPost> posts) {
    final validPosts = _filterValidPosts(posts);
    final sorted = List<NetworkPost>.from(validPosts);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _FeedRankerLogger.info('Recency ranking completed',
        {'count': sorted.length});

    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  // NETWORK RANKING
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByNetwork(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final validPosts = _filterValidPosts(posts);
    final sorted = List<NetworkPost>.from(validPosts);

    sorted.sort((a, b) {
      final aIsConnection = connectionIds.contains(a.userId) ? 1 : 0;
      final bIsConnection = connectionIds.contains(b.userId) ? 1 : 0;

      if (aIsConnection != bIsConnection) {
        return bIsConnection.compareTo(aIsConnection);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    final connectionCount =
        sorted.where((p) => connectionIds.contains(p.userId)).length;

    _FeedRankerLogger.info('Network ranking completed',
        {'count': sorted.length, 'connections': connectionCount});

    return sorted;
  }
}
