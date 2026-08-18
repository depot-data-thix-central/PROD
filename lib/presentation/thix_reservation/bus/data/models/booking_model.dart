// lib/presentation/thix_reservation/bus/data/models/booking_model.dart
import 'bus_trip_model.dart';

class BookingModel {
  final String id;
  final String userId; // UID = THIX ID owner
  final String agencyId;
  final String tripId;
  final BusTripModel? trip;
  final List<String> seats;
  final int totalPriceFcfa;
  final String status; // pending_payment, confirmed, cancelled, completed
  final String qrCode;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.agencyId,
    required this.tripId,
    this.trip,
    required this.seats,
    required this.totalPriceFcfa,
    required this.status,
    required this.qrCode,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      agencyId: json['agency_id'] as String,
      tripId: json['trip_id'] as String,
      trip: json['bus_trips'] != null
          ? BusTripModel.fromJson(json['bus_trips'] as Map<String, dynamic>)
          : null,
      seats: (json['seats'] as List).cast<String>(),
      totalPriceFcfa: json['total_price_fcfa'] as int,
      status: json['status'] as String,
      qrCode: json['qr_code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
