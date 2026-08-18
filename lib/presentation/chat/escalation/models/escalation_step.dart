import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'escalation_level.dart';
import 'escalation_status.dart';
import 'escalation_priority.dart';

class EscalationStep extends Equatable {
  final String id;
  final String conversationId;
  final EscalationLevel fromLevel;
  final EscalationLevel toLevel;
  final String fromAgentId;
  final String? fromAgentName;
  final String toAgentId;
  final String? toAgentName;
  final String reason;
  final EscalationPriority priority;
  final EscalationStatus status;
  final String? comment;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const EscalationStep({
    required this.id,
    required this.conversationId,
    required this.fromLevel,
    required this.toLevel,
    required this.fromAgentId,
    this.fromAgentName,
    required this.toAgentId,
    this.toAgentName,
    required this.reason,
    required this.priority,
    required this.status,
    this.comment,
    required this.createdAt,
    this.resolvedAt,
  });

  factory EscalationStep.fromJson(Map<String, dynamic> json) {
    return EscalationStep(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      fromLevel: _parseLevel(json['from_level']),
      toLevel: _parseLevel(json['to_level']),
      fromAgentId: json['from_agent_id'] ?? '',
      fromAgentName: json['from_agent_name'],
      toAgentId: json['to_agent_id'] ?? '',
      toAgentName: json['to_agent_name'],
      reason: json['reason'] ?? '',
      priority: _parsePriority(json['priority']),
      status: _parseStatus(json['status']),
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'from_level': fromLevel.index,
      'to_level': toLevel.index,
      'from_agent_id': fromAgentId,
      'from_agent_name': fromAgentName,
      'to_agent_id': toAgentId,
      'to_agent_name': toAgentName,
      'reason': reason,
      'priority': priority.index,
      'status': status.index,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  static EscalationLevel _parseLevel(dynamic value) {
    if (value is int) {
      return EscalationLevel.values[value];
    }
    if (value is String) {
      return EscalationLevel.values[int.parse(value)];
    }
    return EscalationLevel.agent;
  }

  static EscalationPriority _parsePriority(dynamic value) {
    if (value is int) {
      return EscalationPriority.values[value];
    }
    if (value is String) {
      return EscalationPriority.values[int.parse(value)];
    }
    return EscalationPriority.medium;
  }

  static EscalationStatus _parseStatus(dynamic value) {
    if (value is int) {
      return EscalationStatus.values[value];
    }
    if (value is String) {
      return EscalationStatus.values[int.parse(value)];
    }
    return EscalationStatus.pending;
  }

  EscalationStep copyWith({
    String? id,
    String? conversationId,
    EscalationLevel? fromLevel,
    EscalationLevel? toLevel,
    String? fromAgentId,
    String? fromAgentName,
    String? toAgentId,
    String? toAgentName,
    String? reason,
    EscalationPriority? priority,
    EscalationStatus? status,
    String? comment,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return EscalationStep(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      fromLevel: fromLevel ?? this.fromLevel,
      toLevel: toLevel ?? this.toLevel,
      fromAgentId: fromAgentId ?? this.fromAgentId,
      fromAgentName: fromAgentName ?? this.fromAgentName,
      toAgentId: toAgentId ?? this.toAgentId,
      toAgentName: toAgentName ?? this.toAgentName,
      reason: reason ?? this.reason,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        fromLevel,
        toLevel,
        fromAgentId,
        toAgentId,
        reason,
        priority,
        status,
        createdAt,
        resolvedAt,
      ];
}
