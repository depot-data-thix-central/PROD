import 'package:flutter/foundation.dart';

@immutable
class ExecutionGoal {
  const ExecutionGoal({
    required this.id,
    required this.projectCode,
    required this.title,
    required this.type,
    required this.current,
    required this.target,
    this.unit = 'users',
    this.deadline,
    this.kpiType,
    this.status = 'active',
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String title; // Ex: Acquisition Clients
  final String type; // okr, kpi
  final double current;
  final double target;
  final String unit; // utilisateurs, unités, $, %
  final DateTime? deadline;
  final String? kpiType; // MRR, CAC, Churn, CA, Marge, Stock...
  final String status;
  final DateTime? createdAt;

  double get progress => target == 0 ? 0 : (current / target * 100).clamp(0, 100).toDouble();
  bool get isAtRisk => deadline != null && DateTime.now().isAfter(deadline!.subtract(const Duration(days: 7))) && progress < 80;

  factory ExecutionGoal.fromJson(Map<String,dynamic> j) => ExecutionGoal(
    id: j['id'].toString(),
    projectCode: j['project_code'].toString(),
    title: j['title'].toString(),
    type: j['type']?.toString() ?? 'okr',
    current: (j['current'] as num?)?.toDouble() ?? 0,
    target: (j['target'] as num?)?.toDouble() ?? 0,
    unit: j['unit']?.toString() ?? 'users',
    deadline: j['deadline'] != null ? DateTime.tryParse(j['deadline'].toString()) : null,
    kpiType: j['kpi_type'] as String?,
    status: j['status']?.toString() ?? 'active',
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
  );

  Map<String,dynamic> toJson() => {
    'project_code': projectCode,
    'title': title,
    'type': type,
    'current': current,
    'target': target,
    'unit': unit,
    'deadline': deadline?.toIso8601String(),
    'kpi_type': kpiType,
    'status': status,
  };

  ExecutionGoal increment(double value) => ExecutionGoal(
    id: id, projectCode: projectCode, title: title, type: type,
    current: current + value, target: target, unit: unit, deadline: deadline,
    kpiType: kpiType, status: status, createdAt: createdAt,
  );
}
