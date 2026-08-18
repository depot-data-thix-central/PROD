import 'package:flutter/foundation.dart';

class Reservation {
  final String id;
  final String userId;
  final String serviceType; // 'bus', 'flight', 'hotel', 'taxi', 'delivery'
  final String status; // 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled'
  final DateTime reservationDate;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final String location;
  final String? destination;
  final int quantity;
  final double totalPrice;
  final String currency;
  final Map<String, dynamic> details; // Service-specific details
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final List<String>? photoIds; // References to storage

  Reservation({
    required this.id,
    required this.userId,
    required this.serviceType,
    required this.status,
    required this.reservationDate,
    required this.checkInDate,
    this.checkOutDate,
    required this.location,
    this.destination,
    required this.quantity,
    required this.totalPrice,
    required this.currency,
    required this.details,
    this.paymentStatus,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.photoIds,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      serviceType: json['service_type'] ?? 'bus',
      status: json['status'] ?? 'pending',
      reservationDate: json['reservation_date'] != null
          ? DateTime.parse(json['reservation_date'])
          : DateTime.now(),
      checkInDate: json['check_in_date'] != null
          ? DateTime.parse(json['check_in_date'])
          : DateTime.now(),
      checkOutDate: json['check_out_date'] != null
          ? DateTime.parse(json['check_out_date'])
          : null,
      location: json['location'] ?? '',
      destination: json['destination'],
      quantity: json['quantity'] ?? 1,
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      details: json['details'] ?? {},
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      notes: json['notes'],
      photoIds: List<String>.from(json['photo_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'service_type': serviceType,
      'status': status,
      'reservation_date': reservationDate.toIso8601String(),
      'check_in_date': checkInDate.toIso8601String(),
      'check_out_date': checkOutDate?.toIso8601String(),
      'location': location,
      'destination': destination,
      'quantity': quantity,
      'total_price': totalPrice,
      'currency': currency,
      'details': details,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'notes': notes,
      'photo_ids': photoIds,
    };
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? serviceType,
    String? status,
    DateTime? reservationDate,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    String? location,
    String? destination,
    int? quantity,
    double? totalPrice,
    String? currency,
    Map<String, dynamic>? details,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    List<String>? photoIds,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serviceType: serviceType ?? this.serviceType,
      status: status ?? this.status,
      reservationDate: reservationDate ?? this.reservationDate,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      location: location ?? this.location,
      destination: destination ?? this.destination,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      currency: currency ?? this.currency,
      details: details ?? this.details,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      photoIds: photoIds ?? this.photoIds,
    );
  }
}

class ReservationStatistics {
  final int upcomingCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  ReservationStatistics({
    required this.upcomingCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  factory ReservationStatistics.fromJson(Map<String, dynamic> json) {
    return ReservationStatistics(
      upcomingCount: json['upcoming'] ?? 0,
      inProgressCount: json['in_progress'] ?? 0,
      completedCount: json['completed'] ?? 0,
      cancelledCount: json['cancelled'] ?? 0,
    );
  }
}
