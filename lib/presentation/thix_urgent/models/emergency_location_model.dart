// lib/presentation/thix_urgent/models/emergency_location_model.dart
class EmergencyLocationModel {
  final String criseId;
  final double lat;
  final double lng;
  final DateTime createdAt;

  EmergencyLocationModel({required this.criseId, required this.lat, required this.lng, required this.createdAt});

  factory EmergencyLocationModel.fromJson(Map<String, dynamic> json) => EmergencyLocationModel(
    criseId: json['crise_id'],
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at']),
  );
}
