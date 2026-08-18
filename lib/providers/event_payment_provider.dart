import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_payment_service.dart';

final eventPaymentServiceProvider = Provider<EventPaymentService>((ref) {
  return EventPaymentService(Supabase.instance.client);
});

class EventPaymentState {
  final bool isProcessing;
  final String? errorMessage;
  const EventPaymentState({this.isProcessing = false, this.errorMessage});
  EventPaymentState copyWith({bool? isProcessing, String? errorMessage}) {
    return EventPaymentState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class EventPaymentNotifier extends StateNotifier<EventPaymentState> {
  final EventPaymentService _service;
  EventPaymentNotifier(this._service) : super(const EventPaymentState());

  bool get isProcessing => state.isProcessing;
  String? get errorMessage => state.errorMessage;

  Future<bool> makePayment({
    required String bookingId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? phoneNumber,
    Map<String, String>? cardDetails,
  }) async {
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final ok = await _service.processPayment(
        bookingId: bookingId,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        phoneNumber: phoneNumber,
        cardDetails: cardDetails,
      );
      state = state.copyWith(isProcessing: false);
      return ok;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
      return false;
    }
  }

  // Compat pour ancien _paymentProvider
  Future<bool> processPayment({
    required String bookingId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? phoneNumber,
    Map<String, String>? cardDetails,
  }) => makePayment(
    bookingId: bookingId,
    amount: amount,
    currency: currency,
    paymentMethod: paymentMethod,
    phoneNumber: phoneNumber,
    cardDetails: cardDetails,
  );
}

final eventPaymentProvider = StateNotifierProvider<EventPaymentNotifier, EventPaymentState>((ref) {
  final svc = ref.watch(eventPaymentServiceProvider);
  return EventPaymentNotifier(svc);
});

// Alias legacy pour pages qui font Provider<EventPaymentProvider>
typedef EventPaymentProvider = EventPaymentNotifier;
final legacyPaymentProvider = Provider<EventPaymentNotifier>((ref) => ref.read(eventPaymentProvider.notifier));
