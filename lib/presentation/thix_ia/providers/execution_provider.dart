import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/execution_remote_datasource.dart';
import '../repositories/execution_repository.dart';
import '../services/execution_service.dart';
import '../services/execution_ai_service.dart';
import '../models/execution_task.dart';
import '../models/execution_goal.dart';
import '../models/execution_finance.dart';
import '../models/execution_support.dart';
import '../models/execution_project.dart';

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final executionDatasourceProvider = Provider<ExecutionRemoteDatasource>((ref) {
  return ExecutionRemoteDatasource(ref.read(supabaseClientProvider));
});

final executionRepositoryProvider = Provider<ExecutionRepository>((ref) {
  return ExecutionRepository(ref.read(executionDatasourceProvider));
});

final executionServiceProvider = Provider<ExecutionService>((ref) {
  return ExecutionService(ref.read(executionRepositoryProvider));
});

final executionAiServiceProvider = Provider<ExecutionAiService>((ref) {
  return ExecutionAiService(
      ref.read(supabaseClientProvider), ref.read(executionRepositoryProvider));
});

// DASHBOARD COMPLET (recalcule toujours depuis les transactions)
final executionDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, projectCode) async {
  final service = ref.read(executionServiceProvider);
  return service.getDashboard(projectCode);
});

final executionTasksProvider =
    StreamProvider.family<List<ExecutionTask>, String>((ref, projectCode) {
  return ref.read(executionRepositoryProvider).watchTasks(projectCode);
});

final executionTasksFutureProvider =
    FutureProvider.family<List<ExecutionTask>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getTasks(code, limit: 200);
});

final executionGoalsProvider =
    FutureProvider.family<List<ExecutionGoal>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getGoals(code);
});

// ★ CORRECTION : snapshot calculé depuis les transactions
final executionFinanceProvider =
    FutureProvider.family<FinancialSnapshot?, String>((ref, code) async {
  try {
    return await ref.read(executionRepositoryProvider).getFinanceSnapshot(code);
  } catch (_) {
    return null;
  }
});

final executionSuppliersProvider =
    FutureProvider.family<List<Supplier>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getSuppliers(code);
});

final executionRisksProvider =
    FutureProvider.family<List<RiskItem>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getRisks(code);
});

final executionRoadmapProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getRoadmap(code);
});

final executionTransactionsProvider =
    FutureProvider.family<List<FinanceTransaction>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getTransactions(code);
});
