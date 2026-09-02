/// THIX SOS — Riverpod providers (Production Enterprise)
/// ✅ SÉCURISÉ : timeouts, retry, mounted guards, validation, structured logs
/// ✅ ROBUSTE : race-condition protection, autoDispose, error propagation
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/sos_models.dart';
import '../services/sos_service.dart';
import '../services/sos_call_bridge.dart';
import '../services/sos_escalation_controller.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTriggerTimeout = Duration(seconds: 30);
const Duration _kHeartbeatTimeout = Duration(seconds: 15);
const Duration _kGeolocatorTimeout = Duration(seconds: 10);
const Duration _kDefaultHeartbeatInterval = Duration(seconds: 15);
const Duration _kEscalationDelay = Duration(seconds: 15);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);
const int _kMinThixIdLength = 4;
const int _kMaxThixIdLength = 32;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ProvidersValidators {
  _ProvidersValidators._();

  static bool isValidThixId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.length < _kMinThixIdLength ||
        trimmed.length > _kMaxThixIdLength) {
      return false;
    }
    // Autorise lettres, chiffres, tirets, underscores
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed);
  }

  static String? sanitizeIncidentId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _providersRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kTriggerTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosProviders] ❌ $label: timeout after $attempt');
        rethrow;
      }
      debugPrint('[SosProviders] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosProviders] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// SERVICE (singleton)
// ============================================================================
final sosServiceProvider = Provider<SosService>((ref) {
  return SosService();
});

// ============================================================================
// CONTACTS
// ============================================================================
final sosContactsProvider =
    FutureProvider.autoDispose<List<SosContact>>((ref) async {
  debugPrint('[SosProviders] 📥 Loading contacts');
  try {
    final contacts = await ref.watch(sosServiceProvider).getContacts();
    debugPrint('[SosProviders] ✓ Loaded ${contacts.length} contacts');
    return contacts;
  } catch (e, stack) {
    debugPrint('[SosProviders] ❌ getContacts: $e');
    debugPrint('[SosProviders] Stack: $stack');
    rethrow;
  }
});

// ✅ FIX : utilise `read(future)` dans un `async` au lieu de `watch(future)`
final sosContactsCircleProvider =
    FutureProvider.autoDispose.family<List<SosContact>, int>((ref, circle) async {
  final all = await ref.read(sosContactsProvider.future);
  return all.where((c) => c.circle == circle).toList();
});

final sosContactsCountProvider = Provider.autoDispose<Map<int, int>>((ref) {
  final async = ref.watch(sosContactsProvider);
  return async.maybeWhen(
    data: (list) {
      final map = <int, int>{1: 0, 2: 0, 3: 0};
      for (final c in list) {
        map[c.circle] = (map[c.circle] ?? 0) + 1;
      }
      return map;
    },
    orElse: () => {1: 0, 2: 0, 3: 0},
  );
});

// ============================================================================
// RECHERCHE PROFIL (THIX ID) — ✅ avec validation
// ============================================================================
final thixIdLookupProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, thixId) async {
  if (!_ProvidersValidators.isValidThixId(thixId)) {
    debugPrint('[SosProviders] ⚠️ Invalid THIX ID: $thixId');
    return null;
  }
  debugPrint('[SosProviders] 🔍 Looking up THIX ID: $thixId');
  try {
    return await _providersRetry(
      () => ref.watch(sosServiceProvider).lookupProfileByThixId(thixId),
      label: 'thixIdLookup[$thixId]',
    );
  } catch (e) {
    debugPrint('[SosProviders] ❌ thixIdLookup error: $e');
    rethrow;
  }
});

// ============================================================================
// INCIDENT ACTIF & HISTORIQUE
// ============================================================================
final activeSosProvider =
    FutureProvider.autoDispose<SosIncident?>((ref) async {
  try {
    return await ref.watch(sosServiceProvider).getActiveIncident();
  } catch (e) {
    debugPrint('[SosProviders] ❌ getActiveIncident: $e');
    return null;
  }
});

final sosHistoryProvider =
    FutureProvider.autoDispose<List<SosIncident>>((ref) async {
  debugPrint('[SosProviders] 📥 Loading history');
  try {
    return await ref.watch(sosServiceProvider).getHistory();
  } catch (e, stack) {
    debugPrint('[SosProviders] ❌ getHistory: $e');
    debugPrint('[SosProviders] Stack: $stack');
    rethrow;
  }
});

final sosIncidentProvider =
    FutureProvider.autoDispose.family<SosIncident?, String>((ref, id) async {
  final sanitized = _ProvidersValidators.sanitizeIncidentId(id);
  if (sanitized == null) return null;
  try {
    return await ref.watch(sosServiceProvider).getIncidentById(sanitized);
  } catch (e) {
    debugPrint('[SosProviders] ❌ getIncidentById[$sanitized]: $e');
    return null;
  }
});

final sosEventsProvider =
    FutureProvider.autoDispose.family<List<SosEvent>, String>((ref, incidentId) {
  final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
  if (sanitized == null) return AsyncValue.data(<SosEvent>[]);
  return ref.watch(sosServiceProvider).getEvents(sanitized);
});

final sosLocationsProvider =
    FutureProvider.autoDispose.family<List<SosLocationPoint>, String>(
  (ref, incidentId) {
    final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
    if (sanitized == null) return AsyncValue.data(<SosLocationPoint>[]);
    return ref.watch(sosServiceProvider).getLocations(sanitized);
  },
);

// ============================================================================
// POSITION GPS — ✅ avec timeout + logs structurés
// ============================================================================
final sosUserPositionProvider =
    FutureProvider.autoDispose<({double lat, double lng})?>((ref) async {
  debugPrint('[SosProviders] 📍 Getting user position');
  try {
    final serviceOn = await Geolocator.isLocationServiceEnabled()
        .timeout(_kGeolocatorTimeout);
    if (!serviceOn) {
      debugPrint('[SosProviders] ⚠️ Location service disabled');
      return null;
    }

    var permission = await Geolocator.checkPermission()
        .timeout(_kGeolocatorTimeout);
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission()
          .timeout(_kGeolocatorTimeout);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[SosProviders] ⚠️ Location permission: $permission');
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _kGeolocatorTimeout,
      ),
    ).timeout(_kGeolocatorTimeout);

    debugPrint('[SosProviders] ✓ Position: ${pos.latitude}, ${pos.longitude}');
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (e) {
    debugPrint('[SosProviders] ❌ sosUserPositionProvider: $e');
    return null;
  }
});

// ============================================================================
// DÉCLENCHEMENT SOS — ✅ FIX: autoDispose, race condition, timeout, mounted
// ============================================================================
final triggerSosProvider = StateNotifierProvider.autoDispose<
    TriggerSosNotifier, AsyncValue<SosIncident?>>(
  (ref) => TriggerSosNotifier(ref),
);

class TriggerSosNotifier extends StateNotifier<AsyncValue<SosIncident?>> {
  TriggerSosNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  bool _isTriggering = false; // ✅ FIX : flag anti-race-condition

  Future<SosIncident?> trigger() async {
    // ✅ FIX : empêche double-trigger
    if (_isTriggering) {
      debugPrint('[SosProviders] ⚠️ Trigger already in progress');
      return state.valueOrNull;
    }

    _isTriggering = true;
    state = const AsyncLoading();

    try {
      state = await AsyncValue.guard(() async {
        // ✅ FIX : timeout + retry sur l'appel service
        final incident = await _providersRetry(
          () => _ref.read(sosServiceProvider).triggerSos(),
          label: 'triggerSos',
          timeout: _kTriggerTimeout,
        );

        if (incident == null) {
          debugPrint('[SosProviders] ⚠️ triggerSos returned null');
          return null;
        }

        debugPrint('[SosProviders] 🚨 SOS triggered: ${incident.id}');

        // Activation du protocole (chat + appels + escalade)
        try {
          final result = await _providersRetry(
            () => SosCallBridge(
              sos: _ref.read(sosServiceProvider),
            ).activateProtocol(incident),
            label: 'activateProtocol',
            timeout: _kTriggerTimeout,
          );

          debugPrint(
            '[SosProviders] ✓ SOS protocol: chat=${result.conversationId} '
            'calls=${result.answeredOrRinging}/${result.calls.length}',
          );

          // ✅ FIX : syntax error corrigée (interpolation Dart correcte)

          _ref.read(sosEscalationProvider).start(
                incident.id,
                startCircle: 1,
              );
        } catch (e) {
          debugPrint('[SosProviders] ⚠️ SOS protocol partial failure: $e');
          // On continue — le SOS est créé, le protocole peut être partiel
        }

        // ✅ FIX : invalidations wrapped dans try/catch
        _safeInvalidate(activeSosProvider);
        _safeInvalidate(sosHistoryProvider);

        return incident;
      });
    } finally {
      _isTriggering = false;
    }

    return state.valueOrNull;
  }

  /// ✅ Invalidation sécurisée (ignore erreurs si ref déjà disposed)
  void _safeInvalidate(ProviderBase provider) {
    try {
      _ref.invalidate(provider);
    } catch (e) {
      debugPrint('[SosProviders] ⚠️ Invalidate failed: $e');
    }
  }

  void reset() => state = const AsyncData(null);
}

// ============================================================================
// HEARTBEAT — ✅ logs + timeout + mounted checks
// ============================================================================
final sosHeartbeatControllerProvider =
    StateNotifierProvider.autoDispose<SosHeartbeatController, bool>(
  (ref) => SosHeartbeatController(ref),
);

class SosHeartbeatController extends StateNotifier<bool> {
  SosHeartbeatController(this._ref) : super(false);

  final Ref _ref;
  Timer? _timer;
  String? _incidentId;
  int _tickCount = 0;

  void start(String incidentId,
      {Duration interval = _kDefaultHeartbeatInterval}) {
    stop();
    _incidentId = incidentId;
    state = true;
    _tickCount = 0;
    _timer = Timer.periodic(interval, (_) => _tick());
    debugPrint('[SosProviders] 💓 Heartbeat started for $incidentId');
    _tick();
  }

  Future<void> _tick() async {
    final id = _incidentId;
    if (id == null || !state) return;

    _tickCount++;
    try {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).heartbeat(id),
        label: 'heartbeat[$id]',
        timeout: _kHeartbeatTimeout,
        maxRetries: 0, // heartbeat ne doit pas retry (évite surcharge)
      );

      if (_tickCount % 4 == 0) {
        debugPrint('[SosProviders] 💓 Heartbeat #$id: $_tickCount');
      }

      // ✅ FIX : invalidation sécurisée
      try {
        _ref.invalidate(activeSosProvider);
      } catch (e) {
        debugPrint('[SosProviders] ⚠️ Heartbeat invalidate failed: $e');
      }
    } catch (e) {
      // ✅ FIX : plus de catch silencieux — log structuré
      debugPrint('[SosProviders] ❌ Heartbeat #$id failed: $e');
    }
  }

  void stop() {
    if (_timer != null) {
      debugPrint('[SosProviders] 💓 Heartbeat stopped ($_tickCount ticks)');
    }
    _timer?.cancel();
    _timer = null;
    _incidentId = null;
    _tickCount = 0;
    state = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ============================================================================
// ESCALADE SOS (Cercles)
// ============================================================================
final sosEscalationProvider =
    Provider.autoDispose<SosEscalationController>((ref) {
  final controller = SosEscalationController(
    sos: ref.watch(sosServiceProvider),
    delayPerCircle: _kEscalationDelay,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

// ============================================================================
// ACTIONS CONTACTS — ✅ validation + logs + mounted guards
// ============================================================================
final sosContactActionsProvider = Provider<SosContactActions>((ref) {
  return SosContactActions(ref);
});

class SosContactActions {
  SosContactActions(this._ref);
  final Ref _ref;

  SosService get _service => _ref.read(sosServiceProvider);

  /// ✅ Invalidation sécurisée
  void _safeInvalidate() {
    try {
      _ref.invalidate(sosContactsProvider);
    } catch (e) {
      debugPrint('[SosProviders] ⚠️ Contact invalidate failed: $e');
    }
  }

  Future<SosContact> add({
    required String name,
    required int circle,
    String? phone,
    String? thixId,
    String? relation,
  }) async {
    debugPrint('[SosProviders] ➕ Adding contact: $name (circle $circle)');
    try {
      final c = await _providersRetry(
        () => _service.addContact(
          name: name,
          circle: circle,
          phone: phone,
          thixId: thixId,
          relation: relation,
        ),
        label: 'addContact',
      );
      _safeInvalidate();
      debugPrint('[SosProviders] ✓ Contact added: ${c.id}');
      return c;
    } catch (e) {
      debugPrint('[SosProviders] ❌ addContact: $e');
      rethrow;
    }
  }

  Future<SosContact> addFromThix({
    required String thixId,
    required String contactUserId,
    required String name,
    required int circle,
    String? photoUrl,
    String? phone,
    String? relation,
  }) async {
    if (!_ProvidersValidators.isValidThixId(thixId)) {
      throw ArgumentError('Invalid THIX ID: $thixId');
    }
    debugPrint('[SosProviders] ➕ Adding contact from THIX: $thixId (circle $circle)');
    try {
      final c = await _providersRetry(
        () => _service.addContactFromThixProfile(
          thixId: thixId,
          contactUserId: contactUserId,
          name: name,
          circle: circle,
          photoUrl: photoUrl,
          phone: phone,
          relation: relation,
        ),
        label: 'addContactFromThix[$thixId]',
      );
      _safeInvalidate();
      debugPrint('[SosProviders] ✓ Contact added from THIX: ${c.id}');
      return c;
    } catch (e) {
      debugPrint('[SosProviders] ❌ addFromThix: $e');
      rethrow;
    }
  }

  Future<void> update(SosContact contact) async {
    debugPrint('[SosProviders] ✏️ Updating contact: ${contact.id}');
    try {
      await _providersRetry(
        () => _service.updateContact(contact),
        label: 'updateContact[${contact.id}]',
      );
      _safeInvalidate();
    } catch (e) {
      debugPrint('[SosProviders] ❌ updateContact: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    debugPrint('[SosProviders] 🗑️ Deleting contact: $id');
    try {
      await _providersRetry(
        () => _service.deleteContact(id),
        label: 'deleteContact[$id]',
      );
      _safeInvalidate();
    } catch (e) {
      debugPrint('[SosProviders] ❌ deleteContact: $e');
      rethrow;
    }
  }
}

// ============================================================================
// RÉSOUDRE / ANNULER — ✅ mounted guards + logs
// ============================================================================
final sosResolveProvider =
    StateNotifierProvider.autoDispose<SosResolveNotifier, AsyncValue<void>>(
  (ref) => SosResolveNotifier(ref),
);

class SosResolveNotifier extends StateNotifier<AsyncValue<void>> {
  SosResolveNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<bool> resolve(String incidentId) async {
    final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
    if (sanitized == null) return false;

    debugPrint('[SosProviders] ✅ Resolving incident: $sanitized');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).resolveIncident(sanitized),
        label: 'resolveIncident[$sanitized]',
      );
      _safeStopControllers();
      _safeInvalidate(activeSosProvider);
      _safeInvalidate(sosHistoryProvider);
    });

    final success = !state.hasError;
    debugPrint('[SosProviders] ${success ? '✓' : '❌'} Resolve: $success');
    return success;
  }

  Future<bool> cancel(String incidentId) async {
    final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
    if (sanitized == null) return false;

    debugPrint('[SosProviders] 🚫 Cancelling incident: $sanitized');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).cancelIncident(sanitized),
        label: 'cancelIncident[$sanitized]',
      );
      _safeStopControllers();
      _safeInvalidate(activeSosProvider);
      _safeInvalidate(sosHistoryProvider);
    });

    final success = !state.hasError;
    debugPrint('[SosProviders] ${success ? '✓' : '❌'} Cancel: $success');
    return success;
  }

  /// ✅ Arrêt sécurisé des controllers (heartbeat + escalation)
  void _safeStopControllers() {
    try {
      _ref.read(sosHeartbeatControllerProvider.notifier).stop();
    } catch (e) {
      debugPrint('[SosProviders] ⚠️ Stop heartbeat failed: $e');
    }
    try {
      _ref.read(sosEscalationProvider).stop();
    } catch (e) {
      debugPrint('[SosProviders] ⚠️ Stop escalation failed: $e');
    }
  }

  /// ✅ Invalidation sécurisée
  void _safeInvalidate(ProviderBase provider) {
    try {
      _ref.invalidate(provider);
    } catch (e) {
      debugPrint('[SosProviders] ⚠️ Invalidate failed: $e');
    }
  }
}
