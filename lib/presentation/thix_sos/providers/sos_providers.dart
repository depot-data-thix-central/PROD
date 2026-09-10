/// THIX SOS — Riverpod providers
/// Trigger rapide : le protocole chat/appels part en background.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/sos_models.dart';
import '../services/sos_service.dart';
import '../services/sos_protocol_orchestrator.dart';
import '../services/sos_escalation_controller.dart';

const Duration _kTriggerTimeout = Duration(seconds: 12);
const Duration _kHeartbeatTimeout = Duration(seconds: 12);
const Duration _kGeolocatorTimeout = Duration(seconds: 6);
const Duration _kDefaultHeartbeatInterval = Duration(seconds: 15);
const Duration _kEscalationDelay = Duration(seconds: 15);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMinThixIdLength = 4;
const int _kMaxThixIdLength = 32;

class _ProvidersValidators {
  _ProvidersValidators._();

  static bool isValidThixId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.length < _kMinThixIdLength ||
        trimmed.length > _kMaxThixIdLength) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed);
  }

  static String? sanitizeIncidentId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }
}

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

final sosServiceProvider = Provider<SosService>((ref) {
  return SosService();
});

final sosContactsProvider =
    FutureProvider.autoDispose<List<SosContact>>((ref) async {
  return ref.watch(sosServiceProvider).getContacts();
});

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

final thixIdLookupProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, thixId) async {
  if (!_ProvidersValidators.isValidThixId(thixId)) return null;
  return _providersRetry(
    () => ref.watch(sosServiceProvider).lookupProfileByThixId(thixId),
    label: 'thixIdLookup',
  );
});

final activeSosProvider =
    FutureProvider.autoDispose<SosIncident?>((ref) async {
  try {
    return await ref.watch(sosServiceProvider).getActiveIncident();
  } catch (e) {
    return null;
  }
});

final sosHistoryProvider =
    FutureProvider.autoDispose<List<SosIncident>>((ref) async {
  return ref.watch(sosServiceProvider).getHistory();
});

final sosIncidentProvider =
    FutureProvider.autoDispose.family<SosIncident?, String>((ref, id) async {
  final sanitized = _ProvidersValidators.sanitizeIncidentId(id);
  if (sanitized == null) return null;
  try {
    return await ref.watch(sosServiceProvider).getIncidentById(sanitized);
  } catch (e) {
    return null;
  }
});

final sosEventsProvider =
    FutureProvider.autoDispose.family<List<SosEvent>, String>((ref, incidentId) {
  final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
  if (sanitized == null) return [];
  return ref.watch(sosServiceProvider).getEvents(sanitized);
});

final sosLocationsProvider =
    FutureProvider.autoDispose.family<List<SosLocationPoint>, String>(
  (ref, incidentId) {
    final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
    if (sanitized == null) return [];
    return ref.watch(sosServiceProvider).getLocations(sanitized);
  },
);

final sosUserPositionProvider =
    FutureProvider.autoDispose<({double lat, double lng})?>((ref) async {
  try {
    final serviceOn = await Geolocator.isLocationServiceEnabled()
        .timeout(_kGeolocatorTimeout);
    if (!serviceOn) return null;

    var permission =
        await Geolocator.checkPermission().timeout(_kGeolocatorTimeout);
    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission().timeout(_kGeolocatorTimeout);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lng: last.longitude);
    } catch (_) {}

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 3),
      ),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (e) {
    debugPrint('[SosProviders] position: $e');
    return null;
  }
});

final triggerSosProvider = StateNotifierProvider.autoDispose<
    TriggerSosNotifier, AsyncValue<SosIncident?>>(
  (ref) => TriggerSosNotifier(ref),
);

class TriggerSosNotifier extends StateNotifier<AsyncValue<SosIncident?>> {
  TriggerSosNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  bool _isTriggering = false;

  Future<SosIncident?> trigger() async {
    if (_isTriggering) return state.valueOrNull;
    _isTriggering = true;
    state = const AsyncLoading();

    try {
      final incident = await _providersRetry(
        () => _ref.read(sosServiceProvider).triggerSos(),
        label: 'triggerSos',
        timeout: _kTriggerTimeout,
      );

      state = AsyncData(incident);
      _safeInvalidate(activeSosProvider);
      _safeInvalidate(sosHistoryProvider);

      // Protocole (chat + appels + SOS_STARTED) : NE PAS await.
      unawaited(_runProtocol(incident));
      return incident;
    } catch (e, st) {
      debugPrint('[SosProviders] trigger: $e');
      state = AsyncError(e, st);
      return null;
    } finally {
      _isTriggering = false;
    }
  }

  Future<void> _runProtocol(SosIncident incident) async {
    try {
      final result = await SosProtocolOrchestrator(
        sos: _ref.read(sosServiceProvider),
      ).run(incident);

      debugPrint(
        '[SosProviders] protocol chat=${result.conversationId} '
        'calls=${result.answeredOrRinging}/${result.calls.length}',
      );

      try {
        _ref.read(sosEscalationProvider).start(
              incident.id,
              startCircle: 1,
            );
      } catch (e) {
        debugPrint('[SosProviders] escalation: $e');
      }
      _safeInvalidate(activeSosProvider);
    } catch (e) {
      debugPrint('[SosProviders] protocol background: $e');
    }
  }

  void _safeInvalidate(ProviderBase provider) {
    try {
      _ref.invalidate(provider);
    } catch (_) {}
  }

  void reset() => state = const AsyncData(null);
}

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
    _tick();
  }

  Future<void> _tick() async {
    final id = _incidentId;
    if (id == null || !state) return;
    _tickCount++;
    try {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).heartbeat(id),
        label: 'heartbeat',
        timeout: _kHeartbeatTimeout,
        maxRetries: 0,
      );
      if (_tickCount % 4 == 0) {
        try {
          _ref.invalidate(activeSosProvider);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SosProviders] heartbeat: $e');
    }
  }

  void stop() {
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

final sosEscalationProvider =
    Provider.autoDispose<SosEscalationController>((ref) {
  final controller = SosEscalationController(
    sos: ref.watch(sosServiceProvider),
    delayPerCircle: _kEscalationDelay,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final sosContactActionsProvider = Provider<SosContactActions>((ref) {
  return SosContactActions(ref);
});

class SosContactActions {
  SosContactActions(this._ref);
  final Ref _ref;

  SosService get _service => _ref.read(sosServiceProvider);

  void _safeInvalidate() {
    try {
      _ref.invalidate(sosContactsProvider);
    } catch (_) {}
  }

  Future<SosContact> add({
    required String name,
    required int circle,
    String? phone,
    String? thixId,
    String? relation,
  }) async {
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
    return c;
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
      label: 'addFromThix',
    );
    _safeInvalidate();
    return c;
  }

  Future<void> update(SosContact contact) async {
    await _providersRetry(
      () => _service.updateContact(contact),
      label: 'updateContact',
    );
    _safeInvalidate();
  }

  Future<void> delete(String id) async {
    await _providersRetry(
      () => _service.deleteContact(id),
      label: 'deleteContact',
    );
    _safeInvalidate();
  }
}

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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).resolveIncident(sanitized),
        label: 'resolveIncident',
      );
      _safeStopControllers();
      _safeInvalidate(activeSosProvider);
      _safeInvalidate(sosHistoryProvider);
    });
    return !state.hasError;
  }

  Future<bool> cancel(String incidentId) async {
    final sanitized = _ProvidersValidators.sanitizeIncidentId(incidentId);
    if (sanitized == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _providersRetry(
        () => _ref.read(sosServiceProvider).cancelIncident(sanitized),
        label: 'cancelIncident',
      );
      _safeStopControllers();
      _safeInvalidate(activeSosProvider);
      _safeInvalidate(sosHistoryProvider);
    });
    return !state.hasError;
  }

  void _safeStopControllers() {
    try {
      _ref.read(sosHeartbeatControllerProvider.notifier).stop();
    } catch (_) {}
    try {
      _ref.read(sosEscalationProvider).stop();
    } catch (_) {}
  }

  void _safeInvalidate(ProviderBase provider) {
    try {
      _ref.invalidate(provider);
    } catch (_) {}
  }
}
