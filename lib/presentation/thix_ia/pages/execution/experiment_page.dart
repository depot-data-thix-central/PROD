// lib/presentation/thix_ia/pages/execution/experiment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

class ExperimentPage extends ConsumerStatefulWidget {
  const ExperimentPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<ExperimentPage> createState() => _ExperimentPageState();
}

class _ExperimentPageState extends ConsumerState<ExperimentPage> {
  bool _busy = false;
  String _filter = 'all';

  static const _statuses = [
    'draft',
    'running',
    'validated',
    'partial',
    'invalidated',
    'archived',
  ];

  static const _methods = [
    'interview',
    'survey',
    'landing',
    'ab_test',
    'prototype',
    'other',
  ];

  static const _categories = [
    'Produit',
    'Prix',
    'Canal',
    'Message',
    'Marché',
  ];

  @override
  Widget build(BuildContext context) {
    final expsAsync =
        ref.watch(executionExperimentsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Experiment Center',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .invalidate(executionExperimentsProvider(widget.projectCode)),
          ),
        ],
      ),
      body: expsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: () => ref.invalidate(
                    executionExperimentsProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (exps) {
          final filtered = _filter == 'all'
              ? exps
              : exps.where((e) => e['status']?.toString() == _filter).toList();

          final validated =
              exps.where((e) => e['status'] == 'validated').length;
          final running =
              exps.where((e) => e['status'] == 'running').length;
          final invalidated =
              exps.where((e) => e['status'] == 'invalidated').length;
          final avgConf = exps.isEmpty
              ? 0
              : (exps.fold<int>(
                        0,
                        (s, e) =>
                            s + ((e['confidence'] as num?)?.toInt() ?? 0)) /
                    exps.length)
                  .round();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                  executionExperimentsProvider(widget.projectCode));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // KPIs
                Row(
                  children: [
                    _Kpi('Total', '${exps.length}', Colors.indigo),
                    const SizedBox(width: 8),
                    _Kpi('Validées', '$validated', Colors.green),
                    const SizedBox(width: 8),
                    _Kpi('En cours', '$running', Colors.orange),
                    const SizedBox(width: 8),
                    _Kpi('Conf. moy.', '$avgConf%', Colors.blue),
                  ],
                ),
                const SizedBox(height: 12),

                // Filtres
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip('Tous', _filter == 'all',
                          () => setState(() => _filter = 'all')),
                      _Chip('En cours', _filter == 'running',
                          () => setState(() => _filter = 'running')),
                      _Chip('Validées', _filter == 'validated',
                          () => setState(() => _filter = 'validated')),
                      _Chip('Partielles', _filter == 'partial',
                          () => setState(() => _filter = 'partial')),
                      _Chip('Invalidées', _filter == 'invalidated',
                          () => setState(() => _filter = 'invalidated')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (exps.isEmpty)
                  _EmptyState(onCreate: () => _showExperimentSheet())
                else if (filtered.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Aucune expérience pour ce filtre',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...filtered.map((e) => _ExperimentCard(
                        experiment: e,
                        onEdit: () => _showExperimentSheet(existing: e),
                        onAnalyze: () => _analyze(e),
                        onDelete: () => _delete(e),
                        onStatus: (s) => _setStatus(e, s),
                      )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _showExperimentSheet(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.science, color: Colors.white),
        label: const Text('Nouvelle hypothèse',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Score de confiance + statut + résultat (règles métier)
  Map<String, dynamic> _computeAnalysis({
    required int sample,
    required int interested,
    required int willing,
    int converted = 0,
  }) {
    if (sample <= 0) {
      return {
        'confidence': 0,
        'result': 'Échantillon vide',
        'status': 'draft',
      };
    }

    final interestRate = interested / sample;
    final payRate = willing / sample;
    final convertRate = converted > 0 ? converted / sample : 0.0;

    // Pondération : intérêt 35% + intention d'achat 45% + conversion 20%
    // Pénalité si échantillon trop faible (< 10)
    final sampleFactor = sample >= 30
        ? 1.0
        : sample >= 15
            ? 0.9
            : sample >= 10
                ? 0.8
                : 0.65;

    final raw = (interestRate * 35) +
        (payRate * 45) +
        (convertRate * 20);
    final confidence = (raw * sampleFactor).round().clamp(0, 100);

    String status;
    String result;
    if (confidence >= 70) {
      status = 'validated';
      result = 'Hypothèse validée';
    } else if (confidence >= 40) {
      status = 'partial';
      result = 'Validation partielle — itérer';
    } else {
      status = 'invalidated';
      result = 'Hypothèse invalidée';
    }

    // Si toujours en collecte et peu de data
    if (sample < 5 && status != 'validated') {
      status = 'running';
      result = 'Collecte en cours';
    }

    return {
      'confidence': confidence,
      'result': result,
      'status': status,
      'interest_rate': (interestRate * 100).round(),
      'pay_rate': (payRate * 100).round(),
    };
  }

  Future<void> _analyze(Map<String, dynamic> e) async {
    final sample = (e['sample_size'] as num?)?.toInt() ?? 0;
    final interested = (e['interested'] as num?)?.toInt() ?? 0;
    final willing = (e['willing_to_pay'] as num?)?.toInt() ?? 0;
    final converted = (e['converted'] as num?)?.toInt() ?? 0;

    final analysis = _computeAnalysis(
      sample: sample,
      interested: interested,
      willing: willing,
      converted: converted,
    );

    try {
      await ref.read(supabaseClientProvider)
          .from('thix_execution_experiments')
          .update({
        'confidence': analysis['confidence'],
        'result': analysis['result'],
        'status': analysis['status'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', e['id']);
      ref.invalidate(executionExperimentsProvider(widget.projectCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Analyse : \( {analysis['result']} ( \){analysis['confidence']}%)'),
            backgroundColor: analysis['status'] == 'validated'
                ? Colors.green.shade700
                : analysis['status'] == 'invalidated'
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _setStatus(Map<String, dynamic> e, String status) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('thix_execution_experiments')
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', e['id']);
      ref.invalidate(executionExperimentsProvider(widget.projectCode));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(e['hypothesis']?.toString() ?? ''),
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
          .read(supabaseClientProvider)
          .from('thix_execution_experiments')
          .delete()
          .eq('id', e['id']);
      ref.invalidate(executionExperimentsProvider(widget.projectCode));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showExperimentSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final hypoCtrl = TextEditingController(
        text: existing?['hypothesis']?.toString() ?? '');
    final sampleCtrl = TextEditingController(
        text: existing != null
            ? '${existing['sample_size'] ?? 0}'
            : '');
    final interestedCtrl = TextEditingController(
        text: existing != null ? '${existing['interested'] ?? 0}' : '');
    final payCtrl = TextEditingController(
        text: existing != null
            ? '${existing['willing_to_pay'] ?? 0}'
            : '');
    final convertedCtrl = TextEditingController(
        text: existing != null ? '${existing['converted'] ?? 0}' : '');
    final learningCtrl = TextEditingController(
        text: existing?['learning']?.toString() ?? '');
    final nextCtrl = TextEditingController(
        text: existing?['next_action']?.toString() ?? '');

    String method = existing?['method']?.toString() ?? 'interview';
    String category = existing?['category']?.toString() ?? 'Produit';
    if (!_methods.contains(method)) method = 'interview';
    if (!_categories.contains(category)) category = 'Produit';

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
                Text(
                  isEdit ? 'Modifier l\'expérience' : 'Tester une hypothèse',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hypoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Hypothèse *',
                    hintText:
                        'Ex: Les PME paieront 50\$/mois pour cette solution',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: method,
                        decoration: InputDecoration(
                          labelText: 'Méthode',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: _methods
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) =>
                            setModal(() => method = v ?? method),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'Catégorie',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setModal(() => category = v ?? category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sampleCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Échantillon',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: interestedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Intéressés',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: payCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Prêts à payer',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: convertedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Convertis',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: learningCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Apprentissage / insight',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nextCtrl,
                  decoration: InputDecoration(
                    labelText: 'Prochaine action',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    onPressed: _busy
                        ? null
                        : () async {
                            final hypo = hypoCtrl.text.trim();
                            if (hypo.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('L\'hypothèse est obligatoire'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            final sample =
                                int.tryParse(sampleCtrl.text.trim()) ?? 0;
                            final interested =
                                int.tryParse(interestedCtrl.text.trim()) ??
                                    0;
                            final willing =
                                int.tryParse(payCtrl.text.trim()) ?? 0;
                            final converted =
                                int.tryParse(convertedCtrl.text.trim()) ??
                                    0;

                            if (interested > sample ||
                                willing > sample ||
                                converted > sample) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Les compteurs ne peuvent pas dépasser l\'échantillon'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final analysis = _computeAnalysis(
                              sample: sample,
                              interested: interested,
                              willing: willing,
                              converted: converted,
                            );

                            setState(() => _busy = true);
                            try {
                              final payload = {
                                'project_code': widget.projectCode,
                                'hypothesis': hypo,
                                'method': method,
                                'category': category,
                                'sample_size': sample,
                                'interested': interested,
                                'willing_to_pay': willing,
                                'converted': converted,
                                'confidence': analysis['confidence'],
                                'result': analysis['result'],
                                'status': sample == 0
                                    ? 'draft'
                                    : analysis['status'],
                                'learning': learningCtrl.text.trim().isEmpty
                                    ? null
                                    : learningCtrl.text.trim(),
                                'next_action': nextCtrl.text.trim().isEmpty
                                    ? null
                                    : nextCtrl.text.trim(),
                                'updated_at':
                                    DateTime.now().toIso8601String(),
                              };

                              final client =
                                  ref.read(supabaseClientProvider);
                              if (isEdit) {
                                await client
                                    .from('thix_execution_experiments')
                                    .update(payload)
                                    .eq('id', existing!['id']);
                              } else {
                                await client
                                    .from('thix_execution_experiments')
                                    .insert(payload);
                              }

                              if (mounted) Navigator.pop(context);
                              ref.invalidate(executionExperimentsProvider(
                                  widget.projectCode));
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Erreur : $err'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _busy = false);
                              }
                            }
                          },
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            isEdit
                                ? 'Enregistrer'
                                : 'Créer dans Supabase',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
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
// CARD
// ═══════════════════════════════════════════════════════════════

class _ExperimentCard extends StatelessWidget {
  const _ExperimentCard({
    required this.experiment,
    required this.onEdit,
    required this.onAnalyze,
    required this.onDelete,
    required this.onStatus,
  });

  final Map<String, dynamic> experiment;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  Color _statusColor(String status) {
    switch (status) {
      case 'validated':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'invalidated':
        return Colors.red;
      case 'running':
        return Colors.blue;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'validated':
        return 'Validée';
      case 'partial':
        return 'Partielle';
      case 'invalidated':
        return 'Invalidée';
      case 'running':
        return 'En cours';
      case 'draft':
        return 'Brouillon';
      case 'archived':
        return 'Archivée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = experiment;
    final confidence = (e['confidence'] as num?)?.toInt() ?? 0;
    final status = e['status']?.toString() ?? 'running';
    final sample = (e['sample_size'] as num?)?.toInt() ?? 0;
    final interested = (e['interested'] as num?)?.toInt() ?? 0;
    final willing = (e['willing_to_pay'] as num?)?.toInt() ?? 0;
    final converted = (e['converted'] as num?)?.toInt() ?? 0;
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 8),
              if (e['category'] != null)
                Text(e['category'].toString(),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade600)),
              const Spacer(),
              Text('Confiance $confidence%',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                  if (v == 'analyze') onAnalyze();
                  if (v.startsWith('status:')) {
                    onStatus(v.replaceFirst('status:', ''));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'analyze', child: Text('Ré-analyser')),
                  PopupMenuItem(
                      value: 'status:running', child: Text('→ En cours')),
                  PopupMenuItem(
                      value: 'status:validated', child: Text('→ Validée')),
                  PopupMenuItem(
                      value: 'status:invalidated',
                      child: Text('→ Invalidée')),
                  PopupMenuItem(
                      value: 'status:archived', child: Text('→ Archiver')),
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
          const SizedBox(height: 10),
          Text('HYPOTHÈSE',
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(e['hypothesis']?.toString() ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          if (e['method'] != null) ...[
            const SizedBox(height: 4),
            Text('Méthode : ${e['method']}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricBox(label: 'Échantillon', value: '$sample')),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _MetricBox(label: 'Intéressés', value: '$interested')),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _MetricBox(label: 'Prêts à payer', value: '$willing')),
              if (converted > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                    child:
                        _MetricBox(label: 'Convertis', value: '$converted')),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (confidence / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  e['result']?.toString() ?? 'En cours',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: onAnalyze,
                child: const Text('Analyser', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (e['learning'] != null &&
              e['learning'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Insight : ${e['learning']}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic)),
          ],
          if (e['next_action'] != null &&
              e['next_action'].toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Next : ${e['next_action']}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.indigo.withOpacity(0.15),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.science_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Aucune expérimentation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Formulez une hypothèse, mesurez l\'intérêt\net la volonté de payer, puis validez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Créer une hypothèse'),
          ),
        ],
      ),
    );
  }
}
