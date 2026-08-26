import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

class RoadmapPage extends ConsumerStatefulWidget {
  const RoadmapPage({super.key, required this.projectCode});
  final String projectCode;
  @override ConsumerState<RoadmapPage> createState() => _RoadmapPageState();
}

class _RoadmapPageState extends ConsumerState<RoadmapPage> {
  @override Widget build(BuildContext context) {
    final roadmapAsync = ref.watch(executionRoadmapProvider(widget.projectCode));
    return Scaffold(
      appBar: AppBar(title: const Text('Roadmap de Lancement')),
      body: roadmapAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('Erreur $e')),
        data: (steps){
          if(steps.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Roadmap vide'), ElevatedButton(onPressed: _createDefaultRoadmap, child: const Text('Créer roadmap par défaut'))]));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: steps.length,
            itemBuilder: (c,i){
              final s = steps[i];
              final isDone = s['status']=='done';
              final isCurrent = s['status']=='doing';
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  CircleAvatar(radius: 20, backgroundColor: isDone? Colors.green : isCurrent? Colors.blue : Colors.grey.shade300, child: isDone? const Icon(Icons.check, color: Colors.white) : Text('${s['order_index']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  if(i!= steps.length-1) Container(width: 2, height: 40, color: isDone? Colors.green : Colors.grey.shade300),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isCurrent? Colors.blue.shade50 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isCurrent? Colors.blue : Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(s['description']?.toString()?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 8), Row(children: [Chip(label: Text(s['status'].toString(), style: const TextStyle(fontSize: 10)), const Spacer(), if(!isDone) ElevatedButton(onPressed: () async { await ref.read(supabaseClientProvider).from('thix_execution_roadmap').update({'status':'done'}).eq('id', s['id']); ref.invalidate(executionRoadmapProvider); }, child: const Text('Valider', style: TextStyle(fontSize: 10)))])]))),
              ]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createDefaultRoadmap, child: const Icon(Icons.add)),
    );
  }

  Future<void> _createDefaultRoadmap() async {
    final defaults = [
      {'title':'Business Plan Validé','description':'Validation du business plan complet','order_index':1,'status':'done','month':'Mois 1'},
      {'title':'Création Juridique & RCCM','description':'Enregistrement RCCM, ID Nat, NIF','order_index':2,'status':'done','month':'Mois 2'},
      {'title':'Achat & Importation Équipements','description':'Commande machines traitement eau','order_index':3,'status':'doing','month':'Mois 3'},
      {'title':'Lancement de la Production','description':'Installation et test production','order_index':4,'status':'todo','month':'Mois 4'},
      {'title':'Lancement Commercial','description':'Premiers clients et distribution','order_index':5,'status':'todo','month':'Mois 5'},
      {'title':'Croissance','description':'Scale à Kinshasa','order_index':6,'status':'todo','month':'Mois 6'},
    ];
    for(var d in defaults) {
      await ref.read(supabaseClientProvider).from('thix_execution_roadmap').insert({...d,'project_code':widget.projectCode});
    }
    ref.invalidate(executionRoadmapProvider);
  }
}
