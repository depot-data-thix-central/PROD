// lib/presentation/thix_weeding/pages/staff/budget/budget_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class BudgetPage extends ConsumerStatefulWidget {
  final String weddingId;
  const BudgetPage({super.key, required this.weddingId});
  @override ConsumerState<BudgetPage> createState()=> _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  String _filter = 'all';

  @override Widget build(BuildContext context){
    // ON UTILISE TES PROVIDERS TYPÉS DE STAFF
    final budgetAsync = ref.watch(budgetProvider(widget.weddingId));
    final expensesAsync = ref.watch(expensesProvider(widget.weddingId));
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: ()=> _editTotalBudget(context)),
        ]
      ),
      body: budgetAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('$e')),
        data: (BudgetModel? budget){
          // Si pas de budget, on crée celui par défaut via ton Service
          if(budget == null){
            return Center(
              child: FilledButton(
                onPressed: () async {
                  await ref.read(budgetServiceProvider).upsert(widget.weddingId, 3500000);
                  ref.invalidate(budgetProvider(widget.weddingId));
                },
                child: const Text('Créer Budget 3 500 000 FCFA')
              )
            );
          }

          final totalBudget = budget.totalBudget;
          // totalSpent vient du budget mais on recalcule aussi depuis les dépenses pour être exact
          final summaryAsync = ref.watch(paymentsSummaryProvider(widget.weddingId));

          return summaryAsync.when(
            loading: ()=> const Center(child: CircularProgressIndicator()),
            error: (e,s)=> Text('$e'),
            data: (summary){
              final totalSpent = summary['spent']!;
              final remaining = totalBudget - totalSpent;
              final percent = (totalBudget>0? totalSpent/totalBudget : 0).clamp(0,1).toDouble();

              return Column(children: [
                Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Budget global', style: TextStyle(fontWeight: FontWeight.w900, fontSize:16)),
                    Text('${(percent*100).toInt()}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height:12),
                  LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[200], color: Colors.green, minHeight: 10),
                  const SizedBox(height:16),
                  Row(children: [
                    Expanded(child: _MoneyBox(label:'Dépensé', value: totalSpent, color: Colors.red)),
                    const SizedBox(width:12),
                    Expanded(child: _MoneyBox(label:'Restant', value: remaining, color: Colors.green)),
                    const SizedBox(width:12),
                    Expanded(child: _MoneyBox(label:'Total', value: totalBudget, color: const Color(0xFF0B3B8F))),
                  ]),
                ])),
                Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Row(children: [
                  _FilterChip(label:'Toutes', sel:_filter=='all', tap:()=>setState(()=>_filter='all')),
                  const SizedBox(width:8),
                  _FilterChip(label:'Payées', sel:_filter=='paid', tap:()=>setState(()=>_filter='paid')),
                  const SizedBox(width:8),
                  _FilterChip(label:'Impayées', sel:_filter=='unpaid', tap:()=>setState(()=>_filter='unpaid')),
                ])),
                Expanded(child: expensesAsync.when(
                  loading: ()=> const Center(child: CircularProgressIndicator()),
                  error: (e,s)=> Center(child: Text('$e')),
                  data: (List<ExpenseModel> expenses){
                    var filtered = expenses.where((e){
                      if(_filter=='paid') return e.isPaid==true;
                      if(_filter=='unpaid') return e.isPaid==false;
                      return true;
                    }).toList();
                    if(filtered.isEmpty) return const Center(child: Text('Aucune dépense'));
                    return RefreshIndicator(onRefresh: () async {
                      ref.invalidate(expensesProvider(widget.weddingId));
                      ref.invalidate(budgetProvider(widget.weddingId));
                    }, child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: filtered.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (_,i){
                      final ExpenseModel e = filtered[i];
                      final vendorName = vendorsAsync.maybeWhen(
                        data: (vendors){
                          final v = vendors.where((v)=> v.id == e.vendorId);
                          return v.isEmpty? 'Sans prestataire' : v.first.name;
                        },
                        orElse: ()=> e.category
                      );
                      return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: ListTile(
                        leading: Icon(e.isPaid?Icons.check_circle:Icons.pending, color: e.isPaid?Colors.green:Colors.orange),
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$vendorName • ID: ${e.id.substring(0,6)}'),
                        trailing: Text('${e.amount.toInt()} FCFA', style: TextStyle(fontWeight: FontWeight.bold, color: e.isPaid?Colors.green:Colors.red)),
                        onTap: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/budget/${e.id}'),
                      ));
                    }));
                  },
                )),
              ]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/budget/add'), icon: const Icon(Icons.add), label: const Text('Dépense')),
    );
  }

  void _editTotalBudget(BuildContext context){
    final c = TextEditingController(text: '3500000');
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Modifier budget total'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:'3500000')), actions: [
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        final val = double.tryParse(c.text);
        if(val!=null){
          await ref.read(budgetServiceProvider).upsert(widget.weddingId, val);
          ref.invalidate(budgetProvider(widget.weddingId));
          if(context.mounted) Navigator.pop(context);
        }
      }, child: const Text('Enregistrer')),
    ]));
  }
}

class _MoneyBox extends StatelessWidget{ final String label; final double value; final Color color; const _MoneyBox({required this.label, required this.value, required this.color}); @override Widget build(BuildContext context)=> Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize:10, color: color)), Text('${value.toInt()} FCFA', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize:12))])); }
class _FilterChip extends StatelessWidget{ final String label; final bool sel; final VoidCallback tap; const _FilterChip({required this.label, required this.sel, required this.tap}); @override Widget build(BuildContext context)=> ChoiceChip(label: Text(label), selected: sel, onSelected: (_)=> tap()); }
