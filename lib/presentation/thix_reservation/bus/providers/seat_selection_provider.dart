import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/seat_model.dart';
import '../data/services/bus_public_service.dart';

/// ============================================================================
/// SeatSelectionError — Gestion d'erreurs typée
/// ============================================================================
enum SeatSelectionErrorType {
  network,
  timeout,
  seatsUnavailable,
  maxSeatsReached,
  lockFailed,
  unlockFailed,
  tripNotFound,
  server,
  unknown,
}

class SeatSelectionError {
  final SeatSelectionErrorType type;
  final String message;
  final String? originalError;
  final DateTime timestamp;

  const SeatSelectionError({
    required this.type,
    required this.message,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _Now();

  factory SeatSelectionError.fromException(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();

    SeatSelectionErrorType type;
    if (lower.contains('timeout')) {
      type = SeatSelectionErrorType.timeout;
    } else if (lower.contains('network') || lower.contains('socket')) {
      type = SeatSelectionErrorType.network;
    } else if (lower.contains('unavailable') || lower.contains('booked')) {
      type = SeatSelectionErrorType.seatsUnavailable;
    } else if (lower.contains('max') || lower.contains('limit')) {
      type = SeatSelectionErrorType.maxSeatsReached;
    } else if (lower.contains('lock')) {
      type = SeatSelectionErrorType.lockFailed;
    } else if (lower.contains('unlock')) {
      type = SeatSelectionErrorType.unlockFailed;
    } else if (lower.contains('not found') || lower.contains('404')) {
      type = SeatSelectionErrorType.tripNotFound;
    } else if (lower.contains('500') || lower.contains('server')) {
      type = SeatSelectionErrorType.server;
    } else {
      type = SeatSelectionErrorType.unknown;
    }

    return SeatSelectionError(
      type: type,
      message: _humanReadable(type),
      originalError: msg,
    );
  }

  static String _humanReadable(SeatSelectionErrorType type) {
    switch (type) {
      case SeatSelectionErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case SeatSelectionErrorType.timeout:
        return 'La requête a pris trop de temps. Réessayez.';
      case SeatSelectionErrorType.seatsUnavailable:
        return 'Certains sièges ne sont plus disponibles.';
      case SeatSelectionErrorType.maxSeatsReached:
        return 'Nombre maximum de sièges atteint.';
      case SeatSelectionErrorType.lockFailed:
        return 'Impossible de réserver les sièges. Réessayez.';
      case SeatSelectionErrorType.unlockFailed:
        return 'Impossible de libérer les sièges.';
      case SeatSelectionErrorType.tripNotFound:
        return 'Ce trajet n\'existe plus.';
      case SeatSelectionErrorType.server:
        return 'Erreur serveur. Réessayez dans quelques instants.';
      case SeatSelectionErrorType.unknown:
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
/// SeatSelectionState — État immuable de la sélection
/// ============================================================================
class SeatSelectionState {
  // Identifiants
  final String? tripId;
  final int maxSelectable;

  // Données
  final List<SeatModel> seats;
  final Set<String> selectedSeats;

  // États UI
  final bool isLoading;
  final bool isRefreshing;
  final bool isConfirming;
  final bool isCancelling;

  // Lock timer
  final int lockRemainingSeconds;
  final int lockTotalSeconds;

  // Gestion d'erreurs
  final SeatSelectionError? error;
  final DateTime? lastUpdated;

  const SeatSelectionState({
    this.tripId,
    this.seats = const [],
    this.selectedSeats = const {},
    this.maxSelectable = 1,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isConfirming = false,
    this.isCancelling = false,
    this.error,
    this.lastUpdated,
    this.lockRemainingSeconds = 0,
    this.lockTotalSeconds = 300, // 5 minutes par défaut
  });

  SeatSelectionState copyWith({
    String? tripId,
    List<SeatModel>? seats,
    Set<String>? selectedSeats,
    int? maxSelectable,
    bool? isLoading,
    bool? isRefreshing,
    bool? isConfirming,
    bool? isCancelling,
    SeatSelectionError? error,
    DateTime? lastUpdated,
    int? lockRemainingSeconds,
    int? lockTotalSeconds,
    bool clearError = false,
    bool clearTripId = false,
  }) {
    return SeatSelectionState(
      tripId: clearTripId ? null : (tripId ?? this.tripId),
      seats: seats ?? this.seats,
      selectedSeats: selectedSeats ?? this.selectedSeats,
      maxSelectable: maxSelectable ?? this.maxSelectable,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isConfirming: isConfirming ?? this.isConfirming,
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lockRemainingSeconds: lockRemainingSeconds ?? this.lockRemainingSeconds,
      lockTotalSeconds: lockTotalSeconds ?? this.lockTotalSeconds,
    );
  }

  // ─── État ─────────────────────────────────────────────────
  bool get hasError => error != null;
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 2);
  }

  bool get hasSelection => selectedSeats.isNotEmpty;
  bool get isLocked => lockRemainingSeconds > 0;

  // ─── Capacités ────────────────────────────────────────────
  bool get canSelectMore => selectedSeats.length < maxSelectable;
  int get remainingSelectable => maxSelectable - selectedSeats.length;
  bool get isReadyForPayment => hasSelection && !isLoading && !isConfirming;

  // ─── Stats sur les sièges ─────────────────────────────────
  int get totalSeatsCount => seats.length;

  int get availableSeatsCount =>
      seats.where((s) => s.isAvailable).length;

  int get bookedSeatsCount =>
      seats.where((s) => !s.isAvailable).length;

  int get vipSeatsCount =>
      seats.where((s) => s.isVip && s.isAvailable).length;

  double get occupancyRate {
    if (seats.isEmpty) return 0;
    return (bookedSeatsCount / seats.length) * 100;
  }

  // ─── Stats sur la sélection ───────────────────────────────
  int get selectedCount => selectedSeats.length;

  int get vipSeatsSelectedCount {
    var count = 0;
    for (final num in selectedSeats) {
      final seat = seatByNumber(num);
      if (seat != null && seat.isVip) count++;
    }
    return count;
  }

  int get standardSeatsSelectedCount =>
      selectedCount - vipSeatsSelectedCount;

  // ─── Calculs prix ─────────────────────────────────────────
  int get totalVipSupplement {
    var sup = 0;
    for (final num in selectedSeats) {
      final seat = seatByNumber(num);
      if (seat != null) sup += seat.extraPrice;
    }
    return sup;
  }

  int get totalBasePrice => selectedCount; // Sera multiplié par priceFcfa côté UI

  // ─── Timer ────────────────────────────────────────────────
  double get lockProgress {
    if (lockTotalSeconds == 0) return 0;
    return (lockRemainingSeconds / lockTotalSeconds).clamp(0.0, 1.0);
  }

  bool get isLockExpiringSoon =>
      lockRemainingSeconds > 0 && lockRemainingSeconds < 60;

  bool get isLockExpiringUrgent =>
      lockRemainingSeconds > 0 && lockRemainingSeconds < 30;

  String get lockFormattedTime {
    final minutes = (lockRemainingSeconds / 60).floor();
    final seconds = lockRemainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ─── Utilitaires ──────────────────────────────────────────
  SeatModel? seatByNumber(String num) {
    try {
      return seats.firstWhere((s) => s.seatNumber == num);
    } catch (_) {
      return null;
    }
  }

  List<SeatModel> get selectedSeatsModels {
    return selectedSeats
        .map((num) => seatByNumber(num))
        .whereType<SeatModel>()
        .toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
  }

  bool isSelected(String seatNumber) =>
      selectedSeats.contains(seatNumber);

  bool isAvailable(String seatNumber) {
    final seat = seatByNumber(seatNumber);
    return seat?.isAvailable ?? false;
  }
}

/// ============================================================================
/// SeatSelectionNotifier — Logique métier
/// ============================================================================
class SeatSelectionNotifier extends Notifier<SeatSelectionState> {
  final BusPublicService _service = BusPublicService();

  StreamSubscription<List<SeatModel>>? _seatSubscription;
  Timer? _lockTimer;

  static const Duration _timeout = Duration(seconds: 10);
  static const int _defaultLockDurationSeconds = 300; // 5 minutes
  static const int _maxSelectableLimit = 8;

  @override
  SeatSelectionState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const SeatSelectionState();
  }

  void _cleanup() {
    _seatSubscription?.cancel();
    _seatSubscription = null;
    _lockTimer?.cancel();
    _lockTimer = null;
    _log('Cleanup effectué');
  }

  // ─── Initialisation ───────────────────────────────────────
  void init(String tripId, int passengers) {
    if (tripId.isEmpty) {
      state = state.copyWith(
        error: const SeatSelectionError(
          type: SeatSelectionErrorType.tripNotFound,
          message: 'ID de trajet invalide',
        ),
      );
      return;
    }

    final max = passengers.clamp(1, _maxSelectableLimit);

    _cleanup();

    state = SeatSelectionState(
      tripId: tripId,
      maxSelectable: max,
      isLoading: true,
    );

    _log('Init : trip=$tripId, max=$max');
    _listenSeats();
  }

  // ─── Écoute temps réel des sièges ─────────────────────────
  void _listenSeats() {
    final id = state.tripId;
    if (id == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    _seatSubscription = _service.watchSeats(id).listen(
      (data) {
        _handleSeatsUpdate(data);
      },
      onError: (e) {
        _logError('Erreur stream sièges', e);
        state = state.copyWith(
          error: SeatSelectionError.fromException(e),
          isLoading: false,
          isRefreshing: false,
        );
      },
      onDone: () {
        _log('Stream sièges terminé');
      },
    );
  }

  void _handleSeatsUpdate(List<SeatModel> data) {
    // Nettoyer la sélection : retirer les sièges qui ne sont plus disponibles
    final newSelected = Set<String>.from(state.selectedSeats);
    final removedSeats = <String>[];

    newSelected.removeWhere((num) {
      final seat = data.cast<SeatModel?>().firstWhere(
        (s) => s?.seatNumber == num,
        orElse: () => null,
      );

      if (seat == null) {
        removedSeats.add(num);
        return true;
      }

      // Si le siège a été pris par quelqu'un d'autre (pas par nous)
      if (!seat.isAvailable && seat.lockedByCurrentUser != true) {
        removedSeats.add(num);
        return true;
      }

      return false;
    });

    if (removedSeats.isNotEmpty) {
      _log('Sièges retirés (devenus indisponibles) : ${removedSeats.join(", ")}');
      state = state.copyWith(
        error: const SeatSelectionError(
          type: SeatSelectionErrorType.seatsUnavailable,
          message: 'Certains sièges sélectionnés ne sont plus disponibles',
        ),
      );
    }

    state = state.copyWith(
      seats: data,
      selectedSeats: newSelected,
      isLoading: false,
      isRefreshing: false,
      lastUpdated: DateTime.now(),
      lockRemainingSeconds: _calculateRemainingSeconds(data, newSelected),
    );

    _startLockTimer();
  }

  // ─── Refresh ──────────────────────────────────────────────
  Future<void> refresh() async {
    if (state.tripId == null) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    // Le stream se rafraîchira automatiquement via Supabase Realtime
    _log('Refresh demandé');
  }

  // ─── Toggle siège ─────────────────────────────────────────
  void toggleSeat(SeatModel seat) {
    if (!seat.isAvailable) {
      state = state.copyWith(
        error: const SeatSelectionError(
          type: SeatSelectionErrorType.seatsUnavailable,
          message: 'Ce siège n\'est pas disponible',
        ),
      );
      return;
    }

    final newSelected = Set<String>.from(state.selectedSeats);

    if (newSelected.contains(seat.seatNumber)) {
      // Désélection
      newSelected.remove(seat.seatNumber);
      _log('Siège désélectionné : ${seat.seatNumber}');
    } else {
      // Sélection
      if (!state.canSelectMore) {
        state = state.copyWith(
          error: SeatSelectionError(
            type: SeatSelectionErrorType.maxSeatsReached,
            message: 'Maximum ${state.maxSelectable} sièges autorisés',
          ),
        );
        return;
      }
      newSelected.add(seat.seatNumber);
      _log('Siège sélectionné : ${seat.seatNumber} (VIP: ${seat.isVip})');
    }

    state = state.copyWith(selectedSeats: newSelected, clearError: true);
    _handleLock(newSelected);
  }

  // ─── Sélection multiple (pour UX avancée) ─────────────────
  void selectSeats(List<String> seatNumbers) {
    final newSelected = <String>{};
    final errors = <String>[];

    for (final num in seatNumbers) {
      final seat = state.seatByNumber(num);
      if (seat == null || !seat.isAvailable) {
        errors.add(num);
        continue;
      }
      newSelected.add(num);
      if (newSelected.length >= state.maxSelectable) break;
    }

    state = state.copyWith(
      selectedSeats: newSelected,
      clearError: errors.isEmpty,
      error: errors.isEmpty
          ? null
          : SeatSelectionError(
              type: SeatSelectionErrorType.seatsUnavailable,
              message: '${errors.length} siège(s) indisponible(s)',
            ),
    );

    _handleLock(newSelected);
    _log('Sélection multiple : ${newSelected.length} sièges');
  }

  // ─── Auto-sélection des meilleurs sièges ──────────────────
  void autoSelectBestSeats([int? count]) {
    final target = count ?? state.maxSelectable;
    final available = state.seats
        .where((s) => s.isAvailable)
        .toList();

    if (available.isEmpty) {
      state = state.copyWith(
        error: const SeatSelectionError(
          type: SeatSelectionErrorType.seatsUnavailable,
          message: 'Aucun siège disponible',
        ),
      );
      return;
    }

    // Tri : VIP d'abord, puis par numéro
    available.sort((a, b) {
      if (a.isVip != b.isVip) return a.isVip ? -1 : 1;
      return a.seatNumber.compareTo(b.seatNumber);
    });

    final toSelect = available
        .take(target)
        .map((s) => s.seatNumber)
        .toSet();

    state = state.copyWith(selectedSeats: toSelect, clearError: true);
    _handleLock(toSelect);
    _log('Auto-sélection : ${toSelect.length} meilleurs sièges');
  }

  // ─── Effacer la sélection ─────────────────────────────────
  void clearSelection() {
    if (state.selectedSeats.isEmpty) return;

    final previousSelected = state.selectedSeats.toList();
    state = state.copyWith(
      selectedSeats: const {},
      lockRemainingSeconds: 0,
      clearError: true,
    );
    _lockTimer?.cancel();

    // Unlock en background (best effort)
    _unlockSeats(previousSelected);
    _log('Sélection effacée');
  }

  // ─── Lock/Unlock ──────────────────────────────────────────
  Future<void> _handleLock(Set<String> currentlySelected) async {
    final id = state.tripId;
    if (id == null) return;

    if (currentlySelected.isEmpty) {
      _lockTimer?.cancel();
      state = state.copyWith(lockRemainingSeconds: 0);
      return;
    }

    try {
      await _service.lockSeats(
        tripId: id,
        seatNumbers: currentlySelected.toList(),
      ).timeout(_timeout);

      _log('Lock réussi : ${currentlySelected.length} sièges');
      _startLockTimer();
    } catch (e) {
      _logError('Erreur lock', e);
      state = state.copyWith(
        error: SeatSelectionError.fromException(e),
      );
    }
  }

  Future<void> _unlockSeats(List<String> seatNumbers) async {
    final id = state.tripId;
    if (id == null || seatNumbers.isEmpty) return;

    try {
      await _service.unlockSeats(
        tripId: id,
        seatNumbers: seatNumbers,
      ).timeout(_timeout);
      _log('Unlock réussi : ${seatNumbers.length} sièges');
    } catch (e) {
      _logError('Erreur unlock (best effort)', e);
    }
  }

  // ─── Timer de lock ────────────────────────────────────────
  int _calculateRemainingSeconds(
    List<SeatModel> seats,
    Set<String> selected,
  ) {
    DateTime? latestUntil;

    for (final num in selected) {
      for (final seat in seats) {
        if (seat.seatNumber == num && seat.lockedUntil != null) {
          if (latestUntil == null || seat.lockedUntil!.isAfter(latestUntil)) {
            latestUntil = seat.lockedUntil;
          }
        }
      }
    }

    if (latestUntil == null) return 0;
    final sec = latestUntil.difference(DateTime.now()).inSeconds;
    return sec < 0 ? 0 : sec;
  }

  void _startLockTimer() {
    _lockTimer?.cancel();

    if (state.lockRemainingSeconds <= 0) return;

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _calculateRemainingSeconds(
        state.seats,
        state.selectedSeats,
      );

      if (remaining <= 0) {
        timer.cancel();
        _log('Lock expiré — sélection effacée');
        state = state.copyWith(
          lockRemainingSeconds: 0,
          selectedSeats: const {},
          error: const SeatSelectionError(
            type: SeatSelectionErrorType.lockFailed,
            message: 'Le temps de réservation a expiré. Veuillez recommencer.',
          ),
        );
      } else {
        // Seulement update si changement (éviter rebuilds inutiles)
        if (remaining != state.lockRemainingSeconds) {
          state = state.copyWith(lockRemainingSeconds: remaining);
        }
      }
    });
  }

  // ─── Confirmation pour paiement ───────────────────────────
  Future<bool> confirmAndUnlockForPayment() async {
    if (!state.isReadyForPayment) {
      state = state.copyWith(
        error: const SeatSelectionError(
          type: SeatSelectionErrorType.lockFailed,
          message: 'Impossible de confirmer. Vérifiez votre sélection.',
        ),
      );
      return false;
    }

    state = state.copyWith(isConfirming: true, clearError: true);
    _lockTimer?.cancel();

    try {
      // Le unlock est géré par le booking provider après succès
      _log('Confirmation pour paiement : ${state.selectedSeats.length} sièges');
      state = state.copyWith(isConfirming: false);
      return true;
    } catch (e) {
      _logError('Erreur confirmation', e);
      state = state.copyWith(
        isConfirming: false,
        error: SeatSelectionError.fromException(e),
      );
      return false;
    }
  }

  // ─── Annulation ───────────────────────────────────────────
  Future<void> cancelSelection() async {
    if (state.selectedSeats.isEmpty) {
      state = state.copyWith(
        selectedSeats: const {},
        lockRemainingSeconds: 0,
      );
      return;
    }

    state = state.copyWith(isCancelling: true, clearError: true);
    final seatsToUnlock = state.selectedSeats.toList();

    try {
      await _service.unlockSeats(
        tripId: state.tripId!,
        seatNumbers: seatsToUnlock,
      ).timeout(_timeout);

      _log('Annulation réussie : ${seatsToUnlock.length} sièges libérés');
    } catch (e) {
      _logError('Erreur unlock (cancel)', e);
    } finally {
      _lockTimer?.cancel();
      state = state.copyWith(
        isCancelling: false,
        selectedSeats: const {},
        lockRemainingSeconds: 0,
        clearError: true,
      );
    }
  }

  // ─── Utilitaires ──────────────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    _cleanup();
    state = const SeatSelectionState();
    _log('Reset complet');
  }

  // ─── Logging ──────────────────────────────────────────────
  void _log(String message) {
    if (kDebugMode) debugPrint('[SeatSelection] $message');
  }

  void _logError(String context, Object error) {
    if (kDebugMode) debugPrint('[SeatSelection] ❌ $context: $error');
  }
}

/// ============================================================================
/// Provider global
/// ============================================================================
final seatSelectionProvider =
    NotifierProvider<SeatSelectionNotifier, SeatSelectionState>(
  SeatSelectionNotifier.new,
);
