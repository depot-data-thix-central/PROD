import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/execution_provider.dart';
import '../../core/utils/execution_utils.dart';
import 'finance_page.dart';
import 'tasks_page.dart';
import 'roadmap_page.dart';
import 'suppliers_page.dart';
import 'risk_page.dart';
import '../bp_document_editor_page.dart';

class ExecutionDashboardFinal extends ConsumerWidget {
  const ExecutionDashboardFinal({
    super.key,
    required this.projectCode,
    required this.projectName,
  });

  final String projectCode;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(executionDashboardProvider(projectCode));
    final tasksStream = ref.watch(executionTasksProvider(projectCode));
    final goalsAsync = ref.watch(executionGoalsProvider(projectCode));
    final client = ref.read(supabaseClientProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── HEADER ──────────────────────────────────────────
            _buildHeader(context),

            SliverToBoxAdapter(
              child: dashAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Center(child: Text('Erreur $e')),
                data: (dash) {
                  final health = dash['health'];
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. FINANCIAL ENGINE
                        _FinancialEngineCard(
                          projectCode: projectCode,
                          treasury: health?.treasury ?? 0.0,
                          burnRate: health?.burnRate ?? 0.0,
                          runway: health?.runwayMonths ?? 0.0,
                          mrr: health?.mrr ?? 0.0,
                        ),
                        const SizedBox(height: 16),

                        // 2. BUDGET & LEVÉE (depuis thix_execution_budget / BP)
                        _BudgetFundingCard(
                          client: client,
                          projectCode: projectCode,
                        ),
                        const SizedBox(height: 16),

                        // 3. MODULES ENTERPRISE (cartes)
                        const Text(
                          'Pilotage entreprise',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        _EnterpriseModulesGrid(
                          projectCode: projectCode,
                          projectName: projectName,
                        ),
                        const SizedBox(height: 16),

                        // 4. OKRs
                        _SectionHeader(
                          title: 'Objectifs Stratégiques (OKRs)',
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 8),
                        goalsAsync.when(
                          loading: () => const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox(),
                          data: (goals) {
                            if (goals.isEmpty) {
                              return _EmptyBox(
                                  'Aucun objectif — générés auto après BP');
                            }
                            return SizedBox(
                              height: 95,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: goals.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (c, i) {
                                  final g = goals[i];
                                  return _OkrCard(
                                    title: g.title,
                                    current: g.current,
                                    target: g.target,
                                    unit: g.unit,
                                    progress: g.progress,
                                    index: i,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 5. ROADMAP
                        _SectionHeader(
                          title: 'Roadmap de Lancement',
                          onViewAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RoadmapPage(projectCode: projectCode),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RoadmapStrip(
                            client: client, projectCode: projectCode),
                        const SizedBox(height: 16),

                        // 6. ÉQUIPE
                        _SectionHeader(
                          title: 'Équipe & Rôles',
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 8),
                        _TeamCard(client: client, projectCode: projectCode),
                        const SizedBox(height: 16),

                        // 7. PRODUIT / MVP
                        _SectionHeader(
                          title: 'Produit & MVP',
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 8),
                        _ProductCard(client: client, projectCode: projectCode),
                        const SizedBox(height: 16),

                        // 8. FOURNISSEURS
                        _SectionHeader(
                          title: 'Fournisseurs & Partenaires',
                          onViewAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SuppliersPage(projectCode: projectCode),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SuppliersStrip(
                            client: client, projectCode: projectCode),
                        const SizedBox(height: 16),

                        // 9. AUTO-KANBAN
                        _KanbanCard(
                          projectCode: projectCode,
                          tasksStream: tasksStream,
                        ),
                        const SizedBox(height: 16),

                        // 10. RISQUES & COMPLIANCE
                        _SectionHeader(
                          title: 'Risques & Conformité',
                          onViewAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RiskPage(projectCode: projectCode),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RiskComplianceRow(projectCode: projectCode),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(projectCode: projectCode),
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour 👋',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Row(
            children: [
              Flexible(
                child: Text(
                  projectName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: const Icon(Icons.person, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FINANCIAL ENGINE
// ═══════════════════════════════════════════════════════════════

class _FinancialEngineCard extends StatelessWidget {
  const _FinancialEngineCard({
    required this.projectCode,
    required this.treasury,
    required this.burnRate,
    required this.runway,
    required this.mrr,
  });

  final String projectCode;
  final double treasury;
  final double burnRate;
  final double runway;
  final double mrr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Engine',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Trésorerie & Burn Rate',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F3FF),
                  foregroundColor: Colors.indigo,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FinancePage(projectCode: projectCode),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter transaction',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trésorerie actuelle',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              _BottomKpi(
                icon: Icons.local_fire_department,
                iconBg: Colors.orange.shade50,
                iconColor: Colors.orange,
                label: 'Burn Rate',
                value: '\$ ${burnRate.toInt()} /mo',
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              _BottomKpi(
                icon: Icons.flight,
                iconBg: Colors.green.shade50,
                iconColor: Colors.green,
                label: 'Runway',
                value: '${runway.toInt()} Mois',
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              _BottomKpi(
                icon: Icons.trending_up,
                iconBg: Colors.blue.shade50,
                iconColor: Colors.blue,
                label: 'MRR',
                value: '\$ ${mrr.toInt()} /mo',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BUDGET / LEVÉE (BP → Exécution)
// ═══════════════════════════════════════════════════════════════

class _BudgetFundingCard extends StatelessWidget {
  const _BudgetFundingCard({
    required this.client,
    required this.projectCode,
  });

  final SupabaseClient client;
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: client
          .from('thix_execution_budget')
          .select()
          .eq('project_code', projectCode)
          .maybeSingle()
          .then((v) => v == null ? null : Map<String, dynamic>.from(v)),
      builder: (context, snap) {
        final b = snap.data;
        final target = (b?['funding_target'] as num?)?.toDouble() ?? 0;
        final raised = (b?['funding_raised'] as num?)?.toDouble() ?? 0;
        final gap = (b?['funding_gap'] as num?)?.toDouble() ??
            (target - raised).clamp(0, double.infinity);
        final capital = (b?['initial_capital'] as num?)?.toDouble() ?? 0;
        final progress = target > 0 ? (raised / target).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.shade50,
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.rocket_launch, size: 18, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('Levée & Budget (depuis BP)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              if (b == null)
                const Text(
                  'Aucune donnée budget — génère le Business Plan pour injecter automatiquement.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FundChip('Capital', capital),
                    _FundChip('Levé', raised),
                    _FundChip('Cible', target),
                    _FundChip('Reste', gap, highlight: true),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.indigo),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% de la cible atteinte',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FundChip extends StatelessWidget {
  const _FundChip(this.label, this.value, {this.highlight = false});
  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: highlight ? Colors.red : Colors.grey)),
        Text(
          '\$${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: highlight ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MODULES ENTERPRISE (cartes — à brancher une par une)
// ═══════════════════════════════════════════════════════════════

class _EnterpriseModulesGrid extends StatelessWidget {
  const _EnterpriseModulesGrid({
    required this.projectCode,
    required this.projectName,
  });

  final String projectCode;
  final String projectName;

  static const _modules = [
    _Mod('Business Plan A4', Icons.menu_book, Colors.indigo,
        'Éditer · PDF · sections'),
    _Mod('Prévisionnel 12 mois', Icons.timeline, Colors.teal,
        'Cashflow · scénarios'),
    _Mod('Pipeline commercial', Icons.hub, Colors.orange,
        'Leads · conversion'),
    _Mod('Équipe & RH', Icons.groups, Colors.purple,
        'Rôles · hiring plan'),
    _Mod('Produit / Roadmap', Icons.inventory_2, Colors.blue,
        'MVP · releases'),
    _Mod('Conformité légale', Icons.gavel, Colors.red,
        'Licences · checklist'),
    _Mod('KPI Board', Icons.insights, Colors.green,
        'North Star · cohortes'),
    _Mod('Investisseurs CRM', Icons.handshake, Colors.brown,
        'Deck · follow-ups'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) {
        final m = _modules[i];
        return InkWell(
          onTap: () {
            if (i == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BpDocumentEditorPage(projectCode: projectCode),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${m.title} — à brancher (phase suivante)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m.icon, size: 18, color: m.color),
                ),
                const Spacer(),
                Text(m.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(m.subtitle,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Mod {
  const _Mod(this.title, this.icon, this.color, this.subtitle);
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
}

// ═══════════════════════════════════════════════════════════════
// OKR / ROADMAP / TEAM / PRODUCT / SUPPLIERS / KANBAN
// ═══════════════════════════════════════════════════════════════

class _OkrCard extends StatelessWidget {
  const _OkrCard({
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    required this.progress,
    required this.index,
  });

  final String title;
  final num current;
  final num target;
  final String unit;
  final num progress;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = index == 0 ? Colors.blue : Colors.orange;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${current.toInt()} / ${target.toInt()} $unit',
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text('${progress.toInt()}%', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _RoadmapStrip extends StatelessWidget {
  const _RoadmapStrip({required this.client, required this.projectCode});
  final SupabaseClient client;
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: client
          .from('thix_execution_roadmap')
          .select()
          .eq('project_code', projectCode)
          .order('order_index')
          .limit(6)
          .then((v) => v as List<dynamic>),
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const _EmptyBox(
              'Roadmap vide — injectée après génération du BP');
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: list.map<Widget>((r) {
                final i = list.indexOf(r);
                final status = r['status']?.toString() ?? 'todo';
                final isDone = status == 'done';
                final isCurrent = status == 'doing';
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.shade100
                              : isCurrent
                                  ? Colors.white
                                  : Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone
                                ? Colors.green
                                : isCurrent
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.green)
                              : Text('${r['order_index'] ?? i + 1}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? Colors.blue
                                          : Colors.grey)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 80,
                        child: Text(
                          r['title']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.client, required this.projectCode});
  final SupabaseClient client;
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: client
          .from('thix_bp_config')
          .select('founder_name, missing_roles, stage')
          .eq('project_code', projectCode)
          .maybeSingle()
          .then((v) => v == null ? null : Map<String, dynamic>.from(v)),
      builder: (context, snap) {
        final d = snap.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: d == null
              ? const Text('Équipe non renseignée (Pre-Flight BP)',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d['founder_name'] != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.person, size: 18)),
                        title: Text(d['founder_name'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                            'CEO · ${d['stage'] ?? 'Idée'}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    if (d['missing_roles'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Rôles à pourvoir',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(d['missing_roles'].toString(),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.client, required this.projectCode});
  final SupabaseClient client;
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: client
          .from('thix_bp_config')
          .select('product_name, usp, persona, acquisition_channel')
          .eq('project_code', projectCode)
          .maybeSingle()
          .then((v) => v == null ? null : Map<String, dynamic>.from(v)),
      builder: (context, snap) {
        final d = snap.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: d == null
              ? const Text('Produit non défini — renseigne le Pre-Flight BP',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['product_name']?.toString() ?? 'Produit',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    if (d['usp'] != null) ...[
                      const SizedBox(height: 6),
                      Text('USP : ${d['usp']}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    if (d['persona'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Persona : ${d['persona']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                    if (d['acquisition_channel'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Acquisition : ${d['acquisition_channel']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _SuppliersStrip extends StatelessWidget {
  const _SuppliersStrip({required this.client, required this.projectCode});
  final SupabaseClient client;
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: client
          .from('thix_execution_suppliers')
          .select()
          .eq('project_code', projectCode)
          .limit(3)
          .then((v) => v as List<dynamic>),
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 60, child: Center(child: CircularProgressIndicator()));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const _EmptyBox('Aucun fournisseur enregistré');
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: list
                .map<Widget>((s) => ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business, size: 16),
                      ),
                      title: Text(s['name']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(s['category']?.toString() ?? '',
                          style: const TextStyle(fontSize: 10)),
                      trailing: Chip(
                        label: Text(s['status']?.toString() ?? '',
                            style: const TextStyle(fontSize: 9)),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.projectCode,
    required this.tasksStream,
  });

  final String projectCode;
  final AsyncValue tasksStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-Kanban',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Tâches IA + BP',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F3FF),
                  foregroundColor: Colors.indigo,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TasksPage(projectCode: projectCode),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label:
                    const Text('Ajouter tâche', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          tasksStream.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Aucune tâche — générées après le BP',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                );
              }
              return Column(
                children: tasks.take(5).map<Widget>((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          t.status == 'done'
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: t.status == 'done'
                              ? Colors.green
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 12,
                              decoration: t.status == 'done'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (t.isAiSuggested) ...[
                          const Icon(Icons.auto_awesome,
                              size: 14, color: Colors.indigo),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RiskComplianceRow extends StatelessWidget {
  const _RiskComplianceRow({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniActionCard(
            icon: Icons.warning_amber,
            color: Colors.orange,
            title: 'Risques',
            subtitle: 'Matrice · mitigation',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RiskPage(projectCode: projectCode),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniActionCard(
            icon: Icons.verified_user,
            color: Colors.green,
            title: 'Compliance',
            subtitle: 'Licences · checklist',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _MiniActionCard extends StatelessWidget {
  const _MiniActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// UI helpers
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});
  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        TextButton(
          onPressed: onViewAll,
          child: const Text('Voir tout', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _BottomKpi extends StatelessWidget {
  const _BottomKpi({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(value,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(icon: Icons.home, label: 'Accueil', active: true, onTap: () {}),
          _NavItem(
            icon: Icons.pie_chart,
            label: 'Risques',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RiskPage(projectCode: projectCode),
              ),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
          _NavItem(
            icon: Icons.folder,
            label: 'BP Doc',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BpDocumentEditorPage(projectCode: projectCode),
              ),
            ),
          ),
          _NavItem(icon: Icons.settings, label: 'Réglages', onTap: () {}),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.blue : Colors.grey),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: active ? Colors.blue : Colors.grey,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
