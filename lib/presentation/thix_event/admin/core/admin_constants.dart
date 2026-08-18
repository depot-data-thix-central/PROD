// lib/presentation/thix_event/admin/core/admin_constants.dart
class AdminConstants {
  // Pagination pour millions de rows
  static const int eventsPageSize = 20;
  static const int bookingsPageSize = 50;
  static const int seatsBatchSize = 200;

  // Cache
  static const Duration cacheDuration = Duration(minutes: 5);

  // Limites anti-crash
  static const int maxImageSizeMB = 5;
  static const int maxSeatGeneration = 10000; // Ne jamais générer 100k d'un coup

  // Dev Mode
  static const bool isDevOpenAccess = true; // Tu mettras false en prod
}
