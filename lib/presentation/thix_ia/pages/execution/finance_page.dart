// lib/presentation/thix_ia/pages/execution/finance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_finance.dart';
import '../../core/utils/execution_utils.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _busy = false;
  String _txFilter = 'all'; // all | income | expense | capital

  static const _categories = [
    'Général', 'Ventes', 'Marketing', 'Salaires', 'Loyer',
    'Équipement', 'Matière première', 'Logistique', 'Légal',
    'Logiciels', 'Impôts', 'Capital', 'Autre'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync =
        ref.watch(executionFinanceProvider(widget.projectCode));
    final txAsync =
        ref.watch(executionTransactionsProvider(widget.projectCode));
    final projectAsync =
        ref.watch(executionProjectProvider(widget.projectCode));
    final suppliersAsync =
        ref.watch(executionSuppliersProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Financial Engine',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Recalculer depuis projet + txs',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(executionFinanceProvider(widget.projectCode));
              ref.invalidate(
                  executionTransactionsProvider(widget.projectCode));
              ref.invalidate(executionProjectProvider(widget.projectCode));
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Éditer snapshot / budget',
            onPressed: () => _showEditSnapshotSheet(
              snapshotAsync.valueOrNull,
              projectAsync.valueOrNull,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Vue d\'ensemble'),
            Tab(text: 'Transactions'),
            Tab(text: 'Budget & BP'),
          ],
        ),
      ),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: () => ref
                    .invalidate(executionFinanceProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (snap) {
          final txs = txAsync.valueOrNull ?? [];
          final project = projectAsync.valueOrNull;
          final suppliers = suppliersAsync.valueOrNull ?? [];

          // Snapshot effectif : priorité snapshot → projet → calcul txs
          final effective = _buildEffectiveSnapshot(snap, project, txs);

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _OverviewTab(
                snap: effective,
                txs: txs,
                onAdd: _showAddTransactionSheet,
                onEditSnap: () =>
                    _showEditSnapshotSheet(snap, project),
              ),
              _TransactionsTab(
                txs: txs,
                filter: _txFilter,
                onFilter: (f) => setState(() => _txFilter = f),
                onAdd: _showAddTransactionSheet,
                onDelete: _deleteTransaction,
                busy: _busy,
              ),
              _BudgetTab(
                snap: effective,
                project: project,
                txs: txs,
                suppliers: suppliers,
                onEdit: () => _showEditSnapshotSheet(snap, project),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _showAddTransactionSheet,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Transaction',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Fusion snapshot + projet + agrégats transactions
  FinancialSnapshot _buildEffectiveSnapshot(
    FinancialSnapshot? snap,
    dynamic project,
    List<FinanceTransaction> txs,
  ) {
    double treasury = snap?.treasury ?? 0;
    double burn = snap?.burnRate ?? 0;
    double runway = snap?.runwayMonths ?? 0;
    double mrr = snap?.mrr ?? 0;
    double arr = snap?.arr ?? 0;
    double revMonthly = snap?.revenueMonthly ?? 0;
    double expMonthly = snap?.expensesMonthly ?? 0;
    var sector = snap?.sector ?? FinanceSector.service;

    if (project != null) {
      if (treasury == 0) treasury = (project.treasury as num?)?.toDouble() ?? 0;
      if (burn == 0) burn = (project.burnRate as num?)?.toDouble() ?? 0;
      if (runway == 0) runway = (project.runwayMonths as num?)?.toDouble() ?? 0;
      if (mrr == 0) mrr = (project.mrr as num?)?.toDouble() ?? 0;
    }

    // Recalcul depuis transactions si pas de snapshot solide
    if (txs.isNotEmpty) {
      double income = 0, expense = 0, capital = 0;
      for (final t in txs) {
        switch (t.type) {
          case FinanceTransactionType.income:
            income += t.amount;
            break;
          case FinanceTransactionType.expense:
            expense += t.amount;
            break;
          case FinanceTransactionType.capital:
            capital += t.amount;
            break;
        }
      }
      final computedTreasury = capital + income - expense;
      if (snap == null || treasury == 0) treasury = computedTreasury;

      // Burn approximatif : dépenses des 30 derniers jours
      final now = DateTime.now();
      final last30 = txs.where((t) {
        if (t.type != FinanceTransactionType.expense || t.date == null) {
          return false;
        }
        return now.difference(t.date!).inDays <= 30;
      });
      final monthBurn =
          last30.fold<double>(0, (s, t) => s + t.amount);
      if (burn == 0 && monthBurn > 0) burn = monthBurn;

      final monthIncome = txs.where((t) {
        if (t.type != FinanceTransactionType.income || t.date == null) {
          return false;
        }
        return now.difference(t.date!).inDays <= 30;
      }).fold<double>(0, (s, t) => s + t.amount);

      if (revMonthly == 0) revMonthly = monthIncome;
      if (expMonthly == 0) expMonthly = monthBurn;
      if (mrr == 0) mrr = monthIncome;
      if (arr == 0) arr = mrr * 12;
    }

    if (burn > 0 && runway == 0) {
      runway = treasury / burn;
    }

    return FinancialSnapshot(
      projectCode: widget.projectCode,
      treasury: treasury,
      burnRate: burn,
      runwayMonths: runway,
      mrr: mrr,
      arr: arr,
      revenueMonthly: revMonthly,
      expensesMonthly: expMonthly,
      sector: sector,
      cac: snap?.cac,
      ltv: snap?.ltv,
      churnRate: snap?.churnRate,
      grossMargin: snap?.grossMargin,
      stockValue: snap?.stockValue,
      averageBasket: snap?.averageBasket,
    );
  }

  Future<void> _deleteTransaction(FinanceTransaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(
            'Supprimer ${t.category} · ${ExecutionUtils.formatCurrency(t.amount)} ?'),
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
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .from('thix_execution_finances')
          .delete()
          .eq('id', t.id);
      ref.invalidate(executionTransactionsProvider(widget.projectCode));
      ref.invalidate(executionFinanceProvider(widget.projectCode));
      ref.invalidate(executionDashboardProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAddTransactionSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Général';
    String type = 'expense';
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvelle transaction',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'income', child: Text('Revenu (entrée)')),
                    DropdownMenuItem(
                        value: 'expense', child: Text('Dépense (sortie)')),
                    DropdownMenuItem(
                        value: 'capital', child: Text('Capital / Apport')),
                  ],
                  onChanged: (v) => setModal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModal(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Montant (USD)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                      '\( {date.day}/ \){date.month}/${date.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModal(() => date = picked);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    onPressed: _busy
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountCtrl.text.trim()) ?? 0;
                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Montant invalide'),
                                    backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            setState(() => _busy = true);
                            try {
                              final tx = FinanceTransaction(
                                id: '',
                                projectCode: widget.projectCode,
                                type: FinanceTransactionType.values
                                    .firstWhere((e) => e.name == type),
                                category: category,
                                amount: amount,
                                currency: 'USD',
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                date: date,
                              );
                              await ref
                                  .read(executionRepositoryProvider)
                                  .addTransaction(tx);
                              if (mounted) Navigator.pop(context);
                              ref.invalidate(executionTransactionsProvider(
                                  widget.projectCode));
                              ref.invalidate(executionFinanceProvider(
                                  widget.projectCode));
                              ref.invalidate(executionDashboardProvider(
                                  widget.projectCode));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Transaction enregistrée dans Supabase'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Erreur : $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Enregistrer',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSnapshotSheet(
      FinancialSnapshot? snap, dynamic project) {
    final treasuryCtrl = TextEditingController(
        text: (snap?.treasury ?? project?.treasury ?? 0)
            .toStringAsFixed(0));
    final burnCtrl = TextEditingController(
        text: (snap?.burnRate ?? project?.burnRate ?? 0)
            .toStringAsFixed(0));
    final mrrCtrl = TextEditingController(
        text: (snap?.mrr ?? project?.mrr ?? 0).toStringAsFixed(0));
    final budgetCtrl = TextEditingController(text: '0');
    final revCtrl = TextEditingController(
        text: (snap?.revenueMonthly ?? 0).toStringAsFixed(0));
    final expCtrl = TextEditingController(
        text: (snap?.expensesMonthly ?? 0).toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Snapshot & Budget projet',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                'Synchronise trésorerie / burn / MRR avec le Business Plan et le dashboard.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _MoneyField(treasuryCtrl, 'Trésorerie (USD)'),
              const SizedBox(height: 10),
              _MoneyField(burnCtrl, 'Burn rate mensuel (USD)'),
              const SizedBox(height: 10),
              _MoneyField(mrrCtrl, 'MRR / CA mensuel (USD)'),
              const SizedBox(height: 10),
              _MoneyField(revCtrl, 'Revenus mensuels (USD)'),
              const SizedBox(height: 10),
              _MoneyField(expCtrl, 'Dépenses mensuelles (USD)'),
              const SizedBox(height: 10),
              _MoneyField(budgetCtrl, 'Budget total Business Plan (USD)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    final treasury =
                        double.tryParse(treasuryCtrl.text.trim()) ?? 0;
                    final burn =
                        double.tryParse(burnCtrl.text.trim()) ?? 0;
                    final mrr = double.tryParse(mrrCtrl.text.trim()) ?? 0;
                    final rev = double.tryParse(revCtrl.text.trim()) ?? 0;
                    final exp = double.tryParse(expCtrl.text.trim()) ?? 0;
                    final budget =
                        double.tryParse(budgetCtrl.text.trim()) ?? 0;
                    final runway = burn > 0 ? treasury / burn : 0.0;

                    try {
                      final client = ref.read(supabaseClientProvider);
                      // Update projet
                      await client.from('thix_execution_projects').upsert({
                        'project_code': widget.projectCode,
                        'treasury': treasury,
                        'burn_rate': burn,
                        'runway_months': runway,
                        'mrr': mrr,
                        'updated_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'project_code');

                      // Upsert snapshot
                      await client.from('thix_execution_snapshots').upsert({
                        'project_code': widget.projectCode,
                        'treasury': treasury,
                        'burn_rate': burn,
                        'runway_months': runway,
                        'mrr': mrr,
                        'arr': mrr * 12,
                        'revenue_monthly': rev,
                        'expenses_monthly': exp,
                        'budget_total': budget,
                        'updated_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'project_code');

                      if (mounted) Navigator.pop(context);
                      ref.invalidate(
                          executionFinanceProvider(widget.projectCode));
                      ref.invalidate(
                          executionProjectProvider(widget.projectCode));
                      ref.invalidate(
                          executionDashboardProvider(widget.projectCode));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Snapshot & budget synchronisés'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Erreur : $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Enregistrer dans Supabase',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snap,
    required this.txs,
    required this.onAdd,
    required this.onEditSnap,
  });
  final FinancialSnapshot snap;
  final List<FinanceTransaction> txs;
  final VoidCallback onAdd;
  final VoidCallback onEditSnap;

  @override
  Widget build(BuildContext context) {
    final prudent = FinancialScenario.prudent(
        snap.revenueMonthly, snap.burnRate, snap.treasury);
    final normal = FinancialScenario.normal(
        snap.revenueMonthly, snap.burnRate, snap.treasury);
    final optimiste = FinancialScenario.optimiste(
        snap.revenueMonthly, snap.burnRate, snap.treasury);

    final income = txs
        .where((t) => t.type == FinanceTransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = txs
        .where((t) => t.type == FinanceTransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final capital = txs
        .where((t) => t.type == FinanceTransactionType.capital)
        .fold<double>(0, (s, t) => s + t.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Trésorerie hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.shade700,
                Colors.indigo.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Trésorerie',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                    onPressed: onEditSnap,
                  ),
                ],
              ),
              Text(
                ExecutionUtils.formatCurrency(snap.treasury),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _HeroStat('Burn', ExecutionUtils.formatCurrency(snap.burnRate)),
                  _HeroStat(
                      'Runway', '${snap.runwayMonths.toStringAsFixed(1)} mo'),
                  _HeroStat('MRR', ExecutionUtils.formatCurrency(snap.mrr)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Flux
        Row(
          children: [
            Expanded(
                child: _FlowCard('Entrées', income, Colors.green, Icons.arrow_downward)),
            const SizedBox(width: 8),
            Expanded(
                child: _FlowCard('Sorties', expense, Colors.red, Icons.arrow_upward)),
            const SizedBox(width: 8),
            Expanded(
                child: _FlowCard('Capital', capital, Colors.blue, Icons.account_balance)),
          ],
        ),
        const SizedBox(height: 16),

        // KPIs sectoriels
        if (snap.sectorKpis().isNotEmpty) ...[
          const Text('KPIs sectoriels',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: snap.sectorKpis().entries.map((e) {
              final val = e.value is num
                  ? ExecutionUtils.formatCurrency((e.value as num).toDouble())
                  : e.value.toString();
              return Chip(
                label: Text('${e.key}: $val',
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Scénarios
        const Text('Scénarios prévisionnels',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ScenarioCard(s: prudent, color: Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _ScenarioCard(s: normal, color: Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _ScenarioCard(s: optimiste, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 16),

        // Alertes runway
        if (snap.runwayMonths > 0 && snap.runwayMonths < 6)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: snap.runwayMonths < 3
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: snap.runwayMonths < 3
                      ? Colors.red.shade200
                      : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: snap.runwayMonths < 3
                        ? Colors.red
                        : Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snap.runwayMonths < 3
                        ? 'Runway critique : ${snap.runwayMonths.toStringAsFixed(1)} mois — sécuriser le financement'
                        : 'Runway sous 6 mois — anticiper une levée ou réduire le burn',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — TRANSACTIONS
// ═══════════════════════════════════════════════════════════════

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.txs,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
    required this.onDelete,
    required this.busy,
  });
  final List<FinanceTransaction> txs;
  final String filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onAdd;
  final ValueChanged<FinanceTransaction> onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all'
        ? txs
        : txs.where((t) => t.type.name == filter).toList();

    // Répartition par catégorie (dépenses)
    final byCat = <String, double>{};
    for (final t in txs.where((t) => t.type == FinanceTransactionType.expense)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip('Tous', filter == 'all', () => onFilter('all')),
              _FilterChip('Revenus', filter == 'income',
                  () => onFilter('income')),
              _FilterChip('Dépenses', filter == 'expense',
                  () => onFilter('expense')),
              _FilterChip('Capital', filter == 'capital',
                  () => onFilter('capital')),
            ],
          ),
        ),
        if (sortedCats.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Répartition dépenses',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          ...sortedCats.take(5).map((e) {
            final total = byCat.values.fold(0.0, (a, b) => a + b);
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 90,
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(ExecutionUtils.formatCurrency(e.value),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text('Aucune transaction',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = filtered[i];
                final isIncome = t.type == FinanceTransactionType.income;
                final isCapital = t.type == FinanceTransactionType.capital;
                final color = isIncome
                    ? Colors.green
                    : isCapital
                        ? Colors.blue
                        : Colors.red;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(
                      isIncome
                          ? Icons.arrow_downward
                          : isCapital
                              ? Icons.account_balance
                              : Icons.arrow_upward,
                      color: color,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${t.category} · ${ExecutionUtils.formatCurrency(t.amount)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    t.description?.isNotEmpty == true
                        ? t.description!
                        : t.type.name,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.date != null
                            ? '\( {t.date!.day}/ \){t.date!.month}/${t.date!.year}'
                            : '',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        onPressed: busy ? null : () => onDelete(t),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3 — BUDGET & BUSINESS PLAN
// ═══════════════════════════════════════════════════════════════

class _BudgetTab extends StatelessWidget {
  const _BudgetTab({
    required this.snap,
    required this.project,
    required this.txs,
    required this.suppliers,
    required this.onEdit,
  });
  final FinancialSnapshot snap;
  final dynamic project;
  final List<FinanceTransaction> txs;
  final List suppliers;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final spent = txs
        .where((t) => t.type == FinanceTransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    // Budget : si pas dans snapshot, estimation 12× burn ou revenus
    final budgetTotal = snap.expensesMonthly > 0
        ? snap.expensesMonthly * 12
        : (snap.burnRate > 0 ? snap.burnRate * 12 : spent * 1.5);
    final remaining = budgetTotal - spent;
    final pctUsed =
        budgetTotal > 0 ? (spent / budgetTotal * 100).clamp(0, 150) : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
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
                  const Text('Budget projet (Business Plan)',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const Spacer(),
                  TextButton(onPressed: onEdit, child: const Text('Éditer')),
                ],
              ),
              const SizedBox(height: 12),
              Text(ExecutionUtils.formatCurrency(budgetTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                'Consommé ${ExecutionUtils.formatCurrency(spent)} · Reste ${ExecutionUtils.formatCurrency(remaining)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (pctUsed / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    pctUsed > 100
                        ? Colors.red
                        : pctUsed > 80
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('${pctUsed.toStringAsFixed(0)}% du budget utilisé',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pctUsed > 100 ? Colors.red : Colors.grey.shade700)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lien projet
        if (project != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Données projet (thix_execution_projects)',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 12),
                _BpRow('Trésorerie projet',
                    ExecutionUtils.formatCurrency(project.treasury ?? 0)),
                _BpRow('Burn rate',
                    ExecutionUtils.formatCurrency(project.burnRate ?? 0)),
                _BpRow('Runway',
                    '${(project.runwayMonths ?? 0).toStringAsFixed(1)} mois'),
                _BpRow('MRR', ExecutionUtils.formatCurrency(project.mrr ?? 0)),
                if (project.healthScore != null)
                  _BpRow('Health score', '${project.healthScore}%'),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Intersection fournisseurs (coûts potentiels)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fournisseurs liés (${suppliers.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              if (suppliers.isEmpty)
                Text('Aucun fournisseur — module Fournisseurs',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
              else
                ...suppliers.take(5).map((s) {
                  final name = s.name?.toString() ?? s['name']?.toString() ?? '?';
                  final status =
                      s.status?.toString() ?? s['status']?.toString() ?? '';
                  final price = s.price ?? s['price'];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business, size: 18),
                    title: Text(name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(status, style: const TextStyle(fontSize: 11)),
                    trailing: price != null
                        ? Text(ExecutionUtils.formatCurrency(
                            (price as num).toDouble()),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600))
                        : null,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard(this.label, this.amount, this.color, this.icon);
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(ExecutionUtils.formatCurrency(amount),
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.s, required this.color});
  final FinancialScenario s;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 6),
          Text('CA: \$${s.ca.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11)),
          Text('Marge: ${s.marginPercent}%',
              style: const TextStyle(fontSize: 11)),
          Text('Runway: ${s.runwayMonths.isFinite ? s.runwayMonths.toStringAsFixed(1) : '∞'}m',
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.indigo.withOpacity(0.15),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField(this.ctrl, this.label);
  final TextEditingController ctrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixText: '\$ ',
        isDense: true,
      ),
    );
  }
}

class _BpRow extends StatelessWidget {
  const _BpRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
