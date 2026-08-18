// ============================================================
// lib/presentation/chat/escalation/models/escalation_priority.dart
// ============================================================
import 'package:flutter/material.dart';
enum EscalationPriority {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case EscalationPriority.low:
        return 'Basse';
      case EscalationPriority.medium:
        return 'Moyenne';
      case EscalationPriority.high:
        return 'Haute';
      case EscalationPriority.critical:
        return 'Critique';
    }
  }

  Color get color {
    switch (this) {
      case EscalationPriority.low:
        return Colors.blue;
      case EscalationPriority.medium:
        return Colors.green;
      case EscalationPriority.high:
        return Colors.orange;
      case EscalationPriority.critical:
        return Colors.red;
    }
  }

  int get weight {
    switch (this) {
      case EscalationPriority.low:
        return 1;
      case EscalationPriority.medium:
        return 2;
      case EscalationPriority.high:
        return 3;
      case EscalationPriority.critical:
        return 4;
    }
  }
}
