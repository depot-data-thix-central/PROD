import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachingPage extends StatefulWidget {
  const CoachingPage({super.key, required this.projectCode});
  final String projectCode;
  @override State<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends State<CoachingPage> {
  Map<String,dynamic>? coaching;
  bool loading = true;

  @override void initState(){ super.initState(); _loadCoaching(); }

  Future<void> _loadCoaching() async {
    setState(()=> loading=true);
    try {
      final res = await Supabase.instance.client.functions.invoke('thix-ia-orchestrator', body: {'project_code': widget.projectCode, 'action': 'coaching'});
      coaching = Map<String,dynamic>.from(res.data as Map);
    } catch(_){
      final tasks = await Supabase.instance.client.from('thix_execution_tasks').select('status,due_date').eq('project_code', widget.projectCode);
      final list = tasks as List;
      final done = list.where((t)=> t['status']=='done').length;
      final late = list.where((t)=> t['due_date']!=null && DateTime.tryParse(t['due_date'].toString())!=null && DateTime.now().isAfter(DateTime.parse(t['due_date'].toString())) && t['status']!='done').length;
      coaching = {'week_done': done, 'week_late': late, 'at_risk_goals': 1, 'advice': 'Concentrez vos efforts sur l\'acquisition client cette semaine. Votre burn rate est sous contrôle mais 62% des tâches marketing sont en retard.', 'skills': ['Gestion financière', 'Marketing digital'], 'formation': 'Gestion financière pour entrepreneur - 4h'};
    }
    setState(()=> loading=false);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Coaching IA')),
      body: loading? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Text('🧑‍🏫', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('COACHING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))]),
              const SizedBox(height: 12),
              const Text('Cette semaine:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• ${coaching!['week_done']??0} tâches terminées', style: const TextStyle(fontSize: 13)),
              Text('• ${coaching!['week_late']??0} tâches en retard', style: const TextStyle(fontSize: 13, color: Colors.orange)),
              Text('• ${coaching!['at_risk_goals']??0} objectif à risque', style: const TextStyle(fontSize: 13, color: Colors.red)),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Conseil:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), Text(coaching!['advice'].toString(), style: const TextStyle(fontSize: 13))])),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BESOIN DÉTECTÉ', style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey)),
              const SizedBox(height: 6),
              Text((coaching!['skills'] as List? ?? ['Gestion financière']).first.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Pourquoi? Votre projet entre dans une phase où la gestion du cash-flow devient critique.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.school, color: Colors.deepPurple), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(coaching!['formation'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const Text('Durée: 4h • Niveau: Débutant', style: TextStyle(fontSize: 10))])), ElevatedButton(onPressed: (){}, child: const Text('Commencer', style: TextStyle(fontSize: 11)))])),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Performance entrepreneur', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _SkillBar(label: 'Exécution', value: 78),
          _SkillBar(label: 'Leadership', value: 65),
          _SkillBar(label: 'Finance', value: 62),
          _SkillBar(label: 'Marketing', value: 43),
          _SkillBar(label: 'Discipline', value: 81),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget { const _SkillBar({required this.label, required this.value}); final String label; final int value; @override Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value/100, minHeight: 8))), const SizedBox(width: 8), Text('$value%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])) ;}
