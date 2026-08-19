import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sos_models.dart';
import '../services/sos_service.dart';

final sosServiceProvider = Provider<SosService>((ref) => SosService());

final sosContactsProvider = FutureProvider.autoDispose<List<SosContact>>((ref) {
  return ref.watch(sosServiceProvider).getContacts();
});

final activeSosProvider = FutureProvider.autoDispose<SosIncident?>((ref) {
  return ref.watch(sosServiceProvider).getActiveIncident();
});

final sosHistoryProvider = FutureProvider.autoDispose<List<SosIncident>>((ref) {
  return ref.watch(sosServiceProvider).getHistory();
});

/// Déclenchement SOS (état loading / error)
final triggerSosProvider =
    StateNotifierProvider<TriggerSosNotifier, AsyncValue<SosIncident?>>(
  (ref) => TriggerSosNotifier(ref),
);

class TriggerSosNotifier extends StateNotifier<AsyncValue<SosIncident?>> {
  TriggerSosNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<SosIncident?> trigger() async {
    state = const AsyncValue.loading();
    try {
      final incident = await _ref.read(sosServiceProvider).triggerSos();
      state = AsyncValue.data(incident);
      _ref.invalidate(activeSosProvider);
      _ref.invalidate(sosHistoryProvider);
      return incident;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}
