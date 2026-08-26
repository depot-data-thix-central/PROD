// lib/presentation/thix_ia/pages/execution/team_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  bool _saving = false;
  String _filter = 'all'; // all | low_perf | high_perf

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(executionTeamProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Équipe & RH'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionTeamProvider(widget.projectCode)),
          ),
          IconButton(
            tooltip: 'Ajouter',
            icon: const Icon(Icons.person_add),
            onPressed: () => _showMemberSheet(),
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(executionTeamProvider(widget.projectCode)),
        ),
        data: (members) {
          if (members.isEmpty) {
            return _EmptyTeam(onAdd: () => _showMemberSheet());
          }

          final filtered = members.where((m) {
            final perf = (m['performance'] as num?)?.toInt() ?? 0;
            switch (_filter) {
              case 'low_perf':
                return perf < 60;
              case 'high_perf':
                return perf >= 80;
              default:
                return true;
            }
          }).toList();

          final avgPerf = members.isEmpty
              ? 0
              : (members
                          .map((m) => (m['performance'] as num?)?.toInt() ?? 0)
                          .reduce((a, b) => a + b) /
                      members.length)
                  .round();
          final totalTasks = members.fold<int>(
              0, (s, m) => s + ((m['tasks_completed'] as num?)?.toInt() ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI row
              Row(
                children: [
                  Expanded(
                      child: _KpiBox(
                          label: 'Membres',
                          value: '${members.length}',
                          color: Colors.indigo)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _KpiBox(
                          label: 'Perf. moy.',
                          value: '$avgPerf%',
                          color: avgPerf >= 70
                              ? Colors.green
                              : Colors.orange)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _KpiBox(
                          label: 'Tâches',
                          value: '$totalTasks',
                          color: Colors.teal)),
                ],
              ),
              const SizedBox(height: 14),

              // Late tasks alert (même logique que ta version)
              _LateTasksBanner(projectCode: widget.projectCode),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                        label: 'Tous',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all')),
                    _FilterChip(
                        label: 'Perf. basse',
                        selected: _filter == 'low_perf',
                        onTap: () => setState(() => _filter = 'low_perf')),
                    _FilterChip(
                        label: 'Top performers',
                        selected: _filter == 'high_perf',
                        onTap: () => setState(() => _filter = 'high_perf')),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('Aucun membre pour ce filtre',
                          style: TextStyle(color: Colors.grey))),
                )
              else
                ...filtered.map((m) => _MemberCard(
                      member: m,
                      onEdit: () => _showMemberSheet(existing: m),
                      onDelete: () => _confirmDelete(m),
                    )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showMemberSheet(),
        label: const Text('Ajouter membre'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${m['name']} » de l\'équipe ?'),
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
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(supabaseClientProvider)
          .from('thix_execution_team')
          .delete()
          .eq('id', m['id']);
      ref.invalidate(executionTeamProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Membre supprimé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMemberSheet({Map<String, dynamic>? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final roleCtrl = TextEditingController(
        text: existing?['role']?.toString() ?? 'Marketing');
    final perfCtrl = TextEditingController(
        text: (existing?['performance'] ?? 75).toString());
    final tasksCtrl = TextEditingController(
        text: (existing?['tasks_completed'] ?? 0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
            Text(existing == null ? 'Nouveau membre' : 'Modifier membre',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nom complet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Rôle (Tech, Marketing, Légal…)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: perfCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Performance %',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: tasksCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Tâches complétées',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    final payload = {
                      'project_code': widget.projectCode,
                      'name': nameCtrl.text.trim(),
                      'role': roleCtrl.text.trim(),
                      'performance': int.tryParse(perfCtrl.text) ?? 75,
                      'tasks_completed': int.tryParse(tasksCtrl.text) ?? 0,
                      'updated_at': DateTime.now().toIso8601String(),
                    };
                    if (existing == null) {
                      await ref
                          .read(supabaseClientProvider)
                          .from('thix_execution_team')
                          .insert(payload);
                    } else {
                      await ref
                          .read(supabaseClientProvider)
                          .from('thix_execution_team')
                          .update(payload)
                          .eq('id', existing['id']);
                    }
                    ref.invalidate(executionTeamProvider(widget.projectCode));
                    if (mounted) Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(existing == null
                              ? 'Membre ajouté'
                              : 'Membre mis à jour')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Erreur : $e'),
                          backgroundColor: Colors.red));
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: Text(
                    existing == null ? 'Ajouter le membre' : 'Enregistrer',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────────────

class _LateTasksBanner extends ConsumerWidget {
  const _LateTasksBanner({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(executionTasksFutureProvider(projectCode));
    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tasks) {
        final now = DateTime.now();
        final late = tasks.where((t) {
          if (t.status == 'done' || t.dueDate == null) return false;
          return now.isAfter(t.dueDate!);
        }).toList();
        if (late.isEmpty) return const SizedBox.shrink();

        final byName = <String, int>{};
        for (final t in late) {
          final name = t.assigneeName?.isNotEmpty == true
              ? t.assigneeName!
              : 'Non assigné';
          byName[name] = (byName[name] ?? 0) + 1;
        }
        final worst =
            byName.entries.reduce((a, b) => a.value > b.value ? a : b);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${worst.value} tâche(s) en retard chez ${worst.key}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = member['name']?.toString() ?? 'Membre';
    final role = member['role']?.toString() ?? 'Rôle non défini';
    final perf = (member['performance'] as num?)?.toInt() ?? 0;
    final tasks = (member['tasks_completed'] as num?)?.toInt() ?? 0;
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.indigo.shade50,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('$role • $tasks tâches',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$perf%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: perf >= 70
                          ? Colors.green
                          : perf >= 50
                              ? Colors.orange
                              : Colors.red)),
              const Text('Perf',
                  style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
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
        selectedColor: Colors.indigo.shade100,
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Aucun membre dans l\'équipe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Ajoute les rôles clés (Tech, Marketing, Légal…)\npour suivre la performance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter premier membre'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text('Erreur : $message', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
