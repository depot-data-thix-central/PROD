import 'package:flutter/foundation.dart';

@immutable
class ExecutionTask {
  const ExecutionTask({
    required this.id,
    required this.projectCode,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assigneeId,
    this.assigneeName,
    this.startDate,
    this.dueDate,
    this.completedAt,
    this.dependencies = const [],
    this.isAiSuggested = false,
    this.progress = 0,
    this.estimatedHours,
    this.origin = 'manual',
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String title;
  final String? description;
  final String category; // Légal, Finance, RH, Tech, Marketing, Ops
  final String priority; // low, medium, high, critical
  final String status; // todo, doing, review, done, blocked
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final List<String> dependencies;
  final bool isAiSuggested;
  final int progress;
  final double? estimatedHours;
  final String origin; // ai, manual, auto_generated
  final DateTime? createdAt;

  bool get isLate => dueDate != null && status != 'done' && DateTime.now().isAfter(dueDate!);
  bool get isBlocked => status == 'blocked' || dependencies.isNotEmpty;

  factory ExecutionTask.fromJson(Map<String,dynamic> j) => ExecutionTask(
    id: j['id'].toString(),
    projectCode: j['project_code'].toString(),
    title: j['title'].toString(),
    description: j['description'] as String?,
    category: j['category']?.toString() ?? 'Ops',
    priority: j['priority']?.toString() ?? 'medium',
    status: j['status']?.toString() ?? 'todo',
    assigneeId: j['assignee_id']?.toString(),
    assigneeName: j['assignee_name']?.toString(),
    startDate: j['start_date'] != null ? DateTime.tryParse(j['start_date'].toString()) : null,
    dueDate: j['due_date'] != null ? DateTime.tryParse(j['due_date'].toString()) : null,
    completedAt: j['completed_at'] != null ? DateTime.tryParse(j['completed_at'].toString()) : null,
    dependencies: List<String>.from(j['dependencies'] as List? ?? []),
    isAiSuggested: j['is_ai_suggested'] as bool? ?? false,
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    estimatedHours: (j['estimated_hours'] as num?)?.toDouble(),
    origin: j['origin']?.toString() ?? 'manual',
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
  );

  Map<String,dynamic> toJson() => {
    'project_code': projectCode,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'status': status,
    'assignee_id': assigneeId,
    'assignee_name': assigneeName,
    'start_date': startDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'dependencies': dependencies,
    'is_ai_suggested': isAiSuggested,
    'progress': progress,
    'estimated_hours': estimatedHours,
    'origin': origin,
  };

  ExecutionTask copyWith({String? status, int? progress, DateTime? completedAt}) => ExecutionTask(
    id: id, projectCode: projectCode, title: title, description: description, category: category, priority: priority,
    status: status ?? this.status, assigneeId: assigneeId, assigneeName: assigneeName,
    startDate: startDate, dueDate: dueDate, completedAt: completedAt ?? this.completedAt,
    dependencies: dependencies, isAiSuggested: isAiSuggested, progress: progress ?? this.progress,
    estimatedHours: estimatedHours, origin: origin, createdAt: createdAt,
  );
}
