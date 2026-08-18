// lib/features/network/presentation/providers/feed_ranker.dart
import 'dart:math';

import 'package:thix_id/models/network_post.dart';

/// Ranking type Facebook (affinité + fraîcheur + engagement + diversité).
/// Pas de shuffle aléatoire.
class FeedRanker {
  FeedRanker._();

  /// [connectionIds] = utilisateurs connectés avec le viewer.
  /// [feedType] = all | network | popular | recent
  static List<NetworkPost> rank({
    required List<NetworkPost> posts,
    required Set<String> connectionIds,
    required String feedType,
  }) {
    if (posts.isEmpty) return posts;

    final scored = <({NetworkPost post, double score})>[];

    for (final p in posts) {
      final affinity = connectionIds.contains(p.userId) ? 1.0 : 0.0;

      final engagement = (p.likesCount * 1.0) +
          (p.commentsCount * 2.5) +
          (p.repostsCount * 3.0) +
          ((p.views ?? 0) * 0.02);

      final ageSec =
          DateTime.now().difference(p.createdAt).inSeconds.clamp(0, 1 << 30);
      // Demi-vie \~18h
      final freshness = exp(-ageSec / 64800.0);

      // Boost pin
      final pinBoost = p.isPinned ? 0.35 : 0.0;

      double score;
      switch (feedType) {
        case 'popular':
          score = engagement * 0.70 + freshness * 0.30 + pinBoost;
          break;
        case 'recent':
          score = freshness * 0.85 + engagement * 0.15 + pinBoost;
          break;
        case 'network':
          score = affinity * 0.45 +
              freshness * 0.35 +
              engagement * 0.20 +
              pinBoost;
          break;
        case 'all':
        default:
          score = affinity * 0.40 +
              freshness * 0.35 +
              engagement * 0.25 +
              pinBoost;
      }

      // Bruit faible + stable par jour (évite un feed identique sans tout mélanger)
      final day = DateTime.now().toUtc().day;
      score += _stableNoise(p.id, day) * 0.03;

      scored.add((post: p, score: score));
    }

    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return b.post.createdAt.compareTo(a.post.createdAt);
    });

    return _diversify(scored.map((e) => e.post).toList());
  }

  static double _stableNoise(String id, int day) {
    var h = day * 31;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 1000) / 1000.0;
  }

  /// Évite plus de 2 posts d'affilée du même auteur.
  static List<NetworkPost> _diversify(List<NetworkPost> input) {
    if (input.length < 3) return input;

    final out = <NetworkPost>[];
    final deferred = <NetworkPost>[];

    for (final p in input) {
      if (out.length >= 2 &&
          out[out.length - 1].userId == p.userId &&
          out[out.length - 2].userId == p.userId) {
        deferred.add(p);
      } else {
        out.add(p);
      }
    }

    // Réinsère les différés en respectant un peu la diversité
    for (final p in deferred) {
      var inserted = false;
      for (var i = 0; i < out.length; i++) {
        final prev = i > 0 ? out[i - 1].userId : null;
        final next = out[i].userId;
        if (p.userId != prev && p.userId != next) {
          out.insert(i, p);
          inserted = true;
          break;
        }
      }
      if (!inserted) out.add(p);
    }

    return out;
  }
}
