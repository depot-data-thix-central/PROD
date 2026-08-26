// lib/presentation/thix_ia/pages/execution/compliance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';

class CompliancePage extends ConsumerStatefulWidget {
  const CompliancePage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends ConsumerState<CompliancePage> {
  bool _saving = false;
  String _filter = 'all'; // all | pending | ok | failed

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(executionComplianceProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Conformité légale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionComplianceProvider(widget.projectCode)),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSheet(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Aucune checklist de conformité',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un point'),
                  ),
                ],
              ),
            );
          }

          final filtered = items.where((c) {
            switch (_filter) {
              case 'pending':
                return c.status == 'pending' || c.status == 'todo';
              case 'ok':
                return c.status == 'verified' || c.status == 'ok';
              case 'failed':
                return c.status == 'failed' || c.status == 'non_conforme';
              default:
                return true;
            }
          }).toList();

          final okCount = items
              .where((c) => c.status == 'verified' || c.status == 'ok')
              .length;
          final pct =
              items.isEmpty ? 0 : ((okCount / items.length) * 100).round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                      child: _Kpi(
                          label: 'Points',
                          value: '${items.length}',
                          color: Colors.indigo)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Kpi(
                          label: 'Conformes',
                          value: '$okCount',
                          color: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Kpi(
                          label: 'Couverture',
                          value: '$pct%',
                          color: pct >= 80 ? Colors.green : Colors.orange)),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _Chip('Tous', _filter == 'all', () => setState(() => _filter = 'all')),
                  _Chip('En attente', _filter == 'pending',
                      () => setState(() => _filter = 'pending')),
                  _Chip('OK', _filter == 'ok', () => setState(() => _filter = 'ok')),
                  _Chip('Non conforme', _filter == 'failed',
                      () => setState(() => _filter = 'failed')),
                ]),
              ),
              const SizedBox(height: 12),
              ...filtered.map((c) => _ComplianceCard(
                    item: c,
                    onEdit: () => _showSheet(existing: c),
                    onVerify: () => _setStatus(c, 'verified'),
                    onFail: () => _setStatus(c, 'failed'),
                    onDelete: () => _delete(c),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showSheet(),
        icon: const Icon(Icons.gavel),
        label: const Text('Nouveau point'),
      ),
    );
  }

  Future<void> _setStatus(ComplianceItem c, String status) async {
    try {
      await ref.read(supabaseClientProvider).from('thix_execution_compliance').update({
        'status': status,
        'verified_at': status == 'verified'
            ? DateTime.now().toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', c.id);
      ref.invalidate(executionComplianceProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _delete(ComplianceItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${c.title} » ?'),
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
        .from('thix_execution_compliance')
        .delete()
        .eq('id', c.id);
    ref.invalidate(executionComplianceProvider(widget.projectCode));
  }

  void _showSheet({ComplianceItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String status = existing?.status ?? 'pending';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Nouveau point de conformité' : 'Modifier',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Titre (ex: Licence ARCA, RCCM…)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                    labelText: 'Statut', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('En attente')),
                  DropdownMenuItem(value: 'verified', child: Text('Vérifié / OK')),
                  DropdownMenuItem(value: 'failed', child: Text('Non conforme')),
                ],
                onChanged: (v) => setModal(() => status = v ?? 'pending'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Notes / source', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    setState(() => _saving = true);
                    try {
                      final payload = {
                        'project_code': widget.projectCode,
                        'title': titleCtrl.text.trim(),
                        'status': status,
                        'notes': notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        if (status == 'verified')
                          'verified_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      };
                      if (existing == null) {
                        await ref
                            .read(supabaseClientProvider)
                            .from('thix_execution_compliance')
                            .insert(payload);
                      } else {
                        await ref
                            .read(supabaseClientProvider)
                            .from('thix_execution_compliance')
                            .update(payload)
                            .eq('id', existing.id);
                      }
                      ref.invalidate(
                          executionComplianceProvider(widget.projectCode));
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
    );
  }
}

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({
    required this.item,
    required this.onEdit,
    required this.onVerify,
    required this.onFail,
    required this.onDelete,
  });
  final ComplianceItem item;
  final VoidCallback onEdit, onVerify, onFail, onDelete;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (item.status) {
      case 'verified':
      case 'ok':
        color = Colors.green;
        break;
      case 'failed':
      case 'non_conforme':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text(item.notes!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(item.status,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'verify') onVerify();
              if (v == 'fail') onFail();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'verify', child: Text('Marquer OK')),
              PopupMenuItem(value: 'fail', child: Text('Non conforme')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});
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
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
