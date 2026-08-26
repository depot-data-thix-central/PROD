// lib/presentation/thix_ia/pages/execution/tasks_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_task.dart';
import '../../core/utils/execution_utils.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _generating = false;
  bool _creating = false;
  String _search = '';
  String? _filterCategory;
  String? _filterPriority;

  static const _statuses = ['todo', 'doing', 'review', 'done'];
  static const _statusLabels = {
    'todo': 'À faire',
    'doing': 'En cours',
    'review': 'Validation',
    'done': 'Terminé',
  };
  static const _categories = [
    'Tech', 'Légal', 'Finance', 'RH', 'Marketing', 'Ops', 'Produit', 'Autre'
  ];
  static const _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksStream = ref.watch(executionTasksProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Auto-Kanban',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(executionTasksProvider(widget.projectCode)),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          isScrollable: true,
          tabs: const [
            Tab(text: 'À faire'),
            Tab(text: 'En cours'),
            Tab(text: 'Validation'),
            Tab(text: 'Terminé'),
          ],
        ),
      ),
      body: tasksStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(executionTasksProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (tasks) {
          final filtered = _applyFilters(tasks);
          final todo = filtered.where((t) => t.status == 'todo').toList();
          final doing = filtered.where((t) => t.status == 'doing').toList();
          final review = filtered.where((t) => t.status == 'review').toList();
          final done = filtered.where((t) => t.status == 'done').toList();
          final lateCount = tasks.where((t) => t.isLate).length;
          final donePct = tasks.isEmpty
              ? 0
              : (tasks.where((t) => t.status == 'done').length /
                      tasks.length *
                      100)
                  .round();

          return Column(
            children: [
              // KPIs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _KpiChip('Total', '${tasks.length}', Colors.indigo),
                    const SizedBox(width: 8),
                    _KpiChip('Retard', '$lateCount',
                        lateCount > 0 ? Colors.red : Colors.grey),
                    const SizedBox(width: 8),
                    _KpiChip('Avancement', '$donePct%', Colors.green),
                    const Spacer(),
                    if (_search.isNotEmpty ||
                        _filterCategory != null ||
                        _filterPriority != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _search = '';
                          _filterCategory = null;
                          _filterPriority = null;
                        }),
                        child: const Text('Reset filtres',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une tâche…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _TaskList(
                      tasks: todo,
                      projectCode: widget.projectCode,
                      empty: 'Aucune tâche à faire.\nGénérez avec l’IA ou créez-en une.',
                      onChanged: () => ref.invalidate(
                          executionTasksProvider(widget.projectCode)),
                    ),
                    _TaskList(
                      tasks: doing,
                      projectCode: widget.projectCode,
                      empty: 'Aucune tâche en cours',
                      onChanged: () => ref.invalidate(
                          executionTasksProvider(widget.projectCode)),
                    ),
                    _TaskList(
                      tasks: review,
                      projectCode: widget.projectCode,
                      empty: 'Aucune tâche en validation',
                      onChanged: () => ref.invalidate(
                          executionTasksProvider(widget.projectCode)),
                    ),
                    _TaskList(
                      tasks: done,
                      projectCode: widget.projectCode,
                      empty: 'Aucune tâche terminée',
                      onChanged: () => ref.invalidate(
                          executionTasksProvider(widget.projectCode)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai',
            onPressed: _generating ? null : _generateAiTasks,
            backgroundColor: Colors.indigo,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_generating ? 'Génération…' : 'Générer IA',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'manual',
            onPressed: _creating ? null : () => _showCreateSheet(),
            backgroundColor: Colors.white,
            foregroundColor: Colors.indigo,
            icon: const Icon(Icons.add_task),
            label: const Text('Nouvelle tâche',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<ExecutionTask> _applyFilters(List<ExecutionTask> tasks) {
    return tasks.where((t) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          (t.description?.toLowerCase().contains(q) ?? false) ||
          t.category.toLowerCase().contains(q);
      final matchCat =
          _filterCategory == null || t.category == _filterCategory;
      final matchPrio =
          _filterPriority == null || t.priority == _filterPriority;
      return matchSearch && matchCat && matchPrio;
    }).toList();
  }

  Future<void> _generateAiTasks() async {
    setState(() => _generating = true);
    try {
      // Demande l’objectif à l’utilisateur
      final objective = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: 'Lancement produit');
          return AlertDialog(
            title: const Text('Objectif pour l’IA'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Ex: Lancement MVP, Levée de fonds, Expansion…',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Générer'),
              ),
            ],
          );
        },
      );
      if (objective == null || objective.isEmpty) return;

      final created = await ref
          .read(executionAiServiceProvider)
          .autoGenerateTasksFromObjective(widget.projectCode, objective);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${created.length} tâches créées et enregistrées dans Supabase'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
      // Le stream realtime met à jour automatiquement
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur génération : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showCreateSheet({ExecutionTask? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final hoursCtrl = TextEditingController(
        text: existing?.estimatedHours?.toStringAsFixed(0) ?? '');
    String category = existing?.category ?? 'Ops';
    String priority = existing?.priority ?? 'medium';
    String status = existing?.status ?? 'todo';
    DateTime? dueDate = existing?.dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existing == null ? 'Nouvelle tâche' : 'Modifier la tâche',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Titre *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'Catégorie',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setModal(() => category = v ?? category),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priority,
                        decoration: InputDecoration(
                          labelText: 'Priorité',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _priorities
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(p.toUpperCase())))
                            .toList(),
                        onChanged: (v) =>
                            setModal(() => priority = v ?? priority),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _statuses
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(_statusLabels[s]!)))
                      .toList(),
                  onChanged: (v) => setModal(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Heures estimées',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dueDate == null
                        ? 'Échéance : non définie'
                        : 'Échéance : \( {dueDate!.day}/ \){dueDate!.month}/${dueDate!.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            dueDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setModal(() => dueDate = picked);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Le titre est obligatoire')));
                        return;
                      }
                      setState(() => _creating = true);
                      try {
                        final repo = ref.read(executionRepositoryProvider);
                        if (existing == null) {
                          final task = ExecutionTask(
                            id: ExecutionUtils.generateTaskId(widget.projectCode),
                            projectCode: widget.projectCode,
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            category: category,
                            priority: priority,
                            status: status,
                            dueDate: dueDate,
                            estimatedHours:
                                double.tryParse(hoursCtrl.text.trim()),
                            isAiSuggested: false,
                            origin: 'manual',
                            progress: status == 'done'
                                ? 100
                                : status == 'review'
                                    ? 80
                                    : status == 'doing'
                                        ? 30
                                        : 0,
                          );
                          await repo.createTask(task);
                        } else {
                          await repo.updateTask(existing.id, {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            'category': category,
                            'priority': priority,
                            'status': status,
                            'due_date': dueDate?.toIso8601String(),
                            'estimated_hours':
                                double.tryParse(hoursCtrl.text.trim()),
                            'progress': status == 'done'
                                ? 100
                                : status == 'review'
                                    ? 80
                                    : status == 'doing'
                                        ? 30
                                        : 0,
                            if (status == 'done')
                              'completed_at':
                                  DateTime.now().toIso8601String(),
                          });
                        }
                        if (mounted) Navigator.pop(context);
                        // Stream realtime → UI se met à jour seule
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Erreur : $e'),
                              backgroundColor: Colors.red));
                        }
                      } finally {
                        if (mounted) setState(() => _creating = false);
                      }
                    },
                    child: Text(
                      existing == null ? 'Créer dans Supabase' : 'Enregistrer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtres',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Catégorie', style: TextStyle(fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: _filterCategory == null,
                    onSelected: (_) {
                      setState(() => _filterCategory = null);
                      setModal(() {});
                    },
                  ),
                  ..._categories.map((c) => FilterChip(
                        label: Text(c),
                        selected: _filterCategory == c,
                        onSelected: (_) {
                          setState(() => _filterCategory = c);
                          setModal(() {});
                        },
                      )),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Priorité', style: TextStyle(fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: _filterPriority == null,
                    onSelected: (_) {
                      setState(() => _filterPriority = null);
                      setModal(() {});
                    },
                  ),
                  ..._priorities.map((p) => FilterChip(
                        label: Text(p.toUpperCase()),
                        selected: _filterPriority == p,
                        onSelected: (_) {
                          setState(() => _filterPriority = p);
                          setModal(() {});
                        },
                      )),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LISTE DE TÂCHES
// ─────────────────────────────────────────────────────────────
class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.tasks,
    required this.projectCode,
    required this.empty,
    required this.onChanged,
  });

  final List<ExecutionTask> tasks;
  final String projectCode;
  final String empty;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final t = tasks[i];
        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer ?'),
                    content: Text('Supprimer « ${t.title} » de Supabase ?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) async {
            try {
              await ref.read(executionRepositoryProvider).deleteTask(t.id);
              onChanged();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur suppression : $e')),
                );
              }
            }
          },
          child: _TaskCard(
            task: t,
            onStatus: (status) async {
              try {
                await ref
                    .read(executionRepositoryProvider)
                    .updateTaskStatus(t.id, status);
                // Stream realtime → pas besoin d’invalidate forcé
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            onComplete: () async {
              try {
                await ref
                    .read(executionRepositoryProvider)
                    .completeTask(t.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            onEdit: () {
              // Ouvre le sheet d’édition — on passe par le parent via context
              // Pour simplicité : on invalide + on peut étendre avec un callback
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD TÂCHE
// ─────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onStatus,
    required this.onComplete,
    required this.onEdit,
  });

  final ExecutionTask task;
  final void Function(String status) onStatus;
  final VoidCallback onComplete;
  final VoidCallback onEdit;

  Color get _prioColor {
    switch (task.priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = task;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.isLate ? Colors.red.shade300 : Colors.grey.shade200,
          width: t.isLate ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: t.status == 'done',
            activeColor: Colors.green,
            onChanged: (v) {
              if (v == true) {
                onComplete();
              } else {
                onStatus('doing');
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration:
                        t.status == 'done' ? TextDecoration.lineThrough : null,
                    color: t.status == 'done' ? Colors.grey : Colors.black87,
                  ),
                ),
                if (t.description != null && t.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniChip(t.category, Colors.indigo.shade50, Colors.indigo),
                    _MiniChip(
                      t.priority.toUpperCase(),
                      _prioColor.withOpacity(0.12),
                      _prioColor,
                    ),
                    if (t.isAiSuggested)
                      const _MiniChip('✦ IA', Color(0xFFE8EAFD), Color(0xFF3949AB)),
                    if (t.isLate)
                      const _MiniChip('RETARD', Color(0xFFFFEBEE), Colors.red),
                    if (t.dueDate != null)
                      _MiniChip(
                        '\( {t.dueDate!.day}/ \){t.dueDate!.month}',
                        Colors.grey.shade100,
                        Colors.grey.shade700,
                      ),
                    if (t.estimatedHours != null)
                      _MiniChip(
                        '${t.estimatedHours!.toStringAsFixed(0)}h',
                        Colors.grey.shade100,
                        Colors.grey.shade700,
                      ),
                  ],
                ),
                if (t.progress > 0 && t.status != 'done') ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.progress / 100,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation(_prioColor.withOpacity(0.8)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'delete') {
                // géré par Dismissible
              } else {
                onStatus(v);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'todo', child: Text('→ À faire')),
              PopupMenuItem(value: 'doing', child: Text('→ En cours')),
              PopupMenuItem(value: 'review', child: Text('→ Validation')),
              PopupMenuItem(value: 'done', child: Text('→ Terminé')),
              PopupMenuItem(value: 'blocked', child: Text('→ Bloqué')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.bg, this.fg);
  final String label;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
