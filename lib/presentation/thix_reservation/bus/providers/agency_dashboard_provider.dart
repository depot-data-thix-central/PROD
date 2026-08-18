// lib/presentation/thix_reservation/bus/providers/agency_dashboard_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agency_model.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

// ─────────────────────────────────────────────────────────────
// ÉTAT IMMUABLE DU DASHBOARD AGENCE
// ─────────────────────────────────────────────────────────────
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

  // --- Getters Utilitaires ---
  bool get hasAgency => myAgency != null;
  bool get isAgencyActive => myAgency?.status == 'active';
  bool get isPending => myAgency?.status == 'pending';

  int get todayBookingsCount => stats?['bookings_today'] ?? 0;
  int get todayRevenue => stats?['revenue_today'] ?? 0;
  int get pendingDepartures => myTrips
      .where((t) => t.status == 'scheduled' && t.departureTime.isAfter(DateTime.now()))
      .length;
}

// ─────────────────────────────────────────────────────────────
// NOTIFIER (Logique Métier)
// ─────────────────────────────────────────────────────────────
class AgencyDashboardNotifier extends Notifier<AgencyDashboardState> {
  final BusAgencyService _service = BusAgencyService();

  @override
  AgencyDashboardState build() {
    // État initial (le init sera appelé par l'UI)
    return const AgencyDashboardState();
  }

  // --- INIT : Chargé dès que l'utilisateur clique sur "Espace Agence" ---
  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final agency = await _service.getMyAgency();

      if (agency != null) {
        // Charge tout en parallèle pour de meilleures performances
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
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Erreur chargement agence: $e');
      state = state.copyWith(
        error: 'Erreur chargement agence: $e',
        isLoading: false,
      );
    }
  }

  // --- Création Agence (Onboarding SaaS) ---
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
      );

      state = state.copyWith(myAgency: newAgency);
      
      // Recharge les stats et listes vides après création
      await init();
      
      state = state.copyWith(isCreating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isCreating: false,
      );
      return false;
    }
  }

  // --- Création Trajet ---
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
    if (state.myAgency == null) return false;

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

      // On ajoute le nouveau trajet en tête de liste sans recharger toute la DB
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

  // --- Validation Ticket QR ---
  Future<BookingModel?> validateQr(String qrCode) async {
    if (state.myAgency == null) return null;

    try {
      final booking = await _service.validateTicketByQr(state.myAgency!.id, qrCode);
      
      // Met à jour la liste locale immuable
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

// ─────────────────────────────────────────────────────────────
// PROVIDER GLOBAL
// ─────────────────────────────────────────────────────────────
final agencyDashboardProvider = NotifierProvider<AgencyDashboardNotifier, AgencyDashboardState>(() {
  return AgencyDashboardNotifier();
});
