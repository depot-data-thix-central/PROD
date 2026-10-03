// lib/presentation/thix_market/models/live_session_model.dart
// ============================================================================
// LIVE SESSION MODEL — PROD Enterprise v2
// ============================================================================
// Nouveaux champs ajoutés pour le Live Shopping interactif :
//   - prePinnedProductIds  : produits épinglés automatiquement au démarrage
//   - allowVoting          : les spectateurs peuvent voter pour le prochain produit
//   - allowDynamicControl  : l'hôte peut pinner/unpinner en direct
// ============================================================================

class LiveSessionModel {
  final String id;
  final String shopId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String channelName;
  final String? token;
  final List<String> productIds;

  // ✅ NOUVEAU : contrôle dynamique
  final List<String> prePinnedProductIds;
  final bool allowVoting;
  final bool allowDynamicControl;

  final int viewerCount;
  final String status;
  final bool hasAuction;
  final double? startingPrice;
  final DateTime? auctionEndTime;
  final DateTime scheduledStart;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  LiveSessionModel({
    required this.id,
    required this.shopId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.channelName,
    this.token,
    required this.productIds,
    this.prePinnedProductIds = const [], // ✅ NOUVEAU
    this.allowVoting = true, // ✅ NOUVEAU
    this.allowDynamicControl = true, // ✅ NOUVEAU
    this.viewerCount = 0,
    required this.status,
    this.hasAuction = false,
    this.startingPrice,
    this.auctionEndTime,
    required this.scheduledStart,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  // ============================================================================
  // DÉSÉRIALISATION (JSON → Objet)
  // ============================================================================
  factory LiveSessionModel.fromJson(Map<String, dynamic> json) {
    return LiveSessionModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      channelName: json['channel_name'] as String,
      token: json['token'] as String?,
      productIds: List<String>.from(json['products'] ?? []),

      // ✅ NOUVEAU : parsing tolérant (colonnes peuvent manquer en DB legacy)
      prePinnedProductIds:
          List<String>.from(json['pre_pinned_products'] ?? const []),
      allowVoting: json['allow_voting'] as bool? ?? true,
      allowDynamicControl: json['allow_dynamic_control'] as bool? ?? true,

      viewerCount: json['viewer_count'] as int? ?? 0,
      status: json['status'] as String,
      hasAuction: json['has_auction'] as bool? ?? false,
      startingPrice: (json['starting_price'] as num?)?.toDouble(),
      auctionEndTime: json['auction_end_time'] != null
          ? DateTime.parse(json['auction_end_time'] as String)
          : null,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ============================================================================
  // SÉRIALISATION (Objet → JSON)
  // ============================================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'channel_name': channelName,
      'token': token,
      'products': productIds,

      // ✅ NOUVEAU
      'pre_pinned_products': prePinnedProductIds,
      'allow_voting': allowVoting,
      'allow_dynamic_control': allowDynamicControl,

      'viewer_count': viewerCount,
      'status': status,
      'has_auction': hasAuction,
      'starting_price': startingPrice,
      'auction_end_time': auctionEndTime?.toIso8601String(),
      'scheduled_start': scheduledStart.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ============================================================================
  // GETTERS UTILITAIRES
  // ============================================================================
  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isEnded => status == 'ended';
  bool get auctionActive =>
      hasAuction && auctionEndTime != null && auctionEndTime!.isAfter(DateTime.now());

  // ✅ NOUVEAU : helpers Live Shopping
  bool get hasPrePinned => prePinnedProductIds.isNotEmpty;
  bool get isInteractive => allowVoting || allowDynamicControl;

  /// Produits disponibles pour le pin (catalogue de base)
  List<String> get catalogProductIds => productIds;

  // ============================================================================
  // COPYWITH (immutable)
  // ============================================================================
  LiveSessionModel copyWith({
    String? id,
    String? shopId,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? channelName,
    String? token,
    List<String>? productIds,
    List<String>? prePinnedProductIds,
    bool? allowVoting,
    bool? allowDynamicControl,
    int? viewerCount,
    String? status,
    bool? hasAuction,
    double? startingPrice,
    DateTime? auctionEndTime,
    DateTime? scheduledStart,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
  }) {
    return LiveSessionModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelName: channelName ?? this.channelName,
      token: token ?? this.token,
      productIds: productIds ?? this.productIds,
      prePinnedProductIds: prePinnedProductIds ?? this.prePinnedProductIds,
      allowVoting: allowVoting ?? this.allowVoting,
      allowDynamicControl: allowDynamicControl ?? this.allowDynamicControl,
      viewerCount: viewerCount ?? this.viewerCount,
      status: status ?? this.status,
      hasAuction: hasAuction ?? this.hasAuction,
      startingPrice: startingPrice ?? this.startingPrice,
      auctionEndTime: auctionEndTime ?? this.auctionEndTime,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================================================================
  // ÉGALITÉ & HASHCODE
  // ============================================================================
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveSessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LiveSessionModel(id: $id, title: $title, status: $status, '
        'products: ${productIds.length}, prePinned: ${prePinnedProductIds.length}, '
        'voting: $allowVoting, dynamic: $allowDynamicControl, auction: $hasAuction)';
  }
}

// ============================================================================
// AUCTION BID MODEL (inchangé)
// ============================================================================
class AuctionBidModel {
  final String id;
  final String auctionId;
  final String userId;
  final double amount;
  final DateTime createdAt;

  AuctionBidModel({
    required this.id,
    required this.auctionId,
    required this.userId,
    required this.amount,
    required this.createdAt,
  });

  factory AuctionBidModel.fromJson(Map<String, dynamic> json) {
    return AuctionBidModel(
      id: json['id'] as String,
      auctionId: json['auction_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auction_id': auctionId,
      'user_id': userId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'AuctionBidModel(id: $id, amount: $amount)';
}
