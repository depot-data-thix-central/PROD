import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_finance.dart';
import '../../core/utils/execution_utils.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key, required this.projectCode});
  final String projectCode;
  @override ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  @override Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(executionFinanceProvider(widget.projectCode));
    final txAsync = ref.watch(executionTransactionsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Financial Engine'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: ()=> _showAddTransaction())]),
      body: snapshotAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (_,__)=> _buildEmptyFinance(),
        data: (snap){
          if(snap == null) return _buildEmptyFinance();
          final prudent = FinancialScenario.prudent(snap.revenueMonthly, snap.burnRate, snap.treasury);
          final normal = FinancialScenario.normal(snap.revenueMonthly, snap.burnRate, snap.treasury);
          final optimiste = FinancialScenario.optimiste(snap.revenueMonthly, snap.burnRate, snap.treasury);

          return ListView(padding: const EdgeInsets.all(16), children: [
            // KPIs sectoriels réels
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trésorerie: ${ExecutionUtils.formatCurrency(snap.treasury)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: snap.sectorKpis().entries.map((e)=> Chip(label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)))).toList()),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Scénarios', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ScenarioCard(s: prudent, color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _ScenarioCard(s: normal, color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _ScenarioCard(s: optimiste, color: Colors.green)),
            ]),
            const SizedBox(height: 16),
            const Text('Transactions réelles', style: TextStyle(fontWeight: FontWeight.bold)),
            txAsync.when(
              loading: ()=> const CircularProgressIndicator(),
              error: (e,s)=> Text('Erreur $e'),
              data: (txs)=> Column(children: txs.map((t)=> ListTile(
                leading: Icon(t.type == FinanceTransactionType.income? Icons.arrow_downward : Icons.arrow_upward, color: t.type == FinanceTransactionType.income? Colors.green : Colors.red),
                title: Text('${t.category} - ${ExecutionUtils.formatCurrency(t.amount)}', style: const TextStyle(fontSize: 13)),
                subtitle: Text(t.description?? '', style: const TextStyle(fontSize: 11)),
                trailing: Text(t.date?.toString().substring(0,10)?? '', style: const TextStyle(fontSize: 10)),
              )).toList()),
            )
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddTransaction, label: const Text('Ajouter transaction'), icon: const Icon(Icons.add)),
    );
  }

  Widget _buildEmptyFinance()=> Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Aucune donnée financière'), const SizedBox(height: 12), ElevatedButton(onPressed: _showAddTransaction, child: const Text('Créer première transaction'))]));

  void _showAddTransaction(){
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'expense';
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c)=> Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<String>(value: type, items: const [DropdownMenuItem(value: 'income', child: Text('Revenu')), DropdownMenuItem(value: 'expense', child: Text('Dépense')), DropdownMenuItem(value: 'capital', child: Text('Capital'))], onChanged: (v)=> setState(()=> type=v!)),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant \$')),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () async {
          final tx = FinanceTransaction(id: DateTime.now().millisecondsSinceEpoch.toString(), projectCode: widget.projectCode, type: FinanceTransactionType.values.firstWhere((e)=> e.name==type), category: 'Général', amount: double.tryParse(amountCtrl.text)?? 0, currency: 'USD', description: descCtrl.text, date: DateTime.now());
          await ref.read(executionRepositoryProvider).addTransaction(tx);
          if(mounted) Navigator.pop(context);
          ref.invalidate(executionTransactionsProvider);
          ref.invalidate(executionFinanceProvider);
        }, child: const Text('Enregistrer')),
        const SizedBox(height: 24),
      ]),
    ));
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.s, required this.color}); final FinancialScenario s; final Color color;
  @override Widget build(BuildContext context)=> Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)), const SizedBox(height: 6), Text('CA: \$${s.ca.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)), Text('Marge: ${s.marginPercent}%', style: const TextStyle(fontSize: 11)), Text('Runway: ${s.runwayMonths.toStringAsFixed(1)} mois', style: const TextStyle(fontSize: 11))] ));
}
