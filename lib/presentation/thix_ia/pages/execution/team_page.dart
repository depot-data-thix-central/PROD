// lib/presentation/thix_ia/pages/execution/team_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<Map<String, dynamic>> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('thix_execution_team')
          .select()
          .eq('project_code', widget.projectCode);
      if (mounted) {
        setState(() {
          members = List<Map<String, dynamic>>.from(rows as List);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Équipe & Performance')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Aucun membre dans l\'équipe'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addMember,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Ajouter un membre'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client
                          .from('thix_execution_tasks')
                          .select('assignee_name,category,status,due_date')
                          .eq('project_code', widget.projectCode)
                          .then((v) => List<Map<String, dynamic>>.from(v as List)),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                        
                        final tasks = snap.data!;
                        final now = DateTime.now();

                        final lateTasks = tasks.where((t) {
                          if (t['due_date'] == null || t['status'] == 'done') return false;
                          final dueDate = DateTime.tryParse(t['due_date'].toString());
                          return dueDate != null && now.isAfter(dueDate);
                        }).toList();

                        if (lateTasks.isEmpty) return const SizedBox.shrink();

                        final groupedByName = <String, int>{};
                        final groupedByCategory = <String, int>{};

                        for (var t in lateTasks) {
                          final name = t['assignee_name']?.toString() ?? 'Non assigné';
                          final category = t['category']?.toString() ?? 'Général';
                          
                          groupedByName[name] = (groupedByName[name] ?? 0) + 1;
                          groupedByCategory[category] = (groupedByCategory[category] ?? 0) + 1;
                        }

                        if (groupedByName.isEmpty) return const SizedBox.shrink();

                        final worstMember = groupedByName.entries.reduce((a, b) => a.value > b.value ? a : b);
                        
                        final worstCategory = groupedByCategory.entries.isEmpty 
                            ? null 
                            : groupedByCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
                        
                        final categoryPercent = worstCategory != null && lateTasks.isNotEmpty
                            ? ((worstCategory.value / lateTasks.length) * 100).round()
                            : 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${worstMember.value} tâches en retard chez ${worstMember.key}${worstCategory != null ? ' — $categoryPercent% en ${worstCategory.key}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    ...members.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  m['name'] != null && m['name'].toString().isNotEmpty
                                      ? m['name'].toString().substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['name']?.toString() ?? 'Membre',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m['role'] ?? 'Rôle non défini'} • ${m['tasks_completed'] ?? 0} tâches',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${m['performance'] ?? 0}%',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                                  ),
                                  const Text('Perf', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        label: const Text('Ajouter membre'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  void _addMember() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Marketing');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouveau Membre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: 'Rôle (ex: Tech, Marketing, Légal)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  
                  await Supabase.instance.client.from('thix_execution_team').insert({
                    'project_code': widget.projectCode,
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'performance': 75,
                    'tasks_completed': 0,
                  });
                  
                  if (mounted) Navigator.pop(context);
                  _load();
                },
                child: const Text('Ajouter le membre', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
