// lib/presentation/thix_ia/pages/execution/previsionnel_12m_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart'; // ajoute fl_chart dans pubspec si pas déjà
import '../../models/previsionnel_12m.dart';
import '../../core/utils/execution_utils.dart';
import '../../providers/execution_provider.dart'; // réutilise si possible

// ─────────────────────────────────────────────────────────────
// PROVIDER LOCAL (tu peux le déplacer dans providers/)
// ─────────────────────────────────────────────────────────────
final previsionnelProvider = StateNotifierProvider.family<
    PrevisionnelNotifier, AsyncValue<Previsionnel12M>, String>((ref, projectCode) {
  return PrevisionnelNotifier(projectCode);
});

class PrevisionnelNotifier extends StateNotifier<AsyncValue<Previsionnel12M>> {
  PrevisionnelNotifier(this.projectCode) : super(const AsyncValue.loading()) {
    _loadOrGenerate();
  }

  final String projectCode;

  Future<void> _loadOrGenerate() async {
    // TODO: charger depuis Supabase table thix_previsionnel_12m
    // pour l’instant on génère un modèle de base
    final assumptions = const PrevisionnelAssumptions(
      startingCash: 45000,
      baseMonthlyRevenue: 12000,
      revenueGrowthRate: 8.0,
      cogsPercent: 32,
      fixedOpex: 4500,
      variableOpexPercent: 12,
      monthlyCapex: 800,
      scenarioMultiplier: 1.0,
    );
    final model = Previsionnel12M.generate(
      projectCode: projectCode,
      assumptions: assumptions,
      scenarioName: 'Base',
    );
    state = AsyncValue.data(model);
  }

  void updateAssumptions(PrevisionnelAssumptions newAssumptions, {String scenario = 'Base'}) {
    final model = Previsionnel12M.generate(
      projectCode: projectCode,
      assumptions: newAssumptions,
      scenarioName: scenario,
    );
    state = AsyncValue.data(model);
    // TODO: upsert Supabase
  }

  void switchScenario(String name) {
    final current = state.valueOrNull;
    if (current == null) return;
    double mult = 1.0;
    if (name == 'Prudent') mult = 0.7;
    if (name == 'Optimiste') mult = 1.35;
    updateAssumptions(
      current.assumptions.copyWith(scenarioMultiplier: mult),
      scenario: name,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────
class Previsionnel12MPage extends ConsumerStatefulWidget {
  const Previsionnel12MPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<Previsionnel12MPage> createState() => _Previsionnel12MPageState();
}

class _Previsionnel12MPageState extends ConsumerState<Previsionnel12MPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedScenario = 1; // 0=Prudent, 1=Base, 2=Optimiste

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(previsionnelProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Prévisionnel 12 mois',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exporter PDF / Excel',
            onPressed: () {
              // TODO: export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export en cours de développement')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showAssumptionsSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Cashflow'),
            Tab(text: 'Scénarios'),
            Tab(text: 'Tableau'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (model) => TabBarView(
          controller: _tabController,
          children: [
            _CashflowTab(model: model),
            _ScenariosTab(
              model: model,
              selected: _selectedScenario,
              onSelect: (i) {
                setState(() => _selectedScenario = i);
                final names = ['Prudent', 'Base', 'Optimiste'];
                ref.read(previsionnelProvider(widget.projectCode).notifier)
                    .switchScenario(names[i]);
              },
            ),
            _TableTab(model: model),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssumptionsSheet(context),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text('Hypothèses', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showAssumptionsSheet(BuildContext context) {
    final model = ref.read(previsionnelProvider(widget.projectCode)).valueOrNull;
    if (model == null) return;

    final a = model.assumptions;
    final cashCtrl = TextEditingController(text: a.startingCash.toStringAsFixed(0));
    final revCtrl = TextEditingController(text: a.baseMonthlyRevenue.toStringAsFixed(0));
    final growthCtrl = TextEditingController(text: a.revenueGrowthRate.toStringAsFixed(1));
    final cogsCtrl = TextEditingController(text: a.cogsPercent.toStringAsFixed(0));
    final fixedCtrl = TextEditingController(text: a.fixedOpex.toStringAsFixed(0));
    final varCtrl = TextEditingController(text: a.variableOpexPercent.toStringAsFixed(0));
    final capexCtrl = TextEditingController(text: a.monthlyCapex.toStringAsFixed(0));

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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hypothèses du prévisionnel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _numField(cashCtrl, 'Trésorerie de départ (USD)'),
              _numField(revCtrl, 'Revenu mensuel de base (USD)'),
              _numField(growthCtrl, 'Croissance mensuelle (%)'),
              _numField(cogsCtrl, 'COGS (% du CA)'),
              _numField(fixedCtrl, 'Charges fixes mensuelles (USD)'),
              _numField(varCtrl, 'Charges variables (% du CA)'),
              _numField(capexCtrl, 'CAPEX mensuel (USD)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    final newA = a.copyWith(
                      startingCash: double.tryParse(cashCtrl.text) ?? a.startingCash,
                      baseMonthlyRevenue: double.tryParse(revCtrl.text) ?? a.baseMonthlyRevenue,
                      revenueGrowthRate: double.tryParse(growthCtrl.text) ?? a.revenueGrowthRate,
                      cogsPercent: double.tryParse(cogsCtrl.text) ?? a.cogsPercent,
                      fixedOpex: double.tryParse(fixedCtrl.text) ?? a.fixedOpex,
                      variableOpexPercent: double.tryParse(varCtrl.text) ?? a.variableOpexPercent,
                      monthlyCapex: double.tryParse(capexCtrl.text) ?? a.monthlyCapex,
                    );
                    ref.read(previsionnelProvider(widget.projectCode).notifier)
                        .updateAssumptions(newA, scenario: model.scenarioName);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Recalculer le prévisionnel',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ONGLET CASHFLOW (graphique + KPIs)
// ─────────────────────────────────────────────────────────────
class _CashflowTab extends StatelessWidget {
  const _CashflowTab({required this.model});
  final Previsionnel12M model;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPIs
        Row(
          children: [
            Expanded(child: _KpiCard('Trésorerie finale', ExecutionUtils.formatCurrency(model.months.last.closingCash), Colors.indigo)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Cash min', ExecutionUtils.formatCurrency(model.minCash), model.minCash < 0 ? Colors.red : Colors.green)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _KpiCard('CA 12 mois', ExecutionUtils.formatCurrency(model.totalRevenue), Colors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Scénario', model.scenarioName, Colors.purple)),
          ],
        ),
        const SizedBox(height: 20),
        // Graphique cash
        Container(
          height: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Évolution de la trésorerie', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= model.months.length) return const SizedBox();
                            return Text(model.months[i].label.split(' ').first,
                                style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: model.months
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.closingCash))
                            .toList(),
                        isCurved: true,
                        color: Colors.indigo,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.indigo.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Net cash par mois
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Flux net mensuel', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= model.months.length) return const SizedBox();
                            return Text(model.months[i].label.split(' ').first,
                                style: const TextStyle(fontSize: 9));
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: model.months
                        .asMap()
                        .entries
                        .map((e) => BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.netCash,
                                  color: e.value.netCash >= 0 ? Colors.green : Colors.red,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ONGLET SCÉNARIOS
// ─────────────────────────────────────────────────────────────
class _ScenariosTab extends StatelessWidget {
  const _ScenariosTab({
    required this.model,
    required this.selected,
    required this.onSelect,
  });
  final Previsionnel12M model;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      _ScenarioInfo('Prudent', 0.7, Colors.orange, 'Croissance réduite, coûts plus élevés'),
      _ScenarioInfo('Base', 1.0, Colors.indigo, 'Hypothèses actuelles'),
      _ScenarioInfo('Optimiste', 1.35, Colors.green, 'Croissance accélérée, meilleure marge'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...List.generate(3, (i) {
          final s = scenarios[i];
          final isSelected = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? s.color.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? s.color : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: s.color.withOpacity(0.15),
                    child: Icon(Icons.trending_up, color: s.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isSelected ? s.color : Colors.black87)),
                        Text(s.desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: s.color),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Scénario actif : ${model.scenarioName}\nTrésorerie finale : ${ExecutionUtils.formatCurrency(model.months.last.closingCash)}',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class _ScenarioInfo {
  const _ScenarioInfo(this.name, this.mult, this.color, this.desc);
  final String name;
  final double mult;
  final Color color;
  final String desc;
}

// ─────────────────────────────────────────────────────────────
// ONGLET TABLEAU DÉTAILLÉ
// ─────────────────────────────────────────────────────────────
class _TableTab extends StatelessWidget {
  const _TableTab({required this.model});
  final Previsionnel12M model;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Mois', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Revenus', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('COGS', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('OPEX', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('CAPEX', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Cash fin', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: model.months.map((m) {
            return DataRow(cells: [
              DataCell(Text(m.label, style: const TextStyle(fontSize: 12))),
              DataCell(Text(ExecutionUtils.formatCurrency(m.revenue), style: const TextStyle(fontSize: 12))),
              DataCell(Text(ExecutionUtils.formatCurrency(m.cogs), style: const TextStyle(fontSize: 12))),
              DataCell(Text(ExecutionUtils.formatCurrency(m.opex), style: const TextStyle(fontSize: 12))),
              DataCell(Text(ExecutionUtils.formatCurrency(m.capex), style: const TextStyle(fontSize: 12))),
              DataCell(Text(
                ExecutionUtils.formatCurrency(m.netCash),
                style: TextStyle(
                    fontSize: 12,
                    color: m.netCash >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600),
              )),
              DataCell(Text(ExecutionUtils.formatCurrency(m.closingCash),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
