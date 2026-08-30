// lib/presentation/thix_market/delivery/delivery_provider.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kTrackingPollInterval = Duration(seconds: 5);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxNameLength = 80;
const int _kMaxAddressLength = 200;
const int _kMaxPhoneLength = 20;
const int _kMaxPickupPoints = 50;
const double _kDefaultPickupRadiusKm = 10.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _DeliveryValidators {
  _DeliveryValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  /// Validation stricte coordonnées GPS (évite crash Google Maps)
  static LatLng? safeLatLng(dynamic lat, dynamic lng) {
    final latNum = (lat as num?)?.toDouble();
    final lngNum = (lng as num?)?.toDouble();
    if (latNum == null || lngNum == null) return null;
    if (latNum.isNaN || lngNum.isNaN) return null;
    if (latNum.isInfinite || lngNum.isInfinite) return null;
    if (latNum < -90 || latNum > 90) return null;
    if (lngNum < -180 || lngNum > 180) return null;
    return LatLng(latNum, lngNum);
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    return RegExp(r'^\+?[0-9]{6,15}$').hasMatch(cleaned);
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('location')) return 'Permission de localisation requise.';
    if (msg.contains('not found') || msg.contains('404')) return 'Ressource introuvable.';
    if (msg.contains('duplicate') || msg.contains('unique')) return 'Cette entrée existe déjà.';
    if (msg.contains('unauthorized') || msg.contains('policy')) return 'Accès non autorisé.';
    return 'Une erreur est survenue. Réessayez.';
  }

  /// Distance Haversine en km entre 2 points GPS
  static double distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * R * math.asin(math.sqrt(h));
  }
}

/// Mini-classe pour coordonnées (évite dépendance google_maps_flutter dans le provider)
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[DeliveryProvider] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[DeliveryProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDER DECLARATION
// ============================================================================
final deliveryProvider = ChangeNotifierProvider<DeliveryProvider>((ref) {
  return DeliveryProvider()..init();
});

// ============================================================================
// PROVIDER
// ============================================================================
class DeliveryProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── ADDRESSES ─────────────────────────────────────────────
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddresses = false;
  bool _isMutatingAddress = false; // Protection double-tap add/update/delete

  // ─── TRACKING ──────────────────────────────────────────────
  Map<String, dynamic>? _currentTracking;
  bool _isLoadingTracking = false;
  String? _errorTracking;
  Timer? _trackingPollTimer;
  String? _trackingOrderId;

  // ─── PICKUP POINTS ─────────────────────────────────────────
  List<Map<String, dynamic>> _pickupPoints = [];
  bool _isLoadingPickupPoints = false;
  Position? _currentPosition;

  // ─── DELIVERY SLOTS ────────────────────────────────────────
  List<Map<String, dynamic>> _availableSlots = [];
  Map<String, dynamic>? _selectedSlot;
  bool _isLoadingSlots = false;

  // ─── LAST ERROR (global) ───────────────────────────────────
  String? _lastError;

  // ====================================================================
  // GETTERS
  // ====================================================================
  List<Map<String, dynamic>> get addresses => _addresses;
  Map<String, dynamic>? get selectedAddress => _selectedAddress;
  bool get isLoadingAddresses => _isLoadingAddresses;

  Map<String, dynamic>? get currentTracking => _currentTracking;
  bool get isLoadingTracking => _isLoadingTracking;
  String? get errorTracking => _errorTracking;

  List<Map<String, dynamic>> get pickupPoints => _pickupPoints;
  bool get isLoadingPickupPoints => _isLoadingPickupPoints;
  Position? get currentPosition => _currentPosition;

  List<Map<String, dynamic>> get availableSlots => _availableSlots;
  Map<String, dynamic>? get selectedSlot => _selectedSlot;
  bool get isLoadingSlots => _isLoadingSlots;

  String? get lastError => _lastError;

  // ====================================================================
  // INIT
  // ====================================================================
  Future<void> init() async {
    debugPrint('[DeliveryProvider] 🚀 Initializing');
    try {
      await loadAddresses();
      await _ensureLocationPermission();
    } catch (e) {
      debugPrint('[DeliveryProvider] ⚠️ Init error (non-critical): $e');
    }
  }

  Future<void> _ensureLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        debugPrint('[DeliveryProvider] 📍 Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }
    } catch (e) {
      debugPrint('[DeliveryProvider] ⚠️ Location error: $e');
    }
  }

  // ====================================================================
  // TRACKING (avec polling temps réel)
  // ====================================================================
  Future<void> trackDelivery(String orderId) async {
    if (!_DeliveryValidators.isValidId(orderId)) {
      _errorTracking = 'Identifiant de commande invalide';
      notifyListeners();
      return;
    }

    // Si déjà en tracking pour cette commande, ne pas relancer
    if (_trackingOrderId == orderId && _trackingPollTimer != null) {
      debugPrint('[DeliveryProvider] ℹ️ Already tracking $orderId');
      return;
    }

    // Arrêter tout tracking précédent
    stopTracking();

    _trackingOrderId = orderId;
    _isLoadingTracking = true;
    _errorTracking = null;
    notifyListeners();

    debugPrint('[DeliveryProvider] 📡 Starting tracking for order ${orderId.substring(0, 8)}...');

    try {
      await _fetchTrackingData(orderId);

      // Démarrer polling toutes les 5s
      _trackingPollTimer = Timer.periodic(_kTrackingPollInterval, (_) async {
        if (_trackingOrderId == orderId) {
          await _fetchTrackingData(orderId, silent: true);
        }
      });
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ Track delivery error: $e');
      _errorTracking = _DeliveryValidators.friendlyError(e);
      _currentTracking = null;
    } finally {
      _isLoadingTracking = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTrackingData(String orderId, {bool silent = false}) async {
    try {
      final tracking = await _withRetry(
        () => _supabase
            .from('delivery_tracking')
            .select()
            .eq('order_id', orderId)
            .maybeSingle(),
        label: 'fetchTracking[$orderId]',
      );

      if (tracking == null) {
        _currentTracking = null;
        if (!silent) _errorTracking = 'Suivi indisponible';
      } else {
        final driverLat = tracking['current_lat'];
        final driverLng = tracking['current_lng'];
        final driverPos = _DeliveryValidators.safeLatLng(driverLat, driverLng);

        _currentTracking = {
          ...tracking,
          'driver_lat': driverPos?.latitude,
          'driver_lng': driverPos?.longitude,
          'driver': {
            'name': _DeliveryValidators.sanitize(
              tracking['driver_name']?.toString(),
              maxLength: _kMaxNameLength,
            ),
            'phone': _DeliveryValidators.sanitize(
              tracking['driver_phone']?.toString(),
              maxLength: _kMaxPhoneLength,
            ),
            'vehicle': _DeliveryValidators.sanitize(
              tracking['vehicle']?.toString(),
              maxLength: 40,
            ),
            'current_lat': driverPos?.latitude,
            'current_lng': driverPos?.longitude,
          },
        };
      }

      if (!silent) _errorTracking = null;
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ Fetch tracking error: $e');
      if (!silent) {
        _errorTracking = _DeliveryValidators.friendlyError(e);
        _currentTracking = null;
      }
      // En mode silent, on garde l'état précédent (meilleure UX)
    }

    notifyListeners();
  }

  /// Arrête le polling de tracking (à appeler au dispose de la page)
  void stopTracking() {
    if (_trackingPollTimer != null) {
      _trackingPollTimer?.cancel();
      _trackingPollTimer = null;
      debugPrint('[DeliveryProvider] ⏹️ Tracking stopped for ${_trackingOrderId != null ? _trackingOrderId!.substring(0, 8) : 'none'}...');
      _trackingOrderId = null;
    }
  }

  // ====================================================================
  // ADDRESSES
  // ====================================================================
  Future<void> loadAddresses() async {
    final uid = _supabase.auth.currentUser?.id;
    if (!_DeliveryValidators.isValidId(uid)) {
      debugPrint('[DeliveryProvider] ⚠️ loadAddresses: no authenticated user');
      _addresses = [];
      _selectedAddress = null;
      notifyListeners();
      return;
    }

    _isLoadingAddresses = true;
    _lastError = null;
    notifyListeners();

    try {
      final res = await _withRetry(
        () => _supabase
            .from('addresses')
            .select()
            .eq('user_id', uid!)
            .order('is_default', ascending: false)
            .order('created_at', ascending: false),
        label: 'loadAddresses',
      );

      _addresses = (res as List)
          .map((e) => _sanitizeAddress(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Auto-sélection de l'adresse par défaut
      if (_selectedAddress == null && _addresses.isNotEmpty) {
        _selectedAddress = _addresses.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => _addresses.first,
        );
      }

      debugPrint('[DeliveryProvider] ✓ Loaded ${_addresses.length} addresses');
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ loadAddresses error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
    } finally {
      _isLoadingAddresses = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _sanitizeAddress(Map<String, dynamic> addr) {
    return {
      ...addr,
      'full_name': _DeliveryValidators.sanitize(addr['full_name']?.toString(), maxLength: _kMaxNameLength),
      'phone': _DeliveryValidators.sanitize(addr['phone']?.toString(), maxLength: _kMaxPhoneLength),
      'alt_phone': _DeliveryValidators.sanitize(addr['alt_phone']?.toString(), maxLength: _kMaxPhoneLength),
      'address_line': _DeliveryValidators.sanitize(addr['address_line']?.toString(), maxLength: _kMaxAddressLength),
      'commune': _DeliveryValidators.sanitize(addr['commune']?.toString(), maxLength: 60),
      'city': _DeliveryValidators.sanitize(addr['city']?.toString(), maxLength: 40),
      'landmark': _DeliveryValidators.sanitize(addr['landmark']?.toString(), maxLength: 100),
    };
  }

  Future<void> addAddress(Map<String, dynamic> address) async {
    final uid = _supabase.auth.currentUser?.id;
    if (!_DeliveryValidators.isValidId(uid)) {
      throw Exception('Vous devez être connecté pour ajouter une adresse');
    }

    if (_isMutatingAddress) {
      debugPrint('[DeliveryProvider] ⚠️ addAddress already in progress');
      return;
    }

    _isMutatingAddress = true;
    debugPrint('[DeliveryProvider] ➕ Adding address');

    try {
      final isDefault = address['is_default'] == true;

      // Sécurité : une seule adresse par défaut
      if (isDefault) {
        await _withRetry(
          () => _supabase.from('addresses').update({'is_default': false}).eq('user_id', uid!),
          label: 'clearDefaultAddresses',
        );
      }

      final res = await _withRetry(
        () => _supabase
            .from('addresses')
            .insert({...address, 'user_id': uid})
            .select()
            .single(),
        label: 'insertAddress',
      );

      final inserted = _sanitizeAddress(Map<String, dynamic>.from(res as Map));

      // Update local state directement (pas de rechargement complet)
      _addresses.insert(0, inserted);

      // Auto-sélection si default ou si aucune adresse sélectionnée
      if (isDefault || _selectedAddress == null) {
        _selectedAddress = inserted;
      }

      debugPrint('[DeliveryProvider] ✓ Address added: ${inserted['id']}');
      notifyListeners();
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ addAddress error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
      rethrow;
    } finally {
      _isMutatingAddress = false;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    if (!_DeliveryValidators.isValidId(addressId)) {
      throw Exception('Identifiant d\'adresse invalide');
    }

    if (_isMutatingAddress) {
      debugPrint('[DeliveryProvider] ⚠️ deleteAddress already in progress');
      return;
    }

    _isMutatingAddress = true;
    debugPrint('[DeliveryProvider] 🗑️ Deleting address ${addressId.substring(0, 8)}...');

    try {
      await _withRetry(
        () => _supabase.from('addresses').delete().eq('id', addressId),
        label: 'deleteAddress[$addressId]',
      );

      // Update local state
      _addresses.removeWhere((a) => a['id']?.toString() == addressId);

      if (_selectedAddress?['id']?.toString() == addressId) {
        _selectedAddress = _addresses.isNotEmpty
            ? _addresses.firstWhere(
                (a) => a['is_default'] == true,
                orElse: () => _addresses.first,
              )
            : null;
      }

      debugPrint('[DeliveryProvider] ✓ Address deleted');
      notifyListeners();
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ deleteAddress error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
      rethrow;
    } finally {
      _isMutatingAddress = false;
    }
  }

  Future<void> updateAddress(String id, Map<String, dynamic> data) async {
    if (!_DeliveryValidators.isValidId(id)) {
      throw Exception('Identifiant d\'adresse invalide');
    }

    if (_isMutatingAddress) {
      debugPrint('[DeliveryProvider] ⚠️ updateAddress already in progress');
      return;
    }

    _isMutatingAddress = true;
    debugPrint('[DeliveryProvider] ✏️ Updating address ${id.substring(0, 8)}...');

    try {
      final uid = _supabase.auth.currentUser?.id;
      final isDefault = data['is_default'] == true;

      if (isDefault && _DeliveryValidators.isValidId(uid)) {
        await _withRetry(
          () => _supabase.from('addresses').update({'is_default': false}).eq('user_id', uid!),
          label: 'clearDefaultBeforeUpdate',
        );
      }

      await _withRetry(
        () => _supabase.from('addresses').update(data).eq('id', id),
        label: 'updateAddress[$id]',
      );

      // Recharger pour avoir les données cohérentes (is_default a changé pour les autres)
      await loadAddresses();

      debugPrint('[DeliveryProvider] ✓ Address updated');
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ updateAddress error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
      rethrow;
    } finally {
      _isMutatingAddress = false;
    }
  }

  void selectAddress(Map<String, dynamic> a) {
    final id = a['id']?.toString();
    if (!_DeliveryValidators.isValidId(id)) {
      debugPrint('[DeliveryProvider] ⚠️ selectAddress: invalid ID');
      return;
    }
    _selectedAddress = a;
    debugPrint('[DeliveryProvider] ✓ Selected address ${id!.substring(0, 8)}...');
    notifyListeners();
  }

  // ====================================================================
  // PICKUP POINTS
  // ====================================================================
  Future<void> loadNearbyPickupPoints({double radiusKm = _kDefaultPickupRadiusKm}) async {
    _isLoadingPickupPoints = true;
    _lastError = null;
    notifyListeners();

    debugPrint('[DeliveryProvider] 📍 Loading nearby pickup points');

    try {
      // S'assurer qu'on a la position
      if (_currentPosition == null) {
        await _ensureLocationPermission();
      }

      List<Map<String, dynamic>> points = [];

      // Tentative RPC (plus efficace : calcul distance côté serveur)
      if (_currentPosition != null) {
        try {
          final res = await _withRetry(
            () => _supabase.rpc('get_nearby_pickup_points', params: {
              'user_lat': _currentPosition!.latitude,
              'user_lng': _currentPosition!.longitude,
              'radius_km': radiusKm,
              'limit_count': _kMaxPickupPoints,
            }),
            label: 'rpcNearbyPickupPoints',
          );

          points = (res as List)
              .map((e) => _sanitizePickupPoint(Map<String, dynamic>.from(e as Map)))
              .toList();
        } catch (rpcError) {
          debugPrint('[DeliveryProvider] ⚠️ RPC pickup_points unavailable, fallback to full fetch: $rpcError');
          points = await _fallbackLoadPickupPoints();
        }
      } else {
        points = await _fallbackLoadPickupPoints();
      }

      // Tri par distance
      if (_currentPosition != null) {
        final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        points.sort((a, b) {
          final distA = _DeliveryValidators.safeDouble(a['distance_km']);
          final distB = _DeliveryValidators.safeDouble(b['distance_km']);
          return distA.compareTo(distB);
        });
      }

      _pickupPoints = points;
      debugPrint('[DeliveryProvider] ✓ Loaded ${points.length} pickup points');
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ loadNearbyPickupPoints error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
      _pickupPoints = [];
    } finally {
      _isLoadingPickupPoints = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> _fallbackLoadPickupPoints() async {
    final res = await _withRetry(
      () => _supabase
          .from('pickup_points')
          .select()
          .eq('is_active', true)
          .limit(_kMaxPickupPoints),
      label: 'fallbackLoadPickupPoints',
    );

    final points = (res as List)
        .map((e) => _sanitizePickupPoint(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Calcul distance côté client si position connue
    if (_currentPosition != null) {
      final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      for (final p in points) {
        final pos = _DeliveryValidators.safeLatLng(p['latitude'], p['longitude']);
        if (pos != null) {
          p['distance_km'] = _DeliveryValidators.distanceKm(userLatLng, pos);
        }
      }
    }

    return points;
  }

  Map<String, dynamic> _sanitizePickupPoint(Map<String, dynamic> point) {
    return {
      ...point,
      'name': _DeliveryValidators.sanitize(point['name']?.toString(), maxLength: _kMaxNameLength),
      'address': _DeliveryValidators.sanitize(point['address']?.toString(), maxLength: _kMaxAddressLength),
      'opening_hours': _DeliveryValidators.sanitize(point['opening_hours']?.toString(), maxLength: 60),
    };
  }

  // ====================================================================
  // DELIVERY SLOTS
  // ====================================================================
  Future<void> loadAvailableSlots({required DateTime date}) async {
    _isLoadingSlots = true;
    _lastError = null;
    notifyListeners();

    debugPrint('[DeliveryProvider] 🕐 Loading slots for ${date.toIso8601String().substring(0, 10)}');

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final res = await _withRetry(
        () => _supabase
            .from('delivery_slots')
            .select()
            .eq('date', dateStr)
            .eq('is_available', true)
            .gt('available_count', 0)
            .order('start_time', ascending: true),
        label: 'loadAvailableSlots[$dateStr]',
      );

      _availableSlots = (res as List)
          .map((e) => _sanitizeSlot(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Reset selected si plus dans la liste
      if (_selectedSlot != null &&
          !_availableSlots.any((s) => s['id'] == _selectedSlot!['id'])) {
        _selectedSlot = null;
      }

      debugPrint('[DeliveryProvider] ✓ Loaded ${_availableSlots.length} slots');
    } catch (e) {
      debugPrint('[DeliveryProvider] ❌ loadAvailableSlots error: $e');
      _lastError = _DeliveryValidators.friendlyError(e);
      _availableSlots = [];
    } finally {
      _isLoadingSlots = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _sanitizeSlot(Map<String, dynamic> slot) {
    return {
      ...slot,
      'start_time': _DeliveryValidators.sanitize(slot['start_time']?.toString(), maxLength: 20),
      'end_time': _DeliveryValidators.sanitize(slot['end_time']?.toString(), maxLength: 20),
      'available_count': _DeliveryValidators.safeInt(slot['available_count']),
    };
  }

  void selectSlot(Map<String, dynamic> slot) {
    final id = slot['id']?.toString();
    if (!_DeliveryValidators.isValidId(id)) {
      debugPrint('[DeliveryProvider] ⚠️ selectSlot: invalid ID');
      return;
    }
    _selectedSlot = slot;
    debugPrint('[DeliveryProvider] ✓ Slot selected: ${id!.substring(0, 8)}...');
    notifyListeners();
  }

  // ====================================================================
  // CLEANUP
  // ====================================================================
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Reset complet (à appeler au logout)
  void reset() {
    debugPrint('[DeliveryProvider] 🧹 Full reset');
    stopTracking();

    _addresses = [];
    _selectedAddress = null;
    _isLoadingAddresses = false;

    _currentTracking = null;
    _isLoadingTracking = false;
    _errorTracking = null;

    _pickupPoints = [];
    _isLoadingPickupPoints = false;

    _availableSlots = [];
    _selectedSlot = null;
    _isLoadingSlots = false;

    _lastError = null;
    _isMutatingAddress = false;

    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    debugPrint('[DeliveryProvider] 👋 Disposed');
    super.dispose();
  }
}
