// lib/presentation/thix_ia/pages/execution/roadmap_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

class RoadmapPage extends ConsumerStatefulWidget {
  const RoadmapPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<RoadmapPage> createState() => _RoadmapPageState();
}

class _RoadmapPageState extends ConsumerState<RoadmapPage> {
  bool _busy = false;
  String _filter = 'all'; // all | todo | doing | done

  static const _statusLabels = {
    'todo': 'À faire',
    'doing': 'En cours',
    'done': 'Terminé',
    'blocked': 'Bloqué',
  };

  static const _categories = [
    'Ops', 'Tech', 'Légal', 'Finance', 'Marketing', 'Produit', 'RH'
  ];

  @override
  Widget build(BuildContext context) {
    final roadmapAsync =
        ref.watch(executionRoadmapProvider(widget.projectCode));
    final tasksAsync =
        ref.watch(executionTasksFutureProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Roadmap de Lancement',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(executionRoadmapProvider(widget.projectCode)),
          ),
        ],
      ),
      body: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .invalidate(executionRoadmapProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (steps) {
          final tasks = tasksAsync.valueOrNull ?? [];
          final filtered = _filter == 'all'
              ? steps
              : steps.where((s) => s['status']?.toString() == _filter).toList();

          final done =
              steps.where((s) => s['status']?.toString() == 'done').length;
          final doing =
              steps.where((s) => s['status']?.toString() == 'doing').length;
          final total = steps.length;
          final pct = total == 0 ? 0 : (done / total * 100).round();

          return Column(
            children: [
              // KPIs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Kpi('Étapes', '$total', Colors.indigo),
                        const SizedBox(width: 8),
                        _Kpi('Terminées', '$done', Colors.green),
                        const SizedBox(width: 8),
                        _Kpi('En cours', '$doing', Colors.blue),
                        const SizedBox(width: 8),
                        _Kpi('Avancement', '$pct%', pct >= 70 ? Colors.green : Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          pct >= 70 ? Colors.green : Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Chip('Tous', _filter == 'all',
                              () => setState(() => _filter = 'all')),
                          _Chip('À faire', _filter == 'todo',
                              () => setState(() => _filter = 'todo')),
                          _Chip('En cours', _filter == 'doing',
                              () => setState(() => _filter = 'doing')),
                          _Chip('Terminées', _filter == 'done',
                              () => setState(() => _filter = 'done')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: steps.isEmpty
                    ? _EmptyRoadmap(
                        onCreateDefault: _createDefaultRoadmap,
                        onCreateCustom: () => _showStepSheet(),
                        busy: _busy,
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('Aucune étape pour ce filtre',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: filtered.length,
                            itemBuilder: (c, i) {
                              final s = filtered[i];
                              final globalIndex = steps.indexWhere(
                                  (x) => x['id'] == s['id']);
                              // Intersection tâches
                              final title = (s['title'] ?? '').toString().toLowerCase();
                              final relatedTasks = tasks.where((t) {
                                final tt = t.title.toLowerCase();
                                final cat = (s['category'] ?? '').toString().toLowerCase();
                                return tt.contains(title.split(' ').first) ||
                                    (cat.isNotEmpty &&
                                        t.category.toLowerCase() == cat);
                              }).toList();

                              return _TimelineStep(
                                step: s,
                                index: (s['order_index'] as num?)?.toInt() ??
                                    (globalIndex + 1),
                                isLast: i == filtered.length - 1,
                                relatedTasksCount: relatedTasks.length,
                                onValidate: () => _setStatus(s, 'done'),
                                onStart: () => _setStatus(s, 'doing'),
                                onReset: () => _setStatus(s, 'todo'),
                                onEdit: () => _showStepSheet(existing: s),
                                onDelete: () => _confirmDelete(s),
                              );
                            },
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
          if ((ref.watch(executionRoadmapProvider(widget.projectCode)).valueOrNull ?? [])
              .isEmpty)
            FloatingActionButton.extended(
              heroTag: 'default',
              onPressed: _busy ? null : _createDefaultRoadmap,
              backgroundColor: Colors.indigo.shade100,
              foregroundColor: Colors.indigo,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Template startup'),
            ),
          if ((ref.watch(executionRoadmapProvider(widget.projectCode)).valueOrNull ?? [])
              .isEmpty)
            const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _busy ? null : () => _showStepSheet(),
            backgroundColor: Colors.indigo,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Ajouter étape',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(Map<String, dynamic> step, String status) async {
    try {
      await ref
          .read(executionRepositoryProvider)
          .updateRoadmapStatus(step['id'].toString(), status);
      ref.invalidate(executionRoadmapProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> step) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${step['title']} » ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(executionRepositoryProvider)
          .deleteRoadmapStep(step['id'].toString());
      ref.invalidate(executionRoadmapProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Template générique startup (pas de mock métier spécifique)
  Future<void> _createDefaultRoadmap() async {
    setState(() => _busy = true);
    try {
      final existing = await ref
          .read(executionRepositoryProvider)
          .getRoadmap(widget.projectCode);
      if (existing.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Roadmap déjà existante — ajoutez des étapes manuellement')),
          );
        }
        return;
      }

      final defaults = [
        {
          'title': 'Validation Business Plan',
          'description': 'BP finalisé, chiffré et validé en interne',
          'order_index': 1,
          'status': 'todo',
          'month': 'M1',
          'category': 'Finance',
        },
        {
          'title': 'Structure juridique',
          'description': 'RCCM, NIF, statuts, comptes bancaires',
          'order_index': 2,
          'status': 'todo',
          'month': 'M1-M2',
          'category': 'Légal',
        },
        {
          'title': 'MVP / Prototype',
          'description': 'Produit minimum viable testable',
          'order_index': 3,
          'status': 'todo',
          'month': 'M2-M3',
          'category': 'Produit',
        },
        {
          'title': 'Premiers clients / pilotes',
          'description': 'Validation marché avec 5–20 utilisateurs',
          'order_index': 4,
          'status': 'todo',
          'month': 'M3-M4',
          'category': 'Marketing',
        },
        {
          'title': 'Opérations stabilisées',
          'description': 'Process, fournisseurs, équipe core',
          'order_index': 5,
          'status': 'todo',
          'month': 'M4-M5',
          'category': 'Ops',
        },
        {
          'title': 'Scale / levée',
          'description': 'Croissance ou tour de financement',
          'order_index': 6,
          'status': 'todo',
          'month': 'M6+',
          'category': 'Finance',
        },
      ];

      final repo = ref.read(executionRepositoryProvider);
      for (final d in defaults) {
        await repo.upsertRoadmapStep({
          ...d,
          'project_code': widget.projectCode,
          'progress': 0,
        });
      }
      ref.invalidate(executionRoadmapProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('6 étapes créées dans Supabase'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showStepSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final monthCtrl =
        TextEditingController(text: existing?['month']?.toString() ?? '');
    final orderCtrl = TextEditingController(
        text: (existing?['order_index'] ?? '').toString());
    String status = existing?['status']?.toString() ?? 'todo';
    String category = existing?['category']?.toString() ?? 'Ops';
    if (!_categories.contains(category)) category = 'Ops';

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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Modifier l\'étape' : 'Nouvelle étape',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
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
                      child: TextField(
                        controller: orderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ordre',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: monthCtrl,
                        decoration: InputDecoration(
                          labelText: 'Mois (ex: M3)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
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
                  items: _statusLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setModal(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
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
                  onChanged: (v) => setModal(() => category = v ?? category),
                ),
                const SizedBox(height: 20),
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
                              content: Text('Le titre est obligatoire')),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      try {
                        final currentSteps = await ref
                            .read(executionRepositoryProvider)
                            .getRoadmap(widget.projectCode);
                        final nextOrder = orderCtrl.text.trim().isNotEmpty
                            ? int.tryParse(orderCtrl.text.trim())
                            : (currentSteps.length + 1);

                        final payload = <String, dynamic>{
                          if (isEdit) 'id': existing!['id'],
                          'project_code': widget.projectCode,
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          'order_index': nextOrder ?? currentSteps.length + 1,
                          'status': status,
                          'month': monthCtrl.text.trim().isEmpty
                              ? null
                              : monthCtrl.text.trim(),
                          'category': category,
                          'progress': status == 'done'
                              ? 100
                              : status == 'doing'
                                  ? 50
                                  : 0,
                          if (status == 'done')
                            'completed_at':
                                DateTime.now().toIso8601String(),
                        };

                        await ref
                            .read(executionRepositoryProvider)
                            .upsertRoadmapStep(payload);
                        if (mounted) Navigator.pop(context);
                        ref.invalidate(
                            executionRoadmapProvider(widget.projectCode));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                    child: Text(isEdit ? 'Enregistrer' : 'Créer dans Supabase',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TIMELINE STEP
// ═══════════════════════════════════════════════════════════════

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.step,
    required this.index,
    required this.isLast,
    required this.relatedTasksCount,
    required this.onValidate,
    required this.onStart,
    required this.onReset,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> step;
  final int index;
  final bool isLast;
  final int relatedTasksCount;
  final VoidCallback onValidate;
  final VoidCallback onStart;
  final VoidCallback onReset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = step['status']?.toString() ?? 'todo';
    final isDone = status == 'done';
    final isCurrent = status == 'doing';
    final isBlocked = status == 'blocked';
    final title = step['title']?.toString() ?? 'Étape';
    final desc = step['description']?.toString() ?? '';
    final month = step['month']?.toString();
    final category = step['category']?.toString();
    final progress = (step['progress'] as num?)?.toInt() ?? 0;

    Color avatarColor;
    if (isDone) {
      avatarColor = Colors.green;
    } else if (isCurrent) {
      avatarColor = Colors.blue;
    } else if (isBlocked) {
      avatarColor = Colors.red;
    } else {
      avatarColor = Colors.grey.shade400;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text('$index',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 56,
                color: isDone ? Colors.green.shade300 : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? Colors.blue.shade200
                    : isBlocked
                        ? Colors.red.shade200
                        : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02), blurRadius: 6)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          )),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                        if (v == 'todo') onReset();
                        if (v == 'doing') onStart();
                        if (v == 'done') onValidate();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                            value: 'todo', child: Text('→ À faire')),
                        PopupMenuItem(
                            value: 'doing', child: Text('→ En cours')),
                        PopupMenuItem(
                            value: 'done', child: Text('→ Terminé')),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Badge(
                      {'todo': 'À faire', 'doing': 'En cours', 'done': 'Terminé'}[status] ?? status,

                      isDone
                          ? Colors.green
                          : isCurrent
                              ? Colors.blue
                              : isBlocked
                                  ? Colors.red
                                  : Colors.grey,
                    ),
                    if (month != null && month.isNotEmpty)
                      _Badge(month, Colors.indigo),
                    if (category != null && category.isNotEmpty)
                      _Badge(category, Colors.teal),
                    if (relatedTasksCount > 0)
                      _Badge('$relatedTasksCount tâches', Colors.orange),
                  ],
                ),
                if (progress > 0 && !isDone) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ],
                if (!isDone) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!isCurrent)
                        TextButton(
                          onPressed: onStart,
                          child: const Text('Démarrer',
                              style: TextStyle(fontSize: 12)),
                        ),
                      TextButton(
                        onPressed: onValidate,
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade700),
                        child: const Text('Valider',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.indigo.withOpacity(0.15),
      ),
    );
  }
}

class _EmptyRoadmap extends StatelessWidget {
  const _EmptyRoadmap({
    required this.onCreateDefault,
    required this.onCreateCustom,
    required this.busy,
  });
  final VoidCallback onCreateDefault;
  final VoidCallback onCreateCustom;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Roadmap vide',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Créez un template startup générique\nou ajoutez vos propres étapes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : onCreateDefault,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Template startup (6 étapes)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCreateCustom,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une étape'),
            ),
          ],
        ),
      ),
    );
  }
}
