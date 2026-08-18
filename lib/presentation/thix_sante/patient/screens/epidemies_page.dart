import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EpidemiesPage extends ConsumerStatefulWidget {
  const EpidemiesPage({super.key});
  @override
  ConsumerState<EpidemiesPage> createState() => _EpidemiesPageState();
}

class _EpidemiesPageState extends ConsumerState<EpidemiesPage> {
  String _filter = 'Tous';
  final _alerts = [
    {'title':'Grippe saisonnière','level':'Modéré','zone':'Kinshasa','cases':1243,'trend':'+12%','color':const Color(0xFFF59E0B),'icon':'🤧','desc':'Pic saisonnier en cours'},
    {'title':'COVID-19','level':'Faible','zone':'National','cases':89,'trend':'-23%','color':const Color(0xFF10B981),'icon':'🦠','desc':'Circulation faible'},
    {'title':'Choléra','level':'Élevé','zone':'Nord-Kivu','cases':312,'trend':'+45%','color':const Color(0xFFEF4444),'icon':'💧','desc':'Eau non traitée à éviter'},
    {'title':'Rougeole','level':'Modéré','zone':'Lualaba','cases':156,'trend':'+8%','color':const Color(0xFFF59E0B),'icon':'🔴','desc':'Verifier vaccination'},
  ];
  @override
  Widget build(BuildContext context) {
    final filtered = _filter=='Tous'? _alerts : _alerts.where((a)=>a['level']==_filter).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Épidémies', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.white, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]), borderRadius: BorderRadius.circular(16)), child: const Text('Surveillance en temps réel - MAJ il y a 2h', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: ['Tous','Faible','Modéré','Élevé'].map((f)=> ChoiceChip(label: Text(f), selected: _filter==f, onSelected: (_)=> setState(()=>_filter=f))).toList()),
          const SizedBox(height: 12),
          ...filtered.map((a)=> Card(child: ListTile(leading: Text(a['icon'] as String, style: const TextStyle(fontSize: 24)), title: Text(a['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${a['zone']} • ${a['cases']} cas - ${a['desc']}'), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(a['level'] as String, style: TextStyle(color: a['color'] as Color, fontWeight: FontWeight.w800, fontSize: 11)))))),
        ],
      ),
    );
  }
}
