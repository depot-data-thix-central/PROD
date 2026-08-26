// lib/presentation/thix_ia/models/execution_project.dart
import 'package:equatable/equatable.dart';

/// ============================================================================
/// 1. ENTITÉ PRINCIPALE : EXECUTION PROJECT
/// ============================================================================
class ExecutionProject extends Equatable {
  final String id;
  final String projectCode;
  final double initialCapital;
  final List<ExecutionTransaction> transactions;
  final List<ExecutionTask> tasks;
  final List<ExecutionObjective> objectives;
  final List<ExecutionSupplier> suppliers;
  final List<ExecutionMilestone> roadmap;
  final DateTime lastUpdated;

  const ExecutionProject({
    required this.id,
    required this.projectCode,
    required this.initialCapital,
    this.transactions = const [],
    this.tasks = const [],
    this.objectives = const [],
    this.suppliers = const [],
    this.roadmap = const [],
    required this.lastUpdated,
  });

  // --- MOTEUR FINANCIER INTÉGRÉ (Calculs automatiques) ---
  
  double get currentTreasury {
    return initialCapital + transactions.fold(0.0, (sum, t) => sum + (t.isExpense ? -t.amount : t.amount));
  }

  double get monthlyBurnRate {
    final now = DateTime.now();
    // Filtre les dépenses du mois en cours
    final monthlyExpenses = transactions.where((t) => t.isExpense && t.date.month == now.month && t.date.year == now.year);
    return monthlyExpenses.fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyMRR {
    final now = DateTime.now();
    // Filtre les revenus récurrents/générés ce mois-ci
    final monthlyIncome = transactions.where((t) => !t.isExpense && t.date.month == now.month && t.date.year == now.year);
    return monthlyIncome.fold(0.0, (sum, t) => sum + t.amount);
  }

  int get runwayMonths {
    final burn = monthlyBurnRate;
    if (burn <= 0) return 999; // Runway infini si pas de dépenses
    return (currentTreasury / burn).floor();
  }

  ExecutionProject copyWith({
    double? initialCapital,
    List<ExecutionTransaction>? transactions,
    List<ExecutionTask>? tasks,
    List<ExecutionObjective>? objectives,
    List<ExecutionSupplier>? suppliers,
    List<ExecutionMilestone>? roadmap,
    DateTime? lastUpdated,
  }) {
    return ExecutionProject(
      id: id,
      projectCode: projectCode,
      initialCapital: initialCapital ?? this.initialCapital,
      transactions: transactions ?? this.transactions,
      tasks: tasks ?? this.tasks,
      objectives: objectives ?? this.objectives,
      suppliers: suppliers ?? this.suppliers,
      roadmap: roadmap ?? this.roadmap,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [id, projectCode, initialCapital, transactions, tasks, objectives, suppliers, roadmap, lastUpdated];
}

/// ============================================================================
/// 2. SOUS-ENTITÉS
/// ============================================================================

class ExecutionTransaction extends Equatable {
  final String id;
  final double amount;
  final bool isExpense;
  final String category;
  final DateTime date;

  const ExecutionTransaction({required this.id, required this.amount, required this.isExpense, required this.category, required this.date});
  
  @override
  List<Object?> get props => [id, amount, isExpense, category, date];
}

class ExecutionTask extends Equatable {
  final String id;
  final String title;
  final String category;
  final bool isAiGenerated;
  final bool isDone;
  final DateTime createdAt;

  const ExecutionTask({required this.id, required this.title, required this.category, this.isAiGenerated = false, this.isDone = false, required this.createdAt});

  ExecutionTask copyWith({bool? isDone}) => ExecutionTask(id: id, title: title, category: category, isAiGenerated: isAiGenerated, isDone: isDone ?? this.isDone, createdAt: createdAt);
  
  @override
  List<Object?> get props => [id, title, category, isAiGenerated, isDone];
}

class ExecutionObjective extends Equatable {
  final String id;
  final String title;
  final double current;
  final double target;
  final String unit;

  const ExecutionObjective({required this.id, required this.title, required this.current, required this.target, required this.unit});
  
  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  ExecutionObjective copyWith({double? current}) => ExecutionObjective(id: id, title: title, current: current ?? this.current, target: target, unit: unit);

  @override
  List<Object?> get props => [id, title, current, target, unit];
}

class ExecutionSupplier extends Equatable {
  final String id;
  final String name;
  final String category;
  final String status; // 'Validé', 'Négociation', 'Recherche'

  const ExecutionSupplier({required this.id, required this.name, required this.category, required this.status});
  
  @override
  List<Object?> get props => [id, name, category, status];
}

class ExecutionMilestone extends Equatable {
  final String id;
  final String title;
  final String dateLabel; // ex: 'Mois 1'
  final bool isCompleted;
  final bool isCurrent;

  const ExecutionMilestone({required this.id, required this.title, required this.dateLabel, this.isCompleted = false, this.isCurrent = false});
  
  @override
  List<Object?> get props => [id, title, dateLabel, isCompleted, isCurrent];
}
