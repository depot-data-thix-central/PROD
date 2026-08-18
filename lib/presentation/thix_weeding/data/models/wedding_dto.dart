// lib/presentation/thix_weeding/data/models/wedding_dto.dart
import '../../domain/entities/wedding_entity.dart';

class WeddingDto {
  final String id;
  final String brideName;
  final String groomName;
  final String dateIso;
  final String locationName;
  final String locationAddress;
  final double lat;
  final double lng;
  final String coverUrl;
  final String welcomeMessage;
  final String announcement;
  final bool giftEnabled;
  final bool galleryEnabled;
  final String createdAtIso;

  WeddingDto.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        brideName = json['bride_name'] as String? ?? '',
        groomName = json['groom_name'] as String? ?? '',
        dateIso = json['date'] as String,
        locationName = json['location_name'] as String? ?? '',
        locationAddress = json['location_address'] as String? ?? '',
        lat = (json['latitude'] as num?)?.toDouble() ?? 0.0,
        lng = (json['longitude'] as num?)?.toDouble() ?? 0.0,
        coverUrl = json['cover_url'] as String? ?? '',
        welcomeMessage = json['welcome_message'] as String? ?? '',
        announcement = json['announcement'] as String? ?? '',
        giftEnabled = json['is_gift_enabled'] as bool? ?? true,
        galleryEnabled = json['is_gallery_enabled'] as bool? ?? true,
        createdAtIso = json['created_at'] as String? ?? DateTime.now().toIso8601String();

  WeddingEntity toDomain() {
    return WeddingEntity(
      id: id,
      brideName: brideName,
      groomName: groomName,
      date: DateTime.parse(dateIso),
      locationName: locationName,
      locationAddress: locationAddress,
      latitude: lat,
      longitude: lng,
      coverImageUrl: coverUrl,
      welcomeMessage: welcomeMessage,
      announcement: announcement,
      isGiftEnabled: giftEnabled,
      isGalleryEnabled: galleryEnabled,
      createdAt: DateTime.parse(createdAtIso),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bride_name': brideName,
    'groom_name': groomName,
    'date': dateIso,
    'location_name': locationName,
    'location_address': locationAddress,
    'cover_url': coverUrl,
    'welcome_message': welcomeMessage,
  };
}
