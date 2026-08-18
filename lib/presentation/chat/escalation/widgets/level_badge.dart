// ============================================================
// lib/presentation/chat/escalation/widgets/level_badge.dart
// ============================================================

import 'package:flutter/material.dart';
import '../models/escalation_level.dart';

class LevelBadge extends StatelessWidget {
  final EscalationLevel level;
  final bool showLabel;
  final double size;

  const LevelBadge({
    Key? key,
    required this.level,
    this.showLabel = true,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level.icon,
            color: level.color,
            size: size * 0.7,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              level.shortLabel,
              style: TextStyle(
                color: level.color,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
