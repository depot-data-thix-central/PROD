class LiveSessionModel {
  final String id;
  final String shopId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String channelName;
  final String? token;
  final List<String> productIds;
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

  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isEnded => status == 'ended';
  bool get auctionActive => hasAuction && auctionEndTime != null && auctionEndTime!.isAfter(DateTime.now());
}

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
}
