// ============================================================
// lib/presentation/chat/escalation/widgets/priority_chip.dart
// ============================================================

import 'package:flutter/material.dart';
import '../models/escalation_priority.dart';

class PriorityChip extends StatelessWidget {
  final EscalationPriority priority;

  const PriorityChip({Key? key, required this.priority}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priority.color, width: 1),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: priority.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
