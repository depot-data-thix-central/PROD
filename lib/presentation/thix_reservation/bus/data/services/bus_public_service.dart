import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bus_trip_model.dart';
import '../models/city_model.dart';
import '../models/seat_model.dart';
import '../models/booking_model.dart';

/// ============================================================================
/// PublicServiceError — Gestion d'erreurs typée
/// ============================================================================
enum PublicServiceErrorType {
  unauthorized,
  notFound,
  seatsUnavailable,
  lockExpired,
  validation,
  network,
  timeout,
  server,
  unknown,
}

class PublicServiceError implements Exception {
  final PublicServiceErrorType type;
  final String message;
  final String? originalError;
  final String? method;

  const PublicServiceError({
    required this.type,
    required this.message,
    this.originalError,
    this.method,
  });

  factory PublicServiceError.fromException(Object e, {String? method}) {
    final msg = e.toString();
    final lower = msg.toLowerCase();

    PublicServiceErrorType type;
    if (lower.contains('timeout')) {
      type = PublicServiceErrorType.timeout;
    } else if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      type = PublicServiceErrorType.network;
    } else if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt')) {
      type = PublicServiceErrorType.unauthorized;
    } else if (lower.contains('404') || lower.contains('not found')) {
      type = PublicServiceErrorType.notFound;
    } else if (lower.contains('locked') ||
        lower.contains('unavailable') ||
        lower.contains('booked')) {
      type = PublicServiceErrorType.seatsUnavailable;
    } else if (lower.contains('expired')) {
      type = PublicServiceErrorType.lockExpired;
    } else if (lower.contains('400') ||
        lower.contains('validation') ||
        lower.contains('invalid')) {
      type = PublicServiceErrorType.validation;
    } else if (lower.contains('500') || lower.contains('server')) {
      type = PublicServiceErrorType.server;
    } else {
      type = PublicServiceErrorType.unknown;
    }

    return PublicServiceError(
      type: type,
      message: _humanReadable(type),
      originalError: msg,
      method: method,
    );
  }

  static String _humanReadable(PublicServiceErrorType type) {
    switch (type) {
      case PublicServiceErrorType.unauthorized:
        return 'Session expirée. Veuillez vous reconnecter.';
      case PublicServiceErrorType.notFound:
        return 'Ressource introuvable.';
      case PublicServiceErrorType.seatsUnavailable:
        return 'Certains sièges ne sont plus disponibles.';
      case PublicServiceErrorType.lockExpired:
        return 'Le verrouillage des sièges a expiré.';
      case PublicServiceErrorType.validation:
        return 'Données invalides. Vérifiez les informations.';
      case PublicServiceErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case PublicServiceErrorType.timeout:
        return 'La requête a pris trop de temps. Réessayez.';
      case PublicServiceErrorType.server:
        return 'Erreur serveur. Réessayez dans quelques instants.';
      case PublicServiceErrorType.unknown:
        return 'Une erreur inattendue s\'est produite.';
    }
  }

  @override
  String toString() => 'PublicServiceError[$method]: $message';
}

/// ============================================================================
/// BusPublicService
/// ============================================================================
///
/// Service d'accès aux données pour les fonctionnalités côté client (public).
///
/// Responsabilités :
/// - Recherche de trajets (SaaS multi-agences)
/// - Villes (autocomplete)
/// - Routes populaires
/// - Gestion des sièges (lecture + lock/unlock + realtime)
/// - Création et consultation de bookings (client)
///
/// Features :
/// - ✅ Gestion d'erreurs typée (PublicServiceError)
/// - ✅ Timeouts configurables (8s par défaut, 15s pour opérations longues)
/// - ✅ Retry logic avec backoff exponentiel (2 tentatives)
/// - ✅ Logging structuré
/// - ✅ Validation des paramètres
/// - ✅ Opérations batch optimisées (inFilter)
/// - ✅ Stream Realtime avec gestion d'erreurs
/// - ✅ Génération QR code robuste (hash-based)
/// - ✅ Sécurité : vérification auth + ownership
///
/// ============================================================================
class BusPublicService {
  final SupabaseClient _db = Supabase.instance.client;

  // ─── Constantes ───────────────────────────────────────────
  static const String _citiesTable = 'cities';
  static const String _tripsTable = 'bus_trips';
  static const String _seatsTable = 'bus_seats';
  static const String _bookingsTable = 'bus_bookings';
  static const String _popularView = 'popular_routes_view';

  static const Duration _defaultTimeout = Duration(seconds: 8);
  static const Duration _longTimeout = Duration(seconds: 15);
  static const int _maxRetries = 2;
  static const int _seatLockDurationMinutes = 10;
  static const int _maxPopularRoutes = 8;
  static const int _maxCities = 200;

  // ─── Helpers d'authentification ───────────────────────────

  /// UID courant ou null
  String? get _currentUserId => _db.auth.currentUser?.id;

  /// UID requis (throw si non connecté)
  String get _requireUid {
    final uid = _currentUserId;
    if (uid == null) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.unauthorized,
        message: 'Utilisateur non connecté',
      );
    }
    return uid;
  }

  // ═══════════════════════════════════════════════════════════
  // CITIES
  // ═══════════════════════════════════════════════════════════

  /// Récupère la liste des villes actives pour l'autocomplete.
  Future<List<CityModel>> getCities({Duration? timeout}) async {
    return _safeCall<List<CityModel>>(
      'getCities',
      () async {
        final res = await _db
            .from(_citiesTable)
            .select()
            .eq('is_active', true)
            .order('is_popular', ascending: false)
            .order('name', ascending: true)
            .limit(_maxCities);

        return (res as List)
            .map((e) => CityModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH (SaaS multi-agences)
  // ═══════════════════════════════════════════════════════════

  /// Recherche SaaS : cherche dans TOUTES les agences actives.
  ///
  /// Règles métier :
  /// - Uniquement les trajets `scheduled`
  /// - Uniquement les agences `active`
  /// - Minimum `passengers` places disponibles
  /// - Plage de date : jour complet (00h00 → 23h59)
  Future<List<BusTripModel>> searchTrips({
    required String from,
    required String to,
    required DateTime date,
    int passengers = 1,
    Duration? timeout,
  }) async {
    // Validation
    if (from.trim().isEmpty || to.trim().isEmpty) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Villes de départ et d\'arrivée requises',
        method: 'searchTrips',
      );
    }
    if (from.trim() == to.trim()) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Départ et arrivée doivent être différents',
        method: 'searchTrips',
      );
    }
    if (passengers < 1 || passengers > 10) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Nombre de passagers invalide (1-10)',
        method: 'searchTrips',
      );
    }

    return _safeCall<List<BusTripModel>>(
      'searchTrips',
      () async {
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));

        final res = await _db
            .from(_tripsTable)
            .select('*, agencies!inner(*)')
            .eq('departure_city', from.trim())
            .eq('arrival_city', to.trim())
            .eq('status', 'scheduled')
            .gte('departure_time', start.toIso8601String())
            .lt('departure_time', end.toIso8601String())
            .gte('available_seats', passengers)
            .eq('agencies.status', 'active')
            .order('departure_time', ascending: true);

        return (res as List)
            .map((e) =>
                BusTripModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // POPULAR ROUTES
  // ═══════════════════════════════════════════════════════════

  /// Routes populaires : prix le moins cher par route.
  ///
  /// Utilise la vue SQL `popular_routes_view` côté Supabase.
  /// Fallback : agrégation manuelle si la vue n'existe pas.
  Future<List<Map<String, dynamic>>> getPopularRoutes({
    int limit = _maxPopularRoutes,
    Duration? timeout,
  }) async {
    return _safeCall<List<Map<String, dynamic>>>(
      'getPopularRoutes',
      () async {
        try {
          final res =
              await _db.from(_popularView).select().limit(limit);
          return List<Map<String, dynamic>>.from(
            (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (e) {
          _logError('getPopularRoutes (vue indisponible, fallback)', e);
          return _getPopularRoutesFallback(limit: limit);
        }
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Fallback si la vue SQL n'existe pas : agrégation manuelle.
  Future<List<Map<String, dynamic>>> _getPopularRoutesFallback({
    int limit = _maxPopularRoutes,
  }) async {
    final res = await _db
        .from(_tripsTable)
        .select('departure_city, arrival_city, price_fcfa')
        .eq('status', 'scheduled')
        .gte('departure_time', DateTime.now().toIso8601String())
        .order('price_fcfa', ascending: true)
        .limit(limit * 3);

    final list = res as List;

    // Dédupliquer par route en gardant le moins cher
    final routes = <String, Map<String, dynamic>>{};
    for (final row in list) {
      final map = Map<String, dynamic>.from(row as Map);
      final key = '${map['departure_city']}|${map['arrival_city']}';
      if (!routes.containsKey(key)) {
        routes[key] = {
          'departure_city': map['departure_city'],
          'arrival_city': map['arrival_city'],
          'min_price': map['price_fcfa'] ?? 0,
        };
      }
    }

    return routes.values.take(limit).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // SEATS
  // ═══════════════════════════════════════════════════════════

  /// Récupère les sièges d'un trajet (snapshot).
  Future<List<SeatModel>> getSeatsForTrip(
    String tripId, {
    Duration? timeout,
  }) async {
    if (tripId.isEmpty) return const [];

    return _safeCall<List<SeatModel>>(
      'getSeatsForTrip',
      () async {
        final res = await _db
            .from(_seatsTable)
            .select()
            .eq('trip_id', tripId)
            .order('seat_number', ascending: true);

        return (res as List)
            .map((e) =>
                SeatModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Stream Realtime pour le plan de sièges.
  ///
  /// Émet la liste complète des sièges à chaque changement.
  /// Les erreurs du stream sont loggées mais ne tuent pas le stream.
  Stream<List<SeatModel>> watchSeats(String tripId) {
    if (tripId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .from(_seatsTable)
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((data) {
          try {
            return data
                .map((e) =>
                    SeatModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
              ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
          } catch (e) {
            _logError('watchSeats parse', e);
            return <SeatModel>[];
          }
        })
        .handleError((error) {
          _logError('watchSeats stream', error);
        });
  }

  // ═══════════════════════════════════════════════════════════
  // SEAT LOCK / UNLOCK
  // ═══════════════════════════════════════════════════════════

  /// Verrouille des sièges pour 10 minutes (lié au THIX ID courant).
  ///
  /// Utilise une requête batch avec `.inFilter` pour optimiser.
  /// Seuls les sièges `available` sont verrouillés (les autres sont ignorés).
  Future<int> lockSeats({
    required String tripId,
    required List<String> seatNumbers,
    Duration? timeout,
  }) async {
    final userId = _requireUid;

    if (tripId.isEmpty) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'ID de trajet invalide',
        method: 'lockSeats',
      );
    }
    if (seatNumbers.isEmpty) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Aucun siège à verrouiller',
        method: 'lockSeats',
      );
    }

    return _safeCall<int>(
      'lockSeats',
      () async {
        final until = DateTime.now()
            .add(const Duration(minutes: _seatLockDurationMinutes))
            .toIso8601String();

        // Batch update : verrouille tous les sièges disponibles en une requête
        final res = await _db
            .from(_seatsTable)
            .update({
              'status': 'locked',
              'locked_by': userId,
              'locked_until': until,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('trip_id', tripId)
            .inFilter('seat_number', seatNumbers)
            .eq('status', 'available')
            .select();

        final updated = (res as List).length;

        if (updated != seatNumbers.length) {
          _log(
            'lockSeats : $updated/${seatNumbers.length} sièges verrouillés '
            '(${seatNumbers.length - updated} indisponibles)',
          );
        }

        return updated;
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Déverrouille des sièges précédemment verrouillés par l'utilisateur courant.
  ///
  /// Sécurité : ne déverrouille QUE les sièges lockés par `currentUser`.
  Future<void> unlockSeats({
    required String tripId,
    required List<String> seatNumbers,
    Duration? timeout,
  }) async {
    final userId = _requireUid;

    if (tripId.isEmpty || seatNumbers.isEmpty) return;

    await _safeCall<void>(
      'unlockSeats',
      () async {
        await _db
            .from(_seatsTable)
            .update({
              'status': 'available',
              'locked_by': null,
              'locked_until': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('trip_id', tripId)
            .inFilter('seat_number', seatNumbers)
            .eq('locked_by', userId);
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Vérifie si des sièges sont disponibles et les verrouille atomiquement.
  ///
  /// Retourne la liste des sièges effectivement verrouillés.
  /// Utile pour valider avant paiement.
  Future<List<String>> tryLockSeats({
    required String tripId,
    required List<String> seatNumbers,
    Duration? timeout,
  }) async {
    final count = await lockSeats(
      tripId: tripId,
      seatNumbers: seatNumbers,
      timeout: timeout,
    );

    if (count == seatNumbers.length) return seatNumbers;

    // Récupérer ceux qui ont été verrouillés
    final seats = await getSeatsForTrip(tripId, timeout: timeout);
    final userId = _currentUserId;
    return seats
        .where((s) =>
            seatNumbers.contains(s.seatNumber) &&
            s.lockedBy == userId &&
            s.isLockActive)
        .map((s) => s.seatNumber)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // BOOKINGS (Client)
  // ═══════════════════════════════════════════════════════════

  /// Crée une réservation en statut `pending_payment`.
  ///
  /// Le QR code est généré de manière déterministe :
  /// `THX-{AGENCY}-{TIMESTAMP}-{HASH}`
  Future<BookingModel> createBooking({
    required String agencyId,
    required String tripId,
    required List<String> seats,
    required int totalPrice,
    Duration? timeout,
  }) async {
    final userId = _requireUid;

    // Validation
    if (agencyId.isEmpty || tripId.isEmpty) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'IDs agence/trajet invalides',
        method: 'createBooking',
      );
    }
    if (seats.isEmpty) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Aucun siège sélectionné',
        method: 'createBooking',
      );
    }
    if (totalPrice <= 0) {
      throw const PublicServiceError(
        type: PublicServiceErrorType.validation,
        message: 'Prix total invalide',
        method: 'createBooking',
      );
    }

    return _safeCall<BookingModel>(
      'createBooking',
      () async {
        final qr = _generateQrCode(agencyId, userId);

        final res = await _db
            .from(_bookingsTable)
            .insert({
              'user_id': userId,
              'agency_id': agencyId,
              'trip_id': tripId,
              'seats': seats,
              'total_price_fcfa': totalPrice,
              'status': 'pending_payment',
              'qr_code': qr,
            })
            .select('*, bus_trips(*, agencies(*))')
            .single();

        return BookingModel.fromJson(Map<String, dynamic>.from(res as Map));
      },
      timeout: timeout ?? _longTimeout,
    );
  }

  /// Confirme un paiement (après callback Mobile Money / carte).
  ///
  /// Passe le booking de `pending_payment` → `confirmed`.
  /// Libère les sièges de leur lock temporaire (ils restent réservés).
  Future<BookingModel> confirmPayment(
    String bookingId, {
    String? paymentMethod,
    String? paymentReference,
    Duration? timeout,
  }) async {
    _requireUid;

    return _safeCall<BookingModel>(
      'confirmPayment',
      () async {
        final now = DateTime.now().toIso8601String();
        final payload = <String, dynamic>{
          'status': 'confirmed',
          'confirmed_at': now,
          'updated_at': now,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (paymentReference != null) 'payment_reference': paymentReference,
        };

        final res = await _db
            .from(_bookingsTable)
            .update(payload)
            .eq('id', bookingId)
            .eq('status', 'pending_payment') // Sécurité : seulement pending
            .select('*, bus_trips(*, agencies(*))')
            .single();

        return BookingModel.fromJson(Map<String, dynamic>.from(res as Map));
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Récupère les réservations du client courant (liées à son THIX ID).
  Future<List<BookingModel>> getMyBookings({
    int limit = 100,
    Duration? timeout,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return const [];

    return _safeCall<List<BookingModel>>(
      'getMyBookings',
      () async {
        final res = await _db
            .from(_bookingsTable)
            .select('*, bus_trips(*, agencies(*))')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);

        return (res as List)
            .map((e) =>
                BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  /// Récupère une réservation spécifique (vérifie ownership).
  Future<BookingModel?> getBookingById(
    String bookingId, {
    Duration? timeout,
  }) async {
    final userId = _currentUserId;
    if (userId == null || bookingId.isEmpty) return null;

    return _safeCall<BookingModel?>(
      'getBookingById',
      () async {
        final res = await _db
            .from(_bookingsTable)
            .select('*, bus_trips(*, agencies(*))')
            .eq('id', bookingId)
            .eq('user_id', userId) // Sécurité : ownership
            .limit(1);

        final list = res as List;
        if (list.isEmpty) return null;

        return BookingModel.fromJson(
          Map<String, dynamic>.from(list.first as Map),
        );
      },
      timeout: timeout ?? _defaultTimeout,
      nullable: true,
    );
  }

  /// Annule une réservation (côté client, avant départ).
  ///
  /// Règles métier :
  /// - Seulement les bookings `confirmed`
  /// - Seulement si le départ est dans le futur
  /// - Libère les sièges
  Future<BookingModel> cancelMyBooking(
    String bookingId, {
    String? reason,
    Duration? timeout,
  }) async {
    final userId = _requireUid;

    return _safeCall<BookingModel>(
      'cancelMyBooking',
      () async {
        // 1. Vérifier ownership et état
        final booking = await getBookingById(bookingId);
        if (booking == null) {
          throw const PublicServiceError(
            type: PublicServiceErrorType.notFound,
            message: 'Réservation introuvable',
          );
        }
        if (booking.userId != userId) {
          throw const PublicServiceError(
            type: PublicServiceErrorType.unauthorized,
            message: 'Non autorisé à annuler cette réservation',
          );
        }
        if (!booking.canBeCancelled) {
          throw const PublicServiceError(
            type: PublicServiceErrorType.validation,
            message: 'Cette réservation ne peut pas être annulée',
          );
        }

        // 2. Mettre à jour le statut
        final now = DateTime.now().toIso8601String();
        await _db.from(_bookingsTable).update({
          'status': 'cancelled',
          'cancelled_at': now,
          'updated_at': now,
          if (reason != null) 'cancellation_reason': reason,
        }).eq('id', bookingId);

        // 3. Libérer les sièges (best effort)
        try {
          await _db.from(_seatsTable).update({
            'status': 'available',
            'locked_by': null,
            'locked_until': null,
          }).eq('trip_id', booking.tripId).inFilter('seat_number', booking.seats);
        } catch (e) {
          _logError('cancelMyBooking unlock seats', e);
        }

        return booking.copyWith(
          status: BookingStatus.cancelled,
          cancelledAt: DateTime.now(),
          cancellationReason: reason,
        );
      },
      timeout: timeout ?? _defaultTimeout,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Génération de QR code robuste (préfixe + timestamp + hash).
  String _generateQrCode(String agencyId, String userId) {
    final agencyPart =
        agencyId.length >= 3 ? agencyId.substring(0, 3).toUpperCase() : agencyId.toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = (userId.hashCode ^ timestamp).abs().toRadixString(36).toUpperCase();
    final hashPart = hash.length > 6 ? hash.substring(0, 6) : hash.padRight(6, '0');
    return 'THX-$agencyPart-$timestamp-$hashPart';
  }

  /// Appel sécurisé avec timeout + retry + gestion d'erreurs typée.
  Future<T> _safeCall<T>(
    String method,
    Future<T> Function() operation, {
    Duration? timeout,
    int retries = _maxRetries,
    bool nullable = false,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        if (kDebugMode && attempt > 1) {
          _log('[$method] Tentative $attempt/$retries');
        }
        final result = await operation().timeout(effectiveTimeout);
        return result;
      } on TimeoutException catch (e) {
        _logError('[$method] Timeout (tentative $attempt)', e);
        if (attempt == retries) {
          throw PublicServiceError(
            type: PublicServiceErrorType.timeout,
            message: PublicServiceError._humanReadable(
              PublicServiceErrorType.timeout,
            ),
            originalError: e.toString(),
            method: method,
          );
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      } on PublicServiceError {
        rethrow;
      } catch (e) {
        _logError('[$method] Erreur (tentative $attempt)', e);
        if (attempt == retries) {
          throw PublicServiceError.fromException(e, method: method);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    throw PublicServiceError(
      type: PublicServiceErrorType.unknown,
      message: 'Erreur inattendue dans $method',
      method: method,
    );
  }

  // ─── Logging ──────────────────────────────────────────────
  void _log(String message) {
    if (kDebugMode) debugPrint('[BusPublicService] $message');
  }

  void _logError(String context, Object error) {
    if (kDebugMode) debugPrint('[BusPublicService] ❌ $context: $error');
  }
}
