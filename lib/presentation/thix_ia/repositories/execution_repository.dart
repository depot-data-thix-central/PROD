// lib/presentation/thix_ia/repositories/execution_repository.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/execution_project.dart';

/// Provider pour injecter le repository partout dans l'app
final executionRepositoryProvider = Provider<ExecutionRepository>((ref) {
  return ExecutionRepository();
});

class ExecutionRepository {
  /// Récupère le projet d'exécution complet depuis la base de données
  Future<ExecutionProject> getExecutionProject(String projectCode) async {
    // ⏳ SIMULATION D'UN APPEL RÉSEAU SUPABASE (1.2 secondes)
    await Future.delayed(const Duration(milliseconds: 1200));

    // Données initiales calquées exactement sur ta maquette "EcoPlastic Pro"
    return ExecutionProject(
      id: 'exec_001',
      projectCode: projectCode,
      initialCapital: 48230.50, // Capital de départ
      lastUpdated: DateTime.now(),
      transactions: [
        // On simule une dépense pour avoir un Burn Rate à 2340$
        ExecutionTransaction(id: 'tx1', amount: 2340.0, isExpense: true, category: 'Opérations', date: DateTime.now()),
        // On simule un revenu pour avoir un MRR à 5670$
        ExecutionTransaction(id: 'tx2', amount: 5670.0, isExpense: false, category: 'Ventes', date: DateTime.now()),
      ],
      tasks: [
        ExecutionTask(id: 't1', title: 'Valider les statuts juridiques', category: 'Légal', isAiGenerated: true, isDone: false, createdAt: DateTime.now()),
        ExecutionTask(id: 't2', title: 'Payer l\'acompte des machines', category: 'Finance', isAiGenerated: true, isDone: true, createdAt: DateTime.now()),
        ExecutionTask(id: 't3', title: 'Lancer le recrutement équipe', category: 'RH', isAiGenerated: false, isDone: false, createdAt: DateTime.now()),
      ],
      objectives: const [
        ExecutionObjective(id: 'o1', title: 'Acquisition Clients', current: 120, target: 500, unit: 'utilisateurs'),
        ExecutionObjective(id: 'o2', title: 'Production Initiale', current: 2500, target: 10000, unit: 'unités'),
      ],
      suppliers: const [
        ExecutionSupplier(id: 's1', name: 'TechMachinery GmbH', category: 'Équipement', status: 'Validé'),
        ExecutionSupplier(id: 's2', name: 'EcoPack Africa', category: 'Emballages', status: 'Négociation'),
        ExecutionSupplier(id: 's3', name: 'Global Logistics', category: 'Transport', status: 'Recherche'),
      ],
      roadmap: const [
        ExecutionMilestone(id: 'm1', title: 'Business Plan Validé', dateLabel: 'Mois 1', isCompleted: true),
        ExecutionMilestone(id: 'm2', title: 'Création Juridique & RCCM', dateLabel: 'Mois 2', isCompleted: true),
        ExecutionMilestone(id: 'm3', title: 'Achat & Importation', dateLabel: 'Mois 3', isCompleted: false, isCurrent: true),
        ExecutionMilestone(id: 'm4', title: 'Lancement Production', dateLabel: 'Mois 4', isCompleted: false),
      ],
    );
  }

  /// Ajoute une transaction financière
  Future<void> addTransaction(String projectCode, ExecutionTransaction transaction) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simule l'écriture en DB
    // TODO: Implémenter Supabase -> await supabase.from('transactions').insert(transaction.toJson());
  }

  /// Met à jour le statut d'une tâche (Cochée/Décochée)
  Future<void> updateTaskStatus(String projectCode, String taskId, bool isDone) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Implémenter Supabase -> await supabase.from('tasks').update({'is_done': isDone}).eq('id', taskId);
  }

  /// Ajoute une nouvelle tâche au Kanban
  Future<void> addTask(String projectCode, ExecutionTask task) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO: Implémenter Supabase -> await supabase.from('tasks').insert(task.toJson());
  }
}
