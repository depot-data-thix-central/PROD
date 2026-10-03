//lib/presentation/thix_market/models/live_shopping_models.dart
// lib/presentation/thix_market/models/live_shopping_models.dart
class LivePinnedProduct {
  final String id;
  final String sessionId;
  final String productId;
  final int position;
  final bool isFeatured;
  final DateTime pinnedAt;

  const LivePinnedProduct({
    required this.id,
    required this.sessionId,
    required this.productId,
    required this.position,
    required this.isFeatured,
    required this.pinnedAt,
  });

  factory LivePinnedProduct.fromJson(Map<String, dynamic> j) => LivePinnedProduct(
        id: j['id'].toString(),
        sessionId: j['session_id'].toString(),
        productId: j['product_id'].toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        isFeatured: j['is_featured'] == true,
        pinnedAt: DateTime.tryParse(j['pinned_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class LiveVoteCandidate {
  final String productId;
  final int voteCount;
  final bool viewerVoted;
  const LiveVoteCandidate({
    required this.productId,
    required this.voteCount,
    required this.viewerVoted,
  });
}
