// lib/presentation/thix_ia/services/execution_service.dart
import '../repositories/execution_repository.dart';
import '../models/execution_project.dart';
import '../models/execution_finance.dart';
import '../core/utils/execution_utils.dart';

class ExecutionService {
  ExecutionService(this._repo);
  final ExecutionRepository _repo;

  // ═══════════════════════════════════════════════════════════════
  // HEALTH — recalcul multi-dimensions
  // ═══════════════════════════════════════════════════════════════

  Future<ExecutionProject> refreshHealth(String projectCode) async {
    final results = await Future.wait([
      _repo.getTasks(projectCode, limit: 1000),
      _repo.getGoals(projectCode),
      _repo.getRisks(projectCode),
      _repo.getCompliance(projectCode),
      _repo.getTransactions(projectCode),
      _repo.getSuppliers(projectCode),
      _repo.getRoadmap(projectCode),
    ]);

    final tasks = results[0] as List;
    final goals = results[1] as List;
    final risks = results[2] as List;
    final compliance = results[3] as List;
    final transactions = results[4] as List;
    final suppliers = results[5] as List;
    final roadmap = results[6] as List;

    // ── Tâches ────────────────────────────────────────────────
    final tasksList = tasks.cast<dynamic>();
    final doneCount =
        tasksList.where((t) => t.status == 'done').length;
    final double doneRate = tasksList.isEmpty
        ? 0.0
        : (doneCount / tasksList.length * 100);

    final lateTasks =
        tasksList.where((t) => t.isLate == true).toList();

    // ── OKRs ──────────────────────────────────────────────────
    final goalsList = goals.cast<dynamic>();
    final double goalsRate = goalsList.isEmpty
        ? 0.0
        : goalsList
                .map((g) => (g.progress as num?)?.toDouble() ?? 0.0)
                .fold(0.0, (a, b) => a + b) /
            goalsList.length;

    final atRiskGoals = goalsList
        .where((g) => g.isAtRisk == true)
        .map((g) => g.title?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    // ── Compliance ────────────────────────────────────────────
    final complianceList = compliance.cast<dynamic>();
    final double complianceRate = complianceList.isEmpty
        ? 70.0 // neutre si pas encore de checklist
        : (complianceList.where((c) => c.status == 'valid').length /
                complianceList.length *
                100);

    // ── Risques ───────────────────────────────────────────────
    final risksList = risks.cast<dynamic>();
    final openRisks =
        risksList.where((r) => r.status != 'closed').toList();
    final criticalRisks = openRisks
        .where((r) => (r.isCritical == true) || (r.isHigh == true))
        .length;
    final riskPenalty =
        (criticalRisks * 8 + openRisks.length * 2).toDouble().clamp(0, 60);

    // ── Roadmap ───────────────────────────────────────────────
    final roadmapList = roadmap.cast<dynamic>();
    final roadmapDone = roadmapList
        .where((s) => (s is Map ? s['status'] : null) == 'done')
        .length;
    final double roadmapRate = roadmapList.isEmpty
        ? 0.0
        : (roadmapDone / roadmapList.length * 100);

    // ── Fournisseurs ──────────────────────────────────────────
    final suppliersList = suppliers.cast<dynamic>();
    final validatedSuppliers = suppliersList
        .where((s) =>
            (s is Map ? s['status'] : s.status)?.toString() == 'Validé')
        .length;
    final double supplierRate = suppliersList.isEmpty
        ? 50.0
        : (validatedSuppliers / suppliersList.length * 100);

    // ── Finance (transactions réelles) ────────────────────────
    final finance = ExecutionUtils.computeFinanceFromTransactions(
        transactions.cast());
    final double treasury = (finance['treasury'] as num?)?.toDouble() ?? 0;
    final double burn = (finance['burnRate'] as num?)?.toDouble() ?? 0;
    final double runway =
        (finance['runwayMonths'] as num?)?.toDouble() ?? 0;
    final double mrr = (finance['mrr'] as num?)?.toDouble() ?? 0;

    // Score finance : runway + trésorerie relative
    double financeScore = 50;
    if (runway >= 12) {
      financeScore = 95;
    } else if (runway >= 6) {
      financeScore = 80;
    } else if (runway >= 3) {
      financeScore = 55;
    } else if (runway > 0) {
      financeScore = 25;
    } else if (treasury > 0 && burn == 0) {
      financeScore = 70;
    }

    // ── Dimensions santé ──────────────────────────────────────
    final Map<String, double> dimensions = {
      'market': goalsRate.clamp(0, 100),
      'product': ((doneRate + roadmapRate) / 2).clamp(0, 100),
      'finance': financeScore.clamp(0, 100),
      'legal': complianceRate.clamp(0, 100),
      'commercial':
          ((goalsRate * 0.6) + (supplierRate * 0.4)).clamp(0, 100),
      'execution':
          ((doneRate * 0.7) + ((100 - riskPenalty) * 0.3)).clamp(0, 100),
    };

    final healthScore = ExecutionUtils.calculateHealthScore(dimensions);

    // ── Priorité suivante ─────────────────────────────────────
    final nextAction = ExecutionUtils.buildNextBestAction(
      healthScore: healthScore.toDouble(),
      tasksLate: lateTasks,
      goalsAtRisk: atRiskGoals,
      runway: runway,
    );

    // Enrichir si risques critiques
    String? priorityTitle = nextAction['title']?.toString();
    String? priorityReason = nextAction['reason']?.toString();
    if (criticalRisks > 0 && (priorityTitle == null || priorityTitle.isEmpty)) {
      priorityTitle = 'Mitiger $criticalRisks risque(s) critique(s)';
      priorityReason = 'Des risques élevés menacent l\'exécution';
    } else if (runway > 0 && runway < 3) {
      priorityTitle = 'Sécuriser la trésorerie';
      priorityReason =
          'Runway critique : ${runway.toStringAsFixed(1)} mois';
    }

    final project = ExecutionProject(
      id: projectCode,
      projectCode: projectCode,
      healthScore: healthScore,
      healthDimensions: dimensions,
      treasury: treasury,
      burnRate: burn,
      runwayMonths: runway,
      mrr: mrr,
      currentPriorityTitle: priorityTitle,
      currentPriorityReason: priorityReason,
      currentPriorityAction: nextAction['action']?.toString(),
    );

    return _repo.upsertExecutionProject(project);
  }

  /// Après chaque transaction / changement majeur
  Future<ExecutionProject> recalculateFinance(String projectCode) =>
      refreshHealth(projectCode);

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD AGRÉGÉ
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getDashboard(String projectCode) async {
    final health = await refreshHealth(projectCode);

    final results = await Future.wait([
      _repo.getTasks(projectCode, limit: 100),
      _repo.getGoals(projectCode),
      _repo.getSuppliers(projectCode),
      _repo.getRoadmap(projectCode),
      _repo.getRisks(projectCode),
      _repo.getCompliance(projectCode),
      _repo.getTransactions(projectCode),
    ]);

    final tasks = results[0] as List;
    final goals = results[1] as List;
    final suppliers = results[2] as List;
    final roadmap = results[3] as List;
    final risks = results[4] as List;
    final compliance = results[5] as List;
    final transactions = results[6] as List;

    final tasksList = tasks.cast<dynamic>();
    final risksList = risks.cast<dynamic>();
    final openRisks =
        risksList.where((r) => r.status != 'closed').toList();
    final criticalRisks = openRisks
        .where((r) => (r.isCritical == true) || (r.isHigh == true))
        .length;

    final roadmapDone = roadmap
        .whereType<Map>()
        .where((s) => s['status'] == 'done')
        .length;

    return {
      'health': health,
      'tasks': tasks,
      'goals': goals,
      'suppliers': suppliers,
      'roadmap': roadmap,
      'risks': risks,
      'compliance': compliance,
      'transactions': transactions,
      // KPIs dérivés
      'lateCount': tasksList.where((t) => t.isLate == true).length,
      'doneCount':
          tasksList.where((t) => t.status == 'done').length,
      'tasksTotal': tasksList.length,
      'openRisks': openRisks.length,
      'criticalRisks': criticalRisks,
      'roadmapProgress': roadmap.isEmpty
          ? 0
          : (roadmapDone / roadmap.length * 100).round(),
      'suppliersValidated': suppliers
          .where((s) =>
              (s is Map ? s['status'] : s.status)?.toString() ==
              'Validé')
          .length,
      'treasury': health.treasury,
      'burnRate': health.burnRate,
      'runwayMonths': health.runwayMonths,
      'mrr': health.mrr,
      'healthScore': health.healthScore,
    };
  }
}
