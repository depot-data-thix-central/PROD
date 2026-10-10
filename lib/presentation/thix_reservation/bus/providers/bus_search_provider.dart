import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bus_trip_model.dart';
import '../data/models/city_model.dart';
import '../data/services/bus_public_service.dart';

/// ============================================================================
/// SearchError — Gestion d'erreurs typée
/// ============================================================================
enum SearchErrorType {
  network,
  timeout,
  noResults,
  invalidInput,
  server,
  unknown,
}

class SearchError {
  final SearchErrorType type;
  final String message;
  final String? originalError;
  final DateTime timestamp;

  const SearchError({
    required this.type,
    required this.message,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _Now();

  factory SearchError.fromException(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();

    SearchErrorType type;
    if (lower.contains('timeout')) {
      type = SearchErrorType.timeout;
    } else if (lower.contains('network') || lower.contains('socket')) {
      type = SearchErrorType.network;
    } else if (lower.contains('500') || lower.contains('server')) {
      type = SearchErrorType.server;
    } else {
      type = SearchErrorType.unknown;
    }

    return SearchError(
      type: type,
      message: _humanReadable(type),
      originalError: msg,
    );
  }

  static String _humanReadable(SearchErrorType type) {
    switch (type) {
      case SearchErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case SearchErrorType.timeout:
        return 'La recherche a pris trop de temps. Réessayez.';
      case SearchErrorType.noResults:
        return 'Aucun trajet trouvé pour ces critères.';
      case SearchErrorType.invalidInput:
        return 'Veuillez vérifier vos critères de recherche.';
      case SearchErrorType.server:
        return 'Erreur serveur. Réessayez dans quelques instants.';
      case SearchErrorType.unknown:
        return 'Une erreur inattendue s\'est produite.';
    }
  }
}

class _Now implements DateTime {
  const _Now();
  @override
  noSuchMethod(Invocation invocation) => DateTime.now();
}

/// ============================================================================
/// _SearchSort — Options de tri type-safe
/// ============================================================================
enum _SearchSort {
  departure('departure'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),
  duration('duration'),
  seatsAvailable('seats');

  final String value;
  const _SearchSort(this.value);

  static _SearchSort fromString(String? v) {
    return _SearchSort.values.firstWhere(
      (s) => s.value == v,
      orElse: () => _SearchSort.departure,
    );
  }
}

/// ============================================================================
/// RecentSearch — Historique des recherches récentes
/// ============================================================================
class RecentSearch {
  final String from;
  final String to;
  final DateTime timestamp;

  const RecentSearch({
    required this.from,
    required this.to,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSearch &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// ============================================================================
/// BusSearchState — État immuable de la recherche
/// ============================================================================
class BusSearchState {
  // Critères de recherche
  final String? departureCity;
  final String? arrivalCity;
  final DateTime departureDate;
  final int passengers;

  // Données
  final List<CityModel> cities;
  final List<BusTripModel> allResults;
  final List<BusTripModel> filteredResults;

  // Historique
  final List<RecentSearch> recentSearches;

  // États UI
  final bool isLoading;
  final bool isRefreshing;
  final bool isSearching;

  // Filtres
  final double minPrice;
  final double maxPrice;
  final double availableMinPrice;
  final double availableMaxPrice;
  final Set<String> selectedAgencies;
  final Set<String> selectedBusTypes;
  final Set<String> selectedAmenities;
  final int? departureHour; // Filtre par heure (0-23)
  final _SearchSort sortBy;

  // Gestion d'erreurs
  final SearchError? error;
  final DateTime? lastUpdated;

  const BusSearchState({
    this.departureCity,
    this.arrivalCity,
    required this.departureDate,
    this.passengers = 1,
    this.cities = const [],
    this.allResults = const [],
    this.filteredResults = const [],
    this.recentSearches = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSearching = false,
    this.minPrice = 0,
    this.maxPrice = 500000,
    this.availableMinPrice = 0,
    this.availableMaxPrice = 500000,
    this.selectedAgencies = const {},
    this.selectedBusTypes = const {},
    this.selectedAmenities = const {},
    this.departureHour,
    this.sortBy = _SearchSort.departure,
    this.error,
    this.lastUpdated,
  });

  BusSearchState copyWith({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDate,
    int? passengers,
    List<CityModel>? cities,
    List<BusTripModel>? allResults,
    List<BusTripModel>? filteredResults,
    List<RecentSearch>? recentSearches,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSearching,
    double? minPrice,
    double? maxPrice,
    double? availableMinPrice,
    double? availableMaxPrice,
    Set<String>? selectedAgencies,
    Set<String>? selectedBusTypes,
    Set<String>? selectedAmenities,
    int? departureHour,
    _SearchSort? sortBy,
    SearchError? error,
    DateTime? lastUpdated,
    bool clearError = false,
    bool clearDepartureCity = false,
    bool clearArrivalCity = false,
    bool clearDepartureHour = false,
  }) {
    return BusSearchState(
      departureCity: clearDepartureCity ? null : (departureCity ?? this.departureCity),
      arrivalCity: clearArrivalCity ? null : (arrivalCity ?? this.arrivalCity),
      departureDate: departureDate ?? this.departureDate,
      passengers: passengers ?? this.passengers,
      cities: cities ?? this.cities,
      allResults: allResults ?? this.allResults,
      filteredResults: filteredResults ?? this.filteredResults,
      recentSearches: recentSearches ?? this.recentSearches,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSearching: isSearching ?? this.isSearching,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      availableMinPrice: availableMinPrice ?? this.availableMinPrice,
      availableMaxPrice: availableMaxPrice ?? this.availableMaxPrice,
      selectedAgencies: selectedAgencies ?? this.selectedAgencies,
      selectedBusTypes: selectedBusTypes ?? this.selectedBusTypes,
      selectedAmenities: selectedAmenities ?? this.selectedAmenities,
      departureHour: clearDepartureHour ? null : (departureHour ?? this.departureHour),
      sortBy: sortBy ?? this.sortBy,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // ─── État ─────────────────────────────────────────────────
  bool get hasError => error != null;
  bool get hasResults => filteredResults.isNotEmpty;
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 5);
  }

  // ─── Validation ───────────────────────────────────────────
  bool get isSearchValid =>
      departureCity != null &&
      arrivalCity != null &&
      departureCity!.isNotEmpty &&
      arrivalCity!.isNotEmpty &&
      departureCity != arrivalCity &&
      !departureDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  // ─── Filtres actifs (utilisé par UI) ──────────────────────
  bool get hasActiveFilters =>
      selectedAgencies.isNotEmpty ||
      selectedBusTypes.isNotEmpty ||
      selectedAmenities.isNotEmpty ||
      departureHour != null ||
      maxPrice < availableMaxPrice * 0.95 ||
      minPrice > availableMinPrice * 1.05;

  int get activeFiltersCount {
    int count = 0;
    if (selectedAgencies.isNotEmpty) count++;
    if (selectedBusTypes.isNotEmpty) count++;
    if (selectedAmenities.isNotEmpty) count++;
    if (departureHour != null) count++;
    if (maxPrice < availableMaxPrice * 0.95 || minPrice > availableMinPrice * 1.05) count++;
    return count;
  }

  // ─── Getters publics (compatibilité UI) ───────────────────
  String get sortByValue => sortBy.value;
  List<String> get busTypes => selectedBusTypes.toList();
  List<String> get amenities => selectedAmenities.toList();

  // ─── Stats sur les résultats ──────────────────────────────
  int get totalResults => allResults.length;
  int get filteredCount => filteredResults.length;

  // Agences disponibles dans les résultats
  Set<String> get availableAgencies {
    return allResults
        .where((t) => t.agencyId.isNotEmpty)
        .map((t) => t.agencyId)
        .toSet();
  }

  // Types de bus disponibles
  Set<String> get availableBusTypes {
    return allResults.map((t) => t.busType).toSet();
  }

  // Équipements disponibles
  Set<String> get availableAmenities {
    final set = <String>{};
    for (final t in allResults) {
      set.addAll(t.amenities);
    }
    return set;
  }

  // Prix le moins cher
  int get cheapestPrice {
    if (filteredResults.isEmpty) return 0;
    return filteredResults.map((t) => t.priceFcfa).reduce(
      (a, b) => a < b ? a : b,
    );
  }

  // Trajet le plus rapide
  BusTripModel? get fastestTrip {
    if (filteredResults.isEmpty) return null;
    return filteredResults.reduce((a, b) {
      final durA = a.arrivalTime.difference(a.departureTime);
      final durB = b.arrivalTime.difference(b.departureTime);
      return durA < durB ? a : b;
    });
  }

  // Prochain départ
  BusTripModel? get nextDeparture {
    final now = DateTime.now();
    final future = filteredResults.where((t) => t.departureTime.isAfter(now)).toList();
    if (future.isEmpty) return null;
    future.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return future.first;
  }
}

/// ============================================================================
/// BusSearchNotifier — Logique métier
/// ============================================================================
class BusSearchNotifier extends Notifier<BusSearchState> {
  final BusPublicService _service = BusPublicService();

  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const int _maxRecentSearches = 5;
  static const int _maxPassengers = 6;

  @override
  BusSearchState build() {
    final initial = BusSearchState(
      departureDate: DateTime.now().add(const Duration(days: 1)),
    );

    // Charge les villes dès la création du provider
    Future.microtask(() => loadCities());

    return initial;
  }

  // ─── Villes ───────────────────────────────────────────────
  Future<void> loadCities({bool force = false}) async {
    if (!force && state.cities.isNotEmpty && !state.isStale) {
      _log('Villes en cache, skip');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cities = await _service.getCities().timeout(_timeout);
      state = state.copyWith(
        cities: cities,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      _log('${cities.length} villes chargées');
    } catch (e) {
      _logError('Erreur loadCities', e);
      state = state.copyWith(
        error: SearchError.fromException(e),
        isLoading: false,
      );
    }
  }

  // ─── Setters ──────────────────────────────────────────────
  void setDeparture(String city) {
    if (city == state.arrivalCity) {
      // Swap automatique si même ville
      state = state.copyWith(
        departureCity: city,
        clearArrivalCity: true,
      );
    } else {
      state = state.copyWith(departureCity: city, clearError: true);
    }
    _log('Départ : $city');
  }

  void setArrival(String city) {
    if (city == state.departureCity) {
      state = state.copyWith(
        arrivalCity: city,
        clearDepartureCity: true,
      );
    } else {
      state = state.copyWith(arrivalCity: city, clearError: true);
    }
    _log('Arrivée : $city');
  }

  void setDate(DateTime date) {
    // Empêcher dates passées
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    final safeDate = date.isBefore(minDate) ? minDate.add(const Duration(days: 1)) : date;

    state = state.copyWith(departureDate: safeDate, clearError: true);
    _log('Date : ${safeDate.toIso8601String()}');
  }

  void setPassengers(int count) {
    final clamped = count.clamp(1, _maxPassengers);
    state = state.copyWith(passengers: clamped);
    _log('Passagers : $clamped');
  }

  void swapCities() {
    final dep = state.departureCity;
    final arr = state.arrivalCity;
    state = state.copyWith(
      departureCity: arr,
      arrivalCity: dep,
      clearError: true,
    );
    _log('Villes inversées : $arr → $dep');
  }

  // ─── Recherche principale ─────────────────────────────────
  Future<void> search({bool addToHistory = true}) async {
    // Validation
    if (!state.isSearchValid) {
      state = state.copyWith(
        error: const SearchError(
          type: SearchErrorType.invalidInput,
          message: 'Veuillez choisir des villes de départ et d\'arrivée différentes',
        ),
      );
      return;
    }

    state = state.copyWith(isSearching: true, clearError: true);

    try {
      final results = await _service.searchTrips(
        from: state.departureCity!,
        to: state.arrivalCity!,
        date: state.departureDate,
        passengers: state.passengers,
      ).timeout(_timeout);

      // Calculer les bornes de prix dynamiques
      double minP = 0;
      double maxP = 500000;
      if (results.isNotEmpty) {
        final prices = results.map((t) => t.priceFcfa).toList();
        minP = prices.reduce((a, b) => a < b ? a : b).toDouble();
        maxP = prices.reduce((a, b) => a > b ? a : b).toDouble();
        // Ajouter une marge de 10%
        maxP = maxP * 1.1;
      }

      // Ajouter à l'historique
      var recent = List<RecentSearch>.from(state.recentSearches);
      if (addToHistory) {
        final newItem = RecentSearch(
          from: state.departureCity!,
          to: state.arrivalCity!,
          timestamp: DateTime.now(),
        );
        recent.remove(newItem);
        recent.insert(0, newItem);
        if (recent.length > _maxRecentSearches) {
          recent = recent.sublist(0, _maxRecentSearches);
        }
      }

      state = state.copyWith(
        allResults: results,
        availableMinPrice: minP,
        availableMaxPrice: maxP,
        recentSearches: recent,
        lastUpdated: DateTime.now(),
      );

      _applyFiltersAndSort();

      if (results.isEmpty) {
        _log('Aucun résultat pour ${state.departureCity} → ${state.arrivalCity}');
      } else {
        _log('${results.length} résultats trouvés');
      }
    } catch (e) {
      _logError('Erreur search', e);
      state = state.copyWith(
        error: SearchError.fromException(e),
        filteredResults: [],
        allResults: [],
      );
    } finally {
      state = state.copyWith(isSearching: false);
    }
  }

  // ─── Refresh (garde les critères) ─────────────────────────
  Future<void> refresh() async {
    if (state.departureCity == null || state.arrivalCity == null) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final results = await _service.searchTrips(
        from: state.departureCity!,
        to: state.arrivalCity!,
        date: state.departureDate,
        passengers: state.passengers,
      ).timeout(_timeout);

      state = state.copyWith(
        allResults: results,
        isRefreshing: false,
        lastUpdated: DateTime.now(),
      );

      _applyFiltersAndSort();
      _log('Refresh : ${results.length} résultats');
    } catch (e) {
      _logError('Erreur refresh', e);
      state = state.copyWith(
        error: SearchError.fromException(e),
        isRefreshing: false,
      );
    }
  }

  // ─── Application filtres + tri ────────────────────────────
  void _applyFiltersAndSort() {
    var list = state.allResults.where((t) {
      // Prix
      final priceOk = t.priceFcfa >= state.minPrice && t.priceFcfa <= state.maxPrice;
      if (!priceOk) return false;

      // Agences
      if (state.selectedAgencies.isNotEmpty &&
          !state.selectedAgencies.contains(t.agencyId)) {
        return false;
      }

      // Types de bus
      if (state.selectedBusTypes.isNotEmpty &&
          !state.selectedBusTypes.contains(t.busType.toLowerCase())) {
        return false;
      }

      // Équipements
      if (state.selectedAmenities.isNotEmpty) {
        final tripAmenities = t.amenities.map((a) => a.toLowerCase()).toSet();
        final hasAll = state.selectedAmenities.every((a) => tripAmenities.contains(a.toLowerCase()));
        if (!hasAll) return false;
      }

      // Heure de départ
      if (state.departureHour != null) {
        if (t.departureTime.hour != state.departureHour) return false;
      }

      return true;
    }).toList();

    // Tri
    switch (state.sortBy) {
      case _SearchSort.priceAsc:
        list.sort((a, b) => a.priceFcfa.compareTo(b.priceFcfa));
        break;
      case _SearchSort.priceDesc:
        list.sort((a, b) => b.priceFcfa.compareTo(a.priceFcfa));
        break;
      case _SearchSort.duration:
        list.sort((a, b) {
          final durA = a.arrivalTime.difference(a.departureTime);
          final durB = b.arrivalTime.difference(b.departureTime);
          return durA.compareTo(durB);
        });
        break;
      case _SearchSort.seatsAvailable:
        list.sort((a, b) => b.availableSeats.compareTo(a.availableSeats));
        break;
      case _SearchSort.departure:
      default:
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    }

    state = state.copyWith(filteredResults: list);
  }

  // ─── Filtres ──────────────────────────────────────────────
  void updatePriceFilter(double min, double max) {
    state = state.copyWith(minPrice: min, maxPrice: max);
    _applyFiltersAndSort();
    _log('Prix : ${min.toInt()} - ${max.toInt()}');
  }

  void updateBusTypes(List<String> types) {
    state = state.copyWith(selectedBusTypes: types.toSet());
    _applyFiltersAndSort();
    _log('Types bus : ${types.join(", ")}');
  }

  void updateAmenities(List<String> amenities) {
    state = state.copyWith(selectedAmenities: amenities.toSet());
    _applyFiltersAndSort();
    _log('Équipements : ${amenities.join(", ")}');
  }

  void toggleAgency(String agencyId) {
    final newSet = Set<String>.from(state.selectedAgencies);
    if (newSet.contains(agencyId)) {
      newSet.remove(agencyId);
    } else {
      newSet.add(agencyId);
    }
    state = state.copyWith(selectedAgencies: newSet);
    _applyFiltersAndSort();
  }

  void setDepartureHour(int? hour) {
    if (hour == null) {
      state = state.copyWith(clearDepartureHour: true);
    } else {
      state = state.copyWith(departureHour: hour.clamp(0, 23));
    }
    _applyFiltersAndSort();
    _log('Heure départ : ${hour ?? "toutes"}');
  }

  void setSort(String value) {
    final sort = _SearchSort.fromString(value);
    state = state.copyWith(sortBy: sort);
    _applyFiltersAndSort();
    _log('Tri : ${sort.value}');
  }

  void clearFilters() {
    state = state.copyWith(
      minPrice: state.availableMinPrice,
      maxPrice: state.availableMaxPrice,
      selectedAgencies: const {},
      selectedBusTypes: const {},
      selectedAmenities: const {},
      clearDepartureHour: true,
      sortBy: _SearchSort.departure,
    );
    _applyFiltersAndSort();
    _log('Filtres effacés');
  }

  void clearSearch() {
    state = const BusSearchState(
      departureDate: null,
    ).copyWith(
      departureDate: DateTime.now().add(const Duration(days: 1)),
      cities: state.cities,
      recentSearches: state.recentSearches,
    );
    _log('Recherche effacée');
  }

  // ─── Utilitaires ──────────────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void applyRecentSearch(RecentSearch recent) {
    state = state.copyWith(
      departureCity: recent.from,
      arrivalCity: recent.to,
      clearError: true,
    );
    _log('Recherche récente appliquée : ${recent.from} → ${recent.to}');
  }

  // Logging
  void _log(String message) {
    if (kDebugMode) debugPrint('[BusSearch] $message');
  }

  void _logError(String context, Object error) {
    if (kDebugMode) debugPrint('[BusSearch] ❌ $context: $error');
  }
}

/// ============================================================================
/// Provider global
/// ============================================================================
final busSearchProvider =
    NotifierProvider<BusSearchNotifier, BusSearchState>(
  BusSearchNotifier.new,
);
