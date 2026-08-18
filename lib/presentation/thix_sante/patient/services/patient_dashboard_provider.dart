// lib/presentation/thix_sante/patient/providers/patient_dashboard_provider.dart
// =============================================================================
// Providers: Dashboard Patient - Stats temps reel pour ta capture
// Role: Alimente les 4 cartes stats [12 Consultations, 8 Examens...]
// Architecture: Riverpod AsyncNotifier - pattern recommande Master
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_record_service.dart';
import '../services/patient_link_service.dart';
import '../services/prescription_service.dart';
import '../models/health_record_model.dart';

final healthRecordServiceProvider =
    Provider<HealthRecordService>((ref) => HealthRecordService());
final patientLinkServiceProvider =
    Provider<PatientLinkService>((ref) => PatientLinkService());
final prescriptionServiceProvider =
    Provider<PrescriptionService>((ref) => PrescriptionService());

/// Stats dashboard - correspond exactement a ta capture.
class DashboardStats {
  final int consultations;
  final int examens;
  final int medicamentsEnCours;
  final int rendezVousAVenir;

  const DashboardStats({
    required this.consultations,
    required this.examens,
    required this.medicamentsEnCours,
    required this.rendezVousAVenir,
  });

  factory DashboardStats.empty() => const DashboardStats(
        consultations: 0,
        examens: 0,
        medicamentsEnCours: 0,
        rendezVousAVenir: 0,
      );
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final HealthRecordService recordService = ref.read(healthRecordServiceProvider);
  final PrescriptionService prescriptionService =
      ref.read(prescriptionServiceProvider);

  final Map<RecordType, int> recordCounts = await recordService.getStats();
  final int medicaments = await prescriptionService.countActive();

  // TODO: Remplacer par appointment_service quand module RDV pret
  const int rdvCount = 3; // Valeur mock conforme a ta capture

  return DashboardStats(
    consultations: recordCounts[RecordType.consultation]?? 0,
    examens: (recordCounts[RecordType.laboratoire]?? 0) +
        (recordCounts[RecordType.radiologie]?? 0),
    medicamentsEnCours: medicaments,
    rendezVousAVenir: rdvCount,
  );
});

/// Stream dossiers recents pour section Pour vous.
final recentRecordsProvider = StreamProvider<List<HealthRecordModel>>((ref) {
  return ref.read(healthRecordServiceProvider).watchMyRecords();
});

/// Stream mes medecins actifs.
final activeDoctorsCountProvider = FutureProvider<int>((ref) async {
  return ref.read(patientLinkServiceProvider).countMyDoctors();
});
