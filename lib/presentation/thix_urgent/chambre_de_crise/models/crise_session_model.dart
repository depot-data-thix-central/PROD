// lib/presentation/thix_urgent/chambre_de_crise/models/crise_session_model.dart
import 'package:equatable/equatable.dart';

class CriseSessionModel extends Equatable {
  final String id;
  final String userId;
  final String type;
  final List<String> guardianIds;
  final double? lat, lng;
  final bool isLive;
  final DateTime createdAt;
  final int photoCount;
  final int audioSeconds;

  const CriseSessionModel({
    required this.id, required this.userId, required this.type, this.guardianIds = const [],
    this.lat, this.lng, this.isLive = true, required this.createdAt, this.photoCount = 0, this.audioSeconds = 0,
  });

  factory CriseSessionModel.fromJson(Map<String, dynamic> json) => CriseSessionModel(
    id: json['id'], userId: json['user_id'], type: json['type'],
    guardianIds: List<String>.from(json['guardian_ids'] ?? []),
    lat: (json['lat'] as num?)?.toDouble(), lng: (json['lng'] as num?)?.toDouble(),
    isLive: json['is_live'] ?? true, createdAt: DateTime.parse(json['created_at']),
    photoCount: json['photo_count'] ?? 0, audioSeconds: json['audio_seconds'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'type': type, 'guardian_ids': guardianIds,
    'lat': lat, 'lng': lng, 'is_live': isLive, 'created_at': createdAt.toIso8601String(),
  };

  @override List<Object?> get props => [id, isLive, photoCount];
}
