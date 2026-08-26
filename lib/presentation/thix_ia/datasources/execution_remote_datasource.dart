// lib/presentation/thix_ia/datasources/execution_remote_datasource.dart
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

  // ═══════════════════════════════════════════════════════════════
  // ENSURE PROJECT EXISTS
  // ═══════════════════════════════════════════════════════════════

  Future<void> ensureProjectExists(
    String projectCode, {
    String? name,
    String? sector,
  }) async {
    final existing = await _supabase
        .from('thix_projects')
        .select('project_code')
        .eq('project_code', projectCode)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('thix_projects').upsert({
        'project_code': projectCode,
        'name': name ?? 'Projet $projectCode',
        'sector': sector ?? 'General',
        'country': 'RDC',
        'status': 'active',
        'progress': 0.1,
        'analyses_count': 0,
        'documents_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'project_code');
    }

    final execExists = await _supabase
        .from('thix_execution_projects')
        .select('project_code')
        .eq('project_code', projectCode)
        .maybeSingle();

    if (execExists == null) {
      await _supabase.from('thix_execution_projects').upsert({
        'project_code': projectCode,
        'health_score': 0,
        'treasury': 0,
        'burn_rate': 0,
        'runway_months': 0,
        'mrr': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'project_code');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PROJECT HEALTH
  // ═══════════════════════════════════════════════════════════════

  Future<ExecutionProject?> getExecutionProject(String projectCode) async {
    try {
      final row = await _supabase
          .from('thix_execution_projects')
          .select()
          .eq('project_code', projectCode)
          .maybeSingle();
      if (row == null) return null;
      return ExecutionProject.fromJson(row);
    } catch (e) {
      throw ExecutionDataSourceException('getExecutionProject failed',
          cause: e);
    }
  }

  Future<ExecutionProject> upsertExecutionProject(ExecutionProject p) async {
    await ensureProjectExists(p.projectCode);
    final res = await _supabase
        .from('thix_execution_projects')
        .upsert(p.toJson(), onConflict: 'project_code')
        .select()
        .single();
    return ExecutionProject.fromJson(res);
  }

  // ═══════════════════════════════════════════════════════════════
  // TASKS
  // ═══════════════════════════════════════════════════════════════

  Future<List<ExecutionTask>> getTasks(
    String projectCode, {
    int limit = 100,
    int offset = 0,
    String? status,
  }) async {
    var query = _supabase
        .from(ThixExecutionTables.tasks)
        .select()
        .eq('project_code', projectCode);

    if (status != null) {
      query = query.eq('status', status);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List).map((e) => ExecutionTask.fromJson(e)).toList();
  }

  Future<ExecutionTask> createTask(ExecutionTask task) async {
    await ensureProjectExists(task.projectCode);
    final res = await _supabase
        .from(ThixExecutionTables.tasks)
        .insert(task.toJson())
        .select()
        .single();

    try {
      await _supabase.from('audit_logs').insert({
        'action': 'create_task',
        'entity_type': 'task',
        'entity_id': res['id'],
        'project_code': task.projectCode,
        'payload': task.toJson(),
      });
    } catch (_) {
      // audit optionnel
    }

    return ExecutionTask.fromJson(res);
  }

  Future<ExecutionTask> updateTask(String id, Map<String, dynamic> patch) async {
    final res = await _supabase
        .from(ThixExecutionTables.tasks)
        .update({...patch, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return ExecutionTask.fromJson(res);
  }

  Future<ExecutionTask> updateTaskStatus(String id, String status) async {
    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'done') {
      patch['progress'] = 100;
      patch['completed_at'] = DateTime.now().toIso8601String();
    } else if (status == 'doing') {
      patch['progress'] = 50;
      patch['completed_at'] = null;
    } else {
      patch['progress'] = 0;
      patch['completed_at'] = null;
    }
    return updateTask(id, patch);
  }

  Future<ExecutionTask> completeTask(String id) async {
    return updateTaskStatus(id, 'done');
  }

  Future<void> deleteTask(String id) async {
    await _supabase.from(ThixExecutionTables.tasks).delete().eq('id', id);
  }

  Stream<List<ExecutionTask>> watchTasks(String projectCode) {
    return _supabase
        .from(ThixExecutionTables.tasks)
        .stream(primaryKey: ['id'])
        .eq('project_code', projectCode)
        .order('created_at')
        .map((rows) => rows.map((e) => ExecutionTask.fromJson(e)).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  // GOALS / OKR
  // ═══════════════════════════════════════════════════════════════

  Future<List<ExecutionGoal>> getGoals(String projectCode) async {
    final rows = await _supabase
        .from(ThixExecutionTables.goals)
        .select()
        .eq('project_code', projectCode)
        .order('created_at');
    return (rows as List).map((e) => ExecutionGoal.fromJson(e)).toList();
  }

  Future<ExecutionGoal> upsertGoal(ExecutionGoal g) async {
    await ensureProjectExists(g.projectCode);
    final payload = g.toJson();
    if (g.id.isNotEmpty) {
      final res = await _supabase
          .from(ThixExecutionTables.goals)
          .update(payload)
          .eq('id', g.id)
          .select()
          .single();
      return ExecutionGoal.fromJson(res);
    }
    final res = await _supabase
        .from(ThixExecutionTables.goals)
        .insert(payload)
        .select()
        .single();
    return ExecutionGoal.fromJson(res);
  }

  Future<void> deleteGoal(String id) async {
    await _supabase.from(ThixExecutionTables.goals).delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  // FINANCE
  // ═══════════════════════════════════════════════════════════════

  Future<List<FinanceTransaction>> getTransactions(
    String projectCode, {
    int limit = 200,
  }) async {
    final rows = await _supabase
        .from(ThixExecutionTables.finances)
        .select()
        .eq('project_code', projectCode)
        .order('date', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => FinanceTransaction.fromJson(e))
        .toList();
  }

  Future<FinanceTransaction> addTransaction(FinanceTransaction tx) async {
    await ensureProjectExists(tx.projectCode);
    final res = await _supabase
        .from(ThixExecutionTables.finances)
        .insert(tx.toJson())
        .select()
        .single();
    return FinanceTransaction.fromJson(res);
  }

  Future<void> deleteTransaction(String id) async {
    await _supabase.from(ThixExecutionTables.finances).delete().eq('id', id);
  }

  Future<FinancialSnapshot?> getFinancialSnapshot(String projectCode) async {
    final row = await _supabase
        .from('thix_execution_snapshots')
        .select()
        .eq('project_code', projectCode)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return FinancialSnapshot.fromJson(row);
  }

  /// Snapshot calculé depuis transactions + projet (fallback si pas de row)
  Future<FinancialSnapshot> getFinanceSnapshotComputed(
      String projectCode) async {
    final project = await getExecutionProject(projectCode);
    final txs = await getTransactions(projectCode);

    double treasury = project?.treasury ?? 0;
    double burn = project?.burnRate ?? 0;
    double runway = project?.runwayMonths ?? 0;
    double mrr = project?.mrr ?? 0;

    double income = 0, expense = 0, capital = 0;
    for (final t in txs) {
      switch (t.type) {
        case FinanceTransactionType.income:
          income += t.amount;
          break;
        case FinanceTransactionType.expense:
          expense += t.amount;
          break;
        case FinanceTransactionType.capital:
          capital += t.amount;
          break;
      }
    }

    if (txs.isNotEmpty && treasury == 0) {
      treasury = capital + income - expense;
    }

    final now = DateTime.now();
    final last30Exp = txs.where((t) {
      if (t.type != FinanceTransactionType.expense || t.date == null) {
        return false;
      }
      return now.difference(t.date!).inDays <= 30;
    }).fold<double>(0, (s, t) => s + t.amount);

    final last30Inc = txs.where((t) {
      if (t.type != FinanceTransactionType.income || t.date == null) {
        return false;
      }
      return now.difference(t.date!).inDays <= 30;
    }).fold<double>(0, (s, t) => s + t.amount);

    if (burn == 0 && last30Exp > 0) burn = last30Exp;
    if (mrr == 0 && last30Inc > 0) mrr = last30Inc;
    if (burn > 0 && runway == 0) runway = treasury / burn;

    // Snapshot DB si existe
    final snap = await getFinancialSnapshot(projectCode);
    if (snap != null) {
      return FinancialSnapshot(
        projectCode: projectCode,
        treasury: treasury != 0 ? treasury : snap.treasury,
        burnRate: burn != 0 ? burn : snap.burnRate,
        runwayMonths: runway != 0 ? runway : snap.runwayMonths,
        mrr: mrr != 0 ? mrr : snap.mrr,
        arr: (mrr != 0 ? mrr : snap.mrr) * 12,
        revenueMonthly:
            last30Inc > 0 ? last30Inc : snap.revenueMonthly,
        expensesMonthly:
            last30Exp > 0 ? last30Exp : snap.expensesMonthly,
        sector: snap.sector,
        cac: snap.cac,
        ltv: snap.ltv,
        churnRate: snap.churnRate,
        grossMargin: snap.grossMargin,
        stockValue: snap.stockValue,
        averageBasket: snap.averageBasket,
      );
    }

    return FinancialSnapshot(
      projectCode: projectCode,
      treasury: treasury,
      burnRate: burn,
      runwayMonths: runway,
      mrr: mrr,
      arr: mrr * 12,
      revenueMonthly: last30Inc,
      expensesMonthly: last30Exp,
      sector: FinanceSector.service,
    );
  }

  Future<void> upsertFinancialSnapshot(Map<String, dynamic> data) async {
    await ensureProjectExists(data['project_code'] as String);
    await _supabase.from('thix_execution_snapshots').upsert({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'project_code');
  }

  // ═══════════════════════════════════════════════════════════════
  // SUPPLIERS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Supplier>> getSuppliers(String projectCode) async {
    final rows = await _supabase
        .from(ThixExecutionTables.suppliers)
        .select()
        .eq('project_code', projectCode)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => Supplier.fromJson(e)).toList();
  }

  Future<Supplier> upsertSupplier(Supplier s) async {
    await ensureProjectExists(s.projectCode);
    final payload = s.toJson();
    if (s.id.isNotEmpty) {
      final res = await _supabase
          .from(ThixExecutionTables.suppliers)
          .update(payload)
          .eq('id', s.id)
          .select()
          .single();
      return Supplier.fromJson(res);
    }
    final res = await _supabase
        .from(ThixExecutionTables.suppliers)
        .insert(payload)
        .select()
        .single();
    return Supplier.fromJson(res);
  }

  Future<Supplier> updateSupplier(String id, Map<String, dynamic> patch) async {
    final res = await _supabase
        .from(ThixExecutionTables.suppliers)
        .update({...patch, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Supplier.fromJson(res);
  }

  Future<void> deleteSupplier(String id) async {
    await _supabase.from(ThixExecutionTables.suppliers).delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  // RISKS
  // ═══════════════════════════════════════════════════════════════

  Future<List<RiskItem>> getRisks(String projectCode) async {
    final rows = await _supabase
        .from(ThixExecutionTables.risks)
        .select()
        .eq('project_code', projectCode)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => RiskItem.fromJson(e)).toList();
  }

  Future<RiskItem> upsertRisk(RiskItem r) async {
    await ensureProjectExists(r.projectCode);
    final payload = r.toJson();
    if (r.id.isNotEmpty) {
      final res = await _supabase
          .from(ThixExecutionTables.risks)
          .update(payload)
          .eq('id', r.id)
          .select()
          .single();
      return RiskItem.fromJson(res);
    }
    final res = await _supabase
        .from(ThixExecutionTables.risks)
        .insert(payload)
        .select()
        .single();
    return RiskItem.fromJson(res);
  }

  Future<void> deleteRisk(String id) async {
    await _supabase.from(ThixExecutionTables.risks).delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPLIANCE
  // ═══════════════════════════════════════════════════════════════

  Future<List<ComplianceItem>> getCompliance(String projectCode) async {
    final rows = await _supabase
        .from('thix_execution_compliance')
        .select()
        .eq('project_code', projectCode);
    return (rows as List).map((e) => ComplianceItem.fromJson(e)).toList();
  }

  Future<ComplianceItem> upsertCompliance(ComplianceItem c) async {
    await ensureProjectExists(c.projectCode);
    final payload = c.toJson();
    if (c.id.isNotEmpty) {
      final res = await _supabase
          .from('thix_execution_compliance')
          .update(payload)
          .eq('id', c.id)
          .select()
          .single();
      return ComplianceItem.fromJson(res);
    }
    final res = await _supabase
        .from('thix_execution_compliance')
        .insert(payload)
        .select()
        .single();
    return ComplianceItem.fromJson(res);
  }

  // ═══════════════════════════════════════════════════════════════
  // ROADMAP
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRoadmap(String projectCode) async {
    final rows = await _supabase
        .from(ThixExecutionTables.roadmap)
        .select()
        .eq('project_code', projectCode)
        .order('order_index');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> upsertRoadmapStep(
      Map<String, dynamic> step) async {
    await ensureProjectExists(step['project_code'] as String);
    final id = step['id']?.toString();
    if (id != null && id.isNotEmpty) {
      final res = await _supabase
          .from(ThixExecutionTables.roadmap)
          .update({
            ...step,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Map<String, dynamic>.from(res);
    }
    final payload = Map<String, dynamic>.from(step)..remove('id');
    final res = await _supabase
        .from(ThixExecutionTables.roadmap)
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(res);
  }

  Future<void> updateRoadmapStatus(String id, String status) async {
    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'done') {
      patch['progress'] = 100;
      patch['completed_at'] = DateTime.now().toIso8601String();
    } else if (status == 'doing') {
      patch['progress'] = 50;
      patch['completed_at'] = null;
    } else {
      patch['progress'] = 0;
      patch['completed_at'] = null;
    }
    await _supabase
        .from(ThixExecutionTables.roadmap)
        .update(patch)
        .eq('id', id);
  }

  Future<void> deleteRoadmapStep(String id) async {
    await _supabase.from(ThixExecutionTables.roadmap).delete().eq('id', id);
  }
}
