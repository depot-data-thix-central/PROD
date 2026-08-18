// lib/presentation/thix_weeding/pages/staff/checklist/checklist_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class ChecklistPage extends ConsumerStatefulWidget {
  final String weddingId;
  const ChecklistPage({super.key, required this.weddingId});

  @override
  ConsumerState<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends ConsumerState<ChecklistPage> {
  String _filter = 'all';
  final _newTaskCtrl = TextEditingController();

  @override
  void dispose() {
    _newTaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _addQuick() async {
    final title = _newTaskCtrl.text.trim();
    if (title.isEmpty) return;

    try {
      await ref.read(checklistServiceProvider).create({
        'wedding_id': widget.weddingId,
        'title': title,
        'is_done': false,
      });
      _newTaskCtrl.clear();
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _toggleDone(ChecklistModel task, bool? value) async {
    try {
      // Méthode réelle du service = toggle (pas toggleDone)
      await ref.read(checklistServiceProvider).toggle(task.id, value ?? false);
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(checklistProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Checklist'),
        backgroundColor: Colors.white,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<ChecklistModel> tasks) {
          final total = tasks.length;
          final done = tasks.where((t) => t.isDone).length;
          final percent = total > 0 ? done / total : 0.0;

          final filtered = tasks.where((t) {
            if (_filter == 'done') return t.isDone;
            if (_filter == 'todo') return !t.isDone;
            return true;
          }).toList();

          return Column(
            children: [
              _ProgressCard(done: done, total: total, percent: percent),
              _FilterRow(
                filter: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              _QuickAddField(controller: _newTaskCtrl, onAdd: _addQuick),
              _TaskList(
                tasks: filtered,
                weddingId: widget.weddingId,
                onToggle: _toggleDone,
                onRefresh: () async =>
                    ref.invalidate(checklistProvider(widget.weddingId)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int done;
  final int total;
  final double percent;

  const _ProgressCard({
    required this.done,
    required this.total,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$done / $total tâches',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(percent * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF0B3B8F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF0B3B8F),
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      );
}

class _FilterRow extends StatelessWidget {
  final String filter;
  final Function(String) onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _Chip(
              label: 'Toutes',
              sel: filter == 'all',
              tap: () => onChanged('all'),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'À faire',
              sel: filter == 'todo',
              tap: () => onChanged('todo'),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Faites',
              sel: filter == 'done',
              tap: () => onChanged('done'),
            ),
          ],
        ),
      );
}

class _QuickAddField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _QuickAddField({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ajouter une tâche rapide...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.task_alt_outlined),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      );
}

class _TaskList extends StatelessWidget {
  final List<ChecklistModel> tasks;
  final String weddingId;
  final Function(ChecklistModel, bool?) onToggle;
  final Future<void> Function() onRefresh;

  const _TaskList({
    required this.tasks,
    required this.weddingId,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Expanded(child: Center(child: Text('Aucune tâche')));
    }
    return Expanded(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final ChecklistModel t = tasks[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Checkbox(
                  value: t.isDone,
                  activeColor: const Color(0xFF0B3B8F),
                  onChanged: (v) => onToggle(t, v),
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    decoration:
                        t.isDone ? TextDecoration.lineThrough : null,
                    fontWeight:
                        t.isDone ? FontWeight.normal : FontWeight.bold,
                    color: t.isDone ? Colors.grey : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'ID: ${t.id.substring(0, 6)} • ${t.dueDate != null ? t.dueDate.toString().substring(0, 10) : 'Sans date'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => context.push(
                    '/thix-weeding/staff/\( weddingId/checklist/ \){t.id}',
                  ),
                ),
                onTap: () => context.push(
                  '/thix-weeding/staff/\( weddingId/checklist/ \){t.id}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback tap;

  const _Chip({required this.label, required this.sel, required this.tap});

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: const Color(0xFF0B3B8F).withOpacity(0.15),
        onSelected: (_) => tap(),
      );
}
