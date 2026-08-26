import 'package:flutter/foundation.dart';

enum ReportPeriod { weekly, monthly }

@immutable
class ExecutionReport {
  const ExecutionReport({
    required this.id,
    required this.projectCode,
    required this.period,
    required this.title,
    required this.progressPercent,
    required this.results,
    required this.problems,
    required this.risksSummary,
    required this.financeSummary,
    required this.goalsSummary,
    required this.recommendations,
    this.createdAt,
  });
  final String id; final String projectCode; final ReportPeriod period; final String title;
  final int progressPercent; final Map<String,dynamic> results; final List<String> problems;
  final String risksSummary; final String financeSummary; final String goalsSummary;
  final List<String> recommendations; final DateTime? createdAt;

  factory ExecutionReport.fromJson(Map<String,dynamic> j) => ExecutionReport(
    id: j['id'].toString(), projectCode: j['project_code'].toString(),
    period: j['period'] == 'monthly' ? ReportPeriod.monthly : ReportPeriod.weekly,
    title: j['title'].toString(), progressPercent: (j['progress_percent'] as num).toInt(),
    results: Map<String,dynamic>.from(j['results'] as Map? ?? {}),
    problems: List<String>.from(j['problems'] as List? ?? []),
    risksSummary: j['risks_summary']?.toString() ?? '',
    financeSummary: j['finance_summary']?.toString() ?? '',
    goalsSummary: j['goals_summary']?.toString() ?? '',
    recommendations: List<String>.from(j['recommendations'] as List? ?? []),
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
  );
  Map<String,dynamic> toJson() => {
    'project_code': projectCode, 'period': period.name, 'title': title,
    'progress_percent': progressPercent, 'results': results, 'problems': problems,
    'risks_summary': risksSummary, 'finance_summary': financeSummary,
    'goals_summary': goalsSummary, 'recommendations': recommendations,
  };

  static ExecutionReport generateWeekly({required String projectCode, required int progress, required Map<String,dynamic> kpis}) {
    return ExecutionReport(
      id: 'weekly_${DateTime.now().millisecondsSinceEpoch}', projectCode: projectCode, period: ReportPeriod.weekly,
      title: 'Rapport Hebdomadaire ${DateTime.now().day}/${DateTime.now().month}',
      progressPercent: progress, results: kpis, problems: [],
      risksSummary: '${kpis['risks']??0} risques actifs', financeSummary: 'Trésorerie ${kpis['treasury']??0}',
      goalsSummary: '${kpis['goals_done']??0}/${kpis['goals_total']??0} objectifs',
      recommendations: ['Concentrez vos efforts sur acquisition client'],
    );
  }
}
