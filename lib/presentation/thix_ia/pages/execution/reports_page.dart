// lib/presentation/thix_ia/pages/execution/reports_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/execution_provider.dart';
import '../../core/utils/execution_utils.dart';
import '../../models/execution_report.dart';

final executionReportsProvider =
    FutureProvider.family<List<ExecutionReport>, String>((ref, projectCode) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_execution_reports')
      .select()
      .eq('project_code', projectCode)
      .order('created_at', ascending: false);
  return (rows as List).map((e) => ExecutionReport.fromJson(e)).toList();
});

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final reportsAsync =
        ref.watch(executionReportsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Reporting Auto',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(executionReportsProvider(widget.projectCode)),
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .invalidate(executionReportsProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (reports) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(executionReportsProvider(widget.projectCode));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // CTA génération
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Générer un rapport',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        'Agrège tâches, OKRs, risques, finance et fournisseurs depuis Supabase.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _generating
                                  ? null
                                  : () => _generateReport('weekly'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.indigo),
                              icon: _generating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.auto_awesome, size: 18),
                              label: Text(
                                  _generating
                                      ? 'Génération…'
                                      : 'Rapport hebdo',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _generating
                                  ? null
                                  : () => _generateReport('monthly'),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('Mensuel',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (reports.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.assessment_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucun rapport',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Générez le premier rapport à partir des données live du projet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...reports.map((r) => _ReportCard(
                        report: r,
                        onTap: () => _openDetail(r),
                        onDelete: () => _deleteReport(r),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateReport(String period) async {
    setState(() => _generating = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final code = widget.projectCode;

      // ── 1. Charger toutes les sources (parallèle) ──────────
      final results = await Future.wait([
        client
            .from('thix_execution_tasks')
            .select()
            .eq('project_code', code),
        client
            .from('thix_execution_goals')
            .select()
            .eq('project_code', code),
        client
            .from('thix_execution_risks')
            .select()
            .eq('project_code', code),
        client
            .from('thix_execution_suppliers')
            .select()
            .eq('project_code', code),
        client
            .from('thix_execution_projects')
            .select()
            .eq('project_code', code)
            .maybeSingle(),
        client
            .from('thix_execution_finances')
            .select()
            .eq('project_code', code)
            .order('date', ascending: false)
            .limit(100),
      ]);

      final tasks = List<Map<String, dynamic>>.from(results[0] as List);
      final goals = List<Map<String, dynamic>>.from(results[1] as List);
      final risks = List<Map<String, dynamic>>.from(results[2] as List);
      final suppliers = List<Map<String, dynamic>>.from(results[3] as List);
      final project = results[4] as Map<String, dynamic>?;
      final finances = List<Map<String, dynamic>>.from(results[5] as List);

      // ── 2. Calculs réels ───────────────────────────────────
      final tasksTotal = tasks.length;
      final tasksDone =
          tasks.where((t) => t['status']?.toString() == 'done').length;
      final tasksDoing =
          tasks.where((t) => t['status']?.toString() == 'doing').length;
      final tasksReview =
          tasks.where((t) => t['status']?.toString() == 'review').length;
      final progress =
          tasksTotal == 0 ? 0 : (tasksDone / tasksTotal * 100).round();

      final now = DateTime.now();
      final lateTasks = tasks.where((t) {
        final due = t['due_date'];
        if (due == null || t['status']?.toString() == 'done') return false;
        final d = DateTime.tryParse(due.toString());
        return d != null && d.isBefore(now);
      }).length;

      final openRisks =
          risks.where((r) => r['status']?.toString() != 'closed').toList();
      final criticalRisks = openRisks.where((r) {
        final p = (r['probability'] as num?)?.toInt() ?? 1;
        final i = (r['impact'] as num?)?.toInt() ?? 1;
        return p * i >= 12;
      }).length;

      final goalsProgress = goals.isEmpty
          ? 0.0
          : goals.fold<double>(0, (s, g) {
                final cur = (g['current'] as num?)?.toDouble() ?? 0;
                final tgt = (g['target'] as num?)?.toDouble() ?? 1;
                if (tgt == 0) return s;
                return s + (cur / tgt * 100).clamp(0, 100);
              }) /
              goals.length;

      final validatedSuppliers =
          suppliers.where((s) => s['status']?.toString() == 'Validé').length;
      final negotiatingSuppliers =
          suppliers.where((s) => s['status']?.toString() == 'Négociation').length;

      // Finance réelle
      double treasury = (project?['treasury'] as num?)?.toDouble() ?? 0;
      double burn = (project?['burn_rate'] as num?)?.toDouble() ?? 0;
      double runway = (project?['runway_months'] as num?)?.toDouble() ?? 0;
      double mrr = (project?['mrr'] as num?)?.toDouble() ?? 0;

      if (finances.isNotEmpty && treasury == 0) {
        // Fallback : somme des transactions
        for (final tx in finances) {
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
          final type = tx['type']?.toString() ?? '';
          if (type == 'income' || type == 'capital') {
            treasury += amount;
          } else if (type == 'expense') {
            treasury -= amount;
          }
        }
      }

      final healthScore = (project?['health_score'] as num?)?.toInt();

      // ── 3. Problèmes détectés (règles métier) ─────────────
      final problems = <String>[];
      if (lateTasks > 0) {
        problems.add('$lateTasks tâche(s) en retard');
      }
      if (criticalRisks > 0) {
        problems.add('$criticalRisks risque(s) élevé(s) / critique(s)');
      }
      if (runway > 0 && runway < 3) {
        problems.add(
            'Runway critique : ${runway.toStringAsFixed(1)} mois');
      }
      if (tasksDoing == 0 && tasksTotal > tasksDone) {
        problems.add('Aucune tâche en cours — pipeline bloqué');
      }
      if (goals.isNotEmpty && goalsProgress < 40) {
        problems.add(
            'OKRs en retard (moyenne ${goalsProgress.toStringAsFixed(0)}%)');
      }
      if (negotiatingSuppliers > 0 && validatedSuppliers == 0) {
        problems.add(
            '$negotiatingSuppliers fournisseur(s) en négociation, aucun validé');
      }

      // ── 4. Recommandations dynamiques (pas de mock) ────────
      final recommendations = <String>[];
      if (lateTasks > 0) {
        recommendations
            .add('Prioriser le rattrapage des $lateTasks tâches en retard');
      }
      if (criticalRisks > 0) {
        recommendations.add(
            'Mitiger les $criticalRisks risques critiques (module Risques)');
      }
      if (runway > 0 && runway < 6) {
        recommendations.add(
            'Sécuriser la trésorerie (runway ${runway.toStringAsFixed(1)} mois)');
      }
      if (tasksReview > 0) {
        recommendations
            .add('Valider les $tasksReview tâches en attente de review');
      }
      if (goals.isNotEmpty && goalsProgress < 60) {
        recommendations.add(
            'Relancer les OKRs sous-performants (${goalsProgress.toStringAsFixed(0)}% moyen)');
      }
      if (negotiatingSuppliers > 0) {
        recommendations.add(
            'Clôturer la négociation de $negotiatingSuppliers fournisseur(s)');
      }
      if (progress >= 80 && recommendations.isEmpty) {
        recommendations.add(
            'Maintenir le rythme — $progress% des tâches terminées');
      }
      if (recommendations.isEmpty) {
        recommendations.add(
            'Continuer l’exécution et mettre à jour les OKRs cette semaine');
      }

      // ── 5. Essayer edge function IA (optionnel) ────────────
      try {
        final aiRes = await client.functions.invoke('thix-ia-orchestrator',
            body: {
              'project_code': code,
              'action': 'weekly_report',
              'context': {
                'progress': progress,
                'late_tasks': lateTasks,
                'critical_risks': criticalRisks,
                'runway': runway,
                'goals_progress': goalsProgress,
                'problems': problems,
              },
            });
        if (aiRes.data != null &&
            aiRes.data['recommendations'] is List &&
            (aiRes.data['recommendations'] as List).isNotEmpty) {
          recommendations
            ..clear()
            ..addAll(List<String>.from(aiRes.data['recommendations']));
        }
      } catch (_) {
        // Fallback = recommandations règles métier ci-dessus
      }

      // ── 6. Insert Supabase ─────────────────────────────────
      final periodLabel = period == 'monthly' ? 'Mensuel' : 'Hebdomadaire';
      final title =
          'Rapport $periodLabel \( {now.day.toString().padLeft(2, '0')}/ \){now.month.toString().padLeft(2, '0')}/${now.year}';

      await client.from('thix_execution_reports').insert({
        'project_code': code,
        'period': period,
        'title': title,
        'progress_percent': progress,
        'results': {
          'tasks_done': tasksDone,
          'tasks_total': tasksTotal,
          'tasks_doing': tasksDoing,
          'tasks_review': tasksReview,
          'goals_count': goals.length,
          'goals_progress_avg': goalsProgress.round(),
          'suppliers_total': suppliers.length,
          'suppliers_validated': validatedSuppliers,
          'risks_open': openRisks.length,
          'risks_critical': criticalRisks,
          'treasury': treasury,
          'burn_rate': burn,
          'runway_months': runway,
          'mrr': mrr,
        },
        'problems': problems,
        'risks_summary':
            '${openRisks.length} ouverts · $criticalRisks critiques',
        'finance_summary':
            'Trésorerie ${ExecutionUtils.formatCurrency(treasury)} · Burn ${ExecutionUtils.formatCurrency(burn)}/mo · Runway ${runway.toStringAsFixed(1)} mo',
        'goals_summary':
            '${goals.length} OKRs · moyenne ${goalsProgress.toStringAsFixed(0)}%',
        'suppliers_summary':
            '${suppliers.length} total · $validatedSuppliers validés · $negotiatingSuppliers en négo',
        'recommendations': recommendations,
        'health_score': healthScore,
        'late_tasks': lateTasks,
        'tasks_done': tasksDone,
        'tasks_total': tasksTotal,
      });

      ref.invalidate(executionReportsProvider(widget.projectCode));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rapport généré · $progress% progression'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur génération : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _deleteReport(ExecutionReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${r.title} » ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(supabaseClientProvider)
          .from('thix_execution_reports')
          .delete()
          .eq('id', r.id);
      ref.invalidate(executionReportsProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDetail(ExecutionReport r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportDetailPage(report: r)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD
// ═══════════════════════════════════════════════════════════════

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });
  final ExecutionReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final pct = r.progressPercent;
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$pct%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (r.tasksTotal > 0)
                  _MetaChip(
                      Icons.task_alt, '\( {r.tasksDone}/ \){r.tasksTotal} tâches'),
                if (r.lateTasks > 0)
                  _MetaChip(Icons.schedule, '${r.lateTasks} retard',
                      color: Colors.red),
                if (r.healthScore != null)
                  _MetaChip(Icons.favorite, 'Health ${r.healthScore}%'),
                if (r.period.isNotEmpty)
                  _MetaChip(Icons.date_range, r.period),
              ],
            ),
            if (r.risksSummary != null) ...[
              const SizedBox(height: 8),
              Text(r.risksSummary!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            if (r.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Top reco : ${r.recommendations.first}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (r.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                '\( {r.createdAt!.day}/ \){r.createdAt!.month}/${r.createdAt!.year} \( {r.createdAt!.hour.toString().padLeft(2, '0')}: \){r.createdAt!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DÉTAIL RAPPORT
// ═══════════════════════════════════════════════════════════════

class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key, required this.report});
  final ExecutionReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final res = r.results;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(r.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progression
          _Section(
            title: 'Progression',
            child: Column(
              children: [
                Text('${r.progressPercent}%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: r.progressPercent >= 70
                          ? Colors.green
                          : r.progressPercent >= 40
                              ? Colors.orange
                              : Colors.red,
                    )),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (r.progressPercent / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat('Terminées', '${r.tasksDone}'),
                    _Stat('Total', '${r.tasksTotal}'),
                    _Stat('Retard', '${r.lateTasks}'),
                    if (r.healthScore != null)
                      _Stat('Health', '${r.healthScore}%'),
                  ],
                ),
              ],
            ),
          ),

          // Finance
          if (r.financeSummary != null)
            _Section(
              title: 'Finance',
              child: Text(r.financeSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),

          // Goals
          if (r.goalsSummary != null)
            _Section(
              title: 'Objectifs (OKRs)',
              child: Text(r.goalsSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),

          // Suppliers
          if (r.suppliersSummary != null)
            _Section(
              title: 'Fournisseurs',
              child: Text(r.suppliersSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),

          // Risques
          if (r.risksSummary != null)
            _Section(
              title: 'Risques',
              child: Text(r.risksSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),

          // Problèmes
          if (r.problems.isNotEmpty)
            _Section(
              title: 'Problèmes détectés',
              child: Column(
                children: r.problems
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(p,
                                      style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Recommandations
          _Section(
            title: 'Recommandations',
            child: Column(
              children: r.recommendations
                  .map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 16, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(rec,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Raw metrics
          if (res.isNotEmpty)
            _Section(
              title: 'Métriques brutes',
              child: Column(
                children: res.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
