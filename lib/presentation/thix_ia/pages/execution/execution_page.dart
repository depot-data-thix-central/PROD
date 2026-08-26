// lib/presentation/thix_ia/pages/execution/execution_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../core/utils/execution_utils.dart';
import '../../models/execution_finance.dart';
import 'finance_page.dart';
import 'tasks_page.dart';
import 'roadmap_page.dart';
import 'suppliers_page.dart';
import 'reports_page.dart';
import 'market_radar_page.dart';
import 'experiment_page.dart';
// Adapte les imports selon ton arborescence réelle :
// goals_page, risks_page, investors_crm_page, previsionnel_12m_page, etc.

class ExecutionPage extends ConsumerWidget {
  const ExecutionPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync =
        ref.watch(executionDashboardProvider(projectCode));
    final tasksAsync = ref.watch(executionTasksProvider(projectCode));
    final goalsAsync = ref.watch(executionGoalsProvider(projectCode));
    final suppliersAsync =
        ref.watch(executionSuppliersProvider(projectCode));
    final roadmapAsync =
        ref.watch(executionRoadmapProvider(projectCode));
    final financeAsync =
        ref.watch(executionFinanceProvider(projectCode));
    final risksAsync = ref.watch(executionRisksProvider(projectCode));
    final projectAsync =
        ref.watch(executionProjectProvider(projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectCode,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Pilotage exécution',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir tout',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(executionDashboardProvider(projectCode));
              ref.invalidate(executionTasksProvider(projectCode));
              ref.invalidate(executionGoalsProvider(projectCode));
              ref.invalidate(executionSuppliersProvider(projectCode));
              ref.invalidate(executionRoadmapProvider(projectCode));
              ref.invalidate(executionFinanceProvider(projectCode));
              ref.invalidate(executionRisksProvider(projectCode));
              ref.invalidate(executionProjectProvider(projectCode));
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur dashboard : $e',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(executionDashboardProvider(projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (dash) {
          final health = dash is Map ? dash['health'] : dash;
          final project = projectAsync.valueOrNull;

          final treasury = _num(health, 'treasury') ??
              project?.treasury ??
              0.0;
          final burn = _num(health, 'burnRate') ??
              _num(health, 'burn_rate') ??
              project?.burnRate ??
              0.0;
          final runway = _num(health, 'runwayMonths') ??
              _num(health, 'runway_months') ??
              project?.runwayMonths ??
              0.0;
          final healthScore = _num(health, 'healthScore')?.toInt() ??
              _num(health, 'health_score')?.toInt() ??
              project?.healthScore ??
              0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(executionDashboardProvider(projectCode));
              ref.invalidate(executionFinanceProvider(projectCode));
              ref.invalidate(executionTasksProvider(projectCode));
              ref.invalidate(executionGoalsProvider(projectCode));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Health banner
                _HealthBanner(
                  score: healthScore,
                  priorityTitle: project?.currentPriorityTitle ??
                      (dash is Map
                          ? dash['priority_title']?.toString()
                          : null),
                  priorityReason: project?.currentPriorityReason,
                ),
                const SizedBox(height: 14),

                // Grid modules
                _ModulesGrid(projectCode: projectCode),
                const SizedBox(height: 16),

                // Financial Engine
                _FinancialEngineCard(
                  financeAsync: financeAsync,
                  treasury: treasury,
                  burnRate: burn,
                  runway: runway,
                  onOpen: () => _push(context, FinancePage(projectCode: projectCode)),
                  onAddTx: () => _push(context, FinancePage(projectCode: projectCode)),
                ),
                const SizedBox(height: 16),

                // OKRs
                _OkrsSection(
                  goalsAsync: goalsAsync,
                  onSeeAll: () {
                    // Navigue vers ta GoalsPage si elle existe
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Ouvrir module OKRs')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Roadmap
                _RoadmapSection(
                  roadmapAsync: roadmapAsync,
                  onSeeAll: () =>
                      _push(context, RoadmapPage(projectCode: projectCode)),
                ),
                const SizedBox(height: 16),

                // Fournisseurs
                _SuppliersSection(
                  suppliersAsync: suppliersAsync,
                  onSeeAll: () => _push(
                      context, SuppliersPage(projectCode: projectCode)),
                ),
                const SizedBox(height: 16),

                // Risques (aperçu)
                _RisksPreview(
                  risksAsync: risksAsync,
                ),
                const SizedBox(height: 16),

                // Auto-Kanban
                _AutoKanbanSection(
                  tasksAsync: tasksAsync,
                  projectCode: projectCode,
                  onSeeAll: () =>
                      _push(context, TasksPage(projectCode: projectCode)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double? _num(dynamic obj, String key) {
    if (obj == null) return null;
    try {
      if (obj is Map) {
        final v = obj[key];
        if (v is num) return v.toDouble();
      }
      // objet typé (ExecutionProject / health)
      final mirror = obj;
      switch (key) {
        case 'treasury':
          return (mirror.treasury as num?)?.toDouble();
        case 'burnRate':
        case 'burn_rate':
          return (mirror.burnRate as num?)?.toDouble();
        case 'runwayMonths':
        case 'runway_months':
          return (mirror.runwayMonths as num?)?.toDouble();
        case 'healthScore':
        case 'health_score':
          return (mirror.healthScore as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

// ═══════════════════════════════════════════════════════════════
// HEALTH
// ═══════════════════════════════════════════════════════════════

class _HealthBanner extends StatelessWidget {
  const _HealthBanner({
    required this.score,
    this.priorityTitle,
    this.priorityReason,
  });
  final int score;
  final String? priorityTitle;
  final String? priorityReason;

  Color get _color {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
                Text('$score',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: _color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Santé projet',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(
                  priorityTitle?.isNotEmpty == true
                      ? priorityTitle!
                      : 'Priorité à définir',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (priorityReason != null && priorityReason!.isNotEmpty)
                  Text(priorityReason!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MODULES GRID
// ═══════════════════════════════════════════════════════════════

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    final modules = [
      _Mod('Finance', Icons.account_balance_wallet, Colors.indigo,
          () => _go(context, FinancePage(projectCode: projectCode))),
      _Mod('Kanban', Icons.view_kanban, Colors.blue,
          () => _go(context, TasksPage(projectCode: projectCode))),
      _Mod('Roadmap', Icons.route, Colors.teal,
          () => _go(context, RoadmapPage(projectCode: projectCode))),
      _Mod('Fournisseurs', Icons.local_shipping, Colors.orange,
          () => _go(context, SuppliersPage(projectCode: projectCode))),
      _Mod('Reporting', Icons.assessment, Colors.purple,
          () => _go(context, ReportsPage(projectCode: projectCode))),
      _Mod('Market Radar', Icons.radar, Colors.red,
          () => _go(context, MarketRadarPage(projectCode: projectCode))),
      _Mod('Expériences', Icons.science, Colors.green,
          () => _go(context, ExperimentPage(projectCode: projectCode))),
      // Ajoute Prévisionnel / Investisseurs / Risques si pages prêtes
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: modules
          .map((m) => GestureDetector(
                onTap: m.onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(m.icon, color: m.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(m.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Mod {
  const _Mod(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

// ═══════════════════════════════════════════════════════════════
// FINANCIAL
// ═══════════════════════════════════════════════════════════════

class _FinancialEngineCard extends StatelessWidget {
  const _FinancialEngineCard({
    required this.financeAsync,
    required this.treasury,
    required this.burnRate,
    required this.runway,
    required this.onOpen,
    required this.onAddTx,
  });

  final AsyncValue<FinancialSnapshot?> financeAsync;
  final double treasury;
  final double burnRate;
  final double runway;
  final VoidCallback onOpen;
  final VoidCallback onAddTx;

  @override
  Widget build(BuildContext context) {
    final mrr = financeAsync.valueOrNull?.mrr ?? 0;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Financial Engine',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAddTx,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Transaction',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Colors.deepPurple.shade400),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trésorerie actuelle',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      ExecutionUtils.formatCurrency(treasury),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniKpi(
                  icon: Icons.local_fire_department,
                  label: 'Burn Rate',
                  value:
                      '${ExecutionUtils.formatCurrency(burnRate)}/mo',
                ),
                _MiniKpi(
                  icon: Icons.flight,
                  label: 'Runway',
                  value: '${runway.toStringAsFixed(1)} mo',
                ),
                _MiniKpi(
                  icon: Icons.trending_up,
                  label: 'MRR',
                  value: '${ExecutionUtils.formatCurrency(mrr)}/mo',
                ),
              ],
            ),
            if (runway > 0 && runway < 6) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: runway < 3
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16,
                        color: runway < 3 ? Colors.red : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        runway < 3
                            ? 'Runway critique — sécuriser le cash'
                            : 'Runway sous 6 mois — anticiper',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OKRs
// ═══════════════════════════════════════════════════════════════

class _OkrsSection extends StatelessWidget {
  const _OkrsSection({required this.goalsAsync, required this.onSeeAll});
  final AsyncValue goalsAsync;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return goalsAsync.when(
      loading: () => const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(),
      data: (goals) {
        if (goals.isEmpty) {
          return _EmptyCard(
            title: 'Objectifs Stratégiques (OKRs)',
            message: 'Aucun OKR — créez-en dans le module Objectifs',
            onAction: onSeeAll,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Objectifs Stratégiques (OKRs)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                    onPressed: onSeeAll,
                    child: const Text('Voir tout',
                        style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: goals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final g = goals[i];
                  final progress = (g.progress as num?)?.toDouble() ??
                      ((g.current / (g.target == 0 ? 1 : g.target)) * 100);
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          '${g.current.toInt()} / ${g.target.toInt()} ${g.unit ?? ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (progress / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${progress.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ROADMAP
// ═══════════════════════════════════════════════════════════════

class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection({
    required this.roadmapAsync,
    required this.onSeeAll,
  });
  final AsyncValue roadmapAsync;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return roadmapAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (steps) {
        if (steps.isEmpty) {
          return _EmptyCard(
            title: 'Roadmap de Lancement',
            message: 'Roadmap vide — générer le template',
            onAction: onSeeAll,
          );
        }
        final done =
            steps.where((s) => s['status']?.toString() == 'done').length;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Roadmap de Lancement',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('\( done/ \){steps.length}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  TextButton(
                      onPressed: onSeeAll,
                      child: const Text('Voir tout',
                          style: TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 24,
                          height: 2,
                          color: steps[i - 1]['status'] == 'done'
                              ? Colors.green
                              : Colors.grey.shade300,
                        ),
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                steps[i]['status'] == 'done'
                                    ? Colors.green
                                    : steps[i]['status'] == 'doing'
                                        ? Colors.blue
                                        : Colors.grey.shade400,
                            child: steps[i]['status'] == 'done'
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : Text(
                                    '${steps[i]['order_index'] ?? i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 72,
                            child: Text(
                              steps[i]['title']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUPPLIERS
// ═══════════════════════════════════════════════════════════════

class _SuppliersSection extends StatelessWidget {
  const _SuppliersSection({
    required this.suppliersAsync,
    required this.onSeeAll,
  });
  final AsyncValue suppliersAsync;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return suppliersAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return _EmptyCard(
            title: 'Fournisseurs',
            message: 'Aucun fournisseur enregistré',
            onAction: onSeeAll,
          );
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Fournisseurs & Partenaires',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                      onPressed: onSeeAll,
                      child: const Text('Voir tout',
                          style: TextStyle(fontSize: 12))),
                ],
              ),
              ...suppliers.take(3).map((s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business, size: 20),
                    title: Text(s.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text(s.category,
                        style: const TextStyle(fontSize: 10)),
                    trailing: Chip(
                      label: Text(s.status,
                          style: const TextStyle(fontSize: 9)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RISKS PREVIEW
// ═══════════════════════════════════════════════════════════════

class _RisksPreview extends StatelessWidget {
  const _RisksPreview({required this.risksAsync});
  final AsyncValue risksAsync;

  @override
  Widget build(BuildContext context) {
    return risksAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (risks) {
        final open = risks
            .where((r) => r.status != 'closed')
            .toList();
        if (open.isEmpty) return const SizedBox();
        final critical =
            open.where((r) => r.isCritical || r.isHigh).length;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: critical > 0 ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: critical > 0
                ? Border.all(color: Colors.red.shade200)
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: critical > 0 ? Colors.red : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  critical > 0
                      ? '$critical risque(s) élevé(s) · ${open.length} ouverts'
                      : '${open.length} risque(s) ouvert(s)',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AUTO-KANBAN
// ═══════════════════════════════════════════════════════════════

class _AutoKanbanSection extends ConsumerWidget {
  const _AutoKanbanSection({
    required this.tasksAsync,
    required this.projectCode,
    required this.onSeeAll,
  });
  final AsyncValue tasksAsync;
  final String projectCode;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Auto-Kanban',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('Ouvrir', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await ref
                        .read(executionAiServiceProvider)
                        .autoGenerateTasksFromObjective(
                            projectCode, 'Lancement & exécution');
                    ref.invalidate(executionTasksProvider(projectCode));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Tâches IA générées')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Erreur IA : $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('IA', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const Text('Tâches live Supabase',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 8),
          tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur: $e',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aucune tâche — générez via IA ou ouvrez le Kanban',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                );
              }
              final open = tasks
                  .where((t) => t.status != 'done')
                  .take(6)
                  .toList();
              return Column(
                children: open
                    .map((t) => CheckboxListTile(
                          dense: true,
                          value: t.status == 'done',
                          onChanged: (v) async {
                            if (v == true) {
                              await ref
                                  .read(executionRepositoryProvider)
                                  .completeTask(t.id);
                            }
                          },
                          title: Text(t.title,
                              style: TextStyle(
                                fontSize: 12,
                                decoration: t.status == 'done'
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                          secondary: Chip(
                            label: Text(t.category,
                                style: const TextStyle(fontSize: 9)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
    required this.onAction,
  });
  final String title, message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          TextButton(onPressed: onAction, child: const Text('Ouvrir')),
        ],
      ),
    );
  }
}
