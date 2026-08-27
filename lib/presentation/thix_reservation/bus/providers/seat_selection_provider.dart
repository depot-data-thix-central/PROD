// lib/presentation/thix_reservation/bus/providers/seat_selection_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/seat_model.dart';
import '../data/services/bus_public_service.dart';

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

  bool get canSelectMore => selectedSeats.length < maxSelectable;

  SeatModel? seatByNumber(String num) {
    for (final s in seats) {
      if (s.seatNumber == num) return s;
    }
    return null;
  }

  int get totalVipSupplement {
    var sup = 0;
    for (final num in selectedSeats) {
      final found = seatByNumber(num);
      if (found != null) {
        sup += found.extraPrice;
      }
    }
    return sup;
  }
}

class SeatSelectionNotifier extends Notifier<SeatSelectionState> {
  final BusPublicService _service = BusPublicService();

  StreamSubscription? _sub;
  Timer? _lockTimer;

  @override
  SeatSelectionState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _lockTimer?.cancel();
    });
    return const SeatSelectionState();
  }

  void init(String tripIdParam, int passengers) {
    final max = passengers < 1 ? 1 : passengers;
    state = SeatSelectionState(
      tripId: tripIdParam,
      maxSelectable: max,
      isLoading: true,
    );
    listenSeats();
  }

  void listenSeats() {
    final id = state.tripId;
    if (id == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    _sub?.cancel();

    _sub = _service.watchSeats(id).listen((data) {
      final newSelected = Set<String>.from(state.selectedSeats);
      newSelected.removeWhere((num) {
        var exists = false;
        for (final e in data) {
          if (e.seatNumber == num) {
            exists = true;
            break;
          }
        }
        return !exists;
      });

      state = state.copyWith(
        seats: data,
        selectedSeats: newSelected,
        isLoading: false,
        lockRemainingSeconds: _remainingFromSeats(data, newSelected),
      );
      _tickFromLockedUntil();
    }, onError: (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    });
  }

  int _remainingFromSeats(List<SeatModel> seats, Set<String> selected) {
    DateTime? until;
    for (final num in selected) {
      for (final s in seats) {
        if (s.seatNumber == num && s.lockedUntil != null) {
          if (until == null || s.lockedUntil!.isBefore(until)) {
            until = s.lockedUntil;
          }
        }
      }
    }
    if (until == null) return 0;
    final sec = until.difference(DateTime.now()).inSeconds;
    if (sec < 0) return 0;
    return sec;
  }

  void toggleSeat(SeatModel seat) {
    if (!seat.isAvailable) return;

    final newSelected = Set<String>.from(state.selectedSeats);
    if (newSelected.contains(seat.seatNumber)) {
      newSelected.remove(seat.seatNumber);
    } else {
      if (!state.canSelectMore) return;
      newSelected.add(seat.seatNumber);
    }

    state = state.copyWith(selectedSeats: newSelected);
    _handleLock(newSelected);
  }

  Future<void> _handleLock(Set<String> currentlySelected) async {
    final id = state.tripId;
    if (id == null || currentlySelected.isEmpty) {
      _lockTimer?.cancel();
      state = state.copyWith(lockRemainingSeconds: 0);
      return;
    }

    try {
      await _service.lockSeats(
        tripId: id,
        seatNumbers: currentlySelected.toList(),
      );
      _tickFromLockedUntil();
    } catch (e) {
      state = state.copyWith(
        error: 'Impossible de bloquer le siege: ' + e.toString(),
      );
    }
  }

  void _tickFromLockedUntil() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = _remainingFromSeats(state.seats, state.selectedSeats);
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(
          lockRemainingSeconds: 0,
          selectedSeats: const {},
        );
      } else {
        state = state.copyWith(lockRemainingSeconds: remaining);
      }
    });
  }

  Future<void> confirmAndUnlockForPayment() async {
    _lockTimer?.cancel();
  }

  Future<void> cancelSelection() async {
    final id = state.tripId;
    if (id != null && state.selectedSeats.isNotEmpty) {
      await _service.unlockSeats(
        tripId: id,
        seatNumbers: state.selectedSeats.toList(),
      );
    }
    _lockTimer?.cancel();
    state = state.copyWith(
      selectedSeats: const {},
      lockRemainingSeconds: 0,
    );
  }
}

final seatSelectionProvider =
    NotifierProvider<SeatSelectionNotifier, SeatSelectionState>(
  SeatSelectionNotifier.new,
);
