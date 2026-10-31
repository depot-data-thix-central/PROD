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

/// Demi-vie de décroissance temporelle (en heures)
const double _kDecayHalfLifeHours = 24.0;

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

/// Algorithme de ranking intelligent type Facebook EdgeRank
///
/// Score = (Affinité × Poids × Décroissance) + Boost
///
/// - Affinité : Connexion avec l'auteur (0.0 à 1.0)
/// - Poids : Type d'interaction (like=1, comment=2)
/// - Décroissance : Âge du post (plus ancien = score plus bas)
/// - Boost : Posts épinglés, tendances, etc.
class FeedRanker {
  FeedRanker._();

  /// Rank les posts selon le type de feed
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
          // ✅ Algorithme EdgeRank activé
          return _rankBySmartAlgorithm(posts, connectionIds);
        case 'all':
        default:
          // ✅ Ordre déjà calculé par get_smart_feed (DB) — on ne re-trie PAS
          _FeedRankerLogger.info('Passthrough (DB already sorted)',
              {'feedType': feedType, 'count': posts.length});
          return posts;
      }
    } catch (e, stack) {
      _FeedRankerLogger.error('Ranking failed, returning original',
          {'feedType': feedType, 'error': '$e', 'stack': stack.toString()});
      // Fallback : retourner la liste originale non triée
      return posts;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SMART ALGORITHM (EdgeRank-like)
  // ══════════════════════════════════════════════════════════════

  /// Algorithme intelligent (Facebook EdgeRank-like)
  static List<NetworkPost> _rankBySmartAlgorithm(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    // Validation : filtrer les posts invalides
    final validPosts = _filterValidPosts(posts);
    if (validPosts.isEmpty) {
      _FeedRankerLogger.warn('No valid posts after filtering',
          {'original': posts.length});
      return posts;
    }

    final scored = validPosts.map((post) {
      final score = _calculateScore(post, connectionIds, now);
      return (post: post, score: score);
    }).toList();

    // Tri décroissant par score
    scored.sort((a, b) => b.score.compareTo(a.score));

    final result = scored.map((e) => e.post).toList();

    _FeedRankerLogger.info('Smart ranking completed',
        {'posts': result.length, 'topScore': scored.first.score.toStringAsFixed(2)});

    return result;
  }

  /// Calcule le score d'un post avec protections
  static double _calculateScore(
    NetworkPost post,
    Set<String> connectionIds,
    DateTime now,
  ) {
    // 1. Affinité (0.0 à 1.0)
    final affinity = connectionIds.contains(post.userId)
        ? _kAffinityConnection
        : _kAffinityStranger;

    // 2. Poids des interactions
    final engagementScore = _calculateEngagementScore(post);

    // 3. Décroissance temporelle (demi-vie de 24h)
    final ageInHours = now.difference(post.createdAt).inHours.toDouble();

    // Protection : si post a une date future, clamp à 0
    final safeAgeInHours = ageInHours < 0 ? 0.0 : ageInHours;

    // Décroissance exponentielle : e^(-t/24)
    final decay = exp(-safeAgeInHours / _kDecayHalfLifeHours);

    // 4. Boost pour posts épinglés
    final pinBoost = post.isPinned ? _kPinBoost : 1.0;

    // 5. Boost pour posts avec médias
    final mediaBoost = post.hasMedia ? _kMediaBoost : 1.0;

    // Score final
    var score = affinity * engagementScore * decay * pinBoost * mediaBoost;

    // Protection contre NaN/Infinity
    if (score.isNaN || score.isInfinite) {
      _FeedRankerLogger.warn('Invalid score detected, using fallback',
          {'postId': post.id, 'score': '$score'});
      score = 0.0;
    }

    // Clamp entre min et max
    return score.clamp(_kMinScore, _kMaxScore);
  }

  /// Score d'engagement (likes + comments × 2)
  static double _calculateEngagementScore(NetworkPost post) {
    final likes = post.likesCount.toDouble();
    final comments = post.commentsCount.toDouble();

    return likes + (comments * _kCommentMultiplier);
  }

  /// Filtre les posts valides (createdAt non null, etc.)
  static List<NetworkPost> _filterValidPosts(List<NetworkPost> posts) {
    final valid = <NetworkPost>[];
    int invalidCount = 0;

    for (final post in posts) {
      try {
        // Validation minimale
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

  /// Tri par popularité (likes décroissants)
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

  /// Tri par récence (date décroissante)
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

    final connectionCount =
        sorted.where((p) => connectionIds.contains(p.userId)).length;

    _FeedRankerLogger.info('Network ranking completed',
        {'count': sorted.length, 'connections': connectionCount});

    return sorted;
  }
}
