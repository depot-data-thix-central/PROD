// lib/presentation/thix_reservation/bus/data/models/seat_model.dart
class SeatModel {
  final String id;
  final String tripId;
  final String seatNumber;
  final String status;
  final String? lockedBy;
  final DateTime? lockedUntil;
  final bool isVip;
  final int extraPrice;

  const SeatModel({
    required this.id,
    required this.tripId,
    required this.seatNumber,
    required this.status,
    this.lockedBy,
    this.lockedUntil,
    this.isVip = false,
    this.extraPrice = 0,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    final extra = json['extra_price'] ?? json['vip_supplement'] ?? json['supplement'] ?? 0;
    final parsedExtra = extra is int ? extra : int.tryParse(extra.toString()) ?? 0;
    final vipFlag = json['is_vip'] as bool? ?? false;

    return SeatModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      seatNumber: json['seat_number'] as String,
      status: json['status'] as String,
      lockedBy: json['locked_by'] as String?,
      lockedUntil: json['locked_until'] != null
          ? DateTime.tryParse(json['locked_until'] as String)
          : null,
      isVip: vipFlag || parsedExtra > 0,
      extraPrice: parsedExtra,
    );
  }

  bool get isAvailable => status == 'available' || status == 'locked';
  bool get isBooked => status == 'booked';
}
