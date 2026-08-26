import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync =
        ref.watch(executionSuppliersProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Fournisseurs & Partenaires'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionSuppliersProvider(widget.projectCode)),
          ),
          IconButton(
            tooltip: 'Ajouter',
            icon: const Icon(Icons.add_business),
            onPressed: () => _showSupplierSheet(),
          ),
        ],
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text('Erreur : $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(
                      executionSuppliersProvider(widget.projectCode)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucun fournisseur',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ajoute partenaires, prestataires ou fournisseurs\npour ce projet.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _showSupplierSheet(),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter fournisseur'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(executionSuppliersProvider(widget.projectCode));
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: suppliers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = suppliers[i];
                return _SupplierCard(
                  supplier: s,
                  onEdit: () => _showSupplierSheet(existing: s),
                  onDelete: () => _confirmDelete(s),
                  onStatusChange: (status) => _updateStatus(s, status),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showSupplierSheet(),
        label: const Text('Ajouter fournisseur'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${s.name} » définitivement ?'),
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
          .from('thix_execution_suppliers')
          .delete()
          .eq('id', s.id);
      ref.invalidate(executionSuppliersProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fournisseur supprimé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur suppression : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStatus(Supplier s, String status) async {
    try {
      await ref.read(supabaseClientProvider).from('thix_execution_suppliers').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', s.id);
      ref.invalidate(executionSuppliersProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur statut : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSupplierSheet({Supplier? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categoryCtrl =
        TextEditingController(text: existing?.category ?? 'Équipement');
    final contactCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    double priceScore = existing?.priceScore ?? 80;
    double qualityScore = existing?.qualityScore ?? 80;
    double delayScore = existing?.delayScore ?? 80;
    double reliabilityScore = existing?.reliabilityScore ?? 80;
    String status = existing?.status ?? 'Recherche';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isEdit ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom société *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'Tech, Légal, Logistique…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Recherche', child: Text('Recherche')),
                      DropdownMenuItem(
                          value: 'Négociation', child: Text('Négociation')),
                      DropdownMenuItem(
                          value: 'Validé', child: Text('Validé')),
                      DropdownMenuItem(
                          value: 'Inactif', child: Text('Inactif')),
                    ],
                    onChanged: (v) => setModal(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact (email / téléphone)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Scores (0–100)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  _SliderScore(
                    label: 'Prix',
                    value: priceScore,
                    onChanged: (v) => setModal(() => priceScore = v),
                  ),
                  _SliderScore(
                    label: 'Qualité',
                    value: qualityScore,
                    onChanged: (v) => setModal(() => qualityScore = v),
                  ),
                  _SliderScore(
                    label: 'Délai',
                    value: delayScore,
                    onChanged: (v) => setModal(() => delayScore = v),
                  ),
                  _SliderScore(
                    label: 'Fiabilité',
                    value: reliabilityScore,
                    onChanged: (v) => setModal(() => reliabilityScore = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Le nom est obligatoire'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setState(() => _saving = true);
                              try {
                                final payload = {
                                  'project_code': widget.projectCode,
                                  'name': name,
                                  'category': categoryCtrl.text.trim().isEmpty
                                      ? 'Général'
                                      : categoryCtrl.text.trim(),
                                  'status': status,
                                  'price_score': priceScore,
                                  'quality_score': qualityScore,
                                  'delay_score': delayScore,
                                  'reliability_score': reliabilityScore,
                                  'updated_at':
                                      DateTime.now().toIso8601String(),
                                  if (contactCtrl.text.trim().isNotEmpty)
                                    'contact': contactCtrl.text.trim(),
                                  if (notesCtrl.text.trim().isNotEmpty)
                                    'notes': notesCtrl.text.trim(),
                                };

                                final client =
                                    ref.read(supabaseClientProvider);
                                if (isEdit) {
                                  await client
                                      .from('thix_execution_suppliers')
                                      .update(payload)
                                      .eq('id', existing!.id);
                                } else {
                                  await client
                                      .from('thix_execution_suppliers')
                                      .insert(payload);
                                }

                                if (mounted) Navigator.pop(context);
                                ref.invalidate(executionSuppliersProvider(
                                    widget.projectCode));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'Fournisseur mis à jour'
                                          : 'Fournisseur ajouté'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur : $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              }
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Carte fournisseur ─────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  Color _statusColor(String status) {
    switch (status) {
      case 'Validé':
        return Colors.green;
      case 'Négociation':
        return Colors.orange;
      case 'Inactif':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = supplier.calculatedScore;
    final statusColor = _statusColor(supplier.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business, size: 20, color: Colors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      supplier.category,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                  if (v.startsWith('status:')) {
                    onStatusChange(v.replaceFirst('status:', ''));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Modifier')),
                  const PopupMenuItem(
                      value: 'status:Recherche', child: Text('→ Recherche')),
                  const PopupMenuItem(
                      value: 'status:Négociation',
                      child: Text('→ Négociation')),
                  const PopupMenuItem(
                      value: 'status:Validé', child: Text('→ Validé')),
                  const PopupMenuItem(
                      value: 'status:Inactif', child: Text('→ Inactif')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  supplier.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Score ${score.toStringAsFixed(0)}/100',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                score >= 75
                    ? Colors.green
                    : score >= 50
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ScoreChip(label: 'Prix', value: supplier.priceScore),
              _ScoreChip(label: 'Qualité', value: supplier.qualityScore),
              _ScoreChip(label: 'Délai', value: supplier.delayScore),
              _ScoreChip(label: 'Fiabilité', value: supplier.reliabilityScore),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(
          '${value.toInt()}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SliderScore extends StatelessWidget {
  const _SliderScore({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('${value.toInt()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
