// lib/presentation/thix_ia/core/extensions/project_extensions.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../utils/project_code_generator.dart';

/// ============================================================================
/// PROJECT EXTENSIONS - Helpers métier sans dépendre des models
/// ============================================================================

extension ProjectStatusX on String {
  bool get isDraft => toLowerCase() == 'draft';
  bool get isActive => toLowerCase() == 'active';
  bool get isAnalyzing => toLowerCase() == 'analyzing';
  bool get isArchived => toLowerCase() == 'archived';
  bool get isPaused => toLowerCase() == 'paused';

  bool get isInProgress => isActive || isAnalyzing;

  Color get statusColor {
    switch (toLowerCase()) {
      case 'active':
        return ThixPolicy.success;
      case 'analyzing':
        return ThixPolicy.info;
      case 'draft':
        return ThixPolicy.textMuted;
      case 'paused':
        return ThixPolicy.warning;
      case 'archived':
        return ThixPolicy.textDisabled;
      default:
        return ThixPolicy.textSecondary;
    }
  }

  IconData get statusIcon {
    switch (toLowerCase()) {
      case 'active':
        return Icons.play_circle_fill_rounded;
      case 'analyzing':
        return Icons.autorenew_rounded;
      case 'draft':
        return Icons.edit_note_rounded;
      case 'paused':
        return Icons.pause_circle_filled_rounded;
      case 'archived':
        return Icons.archive_rounded;
      default:
        return Icons.circle;
    }
  }
}

extension ProjectCodeX on String {
  bool get isValidProjectCode => ProjectCodeGenerator.isValid(this);
  String get shortProjectCode => ProjectCodeGenerator.shortCode(this);

  /// THX-BIZ-2026-000127 -> 2026
  int? get projectYear => ProjectCodeGenerator.parse(this)?.year;
}

extension DateTimeThixX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year}';
  }
}
