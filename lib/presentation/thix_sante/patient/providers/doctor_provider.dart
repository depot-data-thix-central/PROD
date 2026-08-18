// lib/presentation/thix_sante/patient/providers/doctor_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doctor_model.dart';
import '../services/doctor_service.dart';

final doctorServiceProvider = Provider((ref)=> DoctorService());

final myDoctorsProvider = FutureProvider<List<DoctorModel>>((ref) async {
  return ref.read(doctorServiceProvider).getMyLinkedDoctors();
});

final searchDoctorsProvider = FutureProvider.family<List<DoctorModel>, ({String query, String speciality})>((ref, params) async {
  if(params.query.isEmpty && params.speciality=='Tous') return [];
  return ref.read(doctorServiceProvider).searchDoctors(query: params.query, speciality: params.speciality);
});
