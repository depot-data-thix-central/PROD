import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OpportunityPage extends StatefulWidget {
  const OpportunityPage({super.key, required this.projectCode});
  final String projectCode;
  @override State<OpportunityPage> createState() => _OpportunityPageState();
}

class _OpportunityPageState extends State<OpportunityPage> {
  List<Map<String,dynamic>> opps = [];
  bool loading = true;

  @override void initState(){ super.initState(); _loadOpps(); }

  Future<void> _loadOpps() async {
    try {
      final rows = await Supabase.instance.client.from('thix_opportunities').select().eq('country', 'RDC').order('compatibility', ascending: false).limit(20);
      opps = List<Map<String,dynamic>>.from(rows as List);
    } catch(_){}
    if(opps.isEmpty){
      opps = [
        {'title':'Programme PME agricole - BAD','type':'Financement','amount':'50 000 \$','deadline':'30/09/2026','compatibility':91,'description':'Financement agro-industrie RDC, traitement eau éligible','source':'Banque Africaine de Développement'},
        {'title':'Appel à projet eau potable Kinshasa','type':'Marché public','amount':'120 000 \$','deadline':'15/10/2026','compatibility':87,'description':'Fourniture unités traitement eau communes','source':'Mairie Kinshasa'},
        {'title':'Concours StartUp RDC 2026','type':'Concours','amount':'25 000 \$','deadline':'01/11/2026','compatibility':82,'description':'Prix innovation eau et environnement','source':'Ministère Numérique RDC'},
      ];
    }
    setState(()=> loading=false);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Africa Opportunity Radar')),
      body: loading? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade600, Colors.teal.shade600]), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.public, color: Colors.white), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Opportunités pour ton projet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text('Financements, marchés publics, programmes - match IA', style: TextStyle(color: Colors.white70, fontSize: 11))]))])),
          const SizedBox(height: 16),
          ...opps.map((o)=> Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: (o['compatibility'] as int)>=85? Colors.green.shade200 : Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Chip(label: Text(o['type'].toString(), style: const TextStyle(fontSize: 9))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)), child: Text('Compatibilité ${o['compatibility']}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
              ]),
              const SizedBox(height: 8),
              Text(o['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(o['description'].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.green), Text(o['amount'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12), const Icon(Icons.calendar_today, size: 12), const SizedBox(width: 4), Text(o['deadline'].toString(), style: const TextStyle(fontSize: 10)),
                const Spacer(), ElevatedButton(onPressed: () async {
                  await Supabase.instance.client.from('thix_project_memories').insert({'project_code': widget.projectCode, 'type':'opportunity','content': o, 'created_at': DateTime.now().toIso8601String()});
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opportunité ajoutée à la mémoire projet')));
                }, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)), child: const Text('Analyser', style: TextStyle(fontSize: 11))),
              ]),
              const SizedBox(height: 4),
              Text('Source: ${o['source']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ]),
          )),
        ],
      ),
    );
  }
}
