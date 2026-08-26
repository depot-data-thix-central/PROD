import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key, required this.projectCode});
  final String projectCode;
  @override ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  @override Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(executionSuppliersProvider(widget.projectCode));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Fournisseurs & Partenaires'), actions: [IconButton(icon: const Icon(Icons.add_business), onPressed: _showAddSupplier)]),
      body: suppliersAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('Erreur $e')),
        data: (suppliers){
          if(suppliers.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.local_shipping_outlined, size: 60, color: Colors.grey), const Text('Aucun fournisseur'), ElevatedButton(onPressed: _showAddSupplier, child: const Text('Ajouter fournisseur'))]));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: suppliers.length,
            separatorBuilder: (_,__)=> const SizedBox(height: 8),
            itemBuilder: (c,i){
              final s = suppliers[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(s.category, style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                    Chip(label: Text(s.status, style: const TextStyle(fontSize: 10)), backgroundColor: s.status=='Validé'? Colors.green.shade100 : s.status=='Négociation'? Colors.orange.shade100 : Colors.grey.shade100),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: s.calculatedScore/100, minHeight: 6, backgroundColor: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _ScoreChip(label: 'Prix', value: s.priceScore),
                    _ScoreChip(label: 'Qualité', value: s.qualityScore),
                    _ScoreChip(label: 'Délai', value: s.delayScore),
                    _ScoreChip(label: 'Fiabilité', value: s.reliabilityScore),
                  ]),
                  Align(alignment: Alignment.centerRight, child: Text('Score: ${s.calculatedScore.toStringAsFixed(0)}/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddSupplier, label: const Text('Ajouter fournisseur'), icon: const Icon(Icons.add)),
    );
  }

  void _showAddSupplier(){
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Équipement');
    double priceScore=80, qualityScore=80, delayScore=80, reliabilityScore=80;
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c)=> StatefulBuilder(builder: (c,setSt)=> Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Nouveau fournisseur', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom société')),
        TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Catégorie')),
        _SliderScore(label: 'Prix', value: priceScore, onChanged: (v)=> setSt(()=> priceScore=v)),
        _SliderScore(label: 'Qualité', value: qualityScore, onChanged: (v)=> setSt(()=> qualityScore=v)),
        _SliderScore(label: 'Délai', value: delayScore, onChanged: (v)=> setSt(()=> delayScore=v)),
        _SliderScore(label: 'Fiabilité', value: reliabilityScore, onChanged: (v)=> setSt(()=> reliabilityScore=v)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () async {
          await ref.read(supabaseClientProvider).from('thix_execution_suppliers').insert({
            'project_code': widget.projectCode, 'name': nameCtrl.text, 'category': categoryCtrl.text,
            'status':'Recherche', 'price_score': priceScore, 'quality_score': qualityScore, 'delay_score': delayScore, 'reliability_score': reliabilityScore,
          });
          if(mounted) Navigator.pop(context);
          ref.invalidate(executionSuppliersProvider);
        }, child: const Text('Enregistrer')),
        const SizedBox(height: 24),
      ])),
    )));
  }
}

class _ScoreChip extends StatelessWidget { const _ScoreChip({required this.label, required this.value}); final String label; final double value; @override Widget build(BuildContext context)=> Column(children: [Text(label, style: const TextStyle(fontSize: 8)), Text('${value.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]); }
class _SliderScore extends StatelessWidget { const _SliderScore({required this.label, required this.value, required this.onChanged}); final String label; final double value; final ValueChanged<double> onChanged; @override Widget build(BuildContext context)=> Row(children: [SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 11))), Expanded(child: Slider(value: value, min: 0, max: 100, onChanged: onChanged)), Text('${value.toInt()}', style: const TextStyle(fontSize: 11))]); }
