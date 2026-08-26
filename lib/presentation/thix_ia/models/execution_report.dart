// lib/presentation/thix_ia/models/execution_report.dart
import 'package:flutter/foundation.dart';

@immutable
class ExecutionReport {
  const ExecutionReport({
    required this.id,
    required this.projectCode,
    required this.period,
    required this.title,
    required this.progressPercent,
    this.results = const {},
    this.problems = const [],
    this.risksSummary,
    this.financeSummary,
    this.goalsSummary,
    this.suppliersSummary,
    this.recommendations = const [],
    this.healthScore,
    this.lateTasks = 0,
    this.tasksDone = 0,
    this.tasksTotal = 0,
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String period;
  final String title;
  final int progressPercent;
  final Map<String, dynamic> results;
  final List<String> problems;
  final String? risksSummary;
  final String? financeSummary;
  final String? goalsSummary;
  final String? suppliersSummary;
  final List<String> recommendations;
  final int? healthScore;
  final int lateTasks;
  final int tasksDone;
  final int tasksTotal;
  final DateTime? createdAt;

  factory ExecutionReport.fromJson(Map<String, dynamic> j) => ExecutionReport(
        id: j['id']?.toString() ?? '',
        projectCode: j['project_code']?.toString() ?? '',
        period: j['period']?.toString() ?? 'weekly',
        title: j['title']?.toString() ?? 'Rapport',
        progressPercent: (j['progress_percent'] as num?)?.toInt() ?? 0,
        results: Map<String, dynamic>.from(j['results'] as Map? ?? {}),
        problems: List<String>.from((j['problems'] as List?) ?? []),
        risksSummary: j['risks_summary']?.toString(),
        financeSummary: j['finance_summary']?.toString(),
        goalsSummary: j['goals_summary']?.toString(),
        suppliersSummary: j['suppliers_summary']?.toString(),
        recommendations:
            List<String>.from((j['recommendations'] as List?) ?? []),
        healthScore: (j['health_score'] as num?)?.toInt(),
        lateTasks: (j['late_tasks'] as num?)?.toInt() ?? 0,
        tasksDone: (j['tasks_done'] as num?)?.toInt() ?? 0,
        tasksTotal: (j['tasks_total'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'period': period,
        'title': title,
        'progress_percent': progressPercent,
        'results': results,
        'problems': problems,
        'risks_summary': risksSummary,
        'finance_summary': financeSummary,
        'goals_summary': goalsSummary,
        'suppliers_summary': suppliersSummary,
        'recommendations': recommendations,
        'health_score': healthScore,
        'late_tasks': lateTasks,
        'tasks_done': tasksDone,
        'tasks_total': tasksTotal,
      };
}
