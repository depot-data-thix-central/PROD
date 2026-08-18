// lib/presentation/thix_reservation/bus/providers/bus_search_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bus_trip_model.dart';
import '../data/models/city_model.dart';
import '../data/services/bus_public_service.dart';

// ─────────────────────────────────────────────────────────────
// ÉTAT IMMUABLE DE LA RECHERCHE DE BUS
// ─────────────────────────────────────────────────────────────
class BusSearchState {
  // --- State recherche ---
  final String? departureCity;
  final String? arrivalCity;
  final DateTime departureDate;
  final int passengers;

  final List<CityModel> cities;
  final List<BusTripModel> allResults;
  final List<BusTripModel> filteredResults;

  final bool isLoading;
  final bool isSearching;
  final String? error;

  // --- Filtres ---
  final double minPrice;
  final double maxPrice;
  final Set<String> selectedAgencies;
  final String? selectedBusType;
  final String sortBy; // 'departure', 'price', 'duration'

  const BusSearchState({
    this.departureCity,
    this.arrivalCity,
    required this.departureDate,
    this.passengers = 1,
    this.cities = const [],
    this.allResults = const [],
    this.filteredResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.error,
    this.minPrice = 0,
    this.maxPrice = 50000,
    this.selectedAgencies = const {},
    this.selectedBusType,
    this.sortBy = 'departure',
  });

  BusSearchState copyWith({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDate,
    int? passengers,
    List<CityModel>? cities,
    List<BusTripModel>? allResults,
    List<BusTripModel>? filteredResults,
    bool? isLoading,
    bool? isSearching,
    String? error,
    bool clearError = false,
    double? minPrice,
    double? maxPrice,
    Set<String>? selectedAgencies,
    String? selectedBusType,
    bool clearBusType = false,
    String? sortBy,
  }) {
    return BusSearchState(
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureDate: departureDate ?? this.departureDate,
      passengers: passengers ?? this.passengers,
      cities: cities ?? this.cities,
      allResults: allResults ?? this.allResults,
      filteredResults: filteredResults ?? this.filteredResults,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      selectedAgencies: selectedAgencies ?? this.selectedAgencies,
      selectedBusType: clearBusType ? null : (selectedBusType ?? this.selectedBusType),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NOTIFIER (Logique Métier)
// ─────────────────────────────────────────────────────────────
class BusSearchNotifier extends Notifier<BusSearchState> {
  final BusPublicService _service = BusPublicService();

  @override
  BusSearchState build() {
    // État initial (la date est initialisée à demain par défaut)
    final initialState = BusSearchState(
      departureDate: DateTime.now().add(const Duration(days: 1)),
    );

    // Charge les villes dès la création du provider
    Future.microtask(() => loadCities());

    return initialState;
  }

  Future<void> loadCities() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final citiesList = await _service.getCities();
      state = state.copyWith(
        cities: citiesList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void swapCities() {
    state = state.copyWith(
      departureCity: state.arrivalCity,
      arrivalCity: state.departureCity,
    );
  }

  void setDeparture(String city) {
    state = state.copyWith(departureCity: city);
  }

  void setArrival(String city) {
    state = state.copyWith(arrivalCity: city);
  }

  void setDate(DateTime date) {
    state = state.copyWith(departureDate: date);
  }

  void setPassengers(int count) {
    state = state.copyWith(passengers: count.clamp(1, 6));
  }

  // --- Recherche principale SaaS ---
  Future<void> search() async {
    if (state.departureCity == null || state.arrivalCity == null) {
      state = state.copyWith(error: 'Veuillez choisir départ et arrivée');
      return;
    }

    state = state.copyWith(isSearching: true, clearError: true);

    try {
      final results = await _service.searchTrips(
        from: state.departureCity!,
        to: state.arrivalCity!,
        date: state.departureDate,
        passengers: state.passengers,
      );
      
      state = state.copyWith(allResults: results);
      _applyFiltersAndSort();
    } catch (e) {
      state = state.copyWith(
        error: 'Erreur recherche: $e',
        filteredResults: [],
      );
    } finally {
      state = state.copyWith(isSearching: false);
    }
  }

  // --- Logique de tri et de filtre interne ---
  void _applyFiltersAndSort({BusSearchState? newState}) {
    final currentState = newState ?? state;
    
    var list = currentState.allResults.where((t) {
      final priceOk = t.priceFcfa >= currentState.minPrice && t.priceFcfa <= currentState.maxPrice;
      final agencyOk = currentState.selectedAgencies.isEmpty || currentState.selectedAgencies.contains(t.agencyId);
      final typeOk = currentState.selectedBusType == null || t.busType == currentState.selectedBusType;
      return priceOk && agencyOk && typeOk;
    }).toList();

    switch (currentState.sortBy) {
      case 'price':
        list.sort((a, b) => a.priceFcfa.compareTo(b.priceFcfa));
        break;
      case 'duration':
      case 'departure':
      default:
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    }
    
    state = currentState.copyWith(filteredResults: list);
  }

  void updatePriceFilter(double min, double max) {
    final newState = state.copyWith(minPrice: min, maxPrice: max);
    _applyFiltersAndSort(newState: newState);
  }

  void toggleAgency(String agencyId) {
    // Création d'un nouveau Set pour respecter l'immuabilité
    final newAgencies = Set<String>.from(state.selectedAgencies);
    if (newAgencies.contains(agencyId)) {
      newAgencies.remove(agencyId);
    } else {
      newAgencies.add(agencyId);
    }
    
    final newState = state.copyWith(selectedAgencies: newAgencies);
    _applyFiltersAndSort(newState: newState);
  }

  void setSort(String value) {
    final newState = state.copyWith(sortBy: value);
    _applyFiltersAndSort(newState: newState);
  }

  void clearFilters() {
    final newState = state.copyWith(
      minPrice: 0,
      maxPrice: 50000,
      selectedAgencies: const {},
      clearBusType: true,
      sortBy: 'departure',
      filteredResults: List.from(state.allResults),
    );
    state = newState;
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDER GLOBAL
// ─────────────────────────────────────────────────────────────
final busSearchProvider = NotifierProvider<BusSearchNotifier, BusSearchState>(() {
  return BusSearchNotifier();
});
