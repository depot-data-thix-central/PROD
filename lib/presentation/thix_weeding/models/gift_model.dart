// lib/presentation/thix_weeding/models/gift_model.dart
import 'package:flutter/foundation.dart';

/// Statuts:
/// - wishlist     : cadeau catalogue organisation
/// - proposed     : proposé par un invité (en attente staff)
/// - approved     : accepté par l'organisation
/// - rejected     : refusé
/// - group_active : collecte de groupe en cours (caché côté staff liste simple)
/// - completed    : collecté / offert
@immutable
class GiftItem {
  final String id;
  final String weddingId;
  final String name;
  final String? description;
  final String imageUrl;
  final double price;
  final double contributed;
  final bool isReserved;
  final String status;
  final String? proposedByGuestId;
  final String? proposedByName;
  final bool isGroupCollect;
  final String? groupLeaderGuestId;
  final DateTime? createdAt;

  const GiftItem({
    required this.id,
    required this.weddingId,
    required this.name,
    this.description,
    required this.imageUrl,
    required this.price,
    this.contributed = 0,
    this.isReserved = false,
    this.status = 'wishlist',
    this.proposedByGuestId,
    this.proposedByName,
    this.isGroupCollect = false,
    this.groupLeaderGuestId,
    this.createdAt,
  });

  double get remaining => (price - contributed).clamp(0, price);
  double get percent => price == 0 ? 0 : (contributed / price).clamp(0, 1);

  bool get isProposed => status == 'proposed';
  bool get isApproved => status == 'approved' || status == 'wishlist';
  bool get isRejected => status == 'rejected';
  bool get isGroupActive => status == 'group_active' || isGroupCollect;
  bool get isCompleted => status == 'completed' || contributed >= price;

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      imageUrl: (json['image_url'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      contributed: (json['contributed'] as num?)?.toDouble() ?? 0,
      isReserved: json['is_reserved'] as bool? ?? false,
      status: (json['status'] as String?) ?? 'wishlist',
      proposedByGuestId: json['proposed_by_guest_id'] as String?,
      proposedByName: json['proposed_by_name'] as String?,
      isGroupCollect: json['is_group_collect'] as bool? ?? false,
      groupLeaderGuestId: json['group_leader_guest_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'wedding_id': weddingId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'price': price,
        'contributed': contributed,
        'is_reserved': isReserved,
        'status': status,
        'proposed_by_guest_id': proposedByGuestId,
        'proposed_by_name': proposedByName,
        'is_group_collect': isGroupCollect,
        'group_leader_guest_id': groupLeaderGuestId,
      };
}

@immutable
class GiftContribution {
  final String id;
  final String giftId;
  final String? guestId;
  final String contributorName;
  final double amount;
  final DateTime createdAt;

  const GiftContribution({
    required this.id,
    required this.giftId,
    this.guestId,
    required this.contributorName,
    required this.amount,
    required this.createdAt,
  });

  factory GiftContribution.fromJson(Map<String, dynamic> j) => GiftContribution(
        id: j['id'] as String,
        giftId: j['gift_id'] as String,
        guestId: j['guest_id'] as String?,
        contributorName: (j['contributor_name'] as String?) ?? 'Anonyme',
        amount: (j['amount'] as num).toDouble(),
        createdAt: DateTime.parse(j['created_at'].toString()),
      );
}
