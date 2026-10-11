import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/agency_model.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

// ============================================================================
// STATE
// ============================================================================
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
    return myTrips.where((t) => t.departureTime.isBefore(now)).toList()
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

// ============================================================================
// ENUMS
// ============================================================================
enum _TripFilter { all, scheduled, departed, cancelled, completed }

enum _TripSort { dateAsc, dateDesc, priceAsc, priceDesc, seatsAsc, seatsDesc }

enum AgencyErrorType { network, unauthorized, notFound, validation, server, unknown }

// ============================================================================
// AGENCY ERROR
// ============================================================================
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
  }) : timestamp = timestamp ?? DateTime.now();

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
    return AgencyError(type: type, message: _humanReadableMessage(type), originalError: message);
  }

  static String _humanReadableMessage(AgencyErrorType type) {
    switch (type) {
      case AgencyErrorType.network: return 'Problème de connexion.';
      case AgencyErrorType.unauthorized: return 'Session expirée.';
      case AgencyErrorType.notFound: return 'Ressource introuvable.';
      case AgencyErrorType.validation: return 'Données invalides.';
      case AgencyErrorType.server: return 'Erreur serveur.';
      case AgencyErrorType.unknown: return 'Une erreur inattendue s\'est produite.';
    }
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class AgencyDashboardNotifier extends Notifier<AgencyDashboardState> {
  final BusAgencyService _service = BusAgencyService();
  static const Duration _timeout = Duration(seconds: 10);

  @override
  AgencyDashboardState build() => const AgencyDashboardState();

  Future<void> init({bool force = false}) async {
    if (!force && !state.isStale && state.hasAgency) return;
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
      } else {
        state = const AgencyDashboardState(isLoading: false);
      }
    } catch (e) {
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
    } catch (e) {
      state = state.copyWith(error: AgencyError.fromException(e), isRefreshing: false);
    }
  }

  Future<bool> createMyAgency({
    required String name,
    required String countryCode,
    String? description,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non authentifié');

      debugPrint('🔵 [DEBUG] Création agence - userId: $userId, name: $name');

      final response = await Supabase.instance.client
          .from('bus_agencies')
          .insert({
            'owner_id': userId,
            'name': name,
            'country_code': countryCode,
            'description': description ?? '',
            'status': 'active',
            'is_verified': true,
          })
          .select()
          .single()
          .timeout(_timeout);

      debugPrint('🟢 [DEBUG] Agence créée: $response');

      // ✅ Utilisation de AgencyModel.fromJson (importé depuis data/models)
      final newAgency = AgencyModel.fromJson(Map<String, dynamic>.from(response));
      state = state.copyWith(myAgency: newAgency, isCreating: false);
      await init(force: true);
      return state.hasAgency;
    } catch (e, stack) {
      debugPrint('🔴 [DEBUG] ERREUR création agence: $e\n$stack');
      state = state.copyWith(error: AgencyError.fromException(e), isCreating: false);
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
      state = state.copyWith(error: const AgencyError(type: AgencyErrorType.validation, message: 'Agence non active'));
      return false;
    }
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final newTrip = await _service.createTrip(
        agencyId: state.myAgency!.id, from: from, to: to,
        departureStation: departureStation, arrivalStation: arrivalStation,
        departureTime: departureTime, arrivalTime: arrivalTime,
        price: price, totalSeats: totalSeats, busType: busType, amenities: amenities,
      ).timeout(_timeout);
      state = state.copyWith(myTrips: [newTrip, ...state.myTrips], isCreating: false, lastUpdated: DateTime.now());
      return true;
    } catch (e) {
      state = state.copyWith(error: AgencyError.fromException(e), isCreating: false);
      return false;
    }
  }

  Future<bool> updateTripStatus(String tripId, String newStatus) async {
    if (state.myAgency == null) return false;
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      await _service.updateTripStatus(tripId, newStatus).timeout(_timeout);
      final parsedStatus = TripStatus.values.firstWhere((e) => e.name == newStatus, orElse: () => TripStatus.scheduled);
      final updatedTrips = state.myTrips.map((t) {
        if (t.id == tripId) {
          return BusTripModel(
            id: t.id, agencyId: t.agencyId, agency: t.agency,
            departureCity: t.departureCity, arrivalCity: t.arrivalCity,
            departureStation: t.departureStation, arrivalStation: t.arrivalStation,
            departureTime: t.departureTime, arrivalTime: t.arrivalTime,
            priceFcfa: t.priceFcfa, totalSeats: t.totalSeats, availableSeats: t.availableSeats,
            busType: t.busType, amenities: t.amenities, status: parsedStatus,
          );
        }
        return t;
      }).toList();
      state = state.copyWith(myTrips: updatedTrips, isUpdating: false, lastUpdated: DateTime.now());
      return true;
    } catch (e) {
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
      return true;
    } catch (e) {
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
      if (index != -1) newBookings[index] = booking;
      else newBookings.insert(0, booking);
      state = state.copyWith(agencyBookings: newBookings, lastUpdated: DateTime.now());
      return booking;
    } catch (e) {
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
            id: b.id, tripId: b.tripId, userId: b.userId, seats: b.seats,
            totalPriceFcfa: b.totalPriceFcfa, status: BookingStatus.cancelled,
            qrCode: b.qrCode, createdAt: b.createdAt, passengerName: b.passengerName,
            trip: b.trip, agencyId: b.agencyId,
          );
        }
        return b;
      }).toList();
      state = state.copyWith(agencyBookings: updatedBookings, isUpdating: false, lastUpdated: DateTime.now());
      return true;
    } catch (e) {
      state = state.copyWith(error: AgencyError.fromException(e), isUpdating: false);
      return false;
    }
  }

  void setFilter(_TripFilter? filter) {
    state = state.copyWith(activeFilter: filter, clearFilter: filter == null);
  }

  void setSort(_TripSort sort) {
    state = state.copyWith(activeSort: sort);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final agencyDashboardProvider = NotifierProvider<AgencyDashboardNotifier, AgencyDashboardState>(
  AgencyDashboardNotifier.new,
);
