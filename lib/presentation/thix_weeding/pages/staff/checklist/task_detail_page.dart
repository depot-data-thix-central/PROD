// lib/presentation/thix_weeding/pages/staff/checklist/task_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';


final checklistDetailProvider = FutureProvider.family<ChecklistModel, String>((ref, taskId) async {
  return await ref.read(checklistServiceProvider).getById(taskId);
});

class TaskDetailPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String taskId;
  const TaskDetailPage({super.key, required this.weddingId, required this.taskId});
  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _isDone = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ================= ACTIONS - Tes Services =================

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre requis')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(checklistServiceProvider).update(widget.taskId, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty? null : _descCtrl.text.trim(),
        'due_date': _dueDate?.toIso8601String().split('T')[0],
        'is_done': _isDone,
      });
      ref.invalidate(checklistDetailProvider(widget.taskId));
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la tâche?'),
        content: const Text('Action irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok!= true) return;
    try {
      await ref.read(checklistServiceProvider).delete(widget.taskId);
      ref.invalidate(checklistProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked!= null) setState(() => _dueDate = picked);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(checklistDetailProvider(widget.taskId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Détail tâche'),
        backgroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete)],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (ChecklistModel task) {
          if (!_isInitialized) {
            _titleCtrl.text = task.title;
            _descCtrl.text = task.description?? '';
            _isDone = task.isDone;
            _dueDate = task.dueDate;
            _isInitialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionCard(title: 'Tâche', children: [
                _TitleField(controller: _titleCtrl),
                const SizedBox(height: 16),
                _DescriptionField(controller: _descCtrl),
              ]),
              const SizedBox(height: 16),
              _SectionCard(title: 'Planification', children: [
                _DueDateTile(dueDate: _dueDate, onTap: _pickDueDate, onClear: () => setState(() => _dueDate = null)),
                const Divider(),
                _DoneSwitch(value: _isDone, onChanged: (v) => setState(() => _isDone = v)),
              ]),
              const SizedBox(height: 16),
              _MetaCard(task: task),
              const SizedBox(height: 24),
              _SaveButton(isLoading: _isLoading, onSave: _save),
            ],
          );
        },
      ),
    );
  }
}

// ================= WIDGETS INTERNES - Lecture claire =================

class _SectionCard extends StatelessWidget {
  final String title; final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0B3B8F))),
          const SizedBox(height: 16),
         ...children,
        ]),
      );
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  const _TitleField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.task_alt)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  const _DescriptionField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true));
}

class _DueDateTile extends StatelessWidget {
  final DateTime? dueDate; final VoidCallback onTap; final VoidCallback onClear;
  const _DueDateTile({required this.dueDate, required this.onTap, required this.onClear});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today, color: Color(0xFF0B3B8F)),
        title: Text(dueDate == null? 'Ajouter une échéance' : 'Échéance: ${dueDate!.day}/${dueDate!.month}/${dueDate!.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: dueDate == null? const Text('Optionnel') : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dueDate!= null) IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear),
          const Icon(Icons.edit, size: 18),
        ]),
        onTap: onTap,
      );
}

class _DoneSwitch extends StatelessWidget {
  final bool value; final Function(bool) onChanged;
  const _DoneSwitch({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile(title: const Text('Terminée', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(value? 'Cette tâche est faite' : 'Encore à faire'), value: value, activeColor: Colors.green, onChanged: onChanged);
}

class _MetaCard extends StatelessWidget {
  final ChecklistModel task;
  const _MetaCard({required this.task});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ID unique: ${task.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('Catégorie: ${task.category} • Ordre: ${task.orderIndex}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('Créé le: ${task.createdAt.toString().substring(0, 19)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );
}

class _SaveButton extends StatelessWidget {
  final bool isLoading; final VoidCallback onSave;
  const _SaveButton({required this.isLoading, required this.onSave});
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: isLoading? null : onSave,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: isLoading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
      );
}
