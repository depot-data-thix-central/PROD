import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.projectCode});
  final String projectCode;
  @override State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<Map<String,dynamic>> members = [];
  bool loading = true;

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final rows = await Supabase.instance.client.from('thix_execution_team').select().eq('project_code', widget.projectCode);
    setState((){ members = List<Map<String,dynamic>>.from(rows as List); loading=false; });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Équipe & Performance')),
      body: loading? const Center(child: CircularProgressIndicator()) : members.isEmpty? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.people_outline, size: 60, color: Colors.grey), const Text('Aucun membre'), ElevatedButton(onPressed: _addMember, child: const Text('Ajouter membre'))])) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Détection retard IA
          FutureBuilder<List<Map<String,dynamic>>>(
            future: Supabase.instance.client.from('thix_execution_tasks').select('assignee_name,status,due_date').eq('project_code', widget.projectCode).then((v)=> List<Map<String,dynamic>>.from(v as List)),
            builder: (c,snap){
              if(!snap.hasData) return const SizedBox();
              final late = snap.data!.where((t)=> t['due_date']!=null && DateTime.tryParse(t['due_date'].toString())!=null && DateTime.now().isAfter(DateTime.parse(t['due_date'].toString())) && t['status']!='done').toList();
              if(late.isEmpty) return const SizedBox();
              final grouped = <String,int>{};
              for(var t in late){ final name = t['assignee_name']?.toString()?? 'Non assigné'; grouped[name]=(grouped[name]??0)+1; }
              final worst = grouped.entries.isEmpty? null : grouped.entries.reduce((a,b)=> a.value>b.value? a:b);
              if(worst==null) return const SizedBox();
              return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)), child: Row(children: [const Icon(Icons.warning_amber, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text('${worst.value} tâches en retard chez ${worst.key} - 62% marketing en retard', style: const TextStyle(fontSize: 12)))]));
            },
          ),
          const SizedBox(height: 16),
         ...members.map((m)=> Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CircleAvatar(child: Text(m['name'].toString().substring(0,1).toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text('${m['role']} • ${m['tasks_completed']??0} tâches', style: const TextStyle(fontSize: 11, color: Colors.grey))])),
              Column(children: [Text('${m['performance']??0}%', style: const TextStyle(fontWeight: FontWeight.bold)), const Text('Perf', style: TextStyle(fontSize: 9))]),
            ]),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addMember, label: const Text('Ajouter membre'), icon: const Icon(Icons.person_add)),
    );
  }

  void _addMember(){
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Marketing');
    showModalBottomSheet(context: context, builder: (c)=> Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
      TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Rôle')),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () async {
        await Supabase.instance.client.from('thix_execution_team').insert({'project_code': widget.projectCode, 'name': nameCtrl.text, 'role': roleCtrl.text, 'performance': 75, 'tasks_completed': 0});
        if(mounted) Navigator.pop(context);
        _load();
      }, child: const Text('Ajouter')),
    ])));
  }
}
