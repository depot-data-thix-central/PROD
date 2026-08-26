// lib/presentation/thix_ia/pages/execution/pipeline_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

/// Stages: lead → qualified → proposal → negotiation → won / lost
class PipelinePage extends ConsumerStatefulWidget {
  const PipelinePage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends ConsumerState<PipelinePage> {
  bool _saving = false;
  String _filter = 'all';

  static const stages = [
    'lead',
    'qualified',
    'proposal',
    'negotiation',
    'won',
    'lost',
  ];

  static const stageLabels = {
    'lead': 'Lead',
    'qualified': 'Qualifié',
    'proposal': 'Proposition',
    'negotiation': 'Négociation',
    'won': 'Gagné',
    'lost': 'Perdu',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(executionPipelineProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Pipeline commercial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionPipelineProvider(widget.projectCode)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (leads) {
          if (leads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hub_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Pipeline vide',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un lead'),
                  ),
                ],
              ),
            );
          }

          final filtered = _filter == 'all'
              ? leads
              : leads.where((l) => l['stage'] == _filter).toList();

          final wonValue = leads
              .where((l) => l['stage'] == 'won')
              .fold<double>(0, (s, l) => s + ((l['value'] as num?)?.toDouble() ?? 0));
          final openCount =
              leads.where((l) => !['won', 'lost'].contains(l['stage'])).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                    child: _Kpi('Leads', '${leads.length}', Colors.orange)),
                const SizedBox(width: 10),
                Expanded(child: _Kpi('Ouverts', '$openCount', Colors.indigo)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Kpi(
                        'Won \$',
                        wonValue.toStringAsFixed(0),
                        Colors.green)),
              ]),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip('Tous', _filter == 'all',
                        () => setState(() => _filter = 'all')),
                    ...stages.map((s) => _Chip(
                          stageLabels[s]!,
                          _filter == s,
                          () => setState(() => _filter = s),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...filtered.map((l) => _LeadCard(
                    lead: l,
                    onEdit: () => _showSheet(existing: l),
                    onStage: (stage) => _setStage(l, stage),
                    onDelete: () => _delete(l),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showSheet(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nouveau lead'),
      ),
    );
  }

  Future<void> _setStage(Map<String, dynamic> lead, String stage) async {
    await ref.read(supabaseClientProvider).from('thix_execution_pipeline').update({
      'stage': stage,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lead['id']);
    ref.invalidate(executionPipelineProvider(widget.projectCode));
  }

  Future<void> _delete(Map<String, dynamic> lead) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${lead['name']} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(supabaseClientProvider)
        .from('thix_execution_pipeline')
        .delete()
        .eq('id', lead['id']);
    ref.invalidate(executionPipelineProvider(widget.projectCode));
  }

  void _showSheet({Map<String, dynamic>? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final companyCtrl =
        TextEditingController(text: existing?['company']?.toString() ?? '');
    final valueCtrl = TextEditingController(
        text: (existing?['value'] ?? '').toString());
    final contactCtrl =
        TextEditingController(text: existing?['contact']?.toString() ?? '');
    String stage = existing?['stage']?.toString() ?? 'lead';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Nouveau lead' : 'Modifier lead',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nom du contact',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Entreprise',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Valeur estimée (\$)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Email / Téléphone',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: stage,
                  decoration: const InputDecoration(
                      labelText: 'Étape', border: OutlineInputBorder()),
                  items: stages
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(stageLabels[s]!)))
                      .toList(),
                  onChanged: (v) => setModal(() => stage = v ?? 'lead'),
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
                          'company': companyCtrl.text.trim(),
                          'value': double.tryParse(valueCtrl.text) ?? 0,
                          'contact': contactCtrl.text.trim(),
                          'stage': stage,
                          'updated_at': DateTime.now().toIso8601String(),
                        };
                        if (existing == null) {
                          await ref
                              .read(supabaseClientProvider)
                              .from('thix_execution_pipeline')
                              .insert(payload);
                        } else {
                          await ref
                              .read(supabaseClientProvider)
                              .from('thix_execution_pipeline')
                              .update(payload)
                              .eq('id', existing['id']);
                        }
                        ref.invalidate(
                            executionPipelineProvider(widget.projectCode));
                        if (mounted) Navigator.pop(context);
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
                    child: const Text('Enregistrer'),
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

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.onEdit,
    required this.onStage,
    required this.onDelete,
  });
  final Map<String, dynamic> lead;
  final VoidCallback onEdit, onDelete;
  final void Function(String) onStage;

  @override
  Widget build(BuildContext context) {
    final stage = lead['stage']?.toString() ?? 'lead';
    final value = (lead['value'] as num?)?.toDouble() ?? 0;
    final color = stage == 'won'
        ? Colors.green
        : stage == 'lost'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead['name']?.toString() ?? 'Lead',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${lead['company'] ?? ''} • \$${value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(_PipelinePageState.stageLabels[stage] ?? stage,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (_PipelinePageState.stages.contains(v)) onStage(v);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              ..._PipelinePageState.stages.map((s) => PopupMenuItem(
                  value: s,
                  child: Text('→ ${_PipelinePageState.stageLabels[s]}'))),
              const PopupMenuItem(
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

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
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
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
