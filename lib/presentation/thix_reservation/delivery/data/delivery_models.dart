// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/data/delivery_models.dart
// ROLE: Contient tous les modèles du module DELIVERY
//       Fusion de 5 models en 1 pour scalabilité (1 fichier = 1 import)
//       Utilisé par providers, services et pages
// SCALABLE: immutable + copyWith + fromJson/toJson + calcul prix
// ================================================================

import 'package:flutter/foundation.dart';

// --------------------------------------------------------------
// ENUMS - Pour éviter les String magiques, type-safe
// --------------------------------------------------------------
enum DeliveryMode { standard, express, sameDay }
enum ShipmentStatus { pending, picked, inTransit, outForDelivery, delivered, cancelled, returned }
enum ParcelType { document, clothes, electronics, food, fragile, other }

// Extension pour affichage UI
extension DeliveryModeX on DeliveryMode {
  String get label => switch (this) {
    DeliveryMode.standard => 'Standard (2-3 jours)',
    DeliveryMode.express => 'Express (24-48h)',
    DeliveryMode.sameDay => 'Same Day (Jour même)',
  };
}

// --------------------------------------------------------------
// MODEL 1: DeliveryRoute - Le coeur du business
// C'est ici que l'ADMIN fixe le prix par trajet
// Ex: Abidjan -> Yamoussoukro = 3000F base + 500F/kg sup
// --------------------------------------------------------------
class DeliveryRoute {
  final String id;
  final String fromCity;
  final String toCity;
  final String fromCountry;
  final String toCountry;
  final int basePrice; // Prix pour 0-5kg en standard
  final int expressPrice; // Prix pour 0-5kg en express
  final int pricePerKg; // Supplément par kg au delà de 5kg
  final int distanceKm;
  final String standardDays;
  final String expressDays;
  final bool isInternational;
  final bool isActive;
  final DateTime createdAt;

  const DeliveryRoute({
    required this.id,
    required this.fromCity,
    required this.toCity,
    this.fromCountry = "Côte d'Ivoire",
    this.toCountry = "Côte d'Ivoire",
    required this.basePrice,
    required this.expressPrice,
    this.pricePerKg = 500,
    this.distanceKm = 0,
    this.standardDays = "2-3 jours",
    this.expressDays = "24-48h",
    this.isInternational = false,
    this.isActive = true,
    required this.createdAt,
  });

  // --- LOGIQUE METIER SCALABLE ---
  // Calcul prix final, utilisée partout côté client
  // Formule: si <=5kg = base, sinon base + (kg-5)*supplement
  int calculatePrice({required int weightKg, required DeliveryMode mode}) {
    // Choix du tarif selon le mode
    final base = mode == DeliveryMode.express ? expressPrice : basePrice;
    // Si poids léger, pas de supplément
    if (weightKg <= 5) return base;
    // Poids lourd: on ajoute supplément
    return base + ((weightKg - 5) * pricePerKg);
  }

  factory DeliveryRoute.fromJson(Map<String, dynamic> j) => DeliveryRoute(
    id: j['id'] as String,
    fromCity: j['from_city'] as String,
    toCity: j['to_city'] as String,
    fromCountry: j['from_country'] ?? "Côte d'Ivoire",
    toCountry: j['to_country'] ?? "Côte d'Ivoire",
    basePrice: j['base_price'] as int,
    expressPrice: j['express_price'] as int,
    pricePerKg: j['price_per_kg'] ?? 500,
    distanceKm: j['distance_km'] ?? 0,
    standardDays: j['standard_days'] ?? "2-3 jours",
    expressDays: j['express_days'] ?? "24-48h",
    isInternational: j['is_international'] ?? false,
    isActive: j['is_active'] ?? true,
    createdAt: DateTime.parse(j['created_at']),
  );

  Map<String, dynamic> toInsert() => {
    'from_city': fromCity,
    'to_city': toCity,
    'from_country': fromCountry,
    'to_country': toCountry,
    'base_price': basePrice,
    'express_price': expressPrice,
    'price_per_kg': pricePerKg,
    'distance_km': distanceKm,
    'is_international': isInternational,
  };
}

// --------------------------------------------------------------
// MODEL 2: DeliveryShipment - Un colis envoyé par un client
// --------------------------------------------------------------
class DeliveryShipment {
  final String id;
  final String trackingCode; // THX-XXXXXX affiché dans tracking page
  final String senderId;
  final String fromCity;
  final String toCity;
  final String receiverName;
  final String receiverPhone;
  final String receiverAddress;
  final ParcelType parcelType;
  final int weightKg;
  final DeliveryMode mode;
  final int finalPrice; // Prix calculé depuis DeliveryRoute
  final ShipmentStatus status;
  final DateTime createdAt;

  const DeliveryShipment({
    required this.id,
    required this.trackingCode,
    required this.senderId,
    required this.fromCity,
    required this.toCity,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverAddress,
    required this.parcelType,
    required this.weightKg,
    required this.mode,
    required this.finalPrice,
    required this.status,
    required this.createdAt,
  });

  factory DeliveryShipment.fromJson(Map<String, dynamic> j) => DeliveryShipment(
    id: j['id'],
    trackingCode: j['tracking_code'],
    senderId: j['sender_id'],
    fromCity: j['from_city'],
    toCity: j['to_city'],
    receiverName: j['receiver_name'] ?? '',
    receiverPhone: j['receiver_phone'] ?? '',
    receiverAddress: j['receiver_address'] ?? '',
    parcelType: ParcelType.values.firstWhere((e) => e.name == (j['parcel_type'] ?? 'other'), orElse: () => ParcelType.other),
    weightKg: j['weight_kg'] ?? 1,
    mode: DeliveryMode.values.firstWhere((e) => e.name == (j['delivery_mode'] ?? 'standard'), orElse: () => DeliveryMode.standard),
    finalPrice: j['price'] ?? 0,
    status: ShipmentStatus.values.firstWhere((e) => e.name == (j['status'] ?? 'pending'), orElse: () => ShipmentStatus.pending),
    createdAt: DateTime.parse(j['created_at']),
  );
}

// --------------------------------------------------------------
// MODEL 3 & 4: Offres + Tracking Events (fusionnés ici)
// --------------------------------------------------------------
class DeliveryOffer {
  final String id;
  final String title;
  final int discountPercent;
  final int newPrice;
  final int oldPrice;
  final String type; // express, standard, international, point_relais
  const DeliveryOffer({required this.id, required this.title, required this.discountPercent, required this.newPrice, required this.oldPrice, required this.type});
  factory DeliveryOffer.fromJson(Map<String, dynamic> j) => DeliveryOffer(
    id: j['id'], title: j['title'], discountPercent: j['discount_percent'] ?? 0,
    newPrice: j['new_price'] ?? 0, oldPrice: j['old_price'] ?? 0, type: j['type'] ?? 'standard',
  );
}

class TrackingEvent {
  final String status;
  final String location;
  final String description;
  final DateTime date;
  const TrackingEvent({required this.status, required this.location, required this.description, required this.date});
  factory TrackingEvent.fromJson(Map<String, dynamic> j) => TrackingEvent(
    status: j['status'], location: j['location'] ?? '', description: j['description'] ?? '', date: DateTime.parse(j['created_at']),
  );
}
