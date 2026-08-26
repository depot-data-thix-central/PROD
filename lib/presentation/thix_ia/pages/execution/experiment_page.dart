import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/execution_provider.dart';

class ExperimentPage extends ConsumerStatefulWidget {
  const ExperimentPage({super.key, required this.projectCode});
  final String projectCode;
  @override ConsumerState<ExperimentPage> createState() => _ExperimentPageState();
}

class _ExperimentPageState extends ConsumerState<ExperimentPage> {
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Experiment Center')),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: Supabase.instance.client.from('thix_execution_experiments').select().eq('project_code', widget.projectCode).order('created_at', ascending: false).then((v)=> List<Map<String,dynamic>>.from(v as List)),
        builder: (c,snap){
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          final exps = snap.data!;
          if(exps.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.science_outlined, size: 60, color: Colors.grey), const Text('Aucune expérimentation'), const SizedBox(height: 12), ElevatedButton(onPressed: _showCreateExperiment, child: const Text('Créer hypothèse'))]));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exps.length,
            itemBuilder: (c,i){
              final e = exps[i];
              final confidence = (e['confidence'] as num?)?.toInt()?? 0;
              final status = e['status']?.toString()?? 'running';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Chip(label: Text(status, style: const TextStyle(fontSize: 10)), backgroundColor: status=='validated'? Colors.green.shade100 : status=='invalidated'? Colors.red.shade100 : Colors.orange.shade100), Text('Confiance: $confidence%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  Text('HYPOTHÈSE', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, letterSpacing: 1)),
                  Text(e['hypothesis'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: _MetricBox(label: 'Interrogés', value: '${e['sample_size']??0}')), const SizedBox(width: 8), Expanded(child: _MetricBox(label: 'Intéressés', value: '${e['interested']??0}')), const SizedBox(width: 8), Expanded(child: _MetricBox(label: 'Prêts à payer', value: '${e['willing_to_pay']??0}'))]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: confidence/100, minHeight: 6, backgroundColor: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text('Résultat: ${e['result']??'En cours'}', style: const TextStyle(fontSize: 12))),
                    ElevatedButton(onPressed: () async {
                      final newStatus = confidence>=70? 'validated' : confidence>=40? 'partial' : 'invalidated';
                      await Supabase.instance.client.from('thix_execution_experiments').update({'status': newStatus}).eq('id', e['id']);
                      setState((){});
                    }, child: const Text('Analyser', style: TextStyle(fontSize: 11))),
                  ])
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCreateExperiment, label: const Text('Nouvelle hypothèse'), icon: const Icon(Icons.add)),
    );
  }

  void _showCreateExperiment(){
    final hypoCtrl = TextEditingController();
    final sampleCtrl = TextEditingController(text: '20');
    final interestedCtrl = TextEditingController(text: '13');
    final payCtrl = TextEditingController(text: '7');
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c)=> Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Tester une hypothèse', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: hypoCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Ex: Les PME accepteront de payer 50\$/mois')),
        Row(children: [Expanded(child: TextField(controller: sampleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Échantillon'))), const SizedBox(width: 8), Expanded(child: TextField(controller: interestedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Intéressés'))), const SizedBox(width: 8), Expanded(child: TextField(controller: payCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prêts à payer')))]),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () async {
          final sample = int.tryParse(sampleCtrl.text)?? 0;
          final interested = int.tryParse(interestedCtrl.text)?? 0;
          final willing = int.tryParse(payCtrl.text)?? 0;
          final confidence = sample==0? 0 : ((interested/sample*50)+(willing/sample*50)).round();
          final result = confidence>=70? 'Validée' : confidence>=40? 'Partiellement validée' : 'Invalidée';
          await Supabase.instance.client.from('thix_execution_experiments').insert({
            'project_code': widget.projectCode, 'hypothesis': hypoCtrl.text, 'sample_size': sample, 'interested': interested, 'willing_to_pay': willing, 'confidence': confidence, 'result': result, 'status': confidence>=70? 'validated' : 'running',
          });
          if(mounted) Navigator.pop(context);
          setState((){});
        }, child: const Text('Enregistrer expérimentation')),
        const SizedBox(height: 24),
      ]),
    ));
  }
}

class _MetricBox extends StatelessWidget { const _MetricBox({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context)=> Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey))])); }
