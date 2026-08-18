// lib/presentation/thix_reservation/bus/providers/booking_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/booking_model.dart';
import '../data/services/bus_public_service.dart';

// ─────────────────────────────────────────────────────────────
// ÉTAT IMMUABLE DES RÉSERVATIONS
// ─────────────────────────────────────────────────────────────
class BookingState {
  final List<BookingModel> myBookings;
  final bool isLoading;
  final bool isPaying;
  final String? error;
  final BookingModel? lastBooking;

  const BookingState({
    this.myBookings = const [],
    this.isLoading = false,
    this.isPaying = false,
    this.error,
    this.lastBooking,
  });

  BookingState copyWith({
    List<BookingModel>? myBookings,
    bool? isLoading,
    bool? isPaying,
    String? error,
    bool clearError = false,
    BookingModel? lastBooking,
    bool clearLastBooking = false,
  }) {
    return BookingState(
      myBookings: myBookings ?? this.myBookings,
      isLoading: isLoading ?? this.isLoading,
      isPaying: isPaying ?? this.isPaying,
      error: clearError ? null : (error ?? this.error),
      lastBooking: clearLastBooking ? null : (lastBooking ?? this.lastBooking),
    );
  }

  // --- Getters filtrés ---
  List<BookingModel> get upcoming => myBookings
      .where((b) => b.status == 'confirmed' || b.status == 'pending_payment')
      .toList();
      
  List<BookingModel> get completed => myBookings
      .where((b) => b.status == 'completed')
      .toList();
      
  List<BookingModel> get cancelled => myBookings
      .where((b) => b.status == 'cancelled')
      .toList();
}

// ─────────────────────────────────────────────────────────────
// NOTIFIER (Logique Métier)
// ─────────────────────────────────────────────────────────────
class BookingNotifier extends Notifier<BookingState> {
  final BusPublicService _service = BusPublicService();

  @override
  BookingState build() {
    return const BookingState();
  }

  Future<void> loadMyBookings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final bookings = await _service.getMyBookings();
      state = state.copyWith(
        myBookings: bookings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<BookingModel> createBookingAndPay({
    required String agencyId,
    required String tripId,
    required List<String> seats,
    required int basePrice,
    required int vipSupplement,
  }) async {
    state = state.copyWith(isPaying: true, clearError: true);

    try {
      const serviceFee = 300;
      final total = (basePrice * seats.length) + vipSupplement + serviceFee;

      // 1. Crée booking pending_payment
      final booking = await _service.createBooking(
        agencyId: agencyId,
        tripId: tripId,
        seats: seats,
        totalPrice: total,
      );

      // 2. Ici tu branches ton Thix Money / Mobile Money
      // await _thixMoneyService.pay(amount: total, reference: booking.qrCode);
      // Pour l'instant on simule succès et on confirme côté DB via RPC
      // await _service.confirmPayment(booking.id);

      // On ajoute la nouvelle réservation au début de la liste
      state = state.copyWith(
        lastBooking: booking,
        myBookings: [booking, ...state.myBookings],
        isPaying: false,
      );
      
      return booking;
    } catch (e) {
      state = state.copyWith(
        error: 'Paiement échoué: $e',
        isPaying: false,
      );
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDER GLOBAL
// ─────────────────────────────────────────────────────────────
final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(() {
  return BookingNotifier();
});
