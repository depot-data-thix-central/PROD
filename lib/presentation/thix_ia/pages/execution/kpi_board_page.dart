// lib/presentation/thix_ia/pages/execution/kpi_board_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

class KpiBoardPage extends ConsumerStatefulWidget {
  const KpiBoardPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<KpiBoardPage> createState() => _KpiBoardPageState();
}

class _KpiBoardPageState extends ConsumerState<KpiBoardPage> {
  bool _saving = false;
  String _filter = 'all'; // all | north_star | cohorte | acquisition | retention | revenue | product | ops
  String _sort = 'date'; // date | progress | name

  static const _categories = {
    'all': 'Tous',
    'north_star': 'North Star',
    'cohorte': 'Cohortes',
    'acquisition': 'Acquisition',
    'retention': 'Rétention',
    'revenue': 'Revenue',
    'product': 'Produit',
    'ops': 'Ops',
    'general': 'Général',
  };

  static const _categoryColors = {
    'north_star': Colors.indigo,
    'cohorte': Colors.purple,
    'acquisition': Colors.orange,
    'retention': Colors.teal,
    'revenue': Colors.green,
    'product': Colors.blue,
    'ops': Colors.brown,
    'general': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(executionKpiProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('KPI Board'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(executionKpiProvider(widget.projectCode)),
          ),
          IconButton(
            tooltip: 'Ajouter un KPI',
            icon: const Icon(Icons.add_chart),
            onPressed: () => _showKpiSheet(),
          ),
        ],
      ),
      body: kpiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(executionKpiProvider(widget.projectCode)),
        ),
        data: (kpis) {
          if (kpis.isEmpty) {
            return _EmptyKpi(onAdd: () => _showKpiSheet());
          }

          // Filter
          var list = _filter == 'all'
              ? List<Map<String, dynamic>>.from(kpis)
              : kpis
                  .where((k) =>
                      (k['category']?.toString() ?? 'general') == _filter)
                  .toList();

          // Sort
          list.sort((a, b) {
            switch (_sort) {
              case 'name':
                return (a['name']?.toString() ?? '')
                    .compareTo(b['name']?.toString() ?? '');
              case 'progress':
                final pa = _progress(a);
                final pb = _progress(b);
                return pb.compareTo(pa);
              default: // date
                final da = DateTime.tryParse(
                        a['period_date']?.toString() ?? '') ??
                    DateTime(1970);
                final db = DateTime.tryParse(
                        b['period_date']?.toString() ?? '') ??
                    DateTime(1970);
                return db.compareTo(da);
            }
          });

          // Global metrics
          final onTrack = kpis.where((k) => _progress(k) >= 0.8).length;
          final atRisk = kpis.where((k) {
            final p = _progress(k);
            return p > 0 && p < 0.5;
          }).length;
          final avgProgress = kpis.isEmpty
              ? 0.0
              : kpis.map(_progress).reduce((a, b) => a + b) / kpis.length;

          final northStars = kpis
              .where((k) => k['category']?.toString() == 'north_star')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Global KPI strip ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _KpiBox(
                      label: 'KPIs',
                      value: '${kpis.length}',
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiBox(
                      label: 'On track',
                      value: '$onTrack',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiBox(
                      label: 'À risque',
                      value: '$atRisk',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiBox(
                      label: 'Moyenne',
                      value: '${(avgProgress * 100).round()}%',
                      color: avgProgress >= 0.7
                          ? Colors.green
                          : avgProgress >= 0.4
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── North Star highlight ─────────────────────────
              if (northStars.isNotEmpty) ...[
                const Text(
                  'North Star Metrics',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...northStars.map((k) => _NorthStarCard(
                      kpi: k,
                      onEdit: () => _showKpiSheet(existing: k),
                      onDelete: () => _confirmDelete(k),
                    )),
                const SizedBox(height: 16),
              ],

              // ── Filters + sort ───────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.entries
                      .map((e) => _FilterChip(
                            label: e.value,
                            selected: _filter == e.key,
                            onTap: () => setState(() => _filter = e.key),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Trier : ',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  _SortChip(
                      label: 'Date',
                      selected: _sort == 'date',
                      onTap: () => setState(() => _sort = 'date')),
                  _SortChip(
                      label: 'Progression',
                      selected: _sort == 'progress',
                      onTap: () => setState(() => _sort = 'progress')),
                  _SortChip(
                      label: 'Nom',
                      selected: _sort == 'name',
                      onTap: () => setState(() => _sort = 'name')),
                ],
              ),
              const SizedBox(height: 12),

              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Aucun KPI pour ce filtre',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...list.map((k) => _KpiCard(
                      kpi: k,
                      onEdit: () => _showKpiSheet(existing: k),
                      onDelete: () => _confirmDelete(k),
                      onQuickUpdate: () => _quickUpdateValue(k),
                    )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showKpiSheet(),
        icon: const Icon(Icons.add_chart),
        label: const Text('Nouveau KPI'),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  double _progress(Map<String, dynamic> k) {
    final value = (k['value'] as num?)?.toDouble() ?? 0;
    final target = (k['target'] as num?)?.toDouble() ?? 0;
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 2.0);
  }

  Color _progressColor(double p) {
    if (p >= 1.0) return Colors.green;
    if (p >= 0.7) return Colors.lightGreen;
    if (p >= 0.4) return Colors.orange;
    return Colors.red;
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _confirmDelete(Map<String, dynamic> k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce KPI ?'),
        content: Text('« ${k['name']} » sera définitivement supprimé.'),
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
          .from('thix_execution_kpi_snapshots')
          .delete()
          .eq('id', k['id']);
      ref.invalidate(executionKpiProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KPI supprimé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _quickUpdateValue(Map<String, dynamic> k) {
    final ctrl = TextEditingController(
        text: (k['value'] as num?)?.toString() ?? '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mettre à jour « ${k['name']} »'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nouvelle valeur (${k['unit'] ?? ''})',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v == null) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(supabaseClientProvider)
                    .from('thix_execution_kpi_snapshots')
                    .update({
                  'value': v,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', k['id']);
                ref.invalidate(executionKpiProvider(widget.projectCode));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Valeur mise à jour')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showKpiSheet({Map<String, dynamic>? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final valueCtrl = TextEditingController(
        text: (existing?['value'] as num?)?.toString() ?? '');
    final targetCtrl = TextEditingController(
        text: (existing?['target'] as num?)?.toString() ?? '');
    final unitCtrl =
        TextEditingController(text: existing?['unit']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
    String category = existing?['category']?.toString() ?? 'general';
    String trend = existing?['trend']?.toString() ?? 'stable';
    DateTime periodDate = existing?['period_date'] != null
        ? (DateTime.tryParse(existing!['period_date'].toString()) ??
            DateTime.now())
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Nouveau KPI' : 'Modifier KPI',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du KPI *',
                      hintText: 'ex: MRR, Activation rate, NPS…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valueCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Valeur actuelle',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: targetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cible',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unité (%, \$, users, pts…)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.entries
                        .where((e) => e.key != 'all')
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        setModal(() => category = v ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: trend,
                    decoration: const InputDecoration(
                      labelText: 'Tendance',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'up', child: Text('↑ En hausse')),
                      DropdownMenuItem(
                          value: 'stable', child: Text('→ Stable')),
                      DropdownMenuItem(
                          value: 'down', child: Text('↓ En baisse')),
                    ],
                    onChanged: (v) => setModal(() => trend = v ?? 'stable'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Période', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${periodDate.day.toString().padLeft(2, '0')}/'
                      '${periodDate.month.toString().padLeft(2, '0')}/'
                      '${periodDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: periodDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModal(() => periodDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      border: OutlineInputBorder(),
                    ),
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
                            'value': double.tryParse(
                                    valueCtrl.text.replaceAll(',', '.')) ??
                                0,
                            'target': double.tryParse(
                                    targetCtrl.text.replaceAll(',', '.')) ??
                                0,
                            'unit': unitCtrl.text.trim(),
                            'category': category,
                            'trend': trend,
                            'period_date':
                                '\( {periodDate.year}- \){periodDate.month.toString().padLeft(2, '0')}-${periodDate.day.toString().padLeft(2, '0')}',
                            'notes': notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            'updated_at': DateTime.now().toIso8601String(),
                          };
                          if (existing == null) {
                            await ref
                                .read(supabaseClientProvider)
                                .from('thix_execution_kpi_snapshots')
                                .insert(payload);
                          } else {
                            await ref
                                .read(supabaseClientProvider)
                                .from('thix_execution_kpi_snapshots')
                                .update(payload)
                                .eq('id', existing['id']);
                          }
                          ref.invalidate(
                              executionKpiProvider(widget.projectCode));
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(existing == null
                                      ? 'KPI créé'
                                      : 'KPI mis à jour')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Erreur : $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                      child: Text(
                        existing == null ? 'Créer le KPI' : 'Enregistrer',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

// ═══════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════

class _NorthStarCard extends StatelessWidget {
  const _NorthStarCard({
    required this.kpi,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> kpi;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final value = (kpi['value'] as num?)?.toDouble() ?? 0;
    final target = (kpi['target'] as num?)?.toDouble() ?? 0;
    final unit = kpi['unit']?.toString() ?? '';
    final progress = target > 0 ? (value / target).clamp(0.0, 1.5) : 0.0;
    final color = progress >= 1.0
        ? Colors.green
        : progress >= 0.7
            ? Colors.indigo
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kpi['name']?.toString() ?? 'North Star',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value % 1 == 0
                    ? value.toInt().toString()
                    : value.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit,
                      style: TextStyle(fontSize: 13, color: color)),
                ),
              ],
              const Spacer(),
              Text(
                'cible ${target % 1 == 0 ? target.toInt() : target.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% de la cible',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.kpi,
    required this.onEdit,
    required this.onDelete,
    required this.onQuickUpdate,
  });
  final Map<String, dynamic> kpi;
  final VoidCallback onEdit, onDelete, onQuickUpdate;

  @override
  Widget build(BuildContext context) {
    final name = kpi['name']?.toString() ?? 'KPI';
    final value = (kpi['value'] as num?)?.toDouble() ?? 0;
    final target = (kpi['target'] as num?)?.toDouble() ?? 0;
    final unit = kpi['unit']?.toString() ?? '';
    final category = kpi['category']?.toString() ?? 'general';
    final trend = kpi['trend']?.toString() ?? 'stable';
    final progress = target > 0 ? (value / target).clamp(0.0, 2.0) : 0.0;
    final color = _KpiBoardPageState()._progressColor(progress);
    final catColor =
        _KpiBoardPageState._categoryColors[category] ?? Colors.grey;

    IconData trendIcon;
    Color trendColor;
    switch (trend) {
      case 'up':
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        break;
      case 'down':
        trendIcon = Icons.trending_down;
        trendColor = Colors.red;
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
    }

    final period = kpi['period_date']?.toString();
    String periodLabel = '';
    if (period != null) {
      final d = DateTime.tryParse(period);
      if (d != null) {
        periodLabel =
            '\( {d.day.toString().padLeft(2, '0')}/ \){d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _KpiBoardPageState._categories[category] ?? category,
                  style: TextStyle(
                      fontSize: 10,
                      color: catColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Icon(trendIcon, size: 18, color: trendColor),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'quick') onQuickUpdate();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'quick', child: Text('Maj rapide valeur')),
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value % 1 == 0
                    ? value.toInt().toString()
                    : value.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit,
                      style: TextStyle(fontSize: 12, color: color)),
                ),
              ],
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ ${target % 1 == 0 ? target.toInt() : target.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const Spacer(),
              if (periodLabel.isNotEmpty)
                Text(periodLabel,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% de la cible',
            style: TextStyle(fontSize: 11, color: color),
          ),
          if (kpi['notes'] != null &&
              kpi['notes'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              kpi['notes'].toString(),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
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
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.indigo.shade100,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _EmptyKpi extends StatelessWidget {
  const _EmptyKpi({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Aucun KPI défini',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Définis tes North Star metrics, cohortes\net indicateurs de croissance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_chart),
              label: const Text('Créer le premier KPI'),
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
