// ============================================================
// lib/presentation/chat/escalation/models/escalation_rule.dart
// ============================================================

import 'package:equatable/equatable.dart';

class EscalationRule extends Equatable {
  final String id;
  final String name;
  final Map<String, dynamic> condition;
  final Map<String, dynamic> action;
  final bool isActive;
  final DateTime createdAt;

  const EscalationRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.action,
    this.isActive = true,
    required this.createdAt,
  });

  factory EscalationRule.fromJson(Map<String, dynamic> json) {
    return EscalationRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      condition: Map<String, dynamic>.from(json['condition'] ?? {}),
      action: Map<String, dynamic>.from(json['action'] ?? {}),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'condition': condition,
      'action': action,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, condition, action, isActive, createdAt];
}
