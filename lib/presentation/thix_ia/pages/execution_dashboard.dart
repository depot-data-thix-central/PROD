// lib/presentation/thix_ia/pages/execution_dashboard.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/execution_project.dart';
import '../providers/execution_provider.dart';

/// ============================================================================
/// DASHBOARD PRINCIPAL (CONNECTÉ À RIVERPOD)
/// ============================================================================

class ExecutionDashboard extends ConsumerWidget {
  const ExecutionDashboard({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🧠 Écoute le StateNotifier qui renvoie un AsyncValue<ExecutionProject>
    final asyncState = ref.watch(executionProvider(projectCode));
    final notifier = ref.read(executionProvider(projectCode).notifier);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50.withOpacity(0.4), Colors.purple.shade50.withOpacity(0.4), Colors.white],
        ),
      ),
      child: asyncState.when(
        // ⏳ ETAT CHARGEMENT
        loading: () => const Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3),
        ),
        // ❌ ETAT ERREUR
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erreur de chargement', style: ThixPolicy.h3Style),
              Text(err.toString(), style: ThixPolicy.bodySmallStyle, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => notifier.refresh(), child: const Text('Réessayer'))
            ],
          ),
        ),
        // ✅ ETAT DONNÉES RÉCUPÉRÉES
        data: (project) {
          return ListView(
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
              _MainFinancialCard(project: project),
              const SizedBox(height: 16),
              _QuickStatsRow(project: project),
              
              const SizedBox(height: 32),

              // --- 2. OBJECTIFS (OKRs) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle(title: 'Objectifs Stratégiques (OKRs)', subtitle: 'Suivi des KPIs clés'),
                  TextButton(onPressed: (){}, child: const Text('Voir tout')),
                ],
              ),
              const SizedBox(height: 16),
              _ObjectivesList(objectives: project.objectives),

              const SizedBox(height: 32),

              // --- 3. PLANIFICATION (ROADMAP) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle(title: 'Roadmap de Lancement', subtitle: 'Jalons du projet'),
                  TextButton(onPressed: (){}, child: const Text('Voir tout')),
                ],
              ),
              const SizedBox(height: 16),
              _RoadmapTimeline(roadmap: project.roadmap),

              const SizedBox(height: 32),

              // --- 4. GESTION DES FOURNISSEURS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle(title: 'Fournisseurs & Partenaires', subtitle: 'État des négociations'),
                  TextButton(onPressed: (){}, child: const Text('Voir tout')),
                ],
              ),
              const SizedBox(height: 16),
              _SuppliersList(suppliers: project.suppliers),

              const SizedBox(height: 32),
              
              // --- 5. AUTO-KANBAN ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle(title: 'Auto-Kanban', subtitle: 'Tâches générées par l\'IA'),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18), 
                    label: const Text('Ajouter tâche'),
                    style: FilledButton.styleFrom(backgroundColor: ThixPolicy.primary.withOpacity(0.1), foregroundColor: ThixPolicy.primary, elevation: 0),
                    onPressed: () => _showAddTaskModal(context, notifier),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _KanbanPreviewList(tasks: project.tasks, onToggle: notifier.toggleTaskStatus),
            ],
          );
        },
      ),
    );
  }

  // --- Modales (UI) ---
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
                    if (val != null && val > 0) { notifier.addTransaction(amount: val, isExpense: isExpense, category: 'Général'); Navigator.pop(ctx); }
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
                  if (titleCtrl.text.isNotEmpty) { notifier.addTask(title: titleCtrl.text, category: 'Opérations'); Navigator.pop(ctx); }
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

/// ============================================================================
/// COMPOSANTS UI INTÉGRÉS (À séparer plus tard dans widgets/execution/)
/// ============================================================================

class _ObjectivesList extends StatelessWidget {
  const _ObjectivesList({required this.objectives});
  final List<ExecutionObjective> objectives;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: objectives.map((obj) => Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          child: _LuminousGlassCard(
            shadowColor: ThixPolicy.primary.withOpacity(0.08),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.flag_rounded, size: 20, color: ThixPolicy.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(obj.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          RichText(
                            text: TextSpan(
                              style: ThixPolicy.captionStyle,
                              children: [
                                TextSpan(text: '${obj.current.toInt()} ', style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.bold)),
                                TextSpan(text: '/ ${obj.target.toInt()} ${obj.unit}'),
                              ]
                            )
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: obj.progress,
                          minHeight: 6,
                          backgroundColor: ThixPolicy.primary.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(ThixPolicy.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${(obj.progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _RoadmapTimeline extends StatelessWidget {
  const _RoadmapTimeline({required this.roadmap});
  final List<ExecutionMilestone> roadmap;

  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      shadowColor: Colors.black.withOpacity(0.04),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(roadmap.length, (index) {
            final m = roadmap[index];
            final isLast = index == roadmap.length - 1;
            return Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: m.isCompleted ? const Color(0xFF10B981) : Colors.white, // Vert succès
                        shape: BoxShape.circle,
                        border: Border.all(color: m.isCompleted ? const Color(0xFF10B981) : (m.isCurrent ? ThixPolicy.primary : Colors.grey.shade300), width: 2),
                      ),
                      child: Center(
                        child: m.isCompleted 
                            ? const Icon(Icons.check, size: 20, color: Colors.white) 
                            : Text('${index + 1}', style: TextStyle(color: m.isCurrent ? ThixPolicy.primary : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 90,
                      child: Column(
                        children: [
                          Text(m.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: m.isCompleted ? Colors.black87 : Colors.grey.shade600), maxLines: 2),
                          const SizedBox(height: 4),
                          Text(m.dateLabel, style: ThixPolicy.microStyle.copyWith(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Container(
                    width: 40, height: 2,
                    margin: const EdgeInsets.only(bottom: 50, left: 8, right: 8),
                    color: m.isCompleted ? const Color(0xFF10B981).withOpacity(0.5) : Colors.grey.shade200,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _SuppliersList extends StatelessWidget {
  const _SuppliersList({required this.suppliers});
  final List<ExecutionSupplier> suppliers;

  Color _getStatusColor(String status) {
    if (status == 'Validé') return const Color(0xFF10B981); // Vert
    if (status == 'Négociation') return Colors.orange;
    return Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      shadowColor: Colors.black.withOpacity(0.02),
      padding: EdgeInsets.zero,
      child: Column(
        children: suppliers.map((sup) => Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.domain_rounded, color: ThixPolicy.textSecondary, size: 20),
            ),
            title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(sup.category, style: ThixPolicy.microStyle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusColor(sup.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _getStatusColor(sup.status).withOpacity(0.2))),
                  child: Text(sup.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(sup.status))),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _MainFinancialCard extends StatelessWidget {
  const _MainFinancialCard({required this.project});
  final ExecutionProject project;

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
          Text('\$ ${project.currentTreasury.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _MetricItem(icon: Icons.local_fire_department_rounded, iconColor: Colors.orange, title: 'Burn Rate', value: '\$ ${project.monthlyBurnRate.toStringAsFixed(0)} /mo')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _MetricItem(icon: Icons.flight_takeoff_rounded, iconColor: Colors.green, title: 'Runway', value: project.runwayMonths > 50 ? 'Infini' : '${project.runwayMonths} Mois')),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _MetricItem(icon: Icons.trending_up_rounded, iconColor: Colors.blue, title: 'MRR', value: '\$ ${project.monthlyMRR.toStringAsFixed(0)} /mo')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.project});
  final ExecutionProject project;
  // TODO: Add more quick stats based on design if needed
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Réservé pour de futures jauges si besoin
  }
}

class _KanbanPreviewList extends StatelessWidget {
  const _KanbanPreviewList({required this.tasks, required this.onToggle});
  final List<ExecutionTask> tasks;
  final Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const Center(child: Text('Aucune tâche.'));
    return _LuminousGlassCard(
      shadowColor: Colors.black.withOpacity(0.02),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ...tasks.map((task) => _TaskCard(task: task, onTap: () => onToggle(task.id))),
          TextButton(
            onPressed: () {}, 
            child: Text('Voir toutes les tâches (${tasks.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});
  final ExecutionTask task;
  final VoidCallback onTap;

  Color _getCategoryColor(String cat) {
    if (cat == 'Légal') return Colors.red.shade400;
    if (cat == 'Finance') return Colors.green.shade400;
    if (cat == 'RH') return Colors.purple.shade400;
    return Colors.blue.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(task.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: task.isDone ? const Color(0xFF10B981) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: task.isDone ? const Color(0xFF10B981) : Colors.grey.shade300, width: 2),
              ),
              child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                task.title, 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, decoration: task.isDone ? TextDecoration.lineThrough : null, color: task.isDone ? Colors.grey : Colors.black87)
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(task.category, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            if (task.isAiGenerated) ...[
              const SizedBox(width: 8),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 4),
                  Text('IA', style: TextStyle(color: Colors.deepPurple.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

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
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(height: 8),
        Text(title, style: ThixPolicy.captionStyle),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
