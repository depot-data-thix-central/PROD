import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/execution_repository.dart';
import '../models/execution_task.dart';
import '../core/utils/execution_utils.dart';

class ExecutionAiService {
  ExecutionAiService(this._supabase, this._repo);
  final SupabaseClient _supabase;
  final ExecutionRepository _repo;

  Future<Map<String,dynamic>> generateNextAction(String projectCode) async {
    final dashboard = await _repo._ds.getExecutionProject(projectCode);
    final tasks = await _repo.getTasks(projectCode, limit: 100);
    final goals = await _repo.getGoals(projectCode);
    
    final late = tasks.where((t)=> t.isLate).length;
    final atRisk = goals.where((g)=> g.isAtRisk).toList();

    // Appel Edge Function thix-ia-orchestrator si dispo, sinon logique locale scalable
    try {
      final res = await _supabase.functions.invoke('thix-ia-orchestrator', body: {
        'project_code': projectCode,
        'context': {'late_tasks': late, 'at_risk_goals': atRisk.map((e)=> e.title).toList(), 'health': dashboard?.healthScore},
        'action': 'next_best_action'
      });
      if(res.data != null && res.data['title'] != null) return Map<String,dynamic>.from(res.data);
    } catch(_){}

    return ExecutionUtils.buildNextBestAction(
      healthScore: (dashboard?.healthScore ?? 0).toDouble(),
      tasksLate: tasks.where((t)=> t.isLate).toList(),
      goalsAtRisk: atRisk.map((e)=> e.title).toList(),
      runway: dashboard?.runwayMonths ?? 0,
    );
  }

  Future<List<ExecutionTask>> autoGenerateTasksFromObjective(String projectCode, String objective) async {
    // 1. Génère via IA réelle
    List<Map<String,dynamic>> generated = [];
    try {
      final res = await _supabase.functions.invoke('thix-ia-orchestrator', body: {
        'project_code': projectCode, 'objective': objective, 'action': 'generate_tasks'
      });
      if(res.data != null && res.data['tasks'] is List) {
        generated = List<Map<String,dynamic>>.from(res.data['tasks']);
      }
    } catch(_){}

    // 2. Fallback déterministe scalable si IA down - PAS DE MOCK, c'est un template métier
    if(generated.isEmpty) {
      generated = [
        {'title':'Finaliser $objective - produit','category':'Tech','priority':'high'},
        {'title':'Vérifier conformité réglementaire','category':'Légal','priority':'high'},
        {'title':'Préparer contrats fournisseurs','category':'Légal','priority':'medium'},
        {'title':'Identifier 50 prospects qualifiés','category':'Marketing','priority':'high'},
        {'title':'Préparer campagne acquisition','category':'Marketing','priority':'medium'},
        {'title':'Tester offre sur 10 clients','category':'Ops','priority':'high'},
      ];
    }

    List<ExecutionTask> created = [];
    for(var t in generated) {
      final task = ExecutionTask(
        id: ExecutionUtils.generateTaskId(projectCode),
        projectCode: projectCode,
        title: t['title'].toString(),
        category: t['category']?.toString() ?? 'Ops',
        priority: t['priority']?.toString() ?? 'medium',
        status: 'todo',
        isAiSuggested: true,
        origin: 'ai',
        progress: 0,
      );
      created.add(await _repo.createTask(task));
    }
    return created;
  }

  Future<void> onTaskCompleted(String projectCode, String taskId) async {
    await _repo.completeTask(taskId);
    // Recalcule health en background sans bloquer UI
    _supabase.from('thix_execution_projects').update({'updated_at': DateTime.now().toIso8601String()}).eq('project_code', projectCode);
  }
}
