// lib/presentation/thix_sante/patient/providers/grossesse_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grossesse_model.dart';
import '../services/grossesse_service.dart';
import '../models/health_record_model.dart';

final grossesseServiceProvider = Provider((ref) => GrossesseService());

final grossesseProfileProvider = FutureProvider.family<PregnancyProfile?, String?>((ref, pid) async {
  return ref.read(grossesseServiceProvider).getProfile(pid);
});

final vitalsProvider = FutureProvider.family<List<PregnancyVital>, String?>((ref, pid) async {
  return ref.read(grossesseServiceProvider).getVitals(pid);
});

final kicksProvider = FutureProvider.family<List<PregnancyKick>, String?>((ref, pid) async {
  return ref.read(grossesseServiceProvider).getKicks(pid);
});

final journalProvider = FutureProvider.family<List<PregnancyJournal>, String?>((ref, pid) async {
  return ref.read(grossesseServiceProvider).getJournals(pid);
});

final contractionsProvider = FutureProvider.family<List<PregnancyContraction>, String?>((ref, pid) async {
  return ref.read(grossesseServiceProvider).getContractions(pid);
});

// CORRIGÉ : Utilisation de ChecklistItem au lieu de PregnancyChecklist
final checklistProvider = FutureProvider.family<List<ChecklistItem>, String?>((ref, pid) async {
  final svc = ref.read(grossesseServiceProvider);
  await svc.ensureDefaultChecklist(pid);
  return svc.getChecklist(pid);
});

final grossesseRecordsProvider = FutureProvider.family<List<HealthRecordModel>, String?>((ref, pid) async {
  final db = Supabase.instance.client;
  final uid = pid ?? db.auth.currentUser!.id;
  final data = await db.from('health_records').select().eq('patient_uid', uid).or('title.ilike.%grossesse%,description.ilike.%grossesse%').order('exam_date', ascending: false);
  return (data as List).map((e) => HealthRecordModel.fromJson(e)).toList();
});
