import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Ajouté pour l'insertion directe

import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

/// ============================================================================
/// AgencyDashboardState
/// ============================================================================
class AgencyDashboardState {
  final AgencyModel? myAgency;
  final List<BusTripModel> myTrips;
  final List<BookingModel> agencyBookings;

  final Map<String, dynamic>? statsToday;
  final Map<String, dynamic>? statsWeek;
  final Map<String, dynamic>? statsMonth;
  final Map<String, dynamic>? statsAll;

  final bool isLoading;
  final bool isRefreshing;
  final bool isCreating;
  final bool isUpdating;

  final _TripFilter? activeFilter;
  final _TripSort activeSort;

  final AgencyError? error;
  final DateTime? lastUpdated;

  const AgencyDashboardState({
    this.myAgency,
    this.myTrips = const [],
    this.agencyBookings = const [],
    this.statsToday,
    this.statsWeek,
    this.statsMonth,
    this.statsAll,
    this.isLoading = true,
    this.isRefreshing = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.activeFilter,
    this.activeSort = _TripSort.dateDesc,
    this.error,
    this.lastUpdated,
  });

  AgencyDashboardState copyWith({
    AgencyModel? myAgency,
    List<BusTripModel>? myTrips,
    List<BookingModel>? agencyBookings,
    Map<String, dynamic>? statsToday,
    Map<String, dynamic>? statsWeek,
    Map<String, dynamic>? statsMonth,
    Map<String, dynamic>? statsAll,
    bool? isLoading,
    bool? isRefreshing,
    bool? isCreating,
    bool? isUpdating,
    _TripFilter? activeFilter,
    _TripSort? activeSort,
    AgencyError? error,
    DateTime? lastUpdated,
    bool clearError = false,
    bool clearFilter = false,
  }) {
    return AgencyDashboardState(
      myAgency: myAgency ?? this.myAgency,
      myTrips: myTrips ?? this.myTrips,
      agencyBookings: agencyBookings ?? this.agencyBookings,
      statsToday: statsToday ?? this.statsToday,
      statsWeek: statsWeek ?? this.statsWeek,
      statsMonth: statsMonth ?? this.statsMonth,
      statsAll: statsAll ?? this.statsAll,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      activeSort: activeSort ?? this.activeSort,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasAgency => myAgency != null;
  bool get isAgencyActive => myAgency?.isActive == true;
  bool get isPending => myAgency?.isPending == true;
  bool get hasError => error != null;
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 5);
  }

  int get todayBookingsCount => statsToday?['bookings_count'] ?? 0;
  int get todayRevenue => statsToday?['revenue'] ?? 0;
  double get todayOccupancyRate => (statsToday?['occupancy_rate'] ?? 0).toDouble();

  int get weekBookingsCount => statsWeek?['bookings_count'] ?? 0;
  int get weekRevenue => statsWeek?['revenue'] ?? 0;

  int get monthBookingsCount => statsMonth?['bookings_count'] ?? 0;
  int get monthRevenue => statsMonth?['revenue'] ?? 0;

  int get totalBookingsCount => statsAll?['bookings_count'] ?? 0;
  int get totalRevenue => statsAll?['revenue'] ?? 0;

  List<BusTripModel> get filteredTrips {
    var trips = List<BusTripModel>.from(myTrips);

    if (activeFilter != null) {
      trips = trips.where((t) {
        switch (activeFilter!) {
          case _TripFilter.all: return true;
          case _TripFilter.scheduled: return t.status.name == 'scheduled';
          case _TripFilter.departed: return t.status.name == 'departed';
          case _TripFilter.cancelled: return t.status.name == 'cancelled';
          case _TripFilter.completed: return t.status.name == 'completed';
        }
      }).toList();
    }

    trips.sort((a, b) {
      switch (activeSort) {
        case _TripSort.dateAsc: return a.departureTime.compareTo(b.departureTime);
        case _TripSort.dateDesc: return b.departureTime.compareTo(a.departureTime);
        case _TripSort.priceAsc: return a.priceFcfa.compareTo(b.priceFcfa);
        case _TripSort.priceDesc: return b.priceFcfa.compareTo(a.priceFcfa);
        case _TripSort.seatsAsc: return a.availableSeats.compareTo(b.availableSeats);
        case _TripSort.seatsDesc: return b.availableSeats.compareTo(a.availableSeats);
      }
    });

    return trips;
  }

  List<BookingModel> get sortedBookings {
    final sorted = List<BookingModel>.from(agencyBookings);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<BusTripModel> get upcomingTrips {
    final now = DateTime.now();
    return myTrips
        .where((t) => t.status.name == 'scheduled' && t.departureTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }

  int get pendingDepartures => upcomingTrips.length;

  List<BusTripModel> get pastTrips {
    final now = DateTime.now();
    return myTrips
        .where((t) => t.departureTime.isBefore(now))
        .toList()
      ..sort((a, b) => b.departureTime.compareTo(a.departureTime));
  }

  Map<String, int> get bookingsByStatus {
    final map = <String, int>{};
    for (final b in agencyBookings) {
      final statusKey = b.status.name;
      map[statusKey] = (map[statusKey] ?? 0) + 1;
    }
    return map;
  }
}

enum _TripFilter { all, scheduled, departed, cancelled, completed }
enum _TripSort { dateAsc, dateDesc, priceAsc, priceDesc, seatsAsc, seatsDesc }

enum AgencyErrorType { network, unauthorized, notFound, validation, server, unknown }

class AgencyError {
  final AgencyErrorType type;
  final String message;
  final String? originalError;
  final DateTime timestamp;

  const AgencyError({
    required this.type,
    required this.message,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _Now();

  factory AgencyError.fromException(Object e) {
    final message = e.toString();
    final lower = message.toLowerCase();

    AgencyErrorType type;
    if (lower.contains('network') || lower.contains('timeout') || lower.contains('socket')) {
      type = AgencyErrorType.network;
    } else if (lower.contains('unauthorized') || lower.contains('401')) {
      type = AgencyErrorType.unauthorized;
    } else if (lower.contains('not found') || lower.contains('404')) {
      type = AgencyErrorType.notFound;
    } else if (lower.contains('validation') || lower.contains('400')) {
      type = AgencyErrorType.validation;
    } else if (lower.contains('500') || lower.contains('server')) {
      type = AgencyErrorType.server;
    } else {
      type = AgencyErrorType.unknown;
    }

    return AgencyError(
      type: type,
      message: _humanReadableMessage(type),
      originalError: message,
    );
  }

  static String _humanReadableMessage(AgencyErrorType type) {
    switch (type) {
      case AgencyErrorType.network: return 'Problème de connexion. Vérifiez votre réseau.';
      case AgencyErrorType.unauthorized: return 'Session expirée. Veuillez vous reconnecter.';
      case AgencyErrorType.notFound: return 'Ressource introuvable.';
      case AgencyErrorType.validation: return 'Données invalides. Vérifiez le formulaire.';
      case AgencyErrorType.server: return 'Erreur serveur. Réessayez dans quelques instants.';
      case AgencyErrorType.unknown: return 'Une erreur inattendue s\'est produite.';
    }
  }
}

class _Now implements DateTime {
  const _Now();
  @override
  noSuchMethod(Invocation invocation) => DateTime.now();
}

/// ============================================================================
/// AgencyDashboardNotifier
/// ============================================================================
class AgencyDashboardNotifier extends Notifier<AgencyDashboardState> {
  final BusAgencyService _service = BusAgencyService();
  static const Duration _timeout = Duration(seconds: 10);

  @override
  AgencyDashboardState build() => const AgencyDashboardState();

  Future<void> init({bool force = false}) async {
    if (!force && !state.isStale && state.hasAgency) {
      _log('Données encore fraîches, skip init');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final agency = await _service.getMyAgency().timeout(_timeout);

      if (agency != null) {
        final results = await Future.wait([
          _service.getMyTrips(agency.id).timeout(_timeout),
          _service.getAgencyBookings(agency.id).timeout(_timeout),
          _service.getDashboardStats(agency.id, period: 'today').timeout(_timeout),
          _service.getDashboardStats(agency.id, period: 'week').timeout(_timeout),
          _service.getDashboardStats(agency.id, period: 'month').timeout(_timeout),
          _service.getDashboardStats(agency.id, period: 'all').timeout(_timeout),
        ]);

        state = state.copyWith(
          myAgency: agency,
          myTrips: results[0] as List<BusTripModel>,
          agencyBookings: results[1] as List<BookingModel>,
          statsToday: results[2] as Map<String, dynamic>,
          statsWeek: results[3] as Map<String, dynamic>,
          statsMonth: results[4] as Map<String, dynamic>,
          statsAll: results[5] as Map<String, dynamic>,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
        _log('Init réussi : ${state.myTrips.length} trajets, ${state.agencyBookings.length} bookings');
      } else {
        state = const AgencyDashboardState(isLoading: false);
        _log('Aucune agence trouvée');
      }
    } catch (e) {
      _logError('Erreur init', e);
      state = state.copyWith(error: AgencyError.fromException(e), isLoading: false);
    }
  }

  Future<void> refresh() async {
    if (!state.hasAgency) return;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final results = await Future.wait([
        _service.getMyTrips(state.myAgency!.id).timeout(_timeout),
        _service.getAgencyBookings(state.myAgency!.id).timeout(_timeout),
      ]);

      state = state.copyWith(
        myTrips: results[0] as List<BusTripModel>,
        agencyBookings: results[1] as List<BookingModel>,
        isRefreshing: false,
        lastUpdated: DateTime.now(),
      );
      _log('Refresh réussi');
    } catch (e) {
      _logError('Erreur refresh', e);
      state = state.copyWith(error: AgencyError.fromException(e), isRefreshing: false);
    }
  }

  /// ✅ CORRECTION MAJEURE : Insertion directe avec owner_id et debug logs
  Future<bool> createMyAgency({
    required String name,
    required String countryCode,
    String? description,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non authentifié');
      }

      debugPrint('🔵 [DEBUG] Tentative de création d\'agence...');
      debugPrint('   - User ID: $userId');
      debugPrint('   - Name: $name');
      debugPrint('   - Country: $countryCode');

      // Insertion directe pour garantir que owner_id et status sont bien envoyés
      final response = await Supabase.instance.client
          .from('bus_agencies')
          .insert({
            'owner_id': userId,
            'name': name,
            'country_code': countryCode,
            'description': description ?? '',
            'status': 'active', // Mode test : auto-approbation
            'is_verified': true,
          })
          .select()
          .single()
          .timeout(_timeout);

      debugPrint('🟢 [DEBUG] Agence créée avec succès: $response');

      final newAgency = AgencyModel.fromJson(Map<String, dynamic>.from(response));
      
      state = state.copyWith(myAgency: newAgency, isCreating: false);
      await init(force: true);
      _log('Agence créée : ${newAgency.name}');
      return state.hasAgency;
      
    } catch (e, stack) {
      debugPrint('🔴 [DEBUG] ERREUR création agence: $e');
      debugPrint('Stack trace: $stack');
      
      _logError('Erreur création agence', e);
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isCreating: false,
      );
      return false;
    }
  }

  Future<bool> createTrip({
    required String from,
    required String to,
    required String departureStation,
    required String arrivalStation,
    required DateTime departureTime,
    required DateTime arrivalTime,
    required int price,
    required int totalSeats,
    required String busType,
    List<String> amenities = const [],
  }) async {
    if (state.myAgency == null || !state.isAgencyActive) {
      state = state.copyWith(
        error: const AgencyError(type: AgencyErrorType.validation, message: 'Agence non active'),
      );
      return false;
    }

    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final newTrip = await _service.createTrip(
        agencyId: state.myAgency!.id,
        from: from,
        to: to,
        departureStation: departureStation,
        arrivalStation: arrivalStation,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        price: price,
        totalSeats: totalSeats,
        busType: busType,
        amenities: amenities,
      ).timeout(_timeout);

      state = state.copyWith(
        myTrips: [newTrip, ...state.myTrips],
        isCreating: false,
        lastUpdated: DateTime.now(),
      );
      _log('Trajet créé : ${newTrip.id}');
      return true;
    } catch (e) {
      _logError('Erreur création trajet', e);
      state = state.copyWith(error: AgencyError.fromException(e), isCreating: false);
      return false;
    }
  }

  Future<bool> updateTripStatus(String tripId, String newStatus) async {
    if (state.myAgency == null) return false;
    state = state.copyWith(isUpdating: true, clearError: true);

    try {
      await _service.updateTripStatus(tripId, newStatus).timeout(_timeout);

      final parsedStatus = TripStatus.values.firstWhere(
        (e) => e.name == newStatus,
        orElse: () => TripStatus.scheduled,
      );

      final updatedTrips = state.myTrips.map((t) {
        if (t.id == tripId) {
          return BusTripModel(
            id: t.id,
            agencyId: t.agencyId,
            agency: t.agency,
            departureCity: t.departureCity,
            arrivalCity: t.arrivalCity,
            departureStation: t.departureStation,
            arrivalStation: t.arrivalStation,
            departureTime: t.departureTime,
            arrivalTime: t.arrivalTime,
            priceFcfa: t.priceFcfa,
            totalSeats: t.totalSeats,
            availableSeats: t.availableSeats,
            busType: t.busType,
            amenities: t.amenities,
            status: parsedStatus,
          );
        }
        return t;
      }).toList();

      state = state.copyWith(myTrips: updatedTrips, isUpdating: false, lastUpdated: DateTime.now());
      _log('Statut trajet $tripId → $newStatus');
      return true;
    } catch (e) {
      _logError('Erreur update statut trajet', e);
      state = state.copyWith(error: AgencyError.fromException(e), isUpdating: false);
      return false;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    if (state.myAgency == null) return false;
    state = state.copyWith(isUpdating: true, clearError: true);

    try {
      await _service.deleteTrip(tripId).timeout(_timeout);
      state = state.copyWith(
        myTrips: state.myTrips.where((t) => t.id != tripId).toList(),
        isUpdating: false,
        lastUpdated: DateTime.now(),
      );
      _log('Trajet supprimé : $tripId');
      return true;
    } catch (e) {
      _logError('Erreur suppression trajet', e);
      state = state.copyWith(error: AgencyError.fromException(e), isUpdating: false);
      return false;
    }
  }

  Future<BookingModel?> validateQr(String qrCode) async {
    if (state.myAgency == null) return null;
    state = state.copyWith(clearError: true);

    try {
      final booking = await _service.validateTicketByQr(state.myAgency!.id, qrCode).timeout(_timeout);

      final newBookings = List<BookingModel>.from(state.agencyBookings);
      final index = newBookings.indexWhere((b) => b.id == booking.id);

      if (index != -1) {
        newBookings[index] = booking;
      } else {
        newBookings.insert(0, booking);
      }

      state = state.copyWith(agencyBookings: newBookings, lastUpdated: DateTime.now());
      _log('QR validé : ${booking.id}');
      return booking;
    } catch (e) {
      _logError('Erreur validation QR', e);
      state = state.copyWith(error: AgencyError.fromException(e));
      return null;
    }
  }

  Future<bool> cancelBooking(String bookingId, String reason) async {
    if (state.myAgency == null) return false;
    state = state.copyWith(isUpdating: true, clearError: true);

    try {
      await _service.cancelBooking(bookingId, reason).timeout(_timeout);

      final updatedBookings = state.agencyBookings.map((b) {
        if (b.id == bookingId) {
          return BookingModel(
            id: b.id,
            tripId: b.tripId,
            userId: b.userId,
            seats: b.seats,
            totalPriceFcfa: b.totalPriceFcfa,
            status: BookingStatus.cancelled,
            qrCode: b.qrCode,
            createdAt: b.createdAt,
            passengerName: b.passengerName,
            trip: b.trip,
            agencyId: b.agencyId,
          );
        }
        return b;
      }).toList();

      state = state.copyWith(agencyBookings: updatedBookings, isUpdating: false, lastUpdated: DateTime.now());
      _log('Booking annulé : $bookingId');
      return true;
    } catch (e) {
      _logError('Erreur annulation booking', e);
      state = state.copyWith(error: AgencyError.fromException(e), isUpdating: false);
      return false;
    }
  }

  void setFilter(_TripFilter? filter) {
    state = state.copyWith(activeFilter: filter, clearFilter: filter == null);
    _log('Filtre défini : ${filter?.name ?? "aucun"}');
  }

  void setSort(_TripSort sort) {
    state = state.copyWith(activeSort: sort);
    _log('Tri défini : ${sort.name}');
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[AgencyDashboard] $message');
  }

  void _logError(String context, Object error) {
    if (kDebugMode) debugPrint('[AgencyDashboard] ❌ $context: $error');
  }
}

final agencyDashboardProvider = NotifierProvider<AgencyDashboardNotifier, AgencyDashboardState>(
  AgencyDashboardNotifier.new,
);

/// ============================================================================
/// AgencyModel
/// ============================================================================
class AgencyModel {
  final String id;
  final String ownerId;
  final String name;
  final String countryCode;
  final String? description;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;
  final AgencyStatus status;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? totalTrips;
  final int? totalBookings;
  final double? rating;

  const AgencyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.countryCode,
    this.description,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
    this.status = AgencyStatus.pending,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.totalTrips,
    this.totalBookings,
    this.rating,
  });

  factory AgencyModel.fromJson(Map<String, dynamic> json) {
    return AgencyModel(
      id: (json['id'] as String?) ?? '',
      ownerId: (json['owner_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Agence',
      countryCode: ((json['country_code'] as String?) ?? (json['countryCode'] as String?) ?? '').toUpperCase(),
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['logoUrl'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      status: AgencyStatus.fromString(json['status'] as String?),
      isVerified: _parseBoolSafe(json['is_verified'] ?? json['isVerified']),
      createdAt: _parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
      totalTrips: _parseIntSafe(json['total_trips']),
      totalBookings: _parseIntSafe(json['total_bookings']),
      rating: _parseDoubleSafe(json['rating']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'country_code': countryCode,
      if (description != null) 'description': description,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      'status': status.value,
      'is_verified': isVerified,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (totalTrips != null) 'total_trips': totalTrips,
      if (totalBookings != null) 'total_bookings': totalBookings,
      if (rating != null) 'rating': rating,
    };
  }

  AgencyModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? countryCode,
    String? description,
    String? logoUrl,
    String? phone,
    String? email,
    String? address,
    AgencyStatus? status,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTrips,
    int? totalBookings,
    double? rating,
    bool clearDescription = false,
    bool clearLogoUrl = false,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearAddress = false,
  }) {
    return AgencyModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      description: clearDescription ? null : (description ?? this.description),
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
      address: clearAddress ? null : (address ?? this.address),
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTrips: totalTrips ?? this.totalTrips,
      totalBookings: totalBookings ?? this.totalBookings,
      rating: rating ?? this.rating,
    );
  }

  bool get isActive => status == AgencyStatus.active;
  bool get isPending => status == AgencyStatus.pending;
  bool get isSuspended => status == AgencyStatus.suspended;
  bool get isRejected => status == AgencyStatus.rejected;
  bool get canCreateTrips => isActive && !isSuspended;
  bool get canReceiveBookings => isActive && isVerified;

  String get displayName {
    if (countryCode.isEmpty) return name;
    return '$name ($countryCode)';
  }

  String get initials {
    if (name.isEmpty) return 'A';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, words[0].length > 2 ? 2 : 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  String get flag {
    if (countryCode.isEmpty || countryCode.length != 2) return '🏢';
    final code = countryCode.toUpperCase();
    final base = 0x1F1E6;
    final first = base + (code.codeUnitAt(0) - 65);
    final second = base + (code.codeUnitAt(1) - 65);
    return String.fromCharCodes([first, second]);
  }

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
  bool get hasContact => phone != null || email != null;
  String get ratingLabel => rating != null ? '${rating!.toStringAsFixed(1)}/5' : 'N/A';
  bool get isValid => id.isNotEmpty && name.isNotEmpty && countryCode.length == 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgencyModel && runtimeType == other.runtimeType && id == other.id && ownerId == other.ownerId && name == other.name;

  @override
  int get hashCode => Object.hash(id, ownerId, name);

  @override
  String toString() {
    return 'AgencyModel($name, $countryCode, ${status.value}${isVerified ? ", verified" : ""})';
  }

  static bool _parseBoolSafe(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDoubleSafe(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

enum AgencyStatus {
  active('active'),
  pending('pending'),
  suspended('suspended'),
  rejected('rejected');

  final String value;
  const AgencyStatus(this.value);

  static AgencyStatus fromString(String? value) {
    if (value == null) return AgencyStatus.pending;
    final lower = value.toLowerCase();
    return AgencyStatus.values.firstWhere(
      (s) => s.value == lower,
      orElse: () => AgencyStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case AgencyStatus.active: return 'Active';
      case AgencyStatus.pending: return 'En attente';
      case AgencyStatus.suspended: return 'Suspendue';
      case AgencyStatus.rejected: return 'Refusée';
    }
  }

  String get colorHex {
    switch (this) {
      case AgencyStatus.active: return '#10B981';
      case AgencyStatus.pending: return '#F59E0B';
      case AgencyStatus.suspended: return '#6B7280';
      case AgencyStatus.rejected: return '#EF4444';
    }
  }
}
