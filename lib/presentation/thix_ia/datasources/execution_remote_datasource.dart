import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/execution_project.dart';
import '../models/execution_task.dart';
import '../models/execution_goal.dart';
import '../models/execution_finance.dart';
import '../models/execution_support.dart';
import '../core/errors/thix_ia_execution_errors.dart';
import '../core/constants/thix_ia_execution_constants.dart';

class ExecutionRemoteDatasource {
  ExecutionRemoteDatasource(this._supabase);
  final SupabaseClient _supabase;

  // PROJECT HEALTH
  Future<ExecutionProject?> getExecutionProject(String projectCode) async {
    try {
      final row = await _supabase.from('thix_execution_projects').select().eq('project_code', projectCode).maybeSingle();
      if(row == null) return null;
      return ExecutionProject.fromJson(row);
    } catch(e){ throw ExecutionDataSourceException('getExecutionProject failed', cause: e); }
  }

  Future<ExecutionProject> upsertExecutionProject(ExecutionProject p) async {
    final res = await _supabase.from('thix_execution_projects').upsert(p.toJson(), onConflict: 'project_code').select().single();
    return ExecutionProject.fromJson(res);
  }

  // TASKS - PAGINATED FOR MILLIONS
  Future<List<ExecutionTask>> getTasks(String projectCode, {int limit=100, int offset=0, String? status}) async {
    var q = _supabase.from(ThixExecutionTables.tasks).select().eq('project_code', projectCode).order('created_at', ascending: false).range(offset, offset+limit-1);
    if(status != null) q = _supabase.from(ThixExecutionTables.tasks).select().eq('project_code', projectCode).eq('status', status).order('created_at', ascending: false).range(offset, offset+limit-1);
    final rows = await q;
    return (rows as List).map((e)=> ExecutionTask.fromJson(e)).toList();
  }

  Future<ExecutionTask> createTask(ExecutionTask task) async {
    final res = await _supabase.from(ThixExecutionTables.tasks).insert(task.toJson()).select().single();
    await _supabase.from('audit_logs').insert({'action':'create_task','entity_type':'task','entity_id':res['id'],'project_code':task.projectCode,'payload':task.toJson()});
    return ExecutionTask.fromJson(res);
  }

  Future<ExecutionTask> updateTask(String id, Map<String,dynamic> patch) async {
    final res = await _supabase.from(ThixExecutionTables.tasks).update({...patch,'updated_at':DateTime.now().toIso8601String()}).eq('id', id).select().single();
    return ExecutionTask.fromJson(res);
  }

  // GOALS / OKR
  Future<List<ExecutionGoal>> getGoals(String projectCode) async {
    final rows = await _supabase.from(ThixExecutionTables.goals).select().eq('project_code', projectCode).order('created_at');
    return (rows as List).map((e)=> ExecutionGoal.fromJson(e)).toList();
  }

  Future<ExecutionGoal> upsertGoal(ExecutionGoal g) async {
    final res = await _supabase.from(ThixExecutionTables.goals).upsert(g.toJson(), onConflict: 'id').select().single();
    return ExecutionGoal.fromJson(res);
  }

  // FINANCE
  Future<List<FinanceTransaction>> getTransactions(String projectCode, {int limit=200}) async {
    final rows = await _supabase.from(ThixExecutionTables.finances).select().eq('project_code', projectCode).order('date', ascending: false).limit(limit);
    return (rows as List).map((e)=> FinanceTransaction.fromJson(e)).toList();
  }

  Future<FinanceTransaction> addTransaction(FinanceTransaction tx) async {
    final res = await _supabase.from(ThixExecutionTables.finances).insert(tx.toJson()).select().single();
    return FinanceTransaction.fromJson(res);
  }

  Future<FinancialSnapshot> getFinancialSnapshot(String projectCode) async {
    final row = await _supabase.from('thix_execution_snapshots').select().eq('project_code', projectCode).order('created_at', ascending: false).limit(1).maybeSingle();
    if(row == null) throw ProjectNotFoundFailure(projectCode);
    return FinancialSnapshot.fromJson(row);
  }

  // SUPPLIERS, RISKS, COMPLIANCE
  Future<List<Supplier>> getSuppliers(String projectCode) async {
    final rows = await _supabase.from(ThixExecutionTables.suppliers).select().eq('project_code', projectCode);
    return (rows as List).map((e)=> Supplier.fromJson(e)).toList();
  }
  Future<List<RiskItem>> getRisks(String projectCode) async {
    final rows = await _supabase.from(ThixExecutionTables.risks).select().eq('project_code', projectCode).order('created_at');
    return (rows as List).map((e)=> RiskItem.fromJson(e)).toList();
  }
  Future<List<ComplianceItem>> getCompliance(String projectCode) async {
    final rows = await _supabase.from('thix_execution_compliance').select().eq('project_code', projectCode);
    return (rows as List).map((e)=> ComplianceItem.fromJson(e)).toList();
  }

  // ROADMAP
  Future<List<Map<String,dynamic>>> getRoadmap(String projectCode) async {
    final rows = await _supabase.from(ThixExecutionTables.roadmap).select().eq('project_code', projectCode).order('order_index');
    return List<Map<String,dynamic>>.from(rows as List);
  }

  // REALTIME STREAM
  Stream<List<ExecutionTask>> watchTasks(String projectCode) {
    return _supabase.from(ThixExecutionTables.tasks).stream(primaryKey: ['id']).eq('project_code', projectCode).order('created_at').map((rows)=> rows.map((e)=> ExecutionTask.fromJson(e)).toList());
  }
}
