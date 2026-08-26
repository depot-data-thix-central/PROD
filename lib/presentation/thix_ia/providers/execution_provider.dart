// lib/presentation/thix_ia/providers/execution_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/execution_project.dart';
// Note: Le repository sera créé dans les prochains fichiers, on anticipe son import
import '../repositories/execution_repository.dart'; 

/// Provider global pour accéder au contrôleur d'exécution d'un projet spécifique
final executionProvider = StateNotifierProvider.family<ExecutionNotifier, AsyncValue<ExecutionProject>, String>((ref, projectCode) {
  final repository = ref.watch(executionRepositoryProvider);
  return ExecutionNotifier(repository, projectCode);
});

class ExecutionNotifier extends StateNotifier<AsyncValue<ExecutionProject>> {
  final ExecutionRepository _repository;
  final String _projectCode;

  ExecutionNotifier(this._repository, this._projectCode) : super(const AsyncValue.loading()) {
    _loadProjectData();
  }

  /// Charge les données depuis la base de données (Supabase/API)
  Future<void> _loadProjectData() async {
    try {
      state = const AsyncValue.loading();
      final project = await _repository.getExecutionProject(_projectCode);
      state = AsyncValue.data(project);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Rafraîchissement manuel
  Future<void> refresh() async {
    await _loadProjectData();
  }

  /// ==========================================================================
  /// ACTIONS D'EXÉCUTION (Met à jour le State visuel ET la Base de Données)
  /// ==========================================================================

  Future<void> addTransaction({required double amount, required bool isExpense, required String category}) async {
    final currentState = state.value;
    if (currentState == null) return;

    final newTransaction = ExecutionTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ID temporaire
      amount: amount,
      isExpense: isExpense,
      category: category,
      date: DateTime.now(),
    );

    // 1. Mise à jour optimiste de l'UI (instantané)
    state = AsyncValue.data(currentState.copyWith(
      transactions: [...currentState.transactions, newTransaction],
    ));

    try {
      // 2. Sauvegarde en base de données
      await _repository.addTransaction(_projectCode, newTransaction);
    } catch (e) {
      // En cas d'erreur, on annule et on recharge les vraies données
      _loadProjectData(); 
      throw Exception('Erreur lors de l\'ajout de la transaction : $e');
    }
  }

  Future<void> toggleTaskStatus(String taskId) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Trouve la tâche et inverse son statut
    final updatedTasks = currentState.tasks.map((t) {
      if (t.id == taskId) return t.copyWith(isDone: !t.isDone);
      return t;
    }).toList();

    // 1. Mise à jour optimiste de l'UI
    state = AsyncValue.data(currentState.copyWith(tasks: updatedTasks));

    try {
      // 2. Sauvegarde en base de données
      final taskToUpdate = updatedTasks.firstWhere((t) => t.id == taskId);
      await _repository.updateTaskStatus(_projectCode, taskId, taskToUpdate.isDone);
    } catch (e) {
      _loadProjectData();
      throw Exception('Erreur lors de la mise à jour de la tâche');
    }
  }

  Future<void> addTask({required String title, required String category}) async {
    final currentState = state.value;
    if (currentState == null) return;

    final newTask = ExecutionTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      isAiGenerated: false, // Tâche manuelle
      createdAt: DateTime.now(),
    );

    state = AsyncValue.data(currentState.copyWith(tasks: [...currentState.tasks, newTask]));

    try {
      await _repository.addTask(_projectCode, newTask);
    } catch (e) {
      _loadProjectData();
      throw Exception('Erreur lors de la création de la tâche');
    }
  }
}
