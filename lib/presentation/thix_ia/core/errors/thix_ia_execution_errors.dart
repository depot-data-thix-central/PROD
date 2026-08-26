abstract class ThixExecutionFailure implements Exception {
  final String message; final String? code;
  ThixExecutionFailure(this.message, {this.code});
}

class ProjectNotFoundFailure extends ThixExecutionFailure {
  ProjectNotFoundFailure(String projectCode) : super('Projet $projectCode introuvable', code: 'PROJECT_404');
}
class TaskCreationFailure extends ThixExecutionFailure {
  TaskCreationFailure(String reason) : super(reason, code: 'TASK_CREATE_FAIL');
}
class FinanceCalculationFailure extends ThixExecutionFailure {
  FinanceCalculationFailure(String reason) : super(reason, code: 'FINANCE_CALC_FAIL');
}
class UnauthorizedProjectAccess extends ThixExecutionFailure {
  UnauthorizedProjectAccess() : super('Accès non autorisé à ce projet', code: 'FORBIDDEN');
}
class ExecutionDataSourceException implements Exception {
  final String message; final dynamic cause;
  ExecutionDataSourceException(this.message, {this.cause});
}
