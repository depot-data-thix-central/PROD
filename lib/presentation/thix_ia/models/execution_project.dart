import 'package:flutter/foundation.dart';

@immutable
class ExecutionProject {
  const ExecutionProject({
    required this.id,
    required this.projectCode,
    required this.healthScore,
    required this.healthDimensions,
    this.currentPriorityTitle,
    this.currentPriorityReason,
    this.currentPriorityAction,
    required this.treasury,
    required this.burnRate,
    required this.runwayMonths,
    required this.mrr,
    this.updatedAt,
  });

  final String id;
  final String projectCode;
  final int healthScore; // 0-100
  final Map<String, double> healthDimensions; // market, product, finance, legal, commercial, execution
  final String? currentPriorityTitle;
  final String? currentPriorityReason;
  final String? currentPriorityAction;
  final double treasury;
  final double burnRate;
  final double runwayMonths;
  final double mrr;
  final DateTime? updatedAt;

  factory ExecutionProject.fromJson(Map<String,dynamic> json) {
    return ExecutionProject(
      id: json['id'].toString(),
      projectCode: json['project_code'].toString(),
      healthScore: (json['health_score'] as num?)?.toInt() ?? 0,
      healthDimensions: Map<String,double>.from((json['health_dimensions'] as Map? ?? {}).map((k,v)=> MapEntry(k.toString(), (v as num).toDouble()))),
      currentPriorityTitle: json['current_priority_title'] as String?,
      currentPriorityReason: json['current_priority_reason'] as String?,
      currentPriorityAction: json['current_priority_action'] as String?,
      treasury: (json['treasury'] as num?)?.toDouble() ?? 0,
      burnRate: (json['burn_rate'] as num?)?.toDouble() ?? 0,
      runwayMonths: (json['runway_months'] as num?)?.toDouble() ?? 0,
      mrr: (json['mrr'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String,dynamic> toJson() => {
    'project_code': projectCode,
    'health_score': healthScore,
    'health_dimensions': healthDimensions,
    'current_priority_title': currentPriorityTitle,
    'current_priority_reason': currentPriorityReason,
    'current_priority_action': currentPriorityAction,
    'treasury': treasury,
    'burn_rate': burnRate,
    'runway_months': runwayMonths,
    'mrr': mrr,
    'updated_at': DateTime.now().toIso8601String(),
  };

  ExecutionProject copyWith({int? healthScore, Map<String,double>? healthDimensions, double? treasury, double? burnRate, double? runwayMonths, double? mrr, String? currentPriorityTitle, String? currentPriorityReason}) {
    return ExecutionProject(
      id: id, projectCode: projectCode,
      healthScore: healthScore ?? this.healthScore,
      healthDimensions: healthDimensions ?? this.healthDimensions,
      currentPriorityTitle: currentPriorityTitle ?? this.currentPriorityTitle,
      currentPriorityReason: currentPriorityReason ?? this.currentPriorityReason,
      currentPriorityAction: currentPriorityAction,
      treasury: treasury ?? this.treasury,
      burnRate: burnRate ?? this.burnRate,
      runwayMonths: runwayMonths ?? this.runwayMonths,
      mrr: mrr ?? this.mrr,
      updatedAt: DateTime.now(),
    );
  }
}
