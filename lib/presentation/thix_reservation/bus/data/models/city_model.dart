// lib/presentation/thix_reservation/bus/data/models/city_model.dart
class CityModel {
  final String id;
  final String name;
  final String countryCode;
  final String? imageUrl;

  const CityModel({
    required this.id,
    required this.name,
    required this.countryCode,
    this.imageUrl,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      countryCode: json['country_code'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}
