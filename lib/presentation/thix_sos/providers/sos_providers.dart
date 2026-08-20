/// THIX SOS — Riverpod providers (production)
import 'dart:async';
import 'package:flutter/foundation.dart'; // Pour debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_models.dart';
import '../services/sos_service.dart';
import '../services/sos_call_bridge.dart'; // Protocole Chat + Appels

// ── Service ───────────────────────────────────────────────────
final sosServiceProvider = Provider<SosService>((ref) {
  return SosService();
});

// ── Contacts ──────────────────────────────────────────────────
final sosContactsProvider =
    FutureProvider.autoDispose<List<SosContact>>((ref) async {
  return ref.watch(sosServiceProvider).getContacts();
});

final sosContactsCircleProvider =
    FutureProvider.autoDispose.family<List<SosContact>, int>((ref, circle) async {
  final all = await ref.watch(sosContactsProvider.future);
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

// ── Recherche Profil (THIX ID) ────────────────────────────────
final thixIdLookupProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, thixId) async {
  if (thixId.trim().isEmpty) return null;
  return ref.watch(sosServiceProvider).lookupProfileByThixId(thixId);
});

// ── Incident actif ────────────────────────────────────────────
final activeSosProvider =
    FutureProvider.autoDispose<SosIncident?>((ref) async {
  return ref.watch(sosServiceProvider).getActiveIncident();
});

final sosHistoryProvider =
    FutureProvider.autoDispose<List<SosIncident>>((ref) async {
  return ref.watch(sosServiceProvider).getHistory();
});

final sosIncidentProvider =
    FutureProvider.autoDispose.family<SosIncident?, String>((ref, id) async {
  return ref.watch(sosServiceProvider).getIncidentById(id);
});

final sosEventsProvider =
    FutureProvider.autoDispose.family<List<SosEvent>, String>((ref, incidentId) {
  return ref.watch(sosServiceProvider).getEvents(incidentId);
});

final sosLocationsProvider =
    FutureProvider.autoDispose.family<List<SosLocationPoint>, String>(
  (ref, incidentId) {
    return ref.watch(sosServiceProvider).getLocations(incidentId);
  },
);

// ── Déclenchement SOS ─────────────────────────────────────────
final triggerSosProvider =
    StateNotifierProvider<TriggerSosNotifier, AsyncValue<SosIncident?>>(
  (ref) => TriggerSosNotifier(ref),
);

class TriggerSosNotifier extends StateNotifier<AsyncValue<SosIncident?>> {
  TriggerSosNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<SosIncident?> trigger() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final incident = await _ref.read(sosServiceProvider).triggerSos();

      // Protocole Chat + Appels (ne bloque pas l'UI si échec partiel)
      try {
        final result = await SosCallBridge(
          sos: _ref.read(sosServiceProvider),
        ).activateProtocol(incident);
        debugPrint(
          'SOS protocol: chat=${result.conversationId} calls=${result.answeredOrRinging}/${result.calls.length}',
        );
      } catch (e) {
        debugPrint('SOS protocol partial failure: $e');
      }

      _ref.invalidate(activeSosProvider);
      _ref.invalidate(sosHistoryProvider);
      return incident;
    });
    return state.valueOrNull;
  }

  void reset() => state = const AsyncData(null);
}

// ── Heartbeat automatique (pendant SOS actif) ─────────────────
final sosHeartbeatControllerProvider =
    StateNotifierProvider.autoDispose<SosHeartbeatController, bool>(
  (ref) => SosHeartbeatController(ref),
);

class SosHeartbeatController extends StateNotifier<bool> {
  SosHeartbeatController(this._ref) : super(false);

  final Ref _ref;
  Timer? _timer;
  String? _incidentId;

  /// Démarre un heartbeat toutes les [interval] secondes
  void start(String incidentId, {Duration interval = const Duration(seconds: 15)}) {
    stop();
    _incidentId = incidentId;
    state = true;
    _timer = Timer.periodic(interval, (_) => _tick());
    _tick(); // immédiat
  }

  Future<void> _tick() async {
    final id = _incidentId;
    if (id == null || !state) return;
    try {
      await _ref.read(sosServiceProvider).heartbeat(id);
      _ref.invalidate(activeSosProvider);
    } catch (_) {
      // silencieux : on réessaiera au prochain tick
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _incidentId = null;
    state = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ── Actions contacts ──────────────────────────────────────────
final sosContactActionsProvider = Provider<SosContactActions>((ref) {
  return SosContactActions(ref);
});

class SosContactActions {
  SosContactActions(this._ref);
  final Ref _ref;

  SosService get _service => _ref.read(sosServiceProvider);

  Future<SosContact> add({
    required String name,
    required int circle,
    String? phone,
    String? thixId,
    String? relation,
  }) async {
    final c = await _service.addContact(
      name: name,
      circle: circle,
      phone: phone,
      thixId: thixId,
      relation: relation,
    );
    _ref.invalidate(sosContactsProvider);
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
    final c = await _service.addContactFromThixProfile(
      thixId: thixId,
      contactUserId: contactUserId,
      name: name,
      circle: circle,
      photoUrl: photoUrl,
      phone: phone,
      relation: relation,
    );
    _ref.invalidate(sosContactsProvider);
    return c;
  }

  Future<void> update(SosContact contact) async {
    await _service.updateContact(contact);
    _ref.invalidate(sosContactsProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteContact(id);
    _ref.invalidate(sosContactsProvider);
  }
}

// ── Résoudre / Annuler ────────────────────────────────────────
final sosResolveProvider =
    StateNotifierProvider<SosResolveNotifier, AsyncValue<void>>(
  (ref) => SosResolveNotifier(ref),
);

class SosResolveNotifier extends StateNotifier<AsyncValue<void>> {
  SosResolveNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<bool> resolve(String incidentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref.read(sosServiceProvider).resolveIncident(incidentId);
      _ref.read(sosHeartbeatControllerProvider.notifier).stop();
      _ref.invalidate(activeSosProvider);
      _ref.invalidate(sosHistoryProvider);
    });
    return !state.hasError;
  }

  Future<bool> cancel(String incidentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref.read(sosServiceProvider).cancelIncident(incidentId);
      _ref.read(sosHeartbeatControllerProvider.notifier).stop();
      _ref.invalidate(activeSosProvider);
      _ref.invalidate(sosHistoryProvider);
    });
    return !state.hasError;
  }
}
