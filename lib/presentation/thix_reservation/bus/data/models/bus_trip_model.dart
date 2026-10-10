import 'agency_model.dart';

/// ============================================================================
/// BusTripModel
/// ============================================================================
///
/// Représentation d'un trajet de bus dans le système THIX.
///
/// Utilisée pour :
/// - Recherche et filtrage de trajets
/// - Affichage dans les résultats de recherche
/// - Sélection de sièges
/// - Paiement et réservation
/// - Dashboard agence (gestion des trajets)
///
/// Features :
/// - Enums TripStatus et BusType type-safe
/// - Parsing JSON robuste (gestion null, types incorrects)
/// - Serialization bidirectionnelle (toJson/fromJson)
/// - Égalité structurelle (== et hashCode)
/// - CopyWith pour modifications immuables
/// - Getters utilitaires (durée, prix, disponibilité)
/// - Calculs automatiques (taux occupation, temps restant)
/// - Validation des champs
/// - Support multi-devises (prix en FCFA + conversion)
///
/// ============================================================================
class BusTripModel {
  // ─── Identifiants ─────────────────────────────────────────
  final String id;
  final String agencyId;
  final AgencyModel? agency;

  // ─── Itinéraire ───────────────────────────────────────────
  final String departureCity;
  final String arrivalCity;
  final String departureStation;
  final String arrivalStation;

  // ─── Horaires ─────────────────────────────────────────────
  final DateTime departureTime;
  final DateTime arrivalTime;

  // ─── Prix et capacité ─────────────────────────────────────
  final int priceFcfa;
  final int totalSeats;
  final int availableSeats;

  // ─── Configuration ────────────────────────────────────────
  final BusType busType;
  final List<String> amenities;

  // ─── État ─────────────────────────────────────────────────
  final TripStatus status;

  // ─── Métadonnées ──────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.busType = BusType.standard,
    this.amenities = const [],
    this.status = TripStatus.scheduled,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Factory from JSON ────────────────────────────────────
  factory BusTripModel.fromJson(Map<String, dynamic> json) {
    return BusTripModel(
      id: (json['id'] as String?) ?? '',
      agencyId: (json['agency_id'] as String?) ?? '',
      agency: json['agencies'] != null
          ? AgencyModel.fromJson(json['agencies'] as Map<String, dynamic>)
          : null,
      departureCity: (json['departure_city'] as String?) ?? '',
      arrivalCity: (json['arrival_city'] as String?) ?? '',
      departureStation: (json['departure_station'] as String?) ?? '',
      arrivalStation: (json['arrival_station'] as String?) ?? '',
      departureTime: _parseDateTimeRequired(json['departure_time']),
      arrivalTime: _parseDateTimeRequired(json['arrival_time']),
      priceFcfa: _parseIntSafe(json['price_fcfa']) ?? 0,
      totalSeats: _parseIntSafe(json['total_seats']) ?? 0,
      availableSeats: _parseIntSafe(json['available_seats']) ?? 0,
      busType: BusType.fromString(json['bus_type'] as String?),
      amenities: _parseStringListSafe(json['amenities']),
      status: TripStatus.fromString(json['status'] as String?),
      createdAt: _parseDateTimeSafe(json['created_at']),
      updatedAt: _parseDateTimeSafe(json['updated_at']),
    );
  }

  // ─── Serialization to JSON ────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agency_id': agencyId,
      if (agency != null) 'agencies': agency!.toJson(),
      'departure_city': departureCity,
      'arrival_city': arrivalCity,
      'departure_station': departureStation,
      'arrival_station': arrivalStation,
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime.toIso8601String(),
      'price_fcfa': priceFcfa,
      'total_seats': totalSeats,
      'available_seats': availableSeats,
      'bus_type': busType.value,
      'amenities': amenities,
      'status': status.value,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────
  BusTripModel copyWith({
    String? id,
    String? agencyId,
    AgencyModel? agency,
    String? departureCity,
    String? arrivalCity,
    String? departureStation,
    String? arrivalStation,
    DateTime? departureTime,
    DateTime? arrivalTime,
    int? priceFcfa,
    int? totalSeats,
    int? availableSeats,
    BusType? busType,
    List<String>? amenities,
    TripStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAgency = false,
  }) {
    return BusTripModel(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      agency: clearAgency ? null : (agency ?? this.agency),
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureStation: departureStation ?? this.departureStation,
      arrivalStation: arrivalStation ?? this.arrivalStation,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      priceFcfa: priceFcfa ?? this.priceFcfa,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      busType: busType ?? this.busType,
      amenities: amenities ?? this.amenities,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Getters d'état ───────────────────────────────────────

  /// Le trajet est-il programmé (futur) ?
  bool get isScheduled => status == TripStatus.scheduled;

  /// Le trajet est-il en cours (départ passé, arrivée future) ?
  bool get isDeparted => status == TripStatus.departed;

  /// Le trajet est-il terminé ?
  bool get isCompleted => status == TripStatus.completed;

  /// Le trajet est-il annulé ?
  bool get isCancelled => status == TripStatus.cancelled;

  /// Le trajet est-il actif (peut recevoir des réservations) ?
  bool get isActive =>
      status == TripStatus.scheduled &&
      departureTime.isAfter(DateTime.now()) &&
      availableSeats > 0;

  // ─── Getters de disponibilité ─────────────────────────────

  /// Le trajet est-il complet ?
  bool get isFull => availableSeats == 0;

  /// Le trajet est-il presque complet (≤5 places) ?
  bool get isAlmostFull => availableSeats > 0 && availableSeats <= 5;

  /// Taux d'occupation (0-100%)
  double get occupancyRate {
    if (totalSeats == 0) return 0;
    return ((totalSeats - availableSeats) / totalSeats) * 100;
  }

  /// Nombre de sièges réservés
  int get bookedSeatsCount => totalSeats - availableSeats;

  // ─── Getters de durée ─────────────────────────────────────

  /// Durée du trajet
  Duration get duration => arrivalTime.difference(departureTime);

  /// Durée formatée (ex: "3h45")
  String get durationLabel {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h${minutes.toString().padLeft(2, '0')}';
  }

  /// Durée en heures (décimal)
  double get durationInHours => duration.inMinutes / 60;

  /// Le trajet a-t-il déjà commencé ?
  bool get hasStarted => departureTime.isBefore(DateTime.now());

  /// Le trajet est-il terminé ?
  bool get hasEnded => arrivalTime.isBefore(DateTime.now());

  /// Temps restant avant le départ
  Duration get timeUntilDeparture {
    final diff = departureTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Label temps restant (ex: "Dans 2h30", "Parti", "Demain")
  String get departureLabel {
    if (hasStarted) return 'Parti';
    final diff = timeUntilDeparture;
    if (diff.inDays > 1) return 'Dans ${diff.inDays} jours';
    if (diff.inDays == 1) return 'Demain';
    if (diff.inHours > 0) return 'Dans ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Dans ${diff.inMinutes}min';
    return 'Imminent';
  }

  // ─── Getters de prix ──────────────────────────────────────

  /// Prix par siège (base)
  int get pricePerSeat => priceFcfa;

  /// Le trajet est-il VIP ?
  bool get isVip => busType == BusType.vip;

  /// Équipements formatés pour affichage
  String get amenitiesLabel {
    if (amenities.isEmpty) return 'Standard';
    return amenities.map((a) => a.toUpperCase()).join(', ');
  }

  /// Le trajet a-t-il un équipement spécifique ?
  bool hasAmenity(String amenity) {
    return amenities.any((a) => a.toLowerCase() == amenity.toLowerCase());
  }

  // ─── Getters utilitaires ──────────────────────────────────

  /// Label complet du trajet (ex: "Kinshasa → Matadi")
  String get routeLabel => '$departureCity → $arrivalCity';

  /// Le trajet est-il valide ?
  bool get isValid =>
      id.isNotEmpty &&
      agencyId.isNotEmpty &&
      departureCity.isNotEmpty &&
      arrivalCity.isNotEmpty &&
      departureCity != arrivalCity &&
      arrivalTime.isAfter(departureTime) &&
      totalSeats > 0 &&
      availableSeats >= 0 &&
      priceFcfa >= 0;

  /// Agence nom (fallback si agency null)
  String get agencyName => agency?.name ?? 'Agence';

  // ─── Égalité et hash ──────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusTripModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          agencyId == other.agencyId &&
          departureCity == other.departureCity &&
          arrivalCity == other.arrivalCity &&
          departureTime == other.departureTime &&
          arrivalTime == other.arrivalTime;

  @override
  int get hashCode => Object.hash(
        id,
        agencyId,
        departureCity,
        arrivalCity,
        departureTime,
        arrivalTime,
      );

  @override
  String toString() {
    return 'BusTripModel($routeLabel, ${durationLabel}, ${priceFcfa}FCFA, ${availableSeats}/${totalSeats} seats, ${status.value})';
  }

  // ─── Helpers de parsing ───────────────────────────────────
  static DateTime _parseDateTimeRequired(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    // Fallback : maintenant
    return DateTime.now();
  }

  static DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _parseStringListSafe(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is String) {
      // Support JSON stringifié : '["wifi","clim"]'
      try {
        final decoded = value.replaceAll("'", '"');
        final list = decoded.startsWith('[') ? decoded : '[$decoded]';
        final parsed = list.split(',').map((e) => e.trim().replaceAll('"', '')).toList();
        return parsed.where((e) => e.isNotEmpty).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }
}

/// ============================================================================
/// TripStatus — Enum des statuts de trajet
/// ============================================================================
enum TripStatus {
  scheduled('scheduled'),
  departed('departed'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const TripStatus(this.value);

  static TripStatus fromString(String? value) {
    if (value == null) return TripStatus.scheduled;
    final lower = value.toLowerCase();
    return TripStatus.values.firstWhere(
      (s) => s.value == lower,
      orElse: () => TripStatus.scheduled,
    );
  }

  String get label {
    switch (this) {
      case TripStatus.scheduled:
        return 'Programmé';
      case TripStatus.departed:
        return 'Parti';
      case TripStatus.completed:
        return 'Terminé';
      case TripStatus.cancelled:
        return 'Annulé';
    }
  }

  String get colorHex {
    switch (this) {
      case TripStatus.scheduled:
        return '#10B981';
      case TripStatus.departed:
        return '#3B82F6';
      case TripStatus.completed:
        return '#6B7280';
      case TripStatus.cancelled:
        return '#EF4444';
    }
  }
}

/// ============================================================================
/// BusType — Enum des types de bus
/// ============================================================================
enum BusType {
  standard('standard'),
  clim('clim'),
  vip('vip'),
  sleeper('sleeper');

  final String value;
  const BusType(this.value);

  static BusType fromString(String? value) {
    if (value == null) return BusType.standard;
    final lower = value.toLowerCase();
    return BusType.values.firstWhere(
      (t) => t.value == lower,
      orElse: () => BusType.standard,
    );
  }

  String get label {
    switch (this) {
      case BusType.standard:
        return 'Standard';
      case BusType.clim:
        return 'Climatisé';
      case BusType.vip:
        return 'VIP';
      case BusType.sleeper:
        return 'Couchette';
    }
  }

  String get icon {
    switch (this) {
      case BusType.standard:
        return '🚌';
      case BusType.clim:
        return '❄️';
      case BusType.vip:
        return '⭐';
      case BusType.sleeper:
        return '🛏️';
    }
  }
}

/// ============================================================================
/// BusTripListExtensions — Extensions utilitaires pour List<BusTripModel>
/// ============================================================================
extension BusTripListExtensions on List<BusTripModel> {
  /// Filtre les trajets actifs (programmés + places disponibles)
  List<BusTripModel> get active => where((t) => t.isActive).toList();

  /// Filtre les trajets à venir (départ futur)
  List<BusTripModel> get upcoming {
    final now = DateTime.now();
    return where((t) => t.departureTime.isAfter(now)).toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }

  /// Filtre les trajets passés
  List<BusTripModel> get past {
    final now = DateTime.now();
    return where((t) => t.departureTime.isBefore(now)).toList()
      ..sort((a, b) => b.departureTime.compareTo(a.departureTime));
  }

  /// Trie par prix croissant
  List<BusTripModel> sortByPriceAsc() {
    final sorted = List<BusTripModel>.from(this);
    sorted.sort((a, b) => a.priceFcfa.compareTo(b.priceFcfa));
    return sorted;
  }

  /// Trie par prix décroissant
  List<BusTripModel> sortByPriceDesc() {
    final sorted = List<BusTripModel>.from(this);
    sorted.sort((a, b) => b.priceFcfa.compareTo(a.priceFcfa));
    return sorted;
  }

  /// Trie par durée (plus court d'abord)
  List<BusTripModel> sortByDuration() {
    final sorted = List<BusTripModel>.from(this);
    sorted.sort((a, b) => a.duration.compareTo(b.duration));
    return sorted;
  }

  /// Trie par date de départ
  List<BusTripModel> sortByDeparture() {
    final sorted = List<BusTripModel>.from(this);
    sorted.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return sorted;
  }

  /// Groupe par agence
  Map<String, List<BusTripModel>> groupByAgency() {
    final map = <String, List<BusTripModel>>{};
    for (final trip in this) {
      map.putIfAbsent(trip.agencyId, () => []).add(trip);
    }
    return map;
  }

  /// Groupe par date
  Map<DateTime, List<BusTripModel>> groupByDate() {
    final map = <DateTime, List<BusTripModel>>{};
    for (final trip in this) {
      final date = DateTime(
        trip.departureTime.year,
        trip.departureTime.month,
        trip.departureTime.day,
      );
      map.putIfAbsent(date, () => []).add(trip);
    }
    return map;
  }

  /// Récupère le trajet le moins cher
  BusTripModel? get cheapest {
    if (isEmpty) return null;
    return reduce((a, b) => a.priceFcfa < b.priceFcfa ? a : b);
  }

  /// Récupère le trajet le plus rapide
  BusTripModel? get fastest {
    if (isEmpty) return null;
    return reduce((a, b) => a.duration < b.duration ? a : b);
  }

  /// Récupère le prochain départ
  BusTripModel? get nextDeparture {
    final future = upcoming;
    return future.isEmpty ? null : future.first;
  }

  /// Filtre par agence
  List<BusTripModel> byAgency(String agencyId) {
    return where((t) => t.agencyId == agencyId).toList();
  }

  /// Filtre par type de bus
  List<BusTripModel> byBusType(BusType type) {
    return where((t) => t.busType == type).toList();
  }

  /// Filtre par équipement
  List<BusTripModel> withAmenity(String amenity) {
    return where((t) => t.hasAmenity(amenity)).toList();
  }

  /// Prix moyen
  int get averagePrice {
    if (isEmpty) return 0;
    return (map((t) => t.priceFcfa).reduce((a, b) => a + b) / length).round();
  }

  /// Total sièges disponibles
  int get totalAvailableSeats {
    return map((t) => t.availableSeats).fold(0, (sum, seats) => sum + seats);
  }
}
