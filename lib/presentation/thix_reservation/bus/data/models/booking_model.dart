import 'bus_trip_model.dart';

/// ============================================================================
/// BookingModel
/// ============================================================================
///
/// Représentation d'une réservation de bus dans le système THIX.
///
/// Utilisée pour :
/// - Gestion des réservations client
/// - Validation QR code (côté agence)
/// - Affichage dans "Mes réservations"
/// - Historique et statistiques
/// - Billet électronique (ticket)
///
/// Features :
/// - Enum BookingStatus type-safe (5 statuts)
/// - Parsing JSON robuste (gestion null, types multiples)
/// - Serialization bidirectionnelle (toJson/fromJson)
/// - Égalité structurelle (== et hashCode)
/// - CopyWith pour modifications immuables
/// - Getters utilitaires (validation, calculs, labels)
/// - Support multi-devises (prix en FCFA + conversion)
/// - Extensions List pour manipuler List<BookingModel>
/// - Gestion annulations et remboursements
///
/// ============================================================================
class BookingModel {
  // ─── Identifiants ─────────────────────────────────────────
  final String id;
  final String userId;
  final String agencyId;
  final String tripId;
  final BusTripModel? trip;

  // ─── Réservation ──────────────────────────────────────────
  final List<String> seats;
  final int totalPriceFcfa;
  final String? passengerName;

  // ─── Paiement ─────────────────────────────────────────────
  final BookingStatus status;
  final String qrCode;
  final String? paymentMethod;
  final String? paymentReference;

  // ─── Dates ────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? refundedAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.agencyId,
    required this.tripId,
    this.trip,
    required this.seats,
    required this.totalPriceFcfa,
    this.passengerName,
    required this.status,
    required this.qrCode,
    this.paymentMethod,
    this.paymentReference,
    required this.createdAt,
    this.confirmedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.refundedAt,
  });

  // ─── Factory from JSON ────────────────────────────────────
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      agencyId: (json['agency_id'] as String?) ?? '',
      tripId: (json['trip_id'] as String?) ?? '',
      trip: json['bus_trips'] != null
          ? BusTripModel.fromJson(json['bus_trips'] as Map<String, dynamic>)
          : null,
      seats: _parseStringListSafe(json['seats']),
      totalPriceFcfa: _parseIntSafe(json['total_price_fcfa']) ?? 0,
      passengerName: json['passenger_name'] as String?,
      status: BookingStatus.fromString(json['status'] as String?),
      qrCode: (json['qr_code'] as String?) ?? '',
      paymentMethod: json['payment_method'] as String?,
      paymentReference: json['payment_reference'] as String?,
      createdAt: _parseDateTimeRequired(json['created_at']),
      confirmedAt: _parseDateTimeSafe(json['confirmed_at']),
      cancelledAt: _parseDateTimeSafe(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      refundedAt: _parseDateTimeSafe(json['refunded_at']),
    );
  }

  // ─── Serialization to JSON ────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'agency_id': agencyId,
      'trip_id': tripId,
      if (trip != null) 'bus_trips': trip!.toJson(),
      'seats': seats,
      'total_price_fcfa': totalPriceFcfa,
      if (passengerName != null) 'passenger_name': passengerName,
      'status': status.value,
      'qr_code': qrCode,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentReference != null) 'payment_reference': paymentReference,
      'created_at': createdAt.toIso8601String(),
      if (confirmedAt != null) 'confirmed_at': confirmedAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (refundedAt != null) 'refunded_at': refundedAt!.toIso8601String(),
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────
  BookingModel copyWith({
    String? id,
    String? userId,
    String? agencyId,
    String? tripId,
    BusTripModel? trip,
    List<String>? seats,
    int? totalPriceFcfa,
    String? passengerName,
    BookingStatus? status,
    String? qrCode,
    String? paymentMethod,
    String? paymentReference,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? refundedAt,
    bool clearTrip = false,
    bool clearPassengerName = false,
    bool clearPaymentMethod = false,
    bool clearPaymentReference = false,
    bool clearConfirmedAt = false,
    bool clearCancelledAt = false,
    bool clearCancellationReason = false,
    bool clearRefundedAt = false,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      agencyId: agencyId ?? this.agencyId,
      tripId: tripId ?? this.tripId,
      trip: clearTrip ? null : (trip ?? this.trip),
      seats: seats ?? this.seats,
      totalPriceFcfa: totalPriceFcfa ?? this.totalPriceFcfa,
      passengerName: clearPassengerName ? null : (passengerName ?? this.passengerName),
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      paymentMethod: clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      paymentReference: clearPaymentReference ? null : (paymentReference ?? this.paymentReference),
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: clearConfirmedAt ? null : (confirmedAt ?? this.confirmedAt),
      cancelledAt: clearCancelledAt ? null : (cancelledAt ?? this.cancelledAt),
      cancellationReason: clearCancellationReason ? null : (cancellationReason ?? this.cancellationReason),
      refundedAt: clearRefundedAt ? null : (refundedAt ?? this.refundedAt),
    );
  }

  // ─── Getters d'état ───────────────────────────────────────

  /// La réservation est-elle en attente de paiement ?
  bool get isPendingPayment => status == BookingStatus.pendingPayment;

  /// La réservation est-elle confirmée (payée) ?
  bool get isConfirmed => status == BookingStatus.confirmed;

  /// La réservation est-elle annulée ?
  bool get isCancelled => status == BookingStatus.cancelled;

  /// La réservation est-elle terminée (trajet effectué) ?
  bool get isCompleted => status == BookingStatus.completed;

  /// La réservation est-elle remboursée ?
  bool get isRefunded => status == BookingStatus.refunded;

  /// La réservation est-elle active (peut être utilisée) ?
  bool get isActive =>
      (status == BookingStatus.confirmed || status == BookingStatus.completed) &&
      _isTripActive();

  /// La réservation peut-elle être annulée ?
  bool get canBeCancelled =>
      status == BookingStatus.confirmed &&
      _isTripFuture() &&
      !isRefunded;

  /// La réservation peut-elle être remboursée ?
  bool get canBeRefunded =>
      status == BookingStatus.cancelled &&
      refundedAt == null;

  // ─── Getters de calcul ────────────────────────────────────

  /// Nombre de sièges réservés
  int get seatsCount => seats.length;

  /// Prix par siège
  int get pricePerSeat => seatsCount > 0 ? (totalPriceFcfa / seatsCount).round() : 0;

  /// Frais de service THIX (estimé : 300 FCFA par booking)
  int get serviceFee => 300;

  /// Prix de base (sans frais de service)
  int get basePrice => totalPriceFcfa - serviceFee;

  /// Le trajet est-il dans le futur ?
  bool get isTripFuture {
    if (trip == null) return false;
    return trip!.departureTime.isAfter(DateTime.now());
  }

  /// Le trajet est-il passé ?
  bool get isTripPast {
    if (trip == null) return false;
    return trip!.departureTime.isBefore(DateTime.now());
  }

  // ─── Getters utilitaires ──────────────────────────────────

  /// Label formaté des sièges (ex: "12A, 12B")
  String get seatsLabel {
    if (seats.isEmpty) return 'Aucun';
    return seats.join(', ');
  }

  /// ID court pour affichage (8 premiers caractères)
  String get shortId => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  /// Nom du passager (fallback)
  String get displayName => passengerName ?? 'Passager';

  /// Label de statut pour affichage
  String get statusLabel => status.label;

  /// Couleur du statut (hex)
  String get statusColorHex => status.colorHex;

  /// Temps écoulé depuis la création
  Duration get age => DateTime.now().difference(createdAt);

  /// Label temps écoulé (ex: "Il y a 2h", "Hier")
  String get ageLabel {
    if (age.inDays > 7) return 'Il y a ${age.inDays} jours';
    if (age.inDays > 0) return age.inDays == 1 ? 'Hier' : 'Il y a ${age.inDays} jours';
    if (age.inHours > 0) return 'Il y a ${age.inHours}h';
    if (age.inMinutes > 0) return 'Il y a ${age.inMinutes}min';
    return "À l'instant";
  }

  /// La réservation est-elle valide ?
  bool get isValid =>
      id.isNotEmpty &&
      userId.isNotEmpty &&
      agencyId.isNotEmpty &&
      tripId.isNotEmpty &&
      seats.isNotEmpty &&
      totalPriceFcfa >= 0 &&
      qrCode.isNotEmpty;

  // ─── Helpers privés ───────────────────────────────────────

  bool _isTripActive() {
    if (trip == null) return false;
    return trip!.isActive;
  }

  bool _isTripFuture() {
    if (trip == null) return false;
    return trip!.departureTime.isAfter(DateTime.now());
  }

  // ─── Égalité et hash ──────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          tripId == other.tripId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, userId, tripId, status);

  @override
  String toString() {
    return 'BookingModel($shortId, $seatsCount seats, ${totalPriceFcfa}FCFA, ${status.value})';
  }

  // ─── Helpers de parsing ───────────────────────────────────
  static DateTime _parseDateTimeRequired(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
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
/// BookingStatus — Enum des statuts de réservation
/// ============================================================================
enum BookingStatus {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  completed('completed'),
  cancelled('cancelled'),
  refunded('refunded');

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromString(String? value) {
    if (value == null) return BookingStatus.pendingPayment;
    final lower = value.toLowerCase();
    return BookingStatus.values.firstWhere(
      (s) => s.value == lower,
      orElse: () => BookingStatus.pendingPayment,
    );
  }

  String get label {
    switch (this) {
      case BookingStatus.pendingPayment:
        return 'En attente';
      case BookingStatus.confirmed:
        return 'Confirmée';
      case BookingStatus.completed:
        return 'Terminée';
      case BookingStatus.cancelled:
        return 'Annulée';
      case BookingStatus.refunded:
        return 'Remboursée';
    }
  }

  String get colorHex {
    switch (this) {
      case BookingStatus.pendingPayment:
        return '#F59E0B'; // amber
      case BookingStatus.confirmed:
        return '#10B981'; // green
      case BookingStatus.completed:
        return '#6B7280'; // gray
      case BookingStatus.cancelled:
        return '#EF4444'; // red
      case BookingStatus.refunded:
        return '#3B82F6'; // blue
    }
  }

  String get icon {
    switch (this) {
      case BookingStatus.pendingPayment:
        return '⏳';
      case BookingStatus.confirmed:
        return '✓';
      case BookingStatus.completed:
        return '✔';
      case BookingStatus.cancelled:
        return '✗';
      case BookingStatus.refunded:
        return '↩';
    }
  }
}

/// ============================================================================
/// BookingListExtensions — Extensions utilitaires pour List<BookingModel>
/// ============================================================================
extension BookingListExtensions on List<BookingModel> {
  /// Filtre les réservations actives (confirmées + trajet futur)
  List<BookingModel> get active => where((b) => b.isActive).toList();

  /// Filtre les réservations confirmées
  List<BookingModel> get confirmed => where((b) => b.isConfirmed).toList();

  /// Filtre les réservations en attente de paiement
  List<BookingModel> get pending => where((b) => b.isPendingPayment).toList();

  /// Filtre les réservations annulées
  List<BookingModel> get cancelled => where((b) => b.isCancelled).toList();

  /// Filtre les réservations terminées
  List<BookingModel> get completed => where((b) => b.isCompleted).toList();

  /// Filtre les réservations remboursées
  List<BookingModel> get refunded => where((b) => b.isRefunded).toList();

  /// Trie par date de création (plus récent d'abord)
  List<BookingModel> sortByDateDesc() {
    final sorted = List<BookingModel>.from(this);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Trie par date de création (plus ancien d'abord)
  List<BookingModel> sortByDateAsc() {
    final sorted = List<BookingModel>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Trie par prix décroissant
  List<BookingModel> sortByPriceDesc() {
    final sorted = List<BookingModel>.from(this);
    sorted.sort((a, b) => b.totalPriceFcfa.compareTo(a.totalPriceFcfa));
    return sorted;
  }

  /// Trie par prix croissant
  List<BookingModel> sortByPriceAsc() {
    final sorted = List<BookingModel>.from(this);
    sorted.sort((a, b) => a.totalPriceFcfa.compareTo(b.totalPriceFcfa));
    return sorted;
  }

  /// Trie par date de départ du trajet
  List<BookingModel> sortByTripDate() {
    final sorted = List<BookingModel>.from(this);
    sorted.sort((a, b) {
      if (a.trip == null && b.trip == null) return 0;
      if (a.trip == null) return 1;
      if (b.trip == null) return -1;
      return a.trip!.departureTime.compareTo(b.trip!.departureTime);
    });
    return sorted;
  }

  /// Groupe par statut
  Map<BookingStatus, List<BookingModel>> groupByStatus() {
    final map = <BookingStatus, List<BookingModel>>{};
    for (final booking in this) {
      map.putIfAbsent(booking.status, () => []).add(booking);
    }
    return map;
  }

  /// Groupe par mois
  Map<String, List<BookingModel>> groupByMonth() {
    final map = <String, List<BookingModel>>{};
    for (final booking in this) {
      final key = '${booking.createdAt.year}-${booking.createdAt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(booking);
    }
    return map;
  }

  /// Groupe par agence
  Map<String, List<BookingModel>> groupByAgency() {
    final map = <String, List<BookingModel>>{};
    for (final booking in this) {
      map.putIfAbsent(booking.agencyId, () => []).add(booking);
    }
    return map;
  }

  /// Filtre par agence
  List<BookingModel> byAgency(String agencyId) {
    return where((b) => b.agencyId == agencyId).toList();
  }

  /// Filtre par utilisateur
  List<BookingModel> byUser(String userId) {
    return where((b) => b.userId == userId).toList();
  }

  /// Filtre par période
  List<BookingModel> inDateRange(DateTime start, DateTime end) {
    return where((b) =>
      b.createdAt.isAfter(start) && b.createdAt.isBefore(end)
    ).toList();
  }

  /// Total dépensé (réservations confirmées + complétées)
  int get totalSpent {
    return where((b) => b.isConfirmed || b.isCompleted)
        .fold(0, (sum, b) => sum + b.totalPriceFcfa);
  }

  /// Total remboursé
  int get totalRefunded {
    return where((b) => b.isRefunded)
        .fold(0, (sum, b) => sum + b.totalPriceFcfa);
  }

  /// Nombre total de sièges réservés
  int get totalSeats {
    return fold(0, (sum, b) => sum + b.seatsCount);
  }

  /// Prix moyen par réservation
  int get averagePrice {
    if (isEmpty) return 0;
    return (map((b) => b.totalPriceFcfa).reduce((a, b) => a + b) / length).round();
  }

  /// Réservation la plus chère
  BookingModel? get mostExpensive {
    if (isEmpty) return null;
    return reduce((a, b) => a.totalPriceFcfa > b.totalPriceFcfa ? a : b);
  }

  /// Réservation la moins chère
  BookingModel? get leastExpensive {
    if (isEmpty) return null;
    return reduce((a, b) => a.totalPriceFcfa < b.totalPriceFcfa ? a : b);
  }

  /// Prochains départs (réservations confirmées avec trajet futur)
  List<BookingModel> get upcomingDepartures {
    final now = DateTime.now();
    return where((b) =>
      b.isConfirmed &&
      b.trip != null &&
      b.trip!.departureTime.isAfter(now)
    ).toList()
      ..sort((a, b) => a.trip!.departureTime.compareTo(b.trip!.departureTime));
  }

  /// Stats par statut
  Map<String, int> get statsByStatus {
    final map = <String, int>{};
    for (final booking in this) {
      map[booking.status.value] = (map[booking.status.value] ?? 0) + 1;
    }
    return map;
  }
}
