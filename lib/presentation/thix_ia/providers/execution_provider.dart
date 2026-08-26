// lib/presentation/thix_ia/providers/execution_provider.dart
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
import '../models/execution_report.dart'; // si le fichier modèle existe

// ═══════════════════════════════════════════════════════════════
// INFRA
// ═══════════════════════════════════════════════════════════════

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
    ref.read(supabaseClientProvider),
    ref.read(executionRepositoryProvider),
  );
});

// ═══════════════════════════════════════════════════════════════
// DASHBOARD & PROJET
// ═══════════════════════════════════════════════════════════════

/// Dashboard agrégé (health, priorité, KPIs)
final executionDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, projectCode) async {
  final service = ref.read(executionServiceProvider);
  return service.getDashboard(projectCode);
});

/// Projet exécution (treasury, burn, runway, mrr, health…)
final executionProjectProvider =
    FutureProvider.family<ExecutionProject?, String>((ref, code) async {
  try {
    return await ref.read(executionRepositoryProvider).getProject(code);
  } catch (_) {
    return null;
  }
});

// ═══════════════════════════════════════════════════════════════
// TASKS (stream + one-shot)
// ═══════════════════════════════════════════════════════════════

final executionTasksProvider =
    StreamProvider.family<List<ExecutionTask>, String>((ref, projectCode) {
  return ref.read(executionRepositoryProvider).watchTasks(projectCode);
});

final executionTasksFutureProvider =
    FutureProvider.family<List<ExecutionTask>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getTasks(code, limit: 200);
});

// ═══════════════════════════════════════════════════════════════
// GOALS / OKRs
// ═══════════════════════════════════════════════════════════════

final executionGoalsProvider =
    FutureProvider.family<List<ExecutionGoal>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getGoals(code);
});

// ═══════════════════════════════════════════════════════════════
// FINANCE
// ═══════════════════════════════════════════════════════════════

/// Snapshot financier (calculé depuis txs + projet)
final executionFinanceProvider =
    FutureProvider.family<FinancialSnapshot?, String>((ref, code) async {
  try {
    return await ref.read(executionRepositoryProvider).getFinanceSnapshot(code);
  } catch (_) {
    return null;
  }
});

final executionTransactionsProvider =
    FutureProvider.family<List<FinanceTransaction>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getTransactions(code);
});

// ═══════════════════════════════════════════════════════════════
// SUPPLIERS / RISKS / ROADMAP
// ═══════════════════════════════════════════════════════════════

final executionSuppliersProvider =
    FutureProvider.family<List<Supplier>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getSuppliers(code);
});

final executionRisksProvider =
    FutureProvider.family<List<RiskItem>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getRisks(code);
});

final executionComplianceProvider =
    FutureProvider.family<List<ComplianceItem>, String>((ref, code) async {
  try {
    return await ref.read(executionRepositoryProvider).getCompliance(code);
  } catch (_) {
    return [];
  }
});

final executionRoadmapProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  return ref.read(executionRepositoryProvider).getRoadmap(code);
});

// ═══════════════════════════════════════════════════════════════
// EXPERIMENTS
// ═══════════════════════════════════════════════════════════════

final executionExperimentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_execution_experiments')
      .select()
      .eq('project_code', code)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ═══════════════════════════════════════════════════════════════
// MARKET RADAR
// ═══════════════════════════════════════════════════════════════

final marketSignalsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_execution_market_signals')
      .select()
      .eq('project_code', code)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ═══════════════════════════════════════════════════════════════
// REPORTS
// ═══════════════════════════════════════════════════════════════

/// Si tu as le modèle ExecutionReport :
// final executionReportsProvider =
//     FutureProvider.family<List<ExecutionReport>, String>((ref, code) async {
//   final client = ref.read(supabaseClientProvider);
//   final rows = await client
//       .from('thix_execution_reports')
//       .select()
//       .eq('project_code', code)
//       .order('created_at', ascending: false);
//   return (rows as List).map((e) => ExecutionReport.fromJson(e)).toList();
// });

/// Version Map (sans modèle dédié) :
final executionReportsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_execution_reports')
      .select()
      .eq('project_code', code)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ═══════════════════════════════════════════════════════════════
// BUDGET / LEVÉE (BP → exécution)
// ═══════════════════════════════════════════════════════════════

final executionBudgetProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final row = await client
      .from('thix_execution_budget')
      .select()
      .eq('project_code', code)
      .maybeSingle();
  if (row == null) return null;
  return Map<String, dynamic>.from(row);
});

// ═══════════════════════════════════════════════════════════════
// BP CONFIG (équipe, produit, pre-flight)
// ═══════════════════════════════════════════════════════════════

final bpConfigProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final row = await client
      .from('thix_bp_config')
      .select()
      .eq('project_code', code)
      .maybeSingle();
  if (row == null) return null;
  return Map<String, dynamic>.from(row);
});
