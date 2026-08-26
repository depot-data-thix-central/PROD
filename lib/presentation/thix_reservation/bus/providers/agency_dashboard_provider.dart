// lib/presentation/thix_reservation/bus/providers/agency_dashboard_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agency_model.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

class AgencyDashboardState {
  final AgencyModel? myAgency;
  final List<BusTripModel> myTrips;
  final List<BookingModel> agencyBookings;
  final Map<String, dynamic>? stats;

  final bool isLoading;
  final bool isCreating;
  final String? error;

  const AgencyDashboardState({
    this.myAgency,
    this.myTrips = const [],
    this.agencyBookings = const [],
    this.stats,
    this.isLoading = true,
    this.isCreating = false,
    this.error,
  });

  AgencyDashboardState copyWith({
    AgencyModel? myAgency,
    List<BusTripModel>? myTrips,
    List<BookingModel>? agencyBookings,
    Map<String, dynamic>? stats,
    bool? isLoading,
    bool? isCreating,
    String? error,
    bool clearError = false,
  }) {
    return AgencyDashboardState(
      myAgency: myAgency ?? this.myAgency,
      myTrips: myTrips ?? this.myTrips,
      agencyBookings: agencyBookings ?? this.agencyBookings,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasAgency => myAgency != null;
  bool get isAgencyActive => myAgency?.isActive == true;
  bool get isPending => myAgency?.isPending == true;

  int get todayBookingsCount => stats?['bookings_today'] ?? 0;
  int get todayRevenue => stats?['revenue_today'] ?? 0;
  int get pendingDepartures => myTrips
      .where((t) => t.status == 'scheduled' && t.departureTime.isAfter(DateTime.now()))
      .length;
}

class AgencyDashboardNotifier extends Notifier<AgencyDashboardState> {
  final BusAgencyService _service = BusAgencyService();

  @override
  AgencyDashboardState build() => const AgencyDashboardState();

  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final agency = await _service.getMyAgency();

      if (agency != null) {
        final results = await Future.wait([
          _service.getMyTrips(agency.id),
          _service.getAgencyBookings(agency.id),
          _service.getDashboardStats(agency.id),
        ]);

        state = state.copyWith(
          myAgency: agency,
          myTrips: results[0] as List<BusTripModel>,
          agencyBookings: results[1] as List<BookingModel>,
          stats: results[2] as Map<String, dynamic>,
          isLoading: false,
        );
      } else {
        state = const AgencyDashboardState(isLoading: false);
      }
    } catch (e) {
      debugPrint('Erreur chargement agence: $e');
      state = state.copyWith(
        error: 'Erreur chargement agence: $e',
        isLoading: false,
      );
    }
  }

  Future<bool> createMyAgency({
    required String name,
    required String countryCode,
    String? description,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final newAgency = await _service.createAgency(
        name: name,
        countryCode: countryCode,
        description: description,
        autoApprove: true,
      );

      state = state.copyWith(myAgency: newAgency, isCreating: false);
      await init();
      return state.hasAgency;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
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
  }) async {
    if (state.myAgency == null || !state.isAgencyActive) return false;

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
      );

      state = state.copyWith(
        myTrips: [newTrip, ...state.myTrips],
        isCreating: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isCreating: false,
      );
      return false;
    }
  }

  Future<BookingModel?> validateQr(String qrCode) async {
    if (state.myAgency == null) return null;

    try {
      final booking = await _service.validateTicketByQr(state.myAgency!.id, qrCode);

      final newBookings = List<BookingModel>.from(state.agencyBookings);
      final index = newBookings.indexWhere((b) => b.id == booking.id);

      if (index != -1) {
        newBookings[index] = booking;
        state = state.copyWith(agencyBookings: newBookings);
      }

      return booking;
    } catch (e) {
      state = state.copyWith(
        error: 'Ticket invalide ou déjà utilisé: $e',
      );
      return null;
    }
  }
}

final agencyDashboardProvider =
    NotifierProvider<AgencyDashboardNotifier, AgencyDashboardState>(
  AgencyDashboardNotifier.new,
);
