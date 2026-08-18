// lib/presentation/thix_reservation/bus/data/models/seat_model.dart
class SeatModel {
  final String id;
  final String tripId;
  final String seatNumber; // A1, A2, B1...
  final String status; // available, locked, booked, blocked
  final String? lockedBy; // thix_id user qui a locké
  final DateTime? lockedUntil;
  final bool isVip;

  const SeatModel({
    required this.id,
    required this.tripId,
    required this.seatNumber,
    required this.status,
    this.lockedBy,
    this.lockedUntil,
    this.isVip = false,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    return SeatModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      seatNumber: json['seat_number'] as String,
      status: json['status'] as String,
      lockedBy: json['locked_by'] as String?,
      lockedUntil: json['locked_until'] != null
          ? DateTime.tryParse(json['locked_until'] as String)
          : null,
      isVip: json['is_vip'] as bool? ?? false,
    );
  }

  bool get isAvailable => status == 'available';
  bool get isBooked => status == 'booked';
}
