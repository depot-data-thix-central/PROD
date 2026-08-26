import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_task.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksStream = ref.watch(executionTasksProvider(projectCode));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('Auto-Kanban'), bottom: const TabBar(tabs: [Tab(text: 'À faire'), Tab(text: 'En cours'), Tab(text: 'Validation'), Tab(text: 'Terminé')])),
        body: tasksStream.when(
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error: (e,s)=> Center(child: Text('Erreur $e')),
          data: (tasks){
            final todo = tasks.where((t)=> t.status=='todo').toList();
            final doing = tasks.where((t)=> t.status=='doing').toList();
            final review = tasks.where((t)=> t.status=='review').toList();
            final done = tasks.where((t)=> t.status=='done').toList();
            return TabBarView(children: [
              _TaskList(tasks: todo, projectCode: projectCode, empty: 'Aucune tâche. Générez avec IA.'),
              _TaskList(tasks: doing, projectCode: projectCode, empty: 'Aucune en cours'),
              _TaskList(tasks: review, projectCode: projectCode, empty: 'Aucune en validation'),
              _TaskList(tasks: done, projectCode: projectCode, empty: 'Aucune terminée'),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async => await ref.read(executionAiServiceProvider).autoGenerateTasksFromObjective(projectCode, 'Lancement produit'),
          icon: const Icon(Icons.auto_awesome), label: const Text('Générer tâches IA'),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.projectCode, required this.empty});
  final List<ExecutionTask> tasks; final String projectCode; final String empty;
  @override Widget build(BuildContext context, WidgetRef ref) {
    if(tasks.isEmpty) return Center(child: Text(empty));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      separatorBuilder: (_,__)=> const SizedBox(height: 8),
      itemBuilder: (c,i){
        final t = tasks[i];
        return Dismissible(
          key: Key(t.id),
          background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16), child: const Icon(Icons.check, color: Colors.white)),
          onDismissed: (_) async { await ref.read(executionRepositoryProvider).completeTask(t.id); },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.isLate? Colors.red : Colors.grey.shade200)),
            child: Row(children: [
              Checkbox(value: t.status=='done', onChanged: (v) async {
                if(v==true) await ref.read(executionRepositoryProvider).completeTask(t.id);
                else await ref.read(executionRepositoryProvider).updateTaskStatus(t.id, 'doing');
              }),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: t.status=='done'? TextDecoration.lineThrough : null)),
                Row(children: [Chip(label: Text(t.category, style: const TextStyle(fontSize: 9)), visualDensity: VisualDensity.compact), const SizedBox(width: 6), if(t.isAiSuggested) const Chip(label: Text('✦ IA', style: TextStyle(fontSize: 8)), backgroundColor: Color(0xFFE8EAFD))]),
                if(t.dueDate!= null) Text('Échéance: ${t.dueDate!.day}/${t.dueDate!.month}', style: TextStyle(fontSize: 10, color: t.isLate? Colors.red : Colors.grey)),
              ])),
              PopupMenuButton<String>(onSelected: (v) async => await ref.read(executionRepositoryProvider).updateTaskStatus(t.id, v), itemBuilder: (_)=> const [PopupMenuItem(value: 'todo', child: Text('À faire')), PopupMenuItem(value: 'doing', child: Text('En cours')), PopupMenuItem(value: 'review', child: Text('Validation')), PopupMenuItem(value: 'done', child: Text('Terminé'))]),
            ]),
          ),
        );
      },
    );
  }
}
