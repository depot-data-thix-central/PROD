// lib/presentation/thix_ia/pages/execution/risk_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';

class RiskPage extends ConsumerStatefulWidget {
  const RiskPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<RiskPage> createState() => _RiskPageState();
}

class _RiskPageState extends ConsumerState<RiskPage> {
  bool _saving = false;
  String _filter = 'all'; // all | critical | high | open

  @override
  Widget build(BuildContext context) {
    final risksAsync = ref.watch(executionRisksProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Risk Radar'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionRisksProvider(widget.projectCode)),
          ),
          IconButton(
            tooltip: 'Ajouter',
            icon: const Icon(Icons.add_alert),
            onPressed: () => _showRiskSheet(),
          ),
        ],
      ),
      body: risksAsync.when(
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
                  onPressed: () => ref
                      .invalidate(executionRisksProvider(widget.projectCode)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (risks) {
          if (risks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucun risque identifié',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cartographie les risques financiers, légaux,\nops et marché pour ce projet.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _showRiskSheet(),
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('Ajouter premier risque'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sorted = [...risks]..sort((a, b) => b.level.compareTo(a.level));
          final filtered = sorted.where((r) {
            switch (_filter) {
              case 'critical':
                return r.level >= 16;
              case 'high':
                return r.level >= 12;
              case 'open':
                return r.status == 'open';
              default:
                return true;
            }
          }).toList();

          final criticalCount =
              sorted.where((r) => r.level >= 16 && r.status == 'open').length;
          final openCount =
              sorted.where((r) => r.status == 'open').length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(executionRisksProvider(widget.projectCode));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // KPIs
                Row(
                  children: [
                    Expanded(
                      child: _KpiBox(
                        label: 'Ouverts',
                        value: '$openCount',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiBox(
                        label: 'Critiques',
                        value: '$criticalCount',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiBox(
                        label: 'Total',
                        value: '${sorted.length}',
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filtres
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      _FilterChip(
                        label: 'Ouverts',
                        selected: _filter == 'open',
                        onTap: () => setState(() => _filter = 'open'),
                      ),
                      _FilterChip(
                        label: 'Élevés',
                        selected: _filter == 'high',
                        onTap: () => setState(() => _filter = 'high'),
                      ),
                      _FilterChip(
                        label: 'Critiques',
                        selected: _filter == 'critical',
                        onTap: () => setState(() => _filter = 'critical'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mini radar top 4
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top risques',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ...sorted.take(4).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 72,
                                  height: 8,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (r.level / 25).clamp(0.0, 1.0),
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation(
                                        _levelColor(r.level),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    r.levelLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _levelColor(r.level),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Aucun risque pour ce filtre',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...filtered.map((r) => _RiskCard(
                        risk: r,
                        onEdit: () => _showRiskSheet(existing: r),
                        onResolve: () => _setStatus(r, 'closed'),
                        onMitigate: () => _setStatus(r, 'mitigated'),
                        onDelete: () => _confirmDelete(r),
                      )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : () => _showRiskSheet(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Color _levelColor(int level) {
    if (level >= 16) return Colors.red;
    if (level >= 12) return Colors.deepOrange;
    if (level >= 9) return Colors.orange;
    return Colors.green;
  }

  Future<void> _setStatus(RiskItem r, String status) async {
    try {
      await ref.read(supabaseClientProvider).from('thix_execution_risks').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', r.id);
      ref.invalidate(executionRisksProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'closed'
                ? 'Risque résolu'
                : 'Risque marqué comme atténué'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(RiskItem r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer le risque « ${r.title} » ?'),
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
          .from('thix_execution_risks')
          .delete()
          .eq('id', r.id);
      ref.invalidate(executionRisksProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRiskSheet({RiskItem? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final mitigationCtrl =
        TextEditingController(text: existing?.mitigationPlan ?? '');
    final ownerCtrl = TextEditingController(text: existing?.owner ?? '');

    String category = existing?.category ?? 'financier';
    int prob = existing?.probability ?? 3;
    int impact = existing?.impact ?? 3;
    String status = existing?.status ?? 'open';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final level = prob * impact;
          final levelLabel = level <= 4
              ? 'Faible'
              : level <= 9
                  ? 'Moyen'
                  : level <= 15
                      ? 'Élevé'
                      : 'Critique';

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
                    isEdit ? 'Modifier le risque' : 'Nouveau risque',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Titre du risque *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'financier', child: Text('Financier')),
                      DropdownMenuItem(
                          value: 'juridique', child: Text('Juridique')),
                      DropdownMenuItem(
                          value: 'commercial', child: Text('Commercial')),
                      DropdownMenuItem(
                          value: 'ops', child: Text('Opérationnel')),
                      DropdownMenuItem(
                          value: 'tech', child: Text('Technologique')),
                      DropdownMenuItem(
                          value: 'fournisseur', child: Text('Fournisseur')),
                      DropdownMenuItem(
                          value: 'RH', child: Text('RH')),
                      DropdownMenuItem(
                          value: 'marché', child: Text('Marché')),
                    ],
                    onChanged: (v) =>
                        setModal(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  Text('Probabilité : $prob / 5',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: prob.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$prob',
                    onChanged: (v) => setModal(() => prob = v.toInt()),
                  ),
                  Text('Impact : $impact / 5',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: impact.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$impact',
                    onChanged: (v) => setModal(() => impact = v.toInt()),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _levelColor(level).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Niveau : $level — $levelLabel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _levelColor(level),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mitigationCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Plan de mitigation',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Responsable (optionnel)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (isEdit) ...[
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
                            value: 'open', child: Text('Ouvert')),
                        DropdownMenuItem(
                            value: 'mitigated', child: Text('Atténué')),
                        DropdownMenuItem(
                            value: 'closed', child: Text('Résolu')),
                      ],
                      onChanged: (v) =>
                          setModal(() => status = v ?? status),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Le titre est obligatoire'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setState(() => _saving = true);
                              try {
                                final payload = {
                                  'project_code': widget.projectCode,
                                  'title': title,
                                  'category': category,
                                  'probability': prob,
                                  'impact': impact,
                                  'mitigation_plan':
                                      mitigationCtrl.text.trim().isEmpty
                                          ? null
                                          : mitigationCtrl.text.trim(),
                                  if (ownerCtrl.text.trim().isNotEmpty)
                                    'owner': ownerCtrl.text.trim(),
                                  'status': status,
                                  'updated_at':
                                      DateTime.now().toIso8601String(),
                                };

                                final client =
                                    ref.read(supabaseClientProvider);
                                if (isEdit) {
                                  await client
                                      .from('thix_execution_risks')
                                      .update(payload)
                                      .eq('id', existing!.id);
                                } else {
                                  await client
                                      .from('thix_execution_risks')
                                      .insert(payload);
                                }

                                if (mounted) Navigator.pop(context);
                                ref.invalidate(
                                    executionRisksProvider(widget.projectCode));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'Risque mis à jour'
                                          : 'Risque ajouté'),
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

// ─── Widgets ───────────────────────────────────────────────────

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.risk,
    required this.onEdit,
    required this.onResolve,
    required this.onMitigate,
    required this.onDelete,
  });

  final RiskItem risk;
  final VoidCallback onEdit;
  final VoidCallback onResolve;
  final VoidCallback onMitigate;
  final VoidCallback onDelete;

  Color get _color {
    if (risk.level >= 16) return Colors.red;
    if (risk.level >= 12) return Colors.deepOrange;
    if (risk.level >= 9) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: risk.level >= 15 ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  risk.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk.levelLabel,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'mitigate') onMitigate();
                  if (v == 'resolve') onResolve();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(
                      value: 'mitigate', child: Text('Marquer atténué')),
                  PopupMenuItem(
                      value: 'resolve', child: Text('Résoudre')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Chip(
                label: Text(risk.category, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Chip(
                label: Text(
                  'P(${risk.probability} × I${risk.impact}) = ${risk.level}',
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Chip(
                label: Text(
                  risk.status == 'open'
                      ? 'Ouvert'
                      : risk.status == 'mitigated'
                          ? 'Atténué'
                          : 'Résolu',
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (risk.mitigationPlan != null &&
              risk.mitigationPlan!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mitigation : ${risk.mitigationPlan}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
          if (risk.owner != null && risk.owner!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Owner : ${risk.owner}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
