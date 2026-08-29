import 'dart:math';
import 'package:thix_id/models/network_post.dart';

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
  if (posts.isEmpty) return posts;

  switch (feedType) {
    case 'popular':
      return _rankByPopularity(posts);
    case 'recent':
      return _rankByRecency(posts);
    case 'network':
      return _rankByNetwork(posts, connectionIds);
    case 'all':
    default:
      // ✅ Ordre déjà calculé par get_smart_feed (DB) — on ne re-trie PAS
      return posts;
  }
}
  /// Algorithme intelligent (Facebook-like)
  static List<NetworkPost> _rankBySmartAlgorithm(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    final scored = posts.map((post) {
      final score = _calculateScore(post, connectionIds, now);
      return (post: post, score: score);
    }).toList();

    // Tri décroissant par score
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.post).toList();
  }

  /// Calcule le score d'un post
  static double _calculateScore(
    NetworkPost post,
    Set<String> connectionIds,
    DateTime now,
  ) {
    // 1. Affinité (0.0 à 1.0)
    final affinity = connectionIds.contains(post.userId) ? 1.0 : 0.3;

    // 2. Poids des interactions
    final engagementScore = _calculateEngagementScore(post);

    // 3. Décroissance temporelle (demi-vie de 24h)
    final ageInHours = now.difference(post.createdAt).inHours.toDouble();
    final decay = exp(-ageInHours / 24.0); // e^(-t/24)

    // 4. Boost pour posts épinglés
    final pinBoost = post.isPinned ? 10.0 : 1.0;

    // 5. Boost pour posts avec médias
    final mediaBoost = post.hasMedia ? 1.2 : 1.0;

    // Score final
    return affinity * engagementScore * decay * pinBoost * mediaBoost;
  }

  /// Score d'engagement (likes + comments × 2)
  static double _calculateEngagementScore(NetworkPost post) {
    final likes = post.likesCount.toDouble();
    final comments = post.commentsCount.toDouble();

    return likes + (comments * 2.0);
  }

  /// Tri par popularité (likes décroissants)
  static List<NetworkPost> _rankByPopularity(List<NetworkPost> posts) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
    return sorted;
  }

  /// Tri par récence (date décroissante)
  static List<NetworkPost> _rankByRecency(List<NetworkPost> posts) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Tri par réseau (connexions d'abord, puis récence)
  static List<NetworkPost> _rankByNetwork(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) {
      final aIsConnection = connectionIds.contains(a.userId) ? 1 : 0;
      final bIsConnection = connectionIds.contains(b.userId) ? 1 : 0;

      if (aIsConnection != bIsConnection) {
        return bIsConnection.compareTo(aIsConnection);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}
