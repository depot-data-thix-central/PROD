import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';

final appointmentServiceProvider = Provider((ref) => AppointmentService());

final linkedDoctorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(appointmentServiceProvider).getMyLinkedDoctors();
});

final takenSlotsProvider = FutureProvider.family<List<String>, ({String doctorId, DateTime date})>((ref, p) async {
  return ref.read(appointmentServiceProvider).getTakenSlots(doctorId: p.doctorId, date: p.date);
});

final myAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) async {
  return ref.read(appointmentServiceProvider).getMyAppointments();
});

final createAppointmentProvider = AsyncNotifierProvider<CreateAppointmentNotifier, AppointmentModel?>(CreateAppointmentNotifier.new);

class CreateAppointmentNotifier extends AsyncNotifier<AppointmentModel?> {
  @override Future<AppointmentModel?> build() async => null;
  Future<AppointmentModel> create({required String doctorId, required DateTime date, required String creneau, required String type, required String motif}) async {
    state = const AsyncLoading();
    try {
      final res = await ref.read(appointmentServiceProvider).createAppointment(doctorId: doctorId, date: date, creneau: creneau, type: type, motif: motif);
      ref.invalidate(myAppointmentsProvider);
      ref.invalidate(takenSlotsProvider);
      state = AsyncData(res);
      return res;
    } catch (e, st) { state = AsyncError(e, st); rethrow; }
  }
}
