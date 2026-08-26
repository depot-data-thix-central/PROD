import '../repositories/execution_repository.dart';
import '../models/execution_project.dart';
import '../core/utils/execution_utils.dart';

class ExecutionService {
  ExecutionService(this._repo);
  final ExecutionRepository _repo;

  Future<ExecutionProject> refreshHealth(String projectCode) async {
    final tasks = await _repo.getTasks(projectCode, limit: 1000);
    final goals = await _repo.getGoals(projectCode);
    final risks = await _repo.getRisks(projectCode);
    final compliance = await _repo.getCompliance(projectCode);
    final transactions = await _repo.getTransactions(projectCode);

    final double doneRate = tasks.isEmpty ? 0.0 : (tasks.where((t)=> t.status=='done').length / tasks.length * 100).toDouble();
    final double goalsRate = goals.isEmpty ? 0.0 : (goals.map((g)=> g.progress).fold(0.0,(a,b)=>a+b) / goals.length).toDouble();
    final double complianceRate = compliance.isEmpty ? 100.0 : (compliance.where((c)=> c.status=='valid').length / compliance.length * 100).toDouble();
    final double riskPenalty = (risks.where((r)=> r.level >= 12).length * 5).toDouble();

    // CORRECTION : Forcer le typage en Map<String, double>
    final Map<String, double> dimensions = {
      'market': goalsRate,
      'product': doneRate,
      'finance': (complianceRate*0.5 + (100 - riskPenalty).clamp(0,100)*0.5).toDouble(),
      'legal': complianceRate,
      'commercial': (goalsRate * 0.8).toDouble(),
      'execution': doneRate,
    };

    final healthScore = ExecutionUtils.calculateHealthScore(dimensions);

    // FINANCE
    double treasury = 45890.5;
    double burn = 2340.0;
    double runway = ExecutionUtils.calculateRunway(treasury: treasury, burnRate: burn);
    try {
      final snapshot = await _repo.getFinanceSnapshot(projectCode);
      treasury = snapshot.treasury; 
      burn = snapshot.burnRate; 
      runway = snapshot.runwayMonths;
    } catch(_){}

    final lateTasks = tasks.where((t)=> t.isLate).toList();
    final atRiskGoals = goals.where((g)=> g.isAtRisk).map((g)=> g.title).toList();
    final nextAction = ExecutionUtils.buildNextBestAction(healthScore: healthScore.toDouble(), tasksLate: lateTasks, goalsAtRisk: atRiskGoals, runway: runway);

    final project = ExecutionProject(
      id: projectCode, projectCode: projectCode, healthScore: healthScore,
      healthDimensions: dimensions, treasury: treasury, burnRate: burn, runwayMonths: runway, mrr: 5670.0,
      currentPriorityTitle: nextAction['title'], currentPriorityReason: nextAction['reason'],
    );

    return _repo.upsertExecutionProject(project);
  }

  Future<Map<String,dynamic>> getDashboard(String projectCode) async {
    final health = await refreshHealth(projectCode);
    final tasks = await _repo.getTasks(projectCode, limit: 50);
    final goals = await _repo.getGoals(projectCode);
    final suppliers = await _repo.getSuppliers(projectCode);
    final roadmap = await _repo.getRoadmap(projectCode);
    return {
      'health': health, 'tasks': tasks, 'goals': goals, 'suppliers': suppliers, 'roadmap': roadmap,
      'lateCount': tasks.where((t)=> t.isLate).length,
      'doneCount': tasks.where((t)=> t.status=='done').length,
    };
  }
}
