// lib/models/event_booking_limit.dart
class EventBookingLimit {
  final String eventId;
  final int maxPerPerson;      // Maximum par personne
  final int maxPerTransaction; // Maximum par transaction
  final bool requireIdVerification; // Vérification ID requis
  final int? memberOnlyLimit;   // Limite spéciale membres THIX
  final List<String> restrictedZones; // Zones restreintes

  EventBookingLimit({
    required this.eventId,
    required this.maxPerPerson,
    required this.maxPerTransaction,
    this.requireIdVerification = false,
    this.memberOnlyLimit,
    this.restrictedZones = const [],
  });

  factory EventBookingLimit.fromJson(Map<String, dynamic> json) {
    return EventBookingLimit(
      eventId: json['event_id'],
      maxPerPerson: json['max_per_person'],
      maxPerTransaction: json['max_per_transaction'],
      requireIdVerification: json['require_id_verification'] ?? false,
      memberOnlyLimit: json['member_only_limit'],
      restrictedZones: List<String>.from(json['restricted_zones'] ?? []),
    );
  }
}

class BookingAttempt {
  final String userId;
  final int quantity;
  final DateTime timestamp;
  final String eventId;

  BookingAttempt({
    required this.userId,
    required this.quantity,
    required this.timestamp,
    required this.eventId,
  });
}
