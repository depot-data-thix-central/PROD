// lib/presentation/thix_ia/repositories/execution_repository.dart
import '../datasources/execution_remote_datasource.dart';
import '../models/execution_project.dart';
import '../models/execution_task.dart';
import '../models/execution_goal.dart';
import '../models/execution_finance.dart';
import '../models/execution_support.dart';
import '../core/utils/execution_utils.dart';

class ExecutionRepository {
  ExecutionRepository(this._ds);
  final ExecutionRemoteDatasource _ds;

  // ═══════════════════════════════════════════════════════════════
  // PROJECT / HEALTH
  // ═══════════════════════════════════════════════════════════════

  Future<ExecutionProject?> getProject(String projectCode) =>
      _ds.getExecutionProject(projectCode);

  Future<ExecutionProject> getOrCreateHealth(String projectCode) async {
    final existing = await _ds.getExecutionProject(projectCode);
    if (existing != null) return existing;

    final init = ExecutionProject(
      id: projectCode,
      projectCode: projectCode,
      healthScore: 0,
      healthDimensions: const {
        'market': 0,
        'product': 0,
        'finance': 0,
        'legal': 0,
        'commercial': 0,
        'execution': 0,
      },
      treasury: 0,
      burnRate: 0,
      runwayMonths: 0,
      mrr: 0,
    );
    return _ds.upsertExecutionProject(init);
  }

  Future<ExecutionProject> upsertExecutionProject(ExecutionProject project) =>
      _ds.upsertExecutionProject(project);

  // ═══════════════════════════════════════════════════════════════
  // TASKS
  // ═══════════════════════════════════════════════════════════════

  Future<List<ExecutionTask>> getTasks(
    String code, {
    int limit = 100,
    int offset = 0,
    String? status,
  }) =>
      _ds.getTasks(code, limit: limit, offset: offset, status: status);

  Stream<List<ExecutionTask>> watchTasks(String code) =>
      _ds.watchTasks(code);

  Future<ExecutionTask> createTask(ExecutionTask t) => _ds.createTask(t);

  Future<ExecutionTask> updateTask(String id, Map<String, dynamic> patch) =>
      _ds.updateTask(id, patch);

  Future<ExecutionTask> updateTaskStatus(String id, String status) =>
      _ds.updateTaskStatus(id, status);

  Future<ExecutionTask> completeTask(String id) => _ds.completeTask(id);

  Future<void> deleteTask(String id) => _ds.deleteTask(id);

  /// Templates locaux (fallback si edge IA indisponible)
  Future<List<ExecutionTask>> generateAutoTasks({
    required String projectCode,
    required String objective,
  }) async {
    final templates = [
      {'title': 'Finaliser le produit', 'category': 'Tech', 'priority': 'high'},
      {
        'title': 'Vérifier la conformité $objective',
        'category': 'Légal',
        'priority': 'high'
      },
      {
        'title': 'Préparer les contrats',
        'category': 'Légal',
        'priority': 'medium'
      },
      {
        'title': 'Identifier 50 prospects',
        'category': 'Marketing',
        'priority': 'high'
      },
      {
        'title': 'Préparer la campagne',
        'category': 'Marketing',
        'priority': 'medium'
      },
      {'title': 'Tester l\'offre', 'category': 'Ops', 'priority': 'high'},
      {
        'title': 'Collecter les retours',
        'category': 'Ops',
        'priority': 'medium'
      },
      {
        'title': 'Corriger le produit',
        'category': 'Tech',
        'priority': 'medium'
      },
      {
        'title': 'Lancer',
        'category': 'Marketing',
        'priority': 'critical'
      },
    ];

    final created = <ExecutionTask>[];
    for (final t in templates) {
      final task = ExecutionTask(
        id: ExecutionUtils.generateTaskId(projectCode),
        projectCode: projectCode,
        title: t['title']!,
        category: t['category']!,
        priority: t['priority']!,
        status: 'todo',
        isAiSuggested: true,
        origin: 'ai',
        progress: 0,
      );
      created.add(await _ds.createTask(task));
    }
    return created;
  }

  // ═══════════════════════════════════════════════════════════════
  // GOALS / OKRs
  // ═══════════════════════════════════════════════════════════════

  Future<List<ExecutionGoal>> getGoals(String code) => _ds.getGoals(code);

  Future<ExecutionGoal> upsertGoal(ExecutionGoal g) => _ds.upsertGoal(g);

  Future<void> deleteGoal(String id) => _ds.deleteGoal(id);

  // ═══════════════════════════════════════════════════════════════
  // FINANCE
  // ═══════════════════════════════════════════════════════════════

  Future<List<FinanceTransaction>> getTransactions(String code) =>
      _ds.getTransactions(code);

  /// Ajoute la transaction puis recalcule treasury / burn / runway / MRR
  Future<FinanceTransaction> addTransaction(FinanceTransaction tx) async {
    final created = await _ds.addTransaction(tx);

    final allTx = await _ds.getTransactions(tx.projectCode);
    final finance = ExecutionUtils.computeFinanceFromTransactions(allTx);

    final existing = await _ds.getExecutionProject(tx.projectCode);
    final updated = (existing ??
            ExecutionProject(
              id: tx.projectCode,
              projectCode: tx.projectCode,
              healthScore: 0,
              healthDimensions: const {},
              treasury: 0,
              burnRate: 0,
              runwayMonths: 0,
              mrr: 0,
            ))
        .copyWith(
      treasury: finance['treasury'],
      burnRate: finance['burnRate'],
      runwayMonths: finance['runwayMonths'],
      mrr: finance['mrr'],
    );

    await _ds.upsertExecutionProject(updated);
    return created;
  }

  Future<void> deleteTransaction(String id) => _ds.deleteTransaction(id);

  /// Snapshot live depuis transactions (+ fallback DB / projet)
  Future<FinancialSnapshot?> getFinanceSnapshot(String code) async {
    try {
      // Préférer le calcul datasource enrichi si dispo
      try {
        return await _ds.getFinanceSnapshotComputed(code);
      } catch (_) {
        // fallback local
      }

      final transactions = await _ds.getTransactions(code);
      final project = await _ds.getExecutionProject(code);

      if (transactions.isEmpty) {
        try {
          final snap = await _ds.getFinancialSnapshot(code);
          if (snap != null) return snap;
        } catch (_) {}

        if (project != null) {
          return FinancialSnapshot(
            projectCode: code,
            treasury: project.treasury,
            burnRate: project.burnRate,
            runwayMonths: project.runwayMonths,
            mrr: project.mrr,
            arr: project.mrr * 12,
            revenueMonthly: project.mrr,
            expensesMonthly: project.burnRate,
            sector: FinanceSector.service,
          );
        }
        return null;
      }

      final f = ExecutionUtils.computeFinanceFromTransactions(transactions);
      return FinancialSnapshot(
        projectCode: code,
        treasury: f['treasury'] ?? project?.treasury ?? 0,
        burnRate: f['burnRate'] ?? project?.burnRate ?? 0,
        runwayMonths: f['runwayMonths'] ?? project?.runwayMonths ?? 0,
        mrr: f['mrr'] ?? project?.mrr ?? 0,
        arr: (f['mrr'] ?? project?.mrr ?? 0) * 12,
        revenueMonthly: f['revenueMonthly'] ?? 0,
        expensesMonthly: f['expensesMonthly'] ?? 0,
        sector: FinanceSector.service,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertFinancialSnapshot(Map<String, dynamic> data) =>
      _ds.upsertFinancialSnapshot(data);

  // ═══════════════════════════════════════════════════════════════
  // SUPPLIERS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Supplier>> getSuppliers(String code) => _ds.getSuppliers(code);

  Future<Supplier> upsertSupplier(Supplier s) => _ds.upsertSupplier(s);

  Future<Supplier> updateSupplierStatus(String id, String status) =>
      _ds.updateSupplier(id, {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> deleteSupplier(String id) => _ds.deleteSupplier(id);

  // ═══════════════════════════════════════════════════════════════
  // RISKS
  // ═══════════════════════════════════════════════════════════════

  Future<List<RiskItem>> getRisks(String code) => _ds.getRisks(code);

  Future<RiskItem> upsertRisk(RiskItem r) => _ds.upsertRisk(r);

  Future<void> deleteRisk(String id) => _ds.deleteRisk(id);

  // ═══════════════════════════════════════════════════════════════
  // COMPLIANCE
  // ═══════════════════════════════════════════════════════════════

  Future<List<ComplianceItem>> getCompliance(String code) =>
      _ds.getCompliance(code);

  Future<ComplianceItem> upsertCompliance(ComplianceItem c) =>
      _ds.upsertCompliance(c);

  // ═══════════════════════════════════════════════════════════════
  // ROADMAP
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRoadmap(String code) =>
      _ds.getRoadmap(code);

  Future<Map<String, dynamic>> upsertRoadmapStep(Map<String, dynamic> step) =>
      _ds.upsertRoadmapStep(step);

  Future<void> updateRoadmapStatus(String id, String status) =>
      _ds.updateRoadmapStatus(id, status);

  Future<void> deleteRoadmapStep(String id) => _ds.deleteRoadmapStep(id);
}
