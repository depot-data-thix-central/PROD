// lib/presentation/thix_ia/pages/execution_dashboard.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';

/// ============================================================================
/// 1. MODÈLES DE DONNÉES (POUR LE SAAS ULTRA-RICHE)
/// ============================================================================

class ExecutionTask {
  final String id;
  final String title;
  final String category;
  final Color color;
  final bool isAiGenerated;
  final bool isDone;

  ExecutionTask({required this.id, required this.title, required this.category, required this.color, this.isAiGenerated = false, this.isDone = false});
  ExecutionTask copyWith({bool? isDone}) => ExecutionTask(id: id, title: title, category: category, color: color, isAiGenerated: isAiGenerated, isDone: isDone ?? this.isDone);
}

class Transaction {
  final double amount;
  final bool isExpense;
  final DateTime date;
  Transaction({required this.amount, required this.isExpense, required this.date});
}

// NOUVEAU : Objectifs Stratégiques (OKRs)
class Objective {
  final String title;
  final double current;
  final double target;
  final String unit;
  final Color color;
  Objective({required this.title, required this.current, required this.target, required this.unit, required this.color});
  double get progress => (current / target).clamp(0.0, 1.0);
}

// NOUVEAU : Fournisseurs / Partenaires
class Supplier {
  final String name;
  final String category;
  final String status; // ex: 'Recherche', 'Négociation', 'Validé'
  Supplier({required this.name, required this.category, required this.status});
}

// NOUVEAU : Jalons (Roadmap)
class Milestone {
  final String title;
  final String date;
  final bool isCompleted;
  final bool isCurrent;
  Milestone({required this.title, required this.date, required this.isCompleted, this.isCurrent = false});
}

/// ============================================================================
/// 2. GESTIONNAIRE D'ÉTAT (LE CERVEAU / LOGIQUE)
/// ============================================================================

class ExecutionState {
  final double initialCapital;
  final List<Transaction> transactions;
  final List<ExecutionTask> tasks;
  final List<Objective> objectives;
  final List<Supplier> suppliers;
  final List<Milestone> roadmap;

  ExecutionState({
    required this.initialCapital,
    required this.transactions,
    required this.tasks,
    required this.objectives,
    required this.suppliers,
    required this.roadmap,
  });

  double get currentTreasury {
    double total = initialCapital;
    for (var t in transactions) {
      total += t.isExpense ? -t.amount : t.amount;
    }
    return total;
  }

  double get monthlyBurnRate => transactions.where((t) => t.isExpense).fold(0.0, (sum, item) => sum + item.amount);
  double get monthlyMRR => transactions.where((t) => !t.isExpense).fold(0.0, (sum, item) => sum + item.amount);
  int get runwayMonths => monthlyBurnRate == 0 ? 99 : (currentTreasury / monthlyBurnRate).floor();

  ExecutionState copyWith({
    double? initialCapital,
    List<Transaction>? transactions,
    List<ExecutionTask>? tasks,
  }) {
    return ExecutionState(
      initialCapital: initialCapital ?? this.initialCapital,
      transactions: transactions ?? this.transactions,
      tasks: tasks ?? this.tasks,
      objectives: objectives,
      suppliers: suppliers,
      roadmap: roadmap,
    );
  }
}

final executionProvider = StateNotifierProvider.family<ExecutionNotifier, ExecutionState, String>((ref, projectCode) {
  return ExecutionNotifier();
});

class ExecutionNotifier extends StateNotifier<ExecutionState> {
  ExecutionNotifier()
      : super(ExecutionState(
          initialCapital: 45000.0, 
          transactions: [],
          tasks: [
            ExecutionTask(id: '1', title: 'Valider les statuts juridiques', category: 'Légal', color: Colors.red.shade400, isAiGenerated: true),
            ExecutionTask(id: '2', title: 'Payer l\'acompte des machines', category: 'Finance', color: Colors.green.shade400, isAiGenerated: true),
            ExecutionTask(id: '3', title: 'Lancer le recrutement équipe', category: 'RH', color: Colors.purple.shade400, isAiGenerated: false),
          ],
          // Données simulées ultra-riches pour la démo
          objectives: [
            Objective(title: 'Acquisition Clients', current: 120, target: 500, unit: 'utilisateurs', color: Colors.blue),
            Objective(title: 'Production Initiale', current: 2500, target: 10000, unit: 'unités', color: Colors.orange),
          ],
          suppliers: [
            Supplier(name: 'TechMachinery GmbH', category: 'Équipement', status: 'Validé'),
            Supplier(name: 'EcoPack Africa', category: 'Emballages', status: 'Négociation'),
            Supplier(name: 'Global Logistics', category: 'Transport', status: 'Recherche'),
          ],
          roadmap: [
            Milestone(title: 'Business Plan Validé', date: 'Mois 1', isCompleted: true),
            Milestone(title: 'Création Juridique & RCCM', date: 'Mois 2', isCompleted: true),
            Milestone(title: 'Achat & Importation Équipements', date: 'Mois 3', isCompleted: false, isCurrent: true),
            Milestone(title: 'Lancement de la Production', date: 'Mois 4', isCompleted: false),
          ],
        ));

  void addTransaction(double amount, bool isExpense) {
    state = state.copyWith(transactions: [...state.transactions, Transaction(amount: amount, isExpense: isExpense, date: DateTime.now())]);
  }

  void addTask(String title, String category, Color color) {
    state = state.copyWith(tasks: [...state.tasks, ExecutionTask(id: DateTime.now().toString(), title: title, category: category, color: color)]);
  }

  void toggleTask(String taskId) {
    state = state.copyWith(tasks: state.tasks.map((t) => t.id == taskId ? t.copyWith(isDone: !t.isDone) : t).toList());
  }
}

/// ============================================================================
/// 3. INTERFACE UTILISATEUR (DASHBOARD SAAS)
/// ============================================================================

class ExecutionDashboard extends ConsumerWidget {
  const ExecutionDashboard({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(executionProvider(projectCode));
    final notifier = ref.read(executionProvider(projectCode).notifier);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50.withOpacity(0.4), Colors.purple.shade50.withOpacity(0.4), Colors.white],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          // --- 1. FINANCIAL ENGINE ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle(title: 'Financial Engine', subtitle: 'Trésorerie & Burn Rate'),
              IconButton.filledTonal(icon: const Icon(Icons.add_rounded), color: ThixPolicy.primary, onPressed: () => _showAddTransactionModal(context, notifier)),
            ],
          ),
          const SizedBox(height: 16),
          _MainFinancialCard(state: state),
          const SizedBox(height: 16),
          _QuickStatsRow(state: state),
          
          const SizedBox(height: 32),

          // --- 2. OBJECTIFS (OKRs) ---
          const _SectionTitle(title: 'Objectifs Stratégiques', subtitle: 'Suivi des KPIs (OKRs)'),
          const SizedBox(height: 16),
          _ObjectivesList(objectives: state.objectives),

          const SizedBox(height: 32),

          // --- 3. PLANIFICATION (ROADMAP) ---
          const _SectionTitle(title: 'Planification', subtitle: 'Roadmap de lancement'),
          const SizedBox(height: 16),
          _RoadmapTimeline(roadmap: state.roadmap),

          const SizedBox(height: 32),

          // --- 4. GESTION DES FOURNISSEURS ---
          const _SectionTitle(title: 'Fournisseurs & Partenaires', subtitle: 'État des négociations'),
          const SizedBox(height: 16),
          _SuppliersList(suppliers: state.suppliers),

          const SizedBox(height: 32),
          
          // --- 5. AUTO-KANBAN ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle(title: 'Auto-Kanban', subtitle: 'Tâches générées par l\'IA'),
              IconButton.filledTonal(icon: const Icon(Icons.add_task_rounded), color: ThixPolicy.primary, onPressed: () => _showAddTaskModal(context, notifier)),
            ],
          ),
          const SizedBox(height: 16),
          _KanbanPreviewList(state: state, onToggle: notifier.toggleTask),
        ],
      ),
    );
  }

  // --- Modales d'interactions (inchangées) ---
  void _showAddTransactionModal(BuildContext context, ExecutionNotifier notifier) {
    final amountCtrl = TextEditingController();
    bool isExpense = true;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nouvelle Transaction', style: ThixPolicy.h3Style),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('Dépense (-)')), ButtonSegment(value: false, label: Text('Revenu (+)'))],
                selected: {isExpense}, onSelectionChanged: (val) => setModalState(() => isExpense = val.first),
              ),
              const SizedBox(height: 16),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Montant (\$)', prefixIcon: const Icon(Icons.attach_money), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                  onPressed: () {
                    final val = double.tryParse(amountCtrl.text);
                    if (val != null && val > 0) { notifier.addTransaction(val, isExpense); Navigator.pop(ctx); }
                  },
                  child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskModal(BuildContext context, ExecutionNotifier notifier) {
    final titleCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nouvelle Tâche', style: ThixPolicy.h3Style),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Titre de la tâche', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) { notifier.addTask(titleCtrl.text, 'Manuel', ThixPolicy.primary); Navigator.pop(ctx); }
                },
                child: const Text('Ajouter au Kanban', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NOUVEAUX COMPOSANTS (OBJECTIFS, ROADMAP, FOURNISSEURS)
// ============================================================================

class _ObjectivesList extends StatelessWidget {
  const _ObjectivesList({required this.objectives});
  final List<Objective> objectives;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: objectives.map((obj) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LuminousGlassCard(
          shadowColor: obj.color.withOpacity(0.1),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 18, color: obj.color),
                      const SizedBox(width: 8),
                      Text(obj.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  Text('${(obj.progress * 100).toInt()}%', style: TextStyle(color: obj.color, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: obj.progress,
                  minHeight: 8,
                  backgroundColor: obj.color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(obj.color),
                ),
              ),
              const SizedBox(height: 8),
              Text('${obj.current.toInt()} / ${obj.target.toInt()} ${obj.unit}', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _RoadmapTimeline extends StatelessWidget {
  const _RoadmapTimeline({required this.roadmap});
  final List<Milestone> roadmap;

  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      shadowColor: Colors.blueGrey.withOpacity(0.1),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(roadmap.length, (index) {
          final m = roadmap[index];
          final isLast = index == roadmap.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: m.isCompleted ? ThixPolicy.success : (m.isCurrent ? ThixPolicy.primary : Colors.grey.shade200),
                        shape: BoxShape.circle,
                        border: m.isCurrent ? Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 4) : null,
                      ),
                      child: m.isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                    if (!isLast) Expanded(child: Container(width: 2, color: m.isCompleted ? ThixPolicy.success : Colors.grey.shade200)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.date, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(m.title, style: TextStyle(fontSize: 15, fontWeight: m.isCurrent ? FontWeight.w800 : FontWeight.w600, color: m.isCompleted ? Colors.grey.shade600 : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SuppliersList extends StatelessWidget {
  const _SuppliersList({required this.suppliers});
  final List<Supplier> suppliers;

  Color _getStatusColor(String status) {
    if (status == 'Validé') return ThixPolicy.success;
    if (status == 'Négociation') return Colors.orange;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: suppliers.map((sup) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LuminousGlassCard(
          shadowColor: Colors.black.withOpacity(0.03),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.domain_rounded, color: ThixPolicy.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(sup.category, style: ThixPolicy.microStyle),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _getStatusColor(sup.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(sup.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(sup.status))),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ============================================================================
// ANCIENS COMPOSANTS (KANBAN & FINANCIAL)
// ============================================================================

class _MainFinancialCard extends StatelessWidget {
  const _MainFinancialCard({required this.state});
  final ExecutionState state;
  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      shadowColor: ThixPolicy.primary.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: ThixPolicy.primary),
                    const SizedBox(width: 6),
                    Text('Trésorerie actuelle', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 20),
          Text('\$ ${state.currentTreasury.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _MetricItem(icon: Icons.local_fire_department_rounded, iconColor: Colors.orange, title: 'Burn Rate', value: '\$ ${state.monthlyBurnRate.toStringAsFixed(0)}/mo')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _MetricItem(icon: Icons.flight_takeoff_rounded, iconColor: Colors.green, title: 'Runway', value: state.runwayMonths > 50 ? 'Infini' : '${state.runwayMonths} Mois')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.state});
  final ExecutionState state;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LuminousGlassCard(
            padding: const EdgeInsets.all(16), shadowColor: Colors.purple.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.pie_chart_rounded, color: Colors.purple.shade400, size: 24),
                const SizedBox(height: 12),
                Text('Budget utilisé', style: ThixPolicy.captionStyle),
                const SizedBox(height: 4),
                Text('\$ ${state.monthlyBurnRate.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _LuminousGlassCard(
            padding: const EdgeInsets.all(16), shadowColor: Colors.blue.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.trending_up_rounded, color: Colors.blue.shade400, size: 24),
                const SizedBox(height: 12),
                Text('Revenus (MRR)', style: ThixPolicy.captionStyle),
                const SizedBox(height: 4),
                Text('\$ ${state.monthlyMRR.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KanbanPreviewList extends StatelessWidget {
  const _KanbanPreviewList({required this.state, required this.onToggle});
  final ExecutionState state;
  final Function(String) onToggle;
  @override
  Widget build(BuildContext context) {
    if (state.tasks.isEmpty) return const Center(child: Text('Aucune tâche. Ajoutez-en une !'));
    return Column(children: state.tasks.map((task) => _TaskCard(task: task, onTap: () => onToggle(task.id))).toList());
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});
  final ExecutionTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: _LuminousGlassCard(
          padding: const EdgeInsets.all(16), shadowColor: Colors.black.withOpacity(0.02),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: task.isDone ? ThixPolicy.primary : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: task.isDone ? ThixPolicy.primary : Colors.grey.shade300, width: 2)),
                child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, decoration: task.isDone ? TextDecoration.lineThrough : null, color: task.isDone ? Colors.grey : Colors.black87)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: task.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(task.category, style: TextStyle(color: task.color, fontSize: 10, fontWeight: FontWeight.bold))),
                        if (task.isAiGenerated) ...[const SizedBox(width: 8), const Icon(Icons.auto_awesome, size: 12, color: ThixPolicy.primary), const SizedBox(width: 4), Text('Suggéré par l\'IA', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary))]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS DE BASE (THE CORE)
// ============================================================================

class _LuminousGlassCard extends StatelessWidget {
  const _LuminousGlassCard({required this.child, required this.shadowColor, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 40, spreadRadius: 2, offset: const Offset(0, 16)), BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(padding: padding, decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), border: Border.all(color: Colors.white, width: 1.5)), child: child),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.icon, required this.iconColor, required this.title, required this.value});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: ThixPolicy.captionStyle), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 18)), Text(subtitle, style: ThixPolicy.captionStyle)]);
  }
}
