// lib/presentation/thix_sante/patient/providers/patient_link_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/patient_link_service.dart';
import '../models/doctor_profile_model.dart';

final patientLinkServiceProvider = Provider((ref)=> PatientLinkService());

final myLinkedDoctorsProvider = FutureProvider<List<DoctorProfileModel>>((ref) async {
  return ref.read(patientLinkServiceProvider).getMyLinkedDoctors();
});
