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

  Future<ExecutionProject> getOrCreateHealth(String projectCode) async {
    var existing = await _ds.getExecutionProject(projectCode);
    if(existing != null) return existing;
    final init = ExecutionProject(
      id: projectCode, projectCode: projectCode, healthScore: 0,
      healthDimensions: {'market':0,'product':0,'finance':0,'legal':0,'commercial':0,'execution':0},
      treasury: 0, burnRate: 0, runwayMonths: 0, mrr: 0,
    );
    return _ds.upsertExecutionProject(init);
  }

  // 👇 LA CORRECTION EST ICI : On expose la méthode proprement pour le Service !
  Future<ExecutionProject> upsertExecutionProject(ExecutionProject project) => _ds.upsertExecutionProject(project);

  Future<List<ExecutionTask>> getTasks(String code, {int limit=100, int offset=0, String? status}) => _ds.getTasks(code, limit: limit, offset: offset, status: status);
  Future<ExecutionTask> createTask(ExecutionTask t) => _ds.createTask(t);
  Future<ExecutionTask> completeTask(String id) => _ds.updateTask(id, {'status':'done','progress':100,'completed_at':DateTime.now().toIso8601String()});
  Future<ExecutionTask> updateTaskStatus(String id, String status) => _ds.updateTask(id, {'status':status});

  Future<List<ExecutionGoal>> getGoals(String code) => _ds.getGoals(code);
  Future<ExecutionGoal> upsertGoal(ExecutionGoal g) => _ds.upsertGoal(g);

  Future<List<FinanceTransaction>> getTransactions(String code) => _ds.getTransactions(code);
  Future<FinanceTransaction> addTransaction(FinanceTransaction tx) => _ds.addTransaction(tx);

  Future<FinancialSnapshot> getFinanceSnapshot(String code) => _ds.getFinancialSnapshot(code);
  Future<List<Supplier>> getSuppliers(String code) => _ds.getSuppliers(code);
  Future<List<RiskItem>> getRisks(String code) => _ds.getRisks(code);
  Future<List<ComplianceItem>> getCompliance(String code) => _ds.getCompliance(code);
  Future<List<Map<String,dynamic>>> getRoadmap(String code) => _ds.getRoadmap(code);

  Stream<List<ExecutionTask>> watchTasks(String code) => _ds.watchTasks(code);

  // AUTO-KANBAN IA
  Future<List<ExecutionTask>> generateAutoTasks({required String projectCode, required String objective}) async {
    final templates = [
      {'title':'Finaliser le produit','category':'Tech','priority':'high'},
      {'title':'Vérifier la conformité $objective','category':'Légal','priority':'high'},
      {'title':'Préparer les contrats','category':'Légal','priority':'medium'},
      {'title':'Identifier 50 prospects','category':'Marketing','priority':'high'},
      {'title':'Préparer la campagne','category':'Marketing','priority':'medium'},
      {'title':'Tester l\'offre','category':'Ops','priority':'high'},
      {'title':'Collecter les retours','category':'Ops','priority':'medium'},
      {'title':'Corriger le produit','category':'Tech','priority':'medium'},
      {'title':'Lancer','category':'Marketing','priority':'critical'},
    ];
    List<ExecutionTask> created = [];
    for(var t in templates) {
      final task = ExecutionTask(
        id: ExecutionUtils.generateTaskId(projectCode), projectCode: projectCode,
        title: t['title']!, category: t['category']!, priority: t['priority']!,
        status: 'todo', isAiSuggested: true, origin: 'ai', progress: 0,
      );
      created.add(await _ds.createTask(task));
    }
    return created;
  }
}
