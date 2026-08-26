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

class _FinancePageState extends ConsumerState<FinancePage> {
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(executionFinanceProvider(widget.projectCode));
    final txAsync = ref.watch(executionTransactionsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Financial Engine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTransactionSheet,
          )
        ],
      ),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur de chargement : $e')),
        data: (snap) {
          if (snap == null) {
            return _buildEmptyFinance();
          }

          final prudent = FinancialScenario.prudent(snap.revenueMonthly, snap.burnRate, snap.treasury);
          final normal = FinancialScenario.normal(snap.revenueMonthly, snap.burnRate, snap.treasury);
          final optimiste = FinancialScenario.optimiste(snap.revenueMonthly, snap.burnRate, snap.treasury);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trésorerie Actuelle', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      ExecutionUtils.formatCurrency(snap.treasury),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    if (snap.sectorKpis().isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: snap.sectorKpis().entries.map((e) => Chip(
                          label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.grey.shade100,
                        )).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Text('Scénarios Prévisionnels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
              const SizedBox(height: 24),
              
              const Text('Transactions Réelles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              
              txAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Text('Erreur transactions : $e', style: const TextStyle(color: Colors.red)),
                data: (txs) {
                  if (txs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Aucune transaction enregistrée', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = txs[index];
                        final isIncome = t.type == FinanceTransactionType.income;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.red,
                              size: 18,
                            ),
                          ),
                          title: Text('${t.category} - ${ExecutionUtils.formatCurrency(t.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(t.description?.isNotEmpty == true ? t.description! : 'Aucune description', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: Text(
                            t.date != null ? t.date.toString().substring(0, 10) : '',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionSheet,
        label: const Text('Ajouter transaction'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyFinance() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Aucune donnée financière pour ce projet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Enregistrez votre première transaction ou capital de départ pour initialiser le moteur.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddTransactionSheet,
                icon: const Icon(Icons.add),
                label: const Text('Créer première transaction'),
              )
            ],
          ),
        ),
      );

  void _showAddTransactionSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Général');
    String type = 'income';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nouvelle Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type de transaction', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'income', child: Text('Revenu (Entrée)')),
                  DropdownMenuItem(value: 'expense', child: Text('Dépense (Sortie)')),
                  DropdownMenuItem(value: 'capital', child: Text('Capital / Apport')),
                ],
                onChanged: (v) => setModalState(() => type = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Catégorie (ex: Loyer, Vente, Matière première)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant (\$ USD)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (Optionnel)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isAdding ? null : () async {
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez entrer un montant valide')),
                      );
                      return;
                    }

                    setModalState(() => _isAdding = true);

                    try {
                      final tx = FinanceTransaction(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        projectCode: widget.projectCode,
                        type: FinanceTransactionType.values.firstWhere((e) => e.name == type),
                        category: categoryCtrl.text.trim().isEmpty ? 'Général' : categoryCtrl.text.trim(),
                        amount: amount,
                        currency: 'USD',
                        description: descCtrl.text.trim(),
                        date: DateTime.now(),
                      );

                      await ref.read(executionRepositoryProvider).addTransaction(tx);

                      if (mounted) Navigator.pop(context);

                      ref.invalidate(executionTransactionsProvider(widget.projectCode));
                      ref.invalidate(executionFinanceProvider(widget.projectCode));
                      ref.invalidate(executionDashboardProvider(widget.projectCode));
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) setModalState(() => _isAdding = false);
                    }
                  },
                  child: _isAdding 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer la transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.s, required this.color}); 
  final FinancialScenario s; 
  final Color color;

  @override 
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: color.withOpacity(0.5))
        ), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)), 
            const SizedBox(height: 6), 
            Text('CA: \$${s.ca.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)), 
            Text('Marge: ${s.marginPercent}%', style: const TextStyle(fontSize: 11)), 
            Text('Runway: ${s.runwayMonths.toStringAsFixed(1)}m', style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}
