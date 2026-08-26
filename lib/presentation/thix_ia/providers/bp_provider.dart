import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_plan_config.dart';
import '../repositories/bp_config_repository.dart';

final bpConfigRepositoryProvider = Provider<BpConfigRepository>((ref) {
  return BpConfigRepository();
});

/// Charge la config Pre-Flight depuis Supabase (thix_bp_config)
final bpConfigProvider =
    FutureProvider.family<BusinessPlanConfig?, String>((ref, projectCode) async {
  return ref.read(bpConfigRepositoryProvider).getByProject(projectCode);
});
