// lib/presentation/thix_reservation/bus/data/models/bus_trip_model.dart
// lib/presentation/thix_reservation/bus/data/models/agency_model.dart
import 'agency_model.dart';

class BusTripModel {
  final String id;
  final String agencyId; // SaaS: clé multi-tenant
  final AgencyModel? agency; // Jointure pour affichage client
  final String departureCity;
  final String arrivalCity;
  final String departureStation;
  final String arrivalStation;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int priceFcfa;
  final int totalSeats;
  final int availableSeats;
  final String busType; // vip, standard, clim
  final List<String> amenities; // ['wifi','clim','usb']
  final String status; // scheduled, departed, cancelled

  const BusTripModel({
    required this.id,
    required this.agencyId,
    this.agency,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureStation,
    required this.arrivalStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.priceFcfa,
    required this.totalSeats,
    required this.availableSeats,
    required this.busType,
    this.amenities = const [],
    this.status = 'scheduled',
  });

  factory BusTripModel.fromJson(Map<String, dynamic> json) {
    return BusTripModel(
      id: json['id'] as String,
      agencyId: json['agency_id'] as String,
      agency: json['agencies'] != null
          ? AgencyModel.fromJson(json['agencies'] as Map<String, dynamic>)
          : null,
      departureCity: json['departure_city'] as String,
      arrivalCity: json['arrival_city'] as String,
      departureStation: json['departure_station'] as String? ?? '',
      arrivalStation: json['arrival_station'] as String? ?? '',
      departureTime: DateTime.parse(json['departure_time'] as String),
      arrivalTime: DateTime.parse(json['arrival_time'] as String),
      priceFcfa: json['price_fcfa'] as int,
      totalSeats: json['total_seats'] as int,
      availableSeats: json['available_seats'] as int,
      busType: json['bus_type'] as String? ?? 'standard',
      amenities: (json['amenities'] as List?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  bool get isAlmostFull => availableSeats > 0 && availableSeats <= 5;
  bool get isFull => availableSeats == 0;
  String get durationLabel {
    final diff = arrivalTime.difference(departureTime);
    return '${diff.inHours}h${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}
