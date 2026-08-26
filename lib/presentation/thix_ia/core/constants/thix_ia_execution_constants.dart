class ThixExecutionTables {
  static const projects = 'thix_projects';
  static const goals = 'thix_execution_goals';
  static const tasks = 'thix_execution_tasks';
  static const roadmap = 'thix_execution_roadmap';
  static const finances = 'thix_execution_finances';
  static const risks = 'thix_execution_risks';
  static const suppliers = 'thix_execution_suppliers';
  static const experiments = 'thix_execution_experiments';
  static const kpiSnapshots = 'thix_execution_kpi_snapshots';
}

class ThixExecutionStatus {
  static const todo = 'todo';
  static const doing = 'doing';
  static const review = 'review';
  static const done = 'done';
  static const blocked = 'blocked';
  static const all = [todo, doing, review, done, blocked];
}

class ThixTaskPriority { static const low='low'; static const medium='medium'; static const high='high'; static const critical='critical'; }
class ThixTaskCategory { static const legal='Légal'; static const finance='Finance'; static const rh='RH'; static const tech='Tech'; static const marketing='Marketing'; static const ops='Ops'; }
class ThixGoalType { static const okr='okr'; static const kpi='kpi'; }
class ThixFinanceType { static const income='income'; static const expense='expense'; static const capital='capital'; }
class ThixRiskLevel { static const low=1; static const medium=2; static const high=3; static const critical=4; }

class ThixExecutionConstants {
  static const defaultCurrency = 'USD';
  static const healthWeights = {'market':0.2,'product':0.2,'finance':0.2,'legal':0.15,'commercial':0.1,'execution':0.15};
}
