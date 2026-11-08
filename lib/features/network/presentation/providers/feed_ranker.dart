// lib/features/network/presentation/providers/feed_ranker.dart
//
// v2 :
//  ✅ SMART MIX — Algorithme hybride qui mélange intelligemment :
//     - Posts récents (< 4h) avec un "freshness boost"
//     - Posts anciens mais très engageants
//     - Posts épinglés toujours en top
//  ✅ Décroissance plus douce (demi-vie 48h au lieu de 24h)
//  ✅ Stratégie de "bucketing" : alterne entre buckets d'âge
//  ✅ Protection contre le "tout récent" ou "tout ancien"
//
// v1 : EdgeRank classique avec décroissance exponentielle.

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

/// ✅ NOUVEAU : Demi-vie de décroissance temporelle (en heures)
/// 48h au lieu de 24h pour une décroissance plus douce
const double _kDecayHalfLifeHours = 48.0;

/// ✅ NOUVEAU : Fenêtre de "fraîcheur" (posts boostés)
const Duration _kFreshnessWindow = Duration(hours: 4);

/// ✅ NOUVEAU : Boost multiplicateur pour les posts récents
const double _kFreshnessBoost = 2.5;

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

/// ✅ NOUVEAU : Ratio de posts récents dans le mix (60% récents, 40% anciens)
const double _kRecentPostsRatio = 0.6;

/// ✅ NOUVEAU : Taille des buckets pour le mélange (alterne tous les 5 posts)
const int _kBucketSize = 5;

// ============================================================================
// FEED RANKER (Production Enterprise v2 - Smart Mix)
// ============================================================================

/// Algorithme de ranking intelligent avec MIX INTELLIGENT
///
/// Stratégie :
/// 1. Calculer un score pour chaque post (EdgeRank amélioré)
/// 2. Diviser en 2 buckets : "récents" (< 4h) et "anciens" (>= 4h)
/// 3. Trier chaque bucket par score
/// 4. Alterner : 3 posts récents, 2 posts anciens, 3 récents, 2 anciens...
/// 5. Posts épinglés toujours en top (hors mix)
///
/// Résultat : feed dynamique avec nouveaux posts en avant + anciens performants
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
          // ✅ Algorithme Smart Mix activé
          return _rankBySmartMix(posts, connectionIds);
        case 'all':
        default:
          // ✅ Smart Mix pour le feed principal
          return _rankBySmartMix(posts, connectionIds);
      }
    } catch (e, stack) {
      _FeedRankerLogger.error('Ranking failed, returning original',
          {'feedType': feedType, 'error': '$e', 'stack': stack.toString()});
      return posts;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ SMART MIX ALGORITHM (NOUVEAU)
  // ══════════════════════════════════════════════════════════════

  /// Algorithme de mix intelligent :
  /// - Posts épinglés en top
  /// - Posts récents (< 4h) boostés et prioritaires
  /// - Posts anciens mais performants mélangés
  /// - Alternance intelligente pour éviter le "tout récent" ou "tout ancien"
  static List<NetworkPost> _rankBySmartMix(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    // 1. Validation : filtrer les posts invalides
    final validPosts = _filterValidPosts(posts);
    if (validPosts.isEmpty) {
      _FeedRankerLogger.warn('No valid posts after filtering',
          {'original': posts.length});
      return posts;
    }

    // 2. Séparer les posts épinglés (toujours en top)
    final pinnedPosts = validPosts.where((p) => p.isPinned).toList();
    final regularPosts = validPosts.where((p) => !p.isPinned).toList();

    // 3. Calculer les scores pour tous les posts réguliers
    final scored = regularPosts.map((post) {
      final score = _calculateScoreWithFreshness(post, connectionIds, now);
      return (post: post, score: score);
    }).toList();

    // 4. Diviser en 2 buckets : récents (< 4h) et anciens (>= 4h)
    final recentPosts = scored
        .where((e) => now.difference(e.post.createdAt) < _kFreshnessWindow)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final olderPosts = scored
        .where((e) => now.difference(e.post.createdAt) >= _kFreshnessWindow)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    _FeedRankerLogger.info('Smart Mix buckets',
        {'recent': recentPosts.length, 'older': olderPosts.length});

    // 5. Mélanger intelligemment avec alternance
    final mixed = _smartMix(recentPosts, olderPosts);

    // 6. Ajouter les posts épinglés en top
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

  /// ✅ NOUVEAU : Mélange intelligent avec alternance par buckets
  ///
  /// Stratégie : alterner entre posts récents et anciens
  /// Exemple avec bucket size = 5 :
  ///   [3 récents, 2 anciens, 3 récents, 2 anciens, ...]
  ///
  /// Si un bucket est épuisé, continuer avec l'autre
  static List<NetworkPost> _smartMix(
    List<(NetworkPost post, double score)> recent,
    List<(NetworkPost post, double score)> older,
  ) {
    final result = <NetworkPost>[];
    int recentIdx = 0;
    int olderIdx = 0;

    // Calculer le nombre de posts par bucket
    final recentPerBucket = (_kBucketSize * _kRecentPostsRatio).round();
    final olderPerBucket = _kBucketSize - recentPerBucket;

    _FeedRankerLogger.info('Smart Mix config',
        {
          'bucketSize': _kBucketSize,
          'recentPerBucket': recentPerBucket,
          'olderPerBucket': olderPerBucket,
        });

    // Alterner jusqu'à épuisement des deux listes
    while (recentIdx < recent.length || olderIdx < older.length) {
      // Prendre des posts récents
      for (int i = 0; i < recentPerBucket && recentIdx < recent.length; i++) {
        result.add(recent[recentIdx].post);
        recentIdx++;
      }

      // Prendre des posts anciens
      for (int i = 0; i < olderPerBucket && olderIdx < older.length; i++) {
        result.add(older[olderIdx].post);
        olderIdx++;
      }
    }

    return result;
  }

  /// ✅ NOUVEAU : Calcule le score avec freshness boost
  static double _calculateScoreWithFreshness(
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

    // 3. Décroissance temporelle (demi-vie de 48h - plus douce)
    final ageInHours = now.difference(post.createdAt).inHours.toDouble();
    final safeAgeInHours = ageInHours < 0 ? 0.0 : ageInHours;
    final decay = exp(-safeAgeInHours / _kDecayHalfLifeHours);

    // 4. ✅ NOUVEAU : Freshness boost pour posts < 4h
    final age = now.difference(post.createdAt);
    final freshnessBoost = age < _kFreshnessWindow ? _kFreshnessBoost : 1.0;

    // 5. Boost pour posts épinglés (déjà géré séparément, mais au cas où)
    final pinBoost = post.isPinned ? _kPinBoost : 1.0;

    // 6. Boost pour posts avec médias
    final mediaBoost = post.hasMedia ? _kMediaBoost : 1.0;

    // Score final avec freshness boost
    var score = affinity * engagementScore * decay * freshnessBoost * pinBoost * mediaBoost;

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
  // POPULARITY RANKING (inchangé)
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByPopularity(List<NetworkPost> posts) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));

    _FeedRankerLogger.info('Popularity ranking completed',
        {'count': sorted.length, 'topLikes': sorted.first.likesCount});

    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  // RECENCY RANKING (inchangé)
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
  // NETWORK RANKING (inchangé)
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
