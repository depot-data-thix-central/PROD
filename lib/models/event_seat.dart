// lib/models/event_seat.dart
import 'package:flutter/material.dart';

enum SeatStatus { available, reserved, sold, selected }
enum SeatCategory { standard, vip, gold, family }

class EventSeat {
  final String id;
  final String eventId;
  final String row;
  final int number;
  final SeatCategory category;
  final double price; // 🟢 Le vrai prix exact venant de Supabase
  final SeatStatus status;
  final String? reservedBy;
  final DateTime? reservedUntil;
  final int? bookingId;

  EventSeat({
    required this.id,
    required this.eventId,
    required this.row,
    required this.number,
    required this.category,
    required this.price,
    required this.status,
    this.reservedBy,
    this.reservedUntil,
    this.bookingId,
  });

  factory EventSeat.fromJson(Map<String, dynamic> json) {
    return EventSeat(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      row: json['row']?.toString() ?? 'A',
      number: json['number'] is int ? json['number'] : int.tryParse(json['number']?.toString() ?? '1') ?? 1,
      category: SeatCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['category']?.toString().toLowerCase() ?? 'standard'),
        orElse: () => SeatCategory.standard,
      ),
      price: (json['price'] != null) ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0,
      status: SeatStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status']?.toString().toLowerCase() ?? 'available'),
        orElse: () => SeatStatus.available,
      ),
      reservedBy: json['reserved_by']?.toString(),
      reservedUntil: json['reserved_until'] != null 
          ? DateTime.parse(json['reserved_until']) 
          : null,
      bookingId: json['booking_id'] is int ? json['booking_id'] : int.tryParse(json['booking_id']?.toString() ?? ''),
    );
  }

  String get displayName => '$row$number';

  // 🟢 COULEURS DYNAMIQUES PAR CATÉGORIE (En phase avec le design THIX)
  Color get categoryColor {
    switch (category) {
      case SeatCategory.standard:
        return const Color(0xFF10B981); // Vert émeraude
      case SeatCategory.vip:
        return const Color(0xFF8B5CF6); // Violet clair
      case SeatCategory.gold:
        return const Color(0xFFD4AF37); // Or / Gold
      case SeatCategory.family:
        return const Color(0xFF3B82F6); // Bleu
    }
  }

  // 🟢 CORRECTION DU PRIX : Renvoie directement le prix réel de la base de données sans multiplicateurs arbitraires
  double get categoryPrice => price;

  bool get isAvailable => status == SeatStatus.available;
  bool get isReserved => status == SeatStatus.reserved;
  bool get isSold => status == SeatStatus.sold;
  bool get isSelected => status == SeatStatus.selected;
}

class SeatSelection {
  final String eventId;
  final List<EventSeat> selectedSeats;
  final double totalPrice;

  SeatSelection({
    required this.eventId,
    required this.selectedSeats,
    required this.totalPrice,
  });

  int get totalSeats => selectedSeats.length;
}
