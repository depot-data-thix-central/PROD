// lib/presentation/thix_urgent/models/emergency_photo_model.dart
class EmergencyPhotoModel {
  final String id;
  final String criseId;
  final String url;
  final DateTime createdAt;

  EmergencyPhotoModel({required this.id, required this.criseId, required this.url, required this.createdAt});

  factory EmergencyPhotoModel.fromJson(Map<String, dynamic> json) => EmergencyPhotoModel(
    id: json['id'].toString(),
    criseId: json['crise_id'],
    url: json['url'],
    createdAt: DateTime.parse(json['created_at']),
  );
}
