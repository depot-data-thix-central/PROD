import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// ReservationHomeState
/// ============================================================================
class ReservationHomeState {
  final Map<String, int> counts;
  final bool isLoadingCounts;
  final int selectedNav;
  final int heroIndex;
  final int notificationsCount;
  final String? error;
  final DateTime? lastUpdated;

  const ReservationHomeState({
    this.counts = const {
      'upcoming': 0,
      'ongoing': 0,
      'completed': 0,
      'cancelled': 0,
    },
    this.isLoadingCounts = true,
    this.selectedNav = 0,
    this.heroIndex = 0,
    this.notificationsCount = 0,
    this.error,
    this.lastUpdated,
  });

  ReservationHomeState copyWith({
    Map<String, int>? counts,
    bool? isLoadingCounts,
    int? selectedNav,
    int? heroIndex,
    int? notificationsCount,
    String? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return ReservationHomeState(
      counts: counts ?? this.counts,
      isLoadingCounts: isLoadingCounts ?? this.isLoadingCounts,
      selectedNav: selectedNav ?? this.selectedNav,
      heroIndex: heroIndex ?? this.heroIndex,
      notificationsCount: notificationsCount ?? this.notificationsCount,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasError => error != null;
  int get totalBookings =>
      counts.values.fold(0, (sum, c) => sum + c);

  String getCount(String key) {
    if (isLoadingCounts) return '—';
    return (counts[key] ?? 0).toString();
  }
}

/// ============================================================================
/// ReservationHomeNotifier
/// ============================================================================
class ReservationHomeNotifier extends Notifier<ReservationHomeState> {
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  static const Duration _timeout = Duration(seconds: 8);

  @override
  ReservationHomeState build() {
    ref.onDispose(() {
      _realtimeSub?.cancel();
    });
    return const ReservationHomeState();
  }

  Future<void> init() async {
    await loadCounts();
    _subscribeRealtime();
  }

  Future<void> loadCounts() async {
    state = state.copyWith(isLoadingCounts: true, clearError: true);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(isLoadingCounts: false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('bus_bookings')
          .select('status')
          .eq('user_id', uid)
          .timeout(_timeout);

      final map = <String, int>{
        'upcoming': 0,
        'ongoing': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (final row in res as List) {
        final s = (row['status'] as String?) ?? '';
        switch (s) {
          case 'confirmed':
          case 'pending_payment':
            map['upcoming'] = (map['upcoming'] ?? 0) + 1;
            break;
          case 'in_progress':
            map['ongoing'] = (map['ongoing'] ?? 0) + 1;
            break;
          case 'completed':
            map['completed'] = (map['completed'] ?? 0) + 1;
            break;
          case 'cancelled':
            map['cancelled'] = (map['cancelled'] ?? 0) + 1;
            break;
        }
      }

      state = state.copyWith(
        counts: map,
        isLoadingCounts: false,
        lastUpdated: DateTime.now(),
      );
      _log('Counts chargés : $map');
    } catch (e) {
      _logError('loadCounts', e);
      state = state.copyWith(
        isLoadingCounts: false,
        error: 'Impossible de charger les réservations',
      );
    }
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _realtimeSub?.cancel();
    _realtimeSub = Supabase.instance.client
        .from('bus_bookings:user_id=eq.$uid')
        .stream(primaryKey: ['id'])
        .listen((_) {
      // Recharger les counts à chaque changement
      loadCounts();
    }, onError: (e) {
      _logError('Realtime subscription', e);
    });
  }

  void setSelectedNav(int index) {
    state = state.copyWith(selectedNav: index);
  }

  void setHeroIndex(int index) {
    state = state.copyWith(heroIndex: index);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ReservationHome] $message');
  }

  void _logError(String context, Object error) {
    if (kDebugMode) debugPrint('[ReservationHome] ❌ $context: $error');
  }
}

/// ============================================================================
/// Provider
/// ============================================================================
final reservationHomeProvider =
    NotifierProvider<ReservationHomeNotifier, ReservationHomeState>(
  ReservationHomeNotifier.new,
);

/// ============================================================================
/// Modèle pour une catégorie de service
/// ============================================================================
class ReservationCategory {
  final String id;
  final String labelKey;
  final String route;
  final dynamic icon; // IconData
  final bool isPrimary;

  const ReservationCategory({
    required this.id,
    required this.labelKey,
    required this.route,
    required this.icon,
    this.isPrimary = true,
  });
}

/// Liste centralisée des catégories
const kReservationCategories = [
  ReservationCategory(
    id: 'bus',
    labelKey: 'reservationCatBus',
    route: '/thix-reservation/bus',
    icon: 'directions_bus_filled',
    isPrimary: true,
  ),
  ReservationCategory(
    id: 'flights',
    labelKey: 'reservationCatFlights',
    route: '/thix-reservation/flights',
    icon: 'flight_takeoff',
    isPrimary: true,
  ),
  ReservationCategory(
    id: 'hotels',
    labelKey: 'reservationCatHotels',
    route: '/thix-reservation/hotels',
    icon: 'king_bed',
    isPrimary: true,
  ),
  ReservationCategory(
    id: 'taxi',
    labelKey: 'reservationCatTaxi',
    route: '/thix-reservation/taxi',
    icon: 'local_taxi',
    isPrimary: true,
  ),
  ReservationCategory(
    id: 'delivery',
    labelKey: 'reservationCatDelivery',
    route: '/delivery',
    icon: 'delivery_dining',
    isPrimary: true,
  ),
];
