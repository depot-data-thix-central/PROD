// lib/presentation/thix_urgent/models/emergency_alert_model.dart
class EmergencyAlertModel {
  final String id;
  final String userId;
  final String type;
  final double? lat;
  final double? lng;
  final bool isLive;
  final DateTime createdAt;

  EmergencyAlertModel({
    required this.id,
    required this.userId,
    required this.type,
    this.lat,
    this.lng,
    this.isLive = true,
    required this.createdAt,
  });

  factory EmergencyAlertModel.fromJson(Map<String, dynamic> json) => EmergencyAlertModel(
    id: json['id'],
    userId: json['user_id'],
    type: json['type'],
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    isLive: json['is_live'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
  );
}
