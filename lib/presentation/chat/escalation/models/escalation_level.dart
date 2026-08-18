// ============================================================
// lib/presentation/chat/escalation/models/escalation_level.dart
// ============================================================
import 'package:flutter/material.dart';

enum EscalationLevel {
  agent,      // Niveau 0 (index natif: 0)
  senior,     // Niveau 1 (index natif: 1)
  manager,    // Niveau 2 (index natif: 2)
  director,   // Niveau 3 (index natif: 3)
  technical;  // Niveau 4 (index natif: 4)

  // Le bloc "int get index" a été supprimé car Dart le gère automatiquement !

  String get label {
    switch (this) {
      case EscalationLevel.agent:
        return 'Agent Standard';
      case EscalationLevel.senior:
        return 'Agent Senior';
      case EscalationLevel.manager:
        return 'Manager';
      case EscalationLevel.director:
        return 'Direction';
      case EscalationLevel.technical:
        return 'Service Technique';
    }
  }

  String get shortLabel {
    switch (this) {
      case EscalationLevel.agent:
        return 'L0';
      case EscalationLevel.senior:
        return 'L1';
      case EscalationLevel.manager:
        return 'L2';
      case EscalationLevel.director:
        return 'L3';
      case EscalationLevel.technical:
        return 'L4';
    }
  }

  Color get color {
    switch (this) {
      case EscalationLevel.agent:
        return Colors.blue;
      case EscalationLevel.senior:
        return Colors.green;
      case EscalationLevel.manager:
        return Colors.orange;
      case EscalationLevel.director:
        return Colors.red;
      case EscalationLevel.technical:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case EscalationLevel.agent:
        return Icons.person;
      case EscalationLevel.senior:
        return Icons.star;
      case EscalationLevel.manager:
        return Icons.people;
      case EscalationLevel.director:
        return Icons.business_center;
      case EscalationLevel.technical:
        return Icons.build;
    }
  }

  bool get canEscalateFrom {
    switch (this) {
      case EscalationLevel.agent:
        return true;
      case EscalationLevel.senior:
        return true;
      case EscalationLevel.manager:
        return true;
      case EscalationLevel.director:
        return true;
      case EscalationLevel.technical:
        return false; // Niveau max, pas d'escalade au-dessus
    }
  }

  List<EscalationLevel> get allowedTargets {
    switch (this) {
      case EscalationLevel.agent:
        return [EscalationLevel.senior];
      case EscalationLevel.senior:
        return [EscalationLevel.manager];
      case EscalationLevel.manager:
        return [EscalationLevel.director, EscalationLevel.technical];
      case EscalationLevel.director:
        return [EscalationLevel.technical];
      case EscalationLevel.technical:
        return [];
    }
  }
}
