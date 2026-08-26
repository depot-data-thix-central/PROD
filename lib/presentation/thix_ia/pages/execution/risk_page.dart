import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';

class RiskPage extends ConsumerStatefulWidget {
  const RiskPage({super.key, required this.projectCode});
  final String projectCode;
  @override ConsumerState<RiskPage> createState() => _RiskPageState();
}

class _RiskPageState extends ConsumerState<RiskPage> {
  @override Widget build(BuildContext context) {
    final risksAsync = ref.watch(executionRisksProvider(widget.projectCode));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Risk Radar'), actions: [IconButton(icon: const Icon(Icons.add_alert), onPressed: _showAddRisk)]),
      body: risksAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('Erreur $e')),
        data: (risks){
          if(risks.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.shield_outlined, size: 60, color: Colors.grey), const Text('Aucun risque identifié'), const SizedBox(height: 12), ElevatedButton(onPressed: _showAddRisk, child: const Text('Ajouter premier risque'))]));
          // Tri par niveau critique
          final sorted = [...risks]..sort((a,b)=> b.level.compareTo(a.level));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Radar visuel
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: sorted.take(4).map((r)=> Row(children: [Expanded(child: Text(r.title, style: const TextStyle(fontSize: 12))), Container(width: 60, height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(widthFactor: r.level/25, alignment: Alignment.centerLeft, child: Container(decoration: BoxDecoration(color: r.level>=15? Colors.red : r.level>=9? Colors.orange : Colors.green, borderRadius: BorderRadius.circular(4))))), const SizedBox(width: 8), Text(r.levelLabel, style: TextStyle(fontSize: 10, color: r.level>=15? Colors.red : Colors.grey, fontWeight: FontWeight.bold))])).toList())),
              const SizedBox(height: 16),
             ...sorted.map((r)=> Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: r.level>=15? Colors.red.shade200 : Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Chip(label: Text(r.levelLabel, style: const TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: r.level>=15? Colors.red : r.level>=9? Colors.orange : Colors.green),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [Chip(label: Text(r.category, style: const TextStyle(fontSize: 9))), const SizedBox(width: 6), Text('P:${r.probability} x I:${r.impact} = ${r.level}', style: const TextStyle(fontSize: 10))]),
                  if(r.mitigationPlan!= null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mitigation: ${r.mitigationPlan}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () async { await ref.read(supabaseClientProvider).from('thix_execution_risks').delete().eq('id', r.id); ref.invalidate(executionRisksProvider); }, child: const Text('Résoudre', style: TextStyle(fontSize: 10)))),
                ]),
              )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddRisk, label: const Text('Nouveau risque'), icon: const Icon(Icons.warning_amber)),
    );
  }

  void _showAddRisk(){
    final titleCtrl = TextEditingController();
    String category = 'financier';
    int prob=3, impact=3;
    final mitigationCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c)=> StatefulBuilder(builder: (c,setSt)=> Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Nouveau risque', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre risque')),
        DropdownButton<String>(value: category, isExpanded: true, items: const [DropdownMenuItem(value: 'financier', child: Text('Financier')), DropdownMenuItem(value: 'juridique', child: Text('Juridique')), DropdownMenuItem(value: 'commercial', child: Text('Commercial')), DropdownMenuItem(value: 'opérationnel', child: Text('Opérationnel')), DropdownMenuItem(value: 'technologique', child: Text('Technologique')), DropdownMenuItem(value: 'fournisseur', child: Text('Fournisseur')), DropdownMenuItem(value: 'marché', child: Text('Marché'))], onChanged: (v)=> setSt(()=> category=v!)),
        Row(children: [Expanded(child: Column(children: [Text('Probabilité: $prob'), Slider(value: prob.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v)=> setSt(()=> prob=v.toInt()))])), Expanded(child: Column(children: [Text('Impact: $impact'), Slider(value: impact.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v)=> setSt(()=> impact=v.toInt()))]))]),
        TextField(controller: mitigationCtrl, decoration: const InputDecoration(labelText: 'Plan mitigation')),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () async {
          await ref.read(supabaseClientProvider).from('thix_execution_risks').insert({'project_code': widget.projectCode, 'title': titleCtrl.text, 'category': category, 'probability': prob, 'impact': impact, 'mitigation_plan': mitigationCtrl.text, 'status':'open'});
          if(mounted) Navigator.pop(context);
          ref.invalidate(executionRisksProvider);
        }, child: const Text('Enregistrer')),
        const SizedBox(height: 24),
      ]),
    )));
  }
}
