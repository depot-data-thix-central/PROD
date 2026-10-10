import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agency_model.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

/// ============================================================================
/// AgencyDashboardState
/// ============================================================================
class AgencyDashboardState {
  // Données principales
  final AgencyModel? myAgency;
  final List<BusTripModel> myTrips;
  final List<BookingModel> agencyBookings;

  // Stats par période
  final Map<String, dynamic>? statsToday;
  final Map<String, dynamic>? statsWeek;
  final Map<String, dynamic>? statsMonth;
  final Map<String, dynamic>? statsAll;

  // État UI
  final bool isLoading;
  final bool isRefreshing;
  final bool isCreating;
  final bool isUpdating;

  // Filtres et tri
  final _TripFilter? activeFilter;
  final _TripSort activeSort;

  // Gestion d'erreurs
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

  // Getters de base
  bool get hasAgency => myAgency != null;
  bool get isAgencyActive => myAgency?.isActive == true;
  bool get isPending => myAgency?.isPending == true;
  bool get hasError => error != null;
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 5);
  }

  // Stats aujourd'hui
  int get todayBookingsCount => statsToday?['bookings_count'] ?? 0;
  int get todayRevenue => statsToday?['revenue'] ?? 0;
  double get todayOccupancyRate => (statsToday?['occupancy_rate'] ?? 0).toDouble();

  // Stats semaine
  int get weekBookingsCount => statsWeek?['bookings_count'] ?? 0;
  int get weekRevenue => statsWeek?['revenue'] ?? 0;

  // Stats mois
  int get monthBookingsCount => statsMonth?['bookings_count'] ?? 0;
  int get monthRevenue => statsMonth?['revenue'] ?? 0;

  // Stats totales
  int get totalBookingsCount => statsAll?['bookings_count'] ?? 0;
  int get totalRevenue => statsAll?['revenue'] ?? 0;

  // Trajets filtrés et triés
  List<BusTripModel> get filteredTrips {
    var trips = List<BusTripModel>.from(myTrips);

    // Appliquer le filtre
    if (activeFilter != null) {
      trips = trips.where((t) {
        switch (activeFilter!) {
          case _TripFilter.all:
            return true;
          case _TripFilter.scheduled:
            // Correction: Utilisation de .name pour comparer l'Enum TripStatus avec une String
            return t.status.name == 'scheduled';
          case _TripFilter.departed:
            return t.status.name == 'departed';
          case _TripFilter.cancelled:
            return t.status.name == 'cancelled';
          case _TripFilter.completed:
            return t.status.name == 'completed';
        }
      }).toList();
    }

    // Appliquer le tri
    trips.sort((a, b) {
      switch (activeSort) {
        case _TripSort.dateAsc:
          return a.departureTime.compareTo(b.departureTime);
        case _TripSort.dateDesc:
          return b.departureTime.compareTo(a.departureTime);
        case _TripSort.priceAsc:
          return a.priceFcfa.compareTo(b.priceFcfa);
        case _TripSort.priceDesc:
          return b.priceFcfa.compareTo(a.priceFcfa);
        case _TripSort.seatsAsc:
          return a.availableSeats.compareTo(b.availableSeats);
        case _TripSort.seatsDesc:
          return b.availableSeats.compareTo(a.availableSeats);
      }
    });

    return trips;
  }

  // Bookings triés par date (plus récents en premier)
  List<BookingModel> get sortedBookings {
    final sorted = List<BookingModel>.from(agencyBookings);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // Trajets à venir (départ futur)
  List<BusTripModel> get upcomingTrips {
    final now = DateTime.now();
    return myTrips
        .where((t) => t.status.name == 'scheduled' && t.departureTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }

  int get pendingDepartures => upcomingTrips.length;

  // Trajets passés
  List<BusTripModel> get pastTrips {
    final now = DateTime.now();
    return myTrips
        .where((t) => t.departureTime.isBefore(now))
        .toList()
      ..sort((a, b) => b.departureTime.compareTo(a.departureTime));
  }

  // Stats par statut de booking
  Map<String, int> get bookingsByStatus {
    final map = <String, int>{};
    for (final b in agencyBookings) {
      // Correction: Utilisation de .name pour convertir BookingStatus en String pour la clé de la Map
      final statusKey = b.status.name;
      map[statusKey] = (map[statusKey] ?? 0) + 1;
    }
    return map;
  }
}

/// ============================================================================
/// Enums pour filtres et tri
/// ============================================================================
enum _TripFilter {
  all,
  scheduled,
  departed,
  cancelled,
  completed,
}

enum _TripSort {
  dateAsc,
  dateDesc,
  priceAsc,
  priceDesc,
  seatsAsc,
  seatsDesc,
}

/// ============================================================================
/// AgencyError — Erreurs typées
/// ============================================================================
enum AgencyErrorType {
  network,
  unauthorized,
  notFound,
  validation,
  server,
  unknown,
}

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
      case AgencyErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case AgencyErrorType.unauthorized:
        return 'Session expirée. Veuillez vous reconnecter.';
      case AgencyErrorType.notFound:
        return 'Ressource introuvable.';
      case AgencyErrorType.validation:
        return 'Données invalides. Vérifiez le formulaire.';
      case AgencyErrorType.server:
        return 'Erreur serveur. Réessayez dans quelques instants.';
      case AgencyErrorType.unknown:
        return 'Une erreur inattendue s\'est produite.';
    }
  }
}

// Helper pour DateTime.now() en const
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
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  AgencyDashboardState build() => const AgencyDashboardState();

  /// Initialisation complète avec chargement de toutes les données
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
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isLoading: false,
      );
    }
  }

  /// Refresh léger
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
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isRefreshing: false,
      );
    }
  }

  /// Créer une nouvelle agence
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
      ).timeout(_timeout);

      state = state.copyWith(myAgency: newAgency, isCreating: false);
      await init(force: true);
      _log('Agence créée : ${newAgency.name}');
      return state.hasAgency;
    } catch (e) {
      _logError('Erreur création agence', e);
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isCreating: false,
      );
      return false;
    }
  }

  /// Créer un nouveau trajet
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
        error: const AgencyError(
          type: AgencyErrorType.validation,
          message: 'Agence non active',
        ),
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
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isCreating: false,
      );
      return false;
    }
  }

  /// Mettre à jour le statut d'un trajet
  Future<bool> updateTripStatus(String tripId, String newStatus) async {
    if (state.myAgency == null) return false;

    state = state.copyWith(isUpdating: true, clearError: true);

    try {
      await _service.updateTripStatus(tripId, newStatus).timeout(_timeout);

      // Mettre à jour localement
      final updatedTrips = state.myTrips.map((t) {
        if (t.id == tripId) {
          return BusTripModel(
            id: t.id,
            agencyId: t.agencyId, // Conservé
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
            // Le modèle attend probablement un Enum TripStatus, mais si la méthode prend String, 
            // il faut convertir ou vérifier le constructeur. Ici on suppose que le constructeur accepte String ou qu'il faut caster.
            // Si BusTripModel.status est un Enum TripStatus, il faut faire: status: TripStatus.values.firstWhere((e) => e.name == newStatus)
            // Pour l'instant, on garde la logique précédente mais attention au type réel du champ status dans BusTripModel.
            // Si c'est un String dans le modèle :
            status: newStatus, 
          );
        }
        return t;
      }).toList();

      state = state.copyWith(
        myTrips: updatedTrips,
        isUpdating: false,
        lastUpdated: DateTime.now(),
      );

      _log('Statut trajet $tripId → $newStatus');
      return true;
    } catch (e) {
      _logError('Erreur update statut trajet', e);
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isUpdating: false,
      );
      return false;
    }
  }

  /// Supprimer un trajet
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
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isUpdating: false,
      );
      return false;
    }
  }

  /// Valider un QR code (ticket)
  Future<BookingModel?> validateQr(String qrCode) async {
    if (state.myAgency == null) return null;

    state = state.copyWith(clearError: true);

    try {
      final booking = await _service.validateTicketByQr(
        state.myAgency!.id,
        qrCode,
      ).timeout(_timeout);

      // Mettre à jour localement
      final newBookings = List<BookingModel>.from(state.agencyBookings);
      final index = newBookings.indexWhere((b) => b.id == booking.id);

      if (index != -1) {
        newBookings[index] = booking;
      } else {
        newBookings.insert(0, booking);
      }

      state = state.copyWith(
        agencyBookings: newBookings,
        lastUpdated: DateTime.now(),
      );

      _log('QR validé : ${booking.id}');
      return booking;
    } catch (e) {
      _logError('Erreur validation QR', e);
      state = state.copyWith(
        error: AgencyError.fromException(e),
      );
      return null;
    }
  }

  /// Annuler un booking (côté agence)
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
            // Correction: Conversion si nécessaire, ou utilisation directe si le modèle attend String
            // Si BookingModel.status est un Enum BookingStatus:
            // status: BookingStatus.cancelled, 
            // Sinon si c'est String:
            status: 'cancelled',
            qrCode: b.qrCode,
            createdAt: b.createdAt,
            passengerName: b.passengerName,
            trip: b.trip,
            // Ajout du paramètre manquant agencyId si requis par le constructeur
            agencyId: b.agencyId, 
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        agencyBookings: updatedBookings,
        isUpdating: false,
        lastUpdated: DateTime.now(),
      );

      _log('Booking annulé : $bookingId');
      return true;
    } catch (e) {
      _logError('Erreur annulation booking', e);
      state = state.copyWith(
        error: AgencyError.fromException(e),
        isUpdating: false,
      );
      return false;
    }
  }

  /// Définir le filtre actif
  void setFilter(_TripFilter? filter) {
    state = state.copyWith(
      activeFilter: filter,
      clearFilter: filter == null,
    );
    _log('Filtre défini : ${filter?.name ?? "aucun"}');
  }

  /// Définir le tri actif
  void setSort(_TripSort sort) {
    state = state.copyWith(activeSort: sort);
    _log('Tri défini : ${sort.name}');
  }

  /// Effacer l'erreur
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Logging helpers
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AgencyDashboard] $message');
    }
  }

  void _logError(String context, Object error) {
    if (kDebugMode) {
      debugPrint('[AgencyDashboard] ❌ $context: $error');
    }
  }
}

/// ============================================================================
/// Provider
/// ============================================================================
final agencyDashboardProvider =
    NotifierProvider<AgencyDashboardNotifier, AgencyDashboardState>(
  AgencyDashboardNotifier.new,
);
