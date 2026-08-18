// lib/presentation/thix_reservation/bus/providers/seat_selection_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/seat_model.dart';
import '../data/services/bus_public_service.dart';

// ─────────────────────────────────────────────────────────────
// ÉTAT IMMUABLE DE LA SÉLECTION DES SIÈGES
// ─────────────────────────────────────────────────────────────
class SeatSelectionState {
  final String? tripId;
  final List<SeatModel> seats;
  final Set<String> selectedSeats;
  final int maxSelectable;

  final bool isLoading;
  final String? error;
  final int lockRemainingSeconds;

  const SeatSelectionState({
    this.tripId,
    this.seats = const [],
    this.selectedSeats = const {},
    this.maxSelectable = 1,
    this.isLoading = false,
    this.error,
    this.lockRemainingSeconds = 0,
  });

  SeatSelectionState copyWith({
    String? tripId,
    List<SeatModel>? seats,
    Set<String>? selectedSeats,
    int? maxSelectable,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? lockRemainingSeconds,
  }) {
    return SeatSelectionState(
      tripId: tripId ?? this.tripId,
      seats: seats ?? this.seats,
      selectedSeats: selectedSeats ?? this.selectedSeats,
      maxSelectable: maxSelectable ?? this.maxSelectable,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lockRemainingSeconds: lockRemainingSeconds ?? this.lockRemainingSeconds,
    );
  }

  // --- Getters calculés ---
  bool get canSelectMore => selectedSeats.length < maxSelectable;

  int get totalVipSupplement {
    int sup = 0;
    for (final num in selectedSeats) {
      // Évite l'exception si le siège n'est plus dans la liste
      final seat = seats.cast<SeatModel?>().firstWhere(
            (s) => s?.seatNumber == num,
            orElse: () => null,
          );
      if (seat != null && seat.isVip) {
        sup += 1000;
      }
    }
    return sup;
  }
}

// ─────────────────────────────────────────────────────────────
// NOTIFIER (Logique Métier)
// ─────────────────────────────────────────────────────────────
class SeatSelectionNotifier extends Notifier<SeatSelectionState> {
  final BusPublicService _service = BusPublicService();
  
  StreamSubscription? _sub;
  Timer? _lockTimer;

  @override
  SeatSelectionState build() {
    // Nettoyage automatique à la destruction du provider
    ref.onDispose(() {
      _sub?.cancel();
      _lockTimer?.cancel();
    });
    
    return const SeatSelectionState();
  }

  void init(String tripIdParam, int passengers) {
    state = SeatSelectionState(
      tripId: tripIdParam,
      maxSelectable: passengers,
      isLoading: true,
    );
    
    listenSeats();
  }

  void listenSeats() {
    if (state.tripId == null) return;
    
    state = state.copyWith(isLoading: true, clearError: true);
    _sub?.cancel();

    _sub = _service.watchSeats(state.tripId!).listen((data) {
      final newSelected = Set<String>.from(state.selectedSeats);
      
      // Nettoie la sélection si un siège n'existe plus dans les données du serveur
      newSelected.removeWhere((num) {
        final exists = data.any((e) => e.seatNumber == num);
        return !exists;
      });

      state = state.copyWith(
        seats: data,
        selectedSeats: newSelected,
        isLoading: false,
      );
    }, onError: (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    });
  }

  void toggleSeat(SeatModel seat) {
    if (!seat.isAvailable) return;
    
    final newSelected = Set<String>.from(state.selectedSeats);
    
    if (newSelected.contains(seat.seatNumber)) {
      newSelected.remove(seat.seatNumber);
    } else {
      if (!state.canSelectMore) return; // Bloque si quota atteint
      newSelected.add(seat.seatNumber);
    }
    
    state = state.copyWith(selectedSeats: newSelected);
    _handleLock(newSelected);
  }

  Future<void> _handleLock(Set<String> currentlySelected) async {
    if (state.tripId == null || currentlySelected.isEmpty) return;
    
    try {
      await _service.lockSeats(
        tripId: state.tripId!, 
        seatNumbers: currentlySelected.toList()
      );
      _startLockTimer();
    } catch (e) {
      state = state.copyWith(error: 'Impossible de bloquer le siège: $e');
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    
    // Démarre à 600 secondes (10 minutes)
    state = state.copyWith(lockRemainingSeconds: 600);
    
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.lockRemainingSeconds - 1;
      
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(
          lockRemainingSeconds: 0,
          selectedSeats: const {}, // Vide la sélection à expiration
        );
      } else {
        state = state.copyWith(lockRemainingSeconds: remaining);
      }
    });
  }

  Future<void> confirmAndUnlockForPayment() async {
    _lockTimer?.cancel();
    // On garde le lock, le paiement va convertir en 'booked' côté backend via trigger
  }

  Future<void> cancelSelection() async {
    if (state.tripId != null && state.selectedSeats.isNotEmpty) {
      await _service.unlockSeats(
        tripId: state.tripId!, 
        seatNumbers: state.selectedSeats.toList()
      );
    }
    
    _lockTimer?.cancel();
    state = state.copyWith(
      selectedSeats: const {}, 
      lockRemainingSeconds: 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDER GLOBAL
// ─────────────────────────────────────────────────────────────
final seatSelectionProvider = NotifierProvider<SeatSelectionNotifier, SeatSelectionState>(() {
  return SeatSelectionNotifier();
});
