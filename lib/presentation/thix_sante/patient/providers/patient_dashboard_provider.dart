// lib/presentation/thix_sante/patient/providers/patient_dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_record_model.dart';
import '../services/health_record_service.dart';
import '../services/prescription_service.dart';
import '../services/patient_link_service.dart'; // <-- IMPORT DU VRAI SERVICE

// =============================================================================
// SERVICES
// =============================================================================
final healthRecordServiceProvider = Provider<HealthRecordService>((ref) => HealthRecordService());
final prescriptionServiceProvider = Provider<PrescriptionService>((ref) => PrescriptionService());
final patientLinkServiceProvider = Provider<PatientLinkService>((ref) => PatientLinkService());

// (La fausse classe PatientLinkService a été supprimée d'ici pour laisser place à la vraie)

// =============================================================================
// RECORDS
// =============================================================================
final recentRecordsProvider = FutureProvider<List<HealthRecordModel>>((ref) async {
  final service = ref.watch(healthRecordServiceProvider);
  return service.getMyRecords();
});

final prescriptionsProvider = FutureProvider<List<Map<String,dynamic>>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final List data = await db.from('prescriptions')
      .select()
      .eq('patient_uid', uid)
      .order('created_at', ascending: false);
  return data.map((e) => e as Map<String,dynamic>).toList();
});
