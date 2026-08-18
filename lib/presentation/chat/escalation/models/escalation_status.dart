import 'package:flutter/material.dart';

enum EscalationStatus {
  pending,
  accepted,
  rejected,
  timeout,
  resolved,
  canceled;

  String get label {
    switch (this) {
      case EscalationStatus.pending:
        return 'En attente';
      case EscalationStatus.accepted:
        return 'Acceptée';
      case EscalationStatus.rejected:
        return 'Refusée';
      case EscalationStatus.timeout:
        return 'Expirée';
      case EscalationStatus.resolved:
        return 'Résolue';
      case EscalationStatus.canceled:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case EscalationStatus.pending:
        return Colors.orange;
      case EscalationStatus.accepted:
        return Colors.green;
      case EscalationStatus.rejected:
        return Colors.red;
      case EscalationStatus.timeout:
        return Colors.grey;
      case EscalationStatus.resolved:
        return Colors.green.shade700;
      case EscalationStatus.canceled:
        return Colors.grey.shade600;
    }
  }

  IconData get icon {
    switch (this) {
      case EscalationStatus.pending:
        return Icons.hourglass_top;
      case EscalationStatus.accepted:
        return Icons.check_circle;
      case EscalationStatus.rejected:
        return Icons.cancel;
      case EscalationStatus.timeout:
        return Icons.timer_off;
      case EscalationStatus.resolved:
        return Icons.done_all;
      case EscalationStatus.canceled:
        return Icons.block;
    }
  }
}
