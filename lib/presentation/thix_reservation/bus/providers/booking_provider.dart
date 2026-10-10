import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/booking_model.dart';
import '../data/services/bus_public_service.dart';

/// ============================================================================
/// BookingError — Gestion d'erreurs typée
/// ============================================================================
enum BookingErrorType {
  network,
  paymentFailed,
  paymentTimeout,
  insufficientFunds,
  seatsUnavailable,
  tripNotFound,
  unauthorized,
  validation,
  server,
  unknown,
}

class BookingError {
  final BookingErrorType type;
  final String message;
  final String? originalError;
  final DateTime timestamp;

  const BookingError({
    required this.type,
    required this.message,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _Now();

  factory BookingError.fromException(Object e) {
    final message = e.toString();
    final lower = message.toLowerCase();

    BookingErrorType type;
    if (lower.contains('network') || lower.contains('timeout') || lower.contains('socket')) {
      type = BookingErrorType.network;
    } else if (lower.contains('payment') && lower.contains('fail')) {
      type = BookingErrorType.paymentFailed;
    } else if (lower.contains('insufficient') || lower.contains('balance')) {
      type = BookingErrorType.insufficientFunds;
    } else if (lower.contains('seat') && lower.contains('unavailable')) {
      type = BookingErrorType.seatsUnavailable;
    } else if (lower.contains('trip') && lower.contains('not found')) {
      type = BookingErrorType.tripNotFound;
    } else if (lower.contains('unauthorized') || lower.contains('401')) {
      type = BookingErrorType.unauthorized;
    } else if (lower.contains('validation') || lower.contains('400')) {
      type = BookingErrorType.validation;
    } else if (lower.contains('500') || lower.contains('server')) {
      type = BookingErrorType.server;
    } else {
      type = BookingErrorType.unknown;
    }

    return BookingError(
      type: type,
      message: _humanReadableMessage(type),
      originalError: message,
    );
  }

  static String _humanReadableMessage(BookingErrorType type) {
    switch (type) {
      case BookingErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case BookingErrorType.paymentFailed:
        return 'Échec du paiement. Réessayez.';
      case BookingErrorType.paymentTimeout:
        return 'Le paiement a expiré. Réessayez.';
      case BookingErrorType.insufficientFunds:
        return 'Solde insuffisant sur votre compte.';
      case BookingErrorType.seatsUnavailable:
        return 'Les sièges ne sont plus disponibles.';
      case BookingErrorType.tripNotFound:
        return 'Ce trajet n\'existe plus.';
      case BookingErrorType.unauthorized:
        return 'Session expirée. Reconnectez-vous.';
      case BookingErrorType.validation:
        return 'Données invalides. Vérifiez le formulaire.';
      case BookingErrorType.server:
        return 'Erreur serveur. Réessayez dans quelques instants.';
      case BookingErrorType.unknown:
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
/// PaymentMethod — Méthodes de paiement supportées
/// ============================================================================
enum PaymentMethod {
  mobileMoneyOrange,
  mobileMoneyMtn,
  mobileMoneyAirtel,
  mobileMoneyWave,
  mobileMoneyMpesa,
  card,
  thixWallet,
}

/// ============================================================================
/// BookingState — État immuable des réservations
/// ============================================================================
class BookingState {
  // Données principales
  final List<BookingModel> myBookings;
  final BookingModel? lastBooking;
  final BookingModel? selectedBooking;

  // États UI
  final bool isLoading;
  final bool isRefreshing;
  final bool isPaying;
  final bool isCancelling;

  // Gestion d'erreurs
  final BookingError? error;
  final DateTime? lastUpdated;

  // Filtres actifs
  final _BookingFilter? activeFilter;
  final _BookingSort activeSort;

  const BookingState({
    this.myBookings = const [],
    this.lastBooking,
    this.selectedBooking,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isPaying = false,
    this.isCancelling = false,
    this.error,
    this.lastUpdated,
    this.activeFilter,
    this.activeSort = _BookingSort.dateDesc,
  });

  BookingState copyWith({
    List<BookingModel>? myBookings,
    BookingModel? lastBooking,
    BookingModel? selectedBooking,
    bool? isLoading,
    bool? isRefreshing,
    bool? isPaying,
    bool? isCancelling,
    BookingError? error,
    DateTime? lastUpdated,
    _BookingFilter? activeFilter,
    _BookingSort? activeSort,
    bool clearError = false,
    bool clearLastBooking = false,
    bool clearSelectedBooking = false,
    bool clearFilter = false,
  }) {
    return BookingState(
      myBookings: myBookings ?? this.myBookings,
      lastBooking: clearLastBooking ? null : (lastBooking ?? this.lastBooking),
      selectedBooking: clearSelectedBooking ? null : (selectedBooking ?? this.selectedBooking),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isPaying: isPaying ?? this.isPaying,
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      activeSort: activeSort ?? this.activeSort,
    );
  }

  // État
  bool get hasError => error != null;
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 5);
  }

  // Getters filtrés par statut
  List<BookingModel> get upcoming => myBookings
      .where((b) => b.status == 'confirmed' || b.status == 'pending_payment')
      .toList();

  List<BookingModel> get completed => myBookings
      .where((b) => b.status == 'completed')
      .toList();

  List<BookingModel> get cancelled => myBookings
      .where((b) => b.status == 'cancelled')
      .toList();

  List<BookingModel> get pending => myBookings
      .where((b) => b.status == 'pending_payment')
      .toList();

  // Bookings filtrés et triés
  List<BookingModel> get filteredBookings {
    var bookings = List<BookingModel>.from(myBookings);

    // Appliquer le filtre
    if (activeFilter != null) {
      bookings = bookings.where((b) {
        switch (activeFilter!) {
          case _BookingFilter.all:
            return true;
          case _BookingFilter.upcoming:
            return b.status == 'confirmed' || b.status == 'pending_payment';
          case _BookingFilter.completed:
            return b.status == 'completed';
          case _BookingFilter.cancelled:
            return b.status == 'cancelled';
          case _BookingFilter.pending:
            return b.status == 'pending_payment';
        }
      }).toList();
    }

    // Appliquer le tri
    bookings.sort((a, b) {
      switch (activeSort) {
        case _BookingSort.dateAsc:
          return a.createdAt.compareTo(b.createdAt);
        case _BookingSort.dateDesc:
          return b.createdAt.compareTo(a.createdAt);
        case _BookingSort.priceAsc:
          return a.totalPriceFcfa.compareTo(b.totalPriceFcfa);
        case _BookingSort.priceDesc:
          return b.totalPriceFcfa.compareTo(a.totalPriceFcfa);
      }
    });

    return bookings;
  }

  // Stats
  int get totalBookings => myBookings.length;
  int get totalSpent {
    return myBookings
        .where((b) => b.status == 'confirmed' || b.status == 'completed')
        .fold(0, (sum, b) => sum + b.totalPriceFcfa);
  }

  Map<String, int> get bookingsByStatus {
    final map = <String, int>{};
    for (final b in myBookings) {
      map[b.status] = (map[b.status] ?? 0) + 1;
    }
    return map;
  }

  // Récupérer un booking par ID
  BookingModel? getById(String id) {
    try {
      return myBookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // Bookings par agence
  List<BookingModel> getByAgency(String agencyId) {
    return myBookings.where((b) => b.trip?.agencyId == agencyId).toList();
  }

  // Bookings par date range
  List<BookingModel> getByDateRange(DateTime start, DateTime end) {
    return myBookings.where((b) {
      return b.createdAt.isAfter(start) && b.createdAt.isBefore(end);
    }).toList();
  }
}

/// ============================================================================
/// Enums pour filtres et tri
/// ============================================================================
enum _BookingFilter {
  all,
  upcoming,
  completed,
  cancelled,
  pending,
}

enum _BookingSort {
  dateAsc,
  dateDesc,
  priceAsc,
  priceDesc,
}

/// ============================================================================
/// BookingNotifier — Logique métier
/// ============================================================================
class BookingNotifier extends Notifier<BookingState> {
  final BusPublicService _service = BusPublicService();

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const int _serviceFee = 300; // Frais de service THIX en CDF

  @override
  BookingState build() {
    return const BookingState();
  }

  /// Charger tous les bookings de l'utilisateur
  Future<void> loadMyBookings({bool force = false}) async {
    // Si on a des données récentes et pas de force refresh, skip
    if (!force && !state.isStale && state.myBookings.isNotEmpty) {
      _log('Données encore fraîches, skip load');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final bookings = await _service.getMyBookings().timeout(_timeout);

      state = state.copyWith(
        myBookings: bookings,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      _log('Bookings chargés : ${bookings.length}');
    } catch (e) {
      _logError('Erreur chargement bookings', e);
      state = state.copyWith(
        error: BookingError.fromException(e),
        isLoading: false,
      );
    }
  }

  /// Refresh léger (sans recharger tout)
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final bookings = await _service.getMyBookings().timeout(_timeout);

      state = state.copyWith(
        myBookings: bookings,
        isRefreshing: false,
        lastUpdated: DateTime.now(),
      );

      _log('Refresh réussi : ${bookings.length} bookings');
    } catch (e) {
      _logError('Erreur refresh', e);
      state = state.copyWith(
        error: BookingError.fromException(e),
        isRefreshing: false,
      );
    }
  }

  /// Créer un booking et initier le paiement
  Future<BookingModel> createBookingAndPay({
    required String agencyId,
    required String tripId,
    required List<String> seats,
    required int basePrice,
    required int vipSupplement,
    PaymentMethod paymentMethod = PaymentMethod.thixWallet,
    String? phoneNumber, // Pour Mobile Money
    String? email, // Pour carte
  }) async {
    // Validation
    if (seats.isEmpty) {
      throw const BookingError(
        type: BookingErrorType.validation,
        message: 'Aucun siège sélectionné',
      );
    }

    if (basePrice <= 0) {
      throw const BookingError(
        type: BookingErrorType.validation,
        message: 'Prix invalide',
      );
    }

    state = state.copyWith(isPaying: true, clearError: true);

    try {
      final total = (basePrice * seats.length) + vipSupplement + _serviceFee;

      _log('Création booking : $total FCFA pour ${seats.length} sièges');

      // 1. Créer le booking en pending_payment
      final booking = await _service.createBooking(
        agencyId: agencyId,
        tripId: tripId,
        seats: seats,
        totalPrice: total,
      ).timeout(_timeout);

      _log('Booking créé : ${booking.id}');

      // 2. Initier le paiement selon la méthode
      await _initiatePayment(
        booking: booking,
        amount: total,
        method: paymentMethod,
        phoneNumber: phoneNumber,
        email: email,
      );

      // 3. Confirmer le paiement (côté backend)
      final confirmedBooking = await _service.confirmPayment(booking.id).timeout(_timeout);

      // 4. Mettre à jour l'état
      state = state.copyWith(
        lastBooking: confirmedBooking,
        myBookings: [confirmedBooking, ...state.myBookings],
        isPaying: false,
        lastUpdated: DateTime.now(),
      );

      _log('Paiement confirmé : ${confirmedBooking.id}');
      return confirmedBooking;
    } catch (e) {
      _logError('Erreur création booking', e);
      state = state.copyWith(
        error: BookingError.fromException(e),
        isPaying: false,
      );
      rethrow;
    }
  }

  /// Initier le paiement selon la méthode choisie
  Future<void> _initiatePayment({
    required BookingModel booking,
    required int amount,
    required PaymentMethod method,
    String? phoneNumber,
    String? email,
  }) async {
    _log('Initiation paiement : ${method.name} pour $amount FCFA');

    switch (method) {
      case PaymentMethod.mobileMoneyOrange:
      case PaymentMethod.mobileMoneyMtn:
      case PaymentMethod.mobileMoneyAirtel:
      case PaymentMethod.mobileMoneyWave:
      case PaymentMethod.mobileMoneyMpesa:
        if (phoneNumber == null || phoneNumber.isEmpty) {
          throw const BookingError(
            type: BookingErrorType.validation,
            message: 'Numéro de téléphone requis pour Mobile Money',
          );
        }
        await _payWithMobileMoney(
          booking: booking,
          amount: amount,
          method: method,
          phoneNumber: phoneNumber,
        );
        break;

      case PaymentMethod.card:
        if (email == null || email.isEmpty) {
          throw const BookingError(
            type: BookingErrorType.validation,
            message: 'Email requis pour paiement par carte',
          );
        }
        await _payWithCard(
          booking: booking,
          amount: amount,
          email: email,
        );
        break;

      case PaymentMethod.thixWallet:
        await _payWithThixWallet(
          booking: booking,
          amount: amount,
        );
        break;
    }
  }

  /// Paiement Mobile Money (Orange, MTN, Airtel, Wave, M-Pesa)
  Future<void> _payWithMobileMoney({
    required BookingModel booking,
    required int amount,
    required PaymentMethod method,
    required String phoneNumber,
  }) async {
    _log('Paiement Mobile Money : ${method.name} → $phoneNumber');

    // TODO: Intégrer les APIs Mobile Money
    // Exemple pour Orange Money :
    // await OrangeMoneyService.initiatePayment(
    //   phoneNumber: phoneNumber,
    //   amount: amount,
    //   reference: booking.id,
    //   callbackUrl: 'https://api.thix.id/payments/callback',
    // );

    // Pour l'instant, on simule un délai de traitement
    await Future.delayed(const Duration(seconds: 2));

    _log('Mobile Money : paiement initié');
  }

  /// Paiement par carte (via Flutterwave/Stripe)
  Future<void> _payWithCard({
    required BookingModel booking,
    required int amount,
    required String email,
  }) async {
    _log('Paiement carte : $email');

    // TODO: Intégrer Flutterwave/Stripe
    // await FlutterwaveService.initiatePayment(
    //   email: email,
    //   amount: amount,
    //   currency: 'XOF',
    //   reference: booking.id,
    //   redirectUrl: 'https://app.thix.id/payment/success',
    // );

    // Pour l'instant, on simule
    await Future.delayed(const Duration(seconds: 2));

    _log('Carte : paiement initié');
  }

  /// Paiement via THIX Wallet
  Future<void> _payWithThixWallet({
    required BookingModel booking,
    required int amount,
  }) async {
    _log('Paiement THIX Wallet : $amount FCFA');

    // TODO: Intégrer THIX Wallet
    // await ThixWalletService.pay(
    //   amount: amount,
    //   reference: booking.id,
    //   description: 'Réservation bus ${booking.id}',
    // );

    // Pour l'instant, on simule
    await Future.delayed(const Duration(seconds: 1));

    _log('THIX Wallet : paiement effectué');
  }

  /// Annuler un booking
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    state = state.copyWith(isCancelling: true, clearError: true);

    try {
      await _service.cancelBooking(bookingId, reason: reason).timeout(_timeout);

      // ✅ CORRECTION : annotation de type explicite <BookingModel>
      final updatedBookings = state.myBookings.map<BookingModel>((b) {
        if (b.id == bookingId) {
          return BookingModel(
            id: b.id,
            tripId: b.tripId,
            userId: b.userId,
            seats: b.seats,
            totalPriceFcfa: b.totalPriceFcfa,
            status: 'cancelled',
            qrCode: b.qrCode,
            createdAt: b.createdAt,
            passengerName: b.passengerName,
            trip: b.trip,
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        myBookings: updatedBookings,
        isCancelling: false,
        lastUpdated: DateTime.now(),
      );

      _log('Booking annulé : $bookingId');
      return true;
    } catch (e) {
      _logError('Erreur annulation booking', e);
      state = state.copyWith(
        error: BookingError.fromException(e),
        isCancelling: false,
      );
      return false;
    }
  }

  /// Récupérer les détails d'un booking spécifique
  Future<BookingModel?> getBookingDetails(String bookingId) async {
    // D'abord chercher dans le cache local
    final cached = state.getById(bookingId);
    if (cached != null && !state.isStale) {
      _log('Booking trouvé en cache : $bookingId');
      return cached;
    }

    // Sinon charger depuis l'API
    try {
      final booking = await _service.getBookingById(bookingId).timeout(_timeout);

      // ✅ CORRECTION : annotation de type explicite <BookingModel>
      final updatedBookings = state.myBookings.map<BookingModel>((b) {
        return b.id == bookingId ? booking : b;
      }).toList();

      // Si le booking n'existait pas, l'ajouter
      if (!updatedBookings.any((b) => b.id == bookingId)) {
        updatedBookings.add(booking);
      }

      state = state.copyWith(
        myBookings: updatedBookings,
        selectedBooking: booking,
      );

      _log('Booking chargé : $bookingId');
      return booking;
    } catch (e) {
      _logError('Erreur chargement booking', e);
      state = state.copyWith(
        error: BookingError.fromException(e),
      );
      return null;
    }
  }

  /// Définir le filtre actif
  void setFilter(_BookingFilter? filter) {
    state = state.copyWith(
      activeFilter: filter,
      clearFilter: filter == null,
    );
    _log('Filtre défini : ${filter?.name ?? "aucun"}');
  }

  /// Définir le tri actif
  void setSort(_BookingSort sort) {
    state = state.copyWith(activeSort: sort);
    _log('Tri défini : ${sort.name}');
  }

  /// Sélectionner un booking
  void selectBooking(BookingModel? booking) {
    state = state.copyWith(
      selectedBooking: booking,
      clearSelectedBooking: booking == null,
    );
  }

  /// Effacer l'erreur
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Effacer le lastBooking
  void clearLastBooking() {
    state = state.copyWith(clearLastBooking: true);
  }

  // Logging helpers
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BookingProvider] $message');
    }
  }

  void _logError(String context, Object error) {
    if (kDebugMode) {
      debugPrint('[BookingProvider] ❌ $context: $error');
    }
  }
}

/// ============================================================================
/// Provider global
/// ============================================================================
final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
);
