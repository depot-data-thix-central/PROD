// ============================================================
// lib/presentation/chat/escalation/widgets/status_indicator.dart
// ============================================================

import 'package:flutter/material.dart';
import '../models/escalation_status.dart';

class StatusIndicator extends StatelessWidget {
  final EscalationStatus status;

  const StatusIndicator({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status.icon,
          color: status.color,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: TextStyle(
            color: status.color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
