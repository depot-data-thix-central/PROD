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

/// Constante de temps de la décroissance (en heures) : après ~10 h un post
/// perd 63 % de son score, après 2-3 jours il est quasi invisible.
const double _kDecayHalfLifeHours = 10.0;

/// Constante de temps pour l'onglet « Populaires » (≈ 3 jours)
const double _kPopularDecayHours = 72.0;

/// Score d'affinité pour un post d'une connexion
const double _kAffinityConnection = 1.0;

/// Score d'affinité pour un post hors connexion
const double _kAffinityStranger = 0.3;

/// Multiplicateur pour les commentaires (plus importants que les likes)
const double _kCommentMultiplier = 2.0;

/// Boost pour posts épinglés
const double _kPinBoost = 10.0;

/// Boost pour posts avec médias
const double _kMediaBoost = 1.2;

/// Score minimum pour éviter les valeurs négatives/NaN
const double _kMinScore = 0.0;

/// Score maximum pour éviter les valeurs extrêmes
const double _kMaxScore = 1000.0;

// ============================================================================
// FEED RANKER (Production Enterprise)
// ============================================================================

/// Algorithme de ranking type Facebook EdgeRank, centré sur la RÉCENCE.
///
/// Score = Affinité × Engagement × Décroissance(âge) × Boosts
///
/// - Affinité : connexion avec l'auteur (1.0 connexion, 0.3 inconnu)
/// - Engagement : 1 + ln(1 + likes + 2×commentaires) — toujours >= 1,
///   donc un post récent à 0 like n'est jamais écrasé
/// - Décroissance : e^(-âge/10h) — les posts anciens disparaissent
/// - Boosts : épinglé, médias
class FeedRanker {
  FeedRanker._();

  /// Rank les posts selon le type de feed
  static List<NetworkPost> rank({
    required List<NetworkPost> posts,
    required Set<String> connectionIds,
    required String feedType,
  }) {
    if (posts.isEmpty) {
      _FeedRankerLogger.info('Rank called on empty list', {'feedType': feedType});
      return posts;
    }

    _FeedRankerLogger.info('Ranking posts', {
      'count': posts.length,
      'feedType': feedType,
      'connections': connectionIds.length,
    });

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
          return _rankBySmartAlgorithm(posts, connectionIds);
        case 'all':
        default:
          _FeedRankerLogger.info('Passthrough (no re-sort)',
              {'feedType': feedType, 'count': posts.length});
          return posts;
      }
    } catch (e, stack) {
      _FeedRankerLogger.error('Ranking failed, returning original',
          {'feedType': feedType, 'error': '$e', 'stack': stack.toString()});
      return posts;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SMART ALGORITHM (EdgeRank-like, récence forte)
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankBySmartAlgorithm(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    final validPosts = _filterValidPosts(posts);
    if (validPosts.isEmpty) {
      _FeedRankerLogger.warn('No valid posts after filtering', {'original': posts.length});
      return posts;
    }

    final scored = validPosts.map((post) {
      final score = _calculateScore(post, connectionIds, now);
      return (post: post, score: score);
    }).toList();

    // Tri décroissant par score ; à score égal, le plus récent d'abord
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : b.post.createdAt.compareTo(a.post.createdAt);
    });

    final result = scored.map((e) => e.post).toList();

    _FeedRankerLogger.info('Smart ranking completed', {
      'posts': result.length,
      'topScore': scored.first.score.toStringAsFixed(2),
    });

    return result;
  }

  /// Calcule le score d'un post avec protections
  static double _calculateScore(
    NetworkPost post,
    Set<String> connectionIds,
    DateTime now,
  ) {
    // 1. Affinité
    final affinity = connectionIds.contains(post.userId)
        ? _kAffinityConnection
        : _kAffinityStranger;

    // 2. Engagement (toujours >= 1)
    final engagementScore = _calculateEngagementScore(post);

    // 3. Décroissance temporelle précise (minutes) : e^(-t/10h)
    final ageInHours = now.difference(post.createdAt.toUtc()).inMinutes / 60.0;
    final safeAgeInHours = ageInHours < 0 ? 0.0 : ageInHours;
    final decay = exp(-safeAgeInHours / _kDecayHalfLifeHours);

    // 4. Boosts
    final pinBoost = post.isPinned ? _kPinBoost : 1.0;
    final mediaBoost = post.hasMedia ? _kMediaBoost : 1.0;

    var score = affinity * engagementScore * decay * pinBoost * mediaBoost;

    if (score.isNaN || score.isInfinite) {
      _FeedRankerLogger.warn('Invalid score detected, using fallback',
          {'postId': post.id, 'score': '$score'});
      score = 0.0;
    }

    return score.clamp(_kMinScore, _kMaxScore);
  }

  /// Engagement adouci (log) : 1 + ln(1 + likes + 2×commentaires)
  static double _calculateEngagementScore(NetworkPost post) {
    final raw = post.likesCount + (post.commentsCount * _kCommentMultiplier);
    return 1.0 + log(1.0 + raw);
  }

  /// Filtre les posts valides
  static List<NetworkPost> _filterValidPosts(List<NetworkPost> posts) {
    final valid = <NetworkPost>[];
    int invalidCount = 0;

    for (final post in posts) {
      try {
        if (post.id.isEmpty) {
          invalidCount++;
          continue;
        }
        valid.add(post);
      } catch (e) {
        invalidCount++;
        _FeedRankerLogger.warn('Invalid post skipped in ranking', {'error': '$e'});
      }
    }

    if (invalidCount > 0) {
      _FeedRankerLogger.warn('Invalid posts filtered in ranking',
          {'invalid': invalidCount, 'valid': valid.length});
    }

    return valid;
  }

  // ══════════════════════════════════════════════════════════════
  // POPULARITY RANKING (likes pondérés par l'âge)
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByPopularity(List<NetworkPost> posts) {
    final now = DateTime.now().toUtc();

    double score(NetworkPost p) {
      final raw = p.likesCount + (p.commentsCount * _kCommentMultiplier);
      final ageH = (now.difference(p.createdAt.toUtc()).inMinutes / 60.0)
          .clamp(0.0, 1000000.0);
      return (1.0 + raw) * exp(-ageH / _kPopularDecayHours);
    }

    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => score(b).compareTo(score(a)));

    _FeedRankerLogger.info('Popularity ranking completed', {'count': sorted.length});

    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  // RECENCY RANKING
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByRecency(List<NetworkPost> posts) {
    final validPosts = _filterValidPosts(posts);
    final sorted = List<NetworkPost>.from(validPosts);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _FeedRankerLogger.info('Recency ranking completed', {'count': sorted.length});

    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  // NETWORK RANKING
  // ══════════════════════════════════════════════════════════════

  /// Tri par réseau (connexions d'abord, puis récence)
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

    final connectionCount = sorted.where((p) => connectionIds.contains(p.userId)).length;

    _FeedRankerLogger.info('Network ranking completed',
        {'count': sorted.length, 'connections': connectionCount});

    return sorted;
  }
}
