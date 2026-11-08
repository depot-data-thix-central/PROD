// lib/features/network/presentation/providers/feed_ranker.dart
//
// FeedRanker — Smart Mix "façon Facebook" (Production Enterprise v3)
//
// v3 :
//  ✅ Score "gravity" (style Hacker News / Facebook) :
//     engagement logarithmique / gravité temporelle → un vieux post très
//     aimé peut battre un post récent sans interaction, mais un post
//     récent remonte toujours vite grâce au freshness boost.
//  ✅ Mix par buckets d'âge : FRAIS (<6h) / TIÈDE (6-48h) / ANCIEN (>48h)
//     alternés par rounds (3 frais, 2 tièdes, 1 ancien) → le feed mélange
//     naturellement nouveautés et anciens posts performants.
//  ✅ Diversité auteurs : max 2 posts consécutifs du même auteur.
//  ✅ Épinglés : max 2 en top, les surplus retombent dans le mix.
//  ✅ Records positionnels remplacés par une classe privée _ScoredPost
//     (zéro risque d'erreur de type au build Web/WASM).
//
// v2 : Smart Mix buckets (records — erreur de type au build).
// v1 : EdgeRank classique.

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
// CONSTANTS (réglages du mix)
// ============================================================================

/// Fenêtre "fraîcheur" : un post de moins de 6h est boosté fortement.
const Duration _kFreshWindow = Duration(hours: 6);

/// Fenêtre "tiède" : entre 6h et 48h, boost modéré.
const Duration _kWarmWindow = Duration(hours: 48);

/// Multiplicateur de score pour un post FRAIS (< 6h).
const double _kFreshBoost = 2.2;

/// Multiplicateur de score pour un post TIÈDE (6h → 48h).
const double _kWarmBoost = 1.35;

/// Exposant de gravité temporelle (plus grand = les vieux posts coulent plus vite).
const double _kGravityExponent = 1.35;

/// Poids de l'engagement logarithmique (dampening anti-viral).
const double _kEngagementWeight = 6.0;

/// Affinité : post publié par une connexion.
const double _kAffinityConnection = 1.0;

/// Affinité : post publié hors connexion.
const double _kAffinityStranger = 0.35;

/// Multiplicateur commentaires (plus forts que les likes).
const double _kCommentMultiplier = 2.0;

/// Boost posts avec médias.
const double _kMediaBoost = 1.15;

/// Boost posts épinglés qui retombent dans le mix (au-delà du top épinglé).
const double _kPinBoost = 3.0;

/// Nombre max de posts épinglés affichés tout en haut.
const int _kMaxPinnedTop = 2;

/// Nombre max de posts consécutifs du même auteur.
const int _kMaxConsecutiveSameAuthor = 2;

/// Composition d'un round de mix : 3 frais + 2 tièdes + 1 ancien.
const int _kRoundFresh = 3;
const int _kRoundWarm = 2;
const int _kRoundOld = 1;

/// Bornes de score (anti NaN / extrêmes).
const double _kMinScore = 0.0;
const double _kMaxScore = 1000.0;

// ============================================================================
// SCORED POST (classe privée — pas de records, zéro risque de type)
// ============================================================================

class _ScoredPost {
  final NetworkPost post;
  final double score;
  const _ScoredPost(this.post, this.score);
}

// ============================================================================
// FEED RANKER
// ============================================================================

class FeedRanker {
  FeedRanker._();

  /// Point d'entrée : rank selon l'onglet.
  static List<NetworkPost> rank({
    required List<NetworkPost> posts,
    required Set<String> connectionIds,
    required String feedType,
  }) {
    if (posts.isEmpty) return posts;

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
        case 'all':
        default:
          // ✅ Onglet principal "Pour vous" → Smart Mix Facebook-like
          return _rankBySmartMix(posts, connectionIds);
      }
    } catch (e, stack) {
      _FeedRankerLogger.error('Ranking failed, returning original',
          {'feedType': feedType, 'error': '$e', 'stack': stack.toString()});
      return posts;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SMART MIX (façon Facebook)
  // ══════════════════════════════════════════════════════════════
  //
  // 1. Épinglés (max 2) tout en haut.
  // 2. Score "gravity" pour chaque post restant.
  // 3. Buckets d'âge : FRAIS / TIÈDE / ANCIEN, triés par score.
  // 4. Alternance par rounds : 3 frais, 2 tièdes, 1 ancien.
  // 5. Passe de diversité auteurs (max 2 consécutifs).
  //
  static List<NetworkPost> _rankBySmartMix(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final now = DateTime.now().toUtc();

    final valid = _filterValidPosts(posts);
    if (valid.isEmpty) return posts;

    // ── 1. Épinglés : max 2 en top, surplus → mix normal ──
    final pinnedAll = valid.where((p) => p.isPinned).toList();
    final topPinned = pinnedAll.take(_kMaxPinnedTop).toList();
    final overflowPinned = pinnedAll.skip(_kMaxPinnedTop).toList();

    final regular = [
      ...valid.where((p) => !p.isPinned),
      ...overflowPinned,
    ];

    // ── 2. Score gravity ──
    final scored = regular
        .map((p) => _ScoredPost(p, _score(p, connectionIds, now)))
        .toList();

    // ── 3. Buckets d'âge ──
    double ageOf(_ScoredPost e) =>
        now.difference(e.post.createdAt).inMinutes.toDouble() / 60.0;

    final fresh = scored.where((e) => ageOf(e) < _kFreshWindow.inHours).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final warm = scored
        .where((e) =>
            ageOf(e) >= _kFreshWindow.inHours &&
            ageOf(e) < _kWarmWindow.inHours)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final old = scored.where((e) => ageOf(e) >= _kWarmWindow.inHours).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    _FeedRankerLogger.info('SmartMix buckets',
        {'fresh': fresh.length, 'warm': warm.length, 'old': old.length});

    // ── 4. Alternance par rounds ──
    final mixed = <_ScoredPost>[];
    int fi = 0, wi = 0, oi = 0;

    while (fi < fresh.length || wi < warm.length || oi < old.length) {
      for (int i = 0; i < _kRoundFresh && fi < fresh.length; i++) {
        mixed.add(fresh[fi++]);
      }
      for (int i = 0; i < _kRoundWarm && wi < warm.length; i++) {
        mixed.add(warm[wi++]);
      }
      for (int i = 0; i < _kRoundOld && oi < old.length; i++) {
        mixed.add(old[oi++]);
      }
    }

    // ── 5. Diversité auteurs (max 2 consécutifs) ──
    final diversified = _applyAuthorDiversity(mixed);

    final result = <NetworkPost>[
      ...topPinned,
      ...diversified.map((e) => e.post),
    ];

    _FeedRankerLogger.info('SmartMix completed',
        {'total': result.length, 'pinnedTop': topPinned.length});

    return result;
  }

  /// Évite qu'un même auteur monopolise le feed :
  /// au-delà de [_kMaxConsecutiveSameAuthor] posts consécutifs, le post
  /// est déplacé juste après le prochain post d'un auteur différent.
  static List<_ScoredPost> _applyAuthorDiversity(List<_ScoredPost> input) {
    final result = <_ScoredPost>[];
    final deferred = <_ScoredPost>[];

    String? lastAuthor;
    int consecutive = 0;

    for (final sp in input) {
      final author = sp.post.userId;
      if (author == lastAuthor && consecutive >= _kMaxConsecutiveSameAuthor) {
        deferred.add(sp);
        continue;
      }
      if (author == lastAuthor) {
        consecutive++;
      } else {
        lastAuthor = author;
        consecutive = 1;
      }
      result.add(sp);
    }

    // Réinjecte les posts différés à la suite (ils restent visibles)
    result.addAll(deferred);
    return result;
  }

  /// Score "gravity" façon Facebook/Hacker News :
  ///
  ///   score = affinité × (1 + log(1+engagement)×poids) / (âge+2)^gravité
  ///           × boostFraîcheur × boostMédia × boostPin
  ///
  /// - log() empêche un post viral d'écraser tout le feed.
  /// - La gravité fait couler les vieux posts, mais un vieux post très
  ///   engagé reste visible (mix ancien/récent naturel).
  /// - Le freshness boost garantit que ta nouvelle publication remonte.
  static double _score(
    NetworkPost post,
    Set<String> connectionIds,
    DateTime now,
  ) {
    // Affinité
    final affinity = connectionIds.contains(post.userId)
        ? _kAffinityConnection
        : _kAffinityStranger;

    // Engagement dampené (likes + commentaires ×2)
    final engagement =
        post.likesCount.toDouble() + post.commentsCount.toDouble() * _kCommentMultiplier;
    final logEng = log(1.0 + engagement);

    // Âge en heures (protégé contre dates futures)
    final ageHours =
        max(0.0, now.difference(post.createdAt).inMinutes.toDouble() / 60.0);

    // Gravité temporelle
    final gravity = pow(ageHours + 2.0, _kGravityExponent).toDouble();

    // Score de base
    var score = affinity * ((1.0 + logEng * _kEngagementWeight) / gravity);

    // Boost fraîcheur
    if (ageHours < _kFreshWindow.inHours) {
      score *= _kFreshBoost;
    } else if (ageHours < _kWarmWindow.inHours) {
      score *= _kWarmBoost;
    }

    // Boost média
    if (post.hasMedia) score *= _kMediaBoost;

    // Boost épinglé (pour les épinglés retombés dans le mix)
    if (post.isPinned) score *= _kPinBoost;

    // Protections
    if (score.isNaN || score.isInfinite) score = 0.0;
    return score.clamp(_kMinScore, _kMaxScore);
  }

  // ══════════════════════════════════════════════════════════════
  // VALIDATION
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _filterValidPosts(List<NetworkPost> posts) {
    final valid = <NetworkPost>[];
    for (final post in posts) {
      if (post.id.isEmpty) continue;
      if (post.createdAt == null) continue;
      valid.add(post);
    }
    return valid;
  }

  // ══════════════════════════════════════════════════════════════
  // AUTRES ONGLETS (inchangés)
  // ══════════════════════════════════════════════════════════════

  static List<NetworkPost> _rankByPopularity(List<NetworkPost> posts) {
    final sorted = List<NetworkPost>.from(posts);
    sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
    return sorted;
  }

  static List<NetworkPost> _rankByRecency(List<NetworkPost> posts) {
    final valid = _filterValidPosts(posts);
    final sorted = List<NetworkPost>.from(valid);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static List<NetworkPost> _rankByNetwork(
    List<NetworkPost> posts,
    Set<String> connectionIds,
  ) {
    final valid = _filterValidPosts(posts);
    final sorted = List<NetworkPost>.from(valid);
    sorted.sort((a, b) {
      final aConn = connectionIds.contains(a.userId) ? 1 : 0;
      final bConn = connectionIds.contains(b.userId) ? 1 : 0;
      if (aConn != bConn) return bConn.compareTo(aConn);
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}
