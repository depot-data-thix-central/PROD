// ============================================================
// lib/presentation/chat/escalation/widgets/timeline_widget.dart
// ============================================================

import 'package:flutter/material.dart';
import '../models/escalation_step.dart';

class TimelineWidget extends StatelessWidget {
  final List<EscalationStep> steps;

  const TimelineWidget({Key? key, required this.steps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        return _buildTimelineItem(step, index == steps.length - 1);
      },
    );
  }

  Widget _buildTimelineItem(EscalationStep step, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne verticale avec point
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.status.color,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  step.status.icon,
                  color: Colors.white,
                  size: 10,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.fromLevel.label} → ${step.toLevel.label}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(step.reason),
                if (step.comment != null)
                  Text(
                    step.comment!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                Text(
                  step.createdAt.toString().substring(0, 16),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
