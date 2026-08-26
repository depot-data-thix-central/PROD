import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/execution_utils.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.projectCode});
  final String projectCode;
  
  @override 
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Reporting Auto'), 
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generateWeekly)
        ]
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('thix_execution_reports')
            .select()
            .eq('project_code', widget.projectCode)
            .order('created_at', ascending: false)
            .then((v) => List<Map<String, dynamic>>.from(v as List)),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          final reports = snap.data!;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ElevatedButton.icon(
                onPressed: _generateWeekly, 
                icon: const Icon(Icons.auto_awesome), 
                label: const Text('Générer rapport hebdo IA')
              ),
              const SizedBox(height: 16),
              ...reports.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Text(r['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)), 
                        Chip(label: Text('${r['progress_percent']}%', style: const TextStyle(fontSize: 10)))
                      ]
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Progression: ${r['progress_percent']}% • Risques: ${r['risks_summary']}', 
                      style: const TextStyle(fontSize: 11, color: Colors.grey)
                    ),
                    const SizedBox(height: 8),
                    const Text('Recommandations:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    
                    // LA CORRECTION EST ICI : List? ?? [] au lieu de List??? []
                    ...List<String>.from((r['recommendations'] as List?) ?? []).map((rec) => Padding(
                      padding: const EdgeInsets.only(top: 4), 
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right, size: 14), 
                          const SizedBox(width: 4), 
                          Expanded(child: Text(rec, style: const TextStyle(fontSize: 11)))
                        ]
                      )
                    )),
                  ]
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateWeekly() async {
    final tasks = await Supabase.instance.client.from('thix_execution_tasks').select('status').eq('project_code', widget.projectCode);
    final goals = await Supabase.instance.client.from('thix_execution_goals').select('current,target').eq('project_code', widget.projectCode);
    final risks = await Supabase.instance.client.from('thix_execution_risks').select('id').eq('project_code', widget.projectCode);
    
    final listTasks = tasks as List;
    final done = listTasks.where((t) => t['status'] == 'done').length;
    final progress = listTasks.isEmpty ? 0 : (done / listTasks.length * 100).round();

    await Supabase.instance.client.from('thix_execution_reports').insert({
      'project_code': widget.projectCode, 
      'period': 'weekly', 
      'title': 'Rapport Hebdomadaire ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      'progress_percent': progress, 
      'results': {'tasks_done': done, 'tasks_total': listTasks.length, 'goals': goals},
      'problems': [], 
      'risks_summary': '${(risks as List).length} risques actifs', 
      'finance_summary': 'Trésorerie ${ExecutionUtils.formatCurrency(45890)}', 
      'goals_summary': '${goals.length} objectifs', 
      'recommendations': [
        'Concentrez efforts sur acquisition', 
        'Finaliser conformité licence', 
        'Relancer fournisseurs en négociation'
      ]
    });
    
    setState(() {});
  }
}
