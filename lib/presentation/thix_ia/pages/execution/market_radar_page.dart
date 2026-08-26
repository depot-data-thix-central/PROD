// lib/presentation/thix_ia/pages/execution/market_radar_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';

final marketSignalsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_execution_market_signals')
      .select()
      .eq('project_code', code)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(rows as List);
});

class MarketRadarPage extends ConsumerStatefulWidget {
  const MarketRadarPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<MarketRadarPage> createState() => _MarketRadarPageState();
}

class _MarketRadarPageState extends ConsumerState<MarketRadarPage> {
  bool _scanning = false;
  String _filterType = 'all';
  String _filterImpact = 'all';

  static const _types = [
    'Concurrent',
    'Prix',
    'Réglementation',
    'Tendance',
    'Opportunité',
    'Menace',
    'Techno',
  ];
  static const _impacts = ['Faible', 'Moyen', 'Élevé', 'Critique'];

  @override
  Widget build(BuildContext context) {
    final signalsAsync =
        ref.watch(marketSignalsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Market Radar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(marketSignalsProvider(widget.projectCode)),
          ),
        ],
      ),
      body: signalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur : $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .invalidate(marketSignalsProvider(widget.projectCode)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (signals) {
          final filtered = signals.where((s) {
            final typeOk = _filterType == 'all' ||
                s['type']?.toString() == _filterType;
            final impactOk = _filterImpact == 'all' ||
                s['impact']?.toString() == _filterImpact;
            return typeOk && impactOk;
          }).toList();

          final high = signals
              .where((s) =>
                  s['impact'] == 'Élevé' || s['impact'] == 'Critique')
              .length;
          final newCount =
              signals.where((s) => s['status'] == 'new').length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketSignalsProvider(widget.projectCode));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.radar, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Surveillance marché : concurrents, prix, réglementation, tendances. Scan IA via edge function.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // KPIs
                Row(
                  children: [
                    _Kpi('Signaux', '${signals.length}', Colors.indigo),
                    const SizedBox(width: 8),
                    _Kpi('Élevé+', '$high', Colors.red),
                    const SizedBox(width: 8),
                    _Kpi('Nouveaux', '$newCount', Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),

                // Scan IA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    onPressed: _scanning ? null : _runMarketScan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      _scanning
                          ? 'Scan en cours…'
                          : 'Lancer scan marché IA',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Filtres type
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip('Tous', _filterType == 'all',
                          () => setState(() => _filterType = 'all')),
                      ..._types.map((t) => _Chip(
                            t,
                            _filterType == t,
                            () => setState(() => _filterType = t),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Filtres impact
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip('Impact: tous', _filterImpact == 'all',
                          () => setState(() => _filterImpact = 'all')),
                      ..._impacts.map((i) => _Chip(
                            i,
                            _filterImpact == i,
                            () => setState(() => _filterImpact = i),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.radar_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucun signal marché',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Lancez un scan IA ou ajoutez un signal manuellement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showSignalSheet(),
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un signal'),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((s) => _SignalCard(
                        signal: s,
                        onTap: () => _showSignalDetail(s),
                        onStatus: (status) => _updateStatus(s, status),
                        onDelete: () => _deleteSignal(s),
                      )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSignalSheet(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Signal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Scan IA + fallback analyses + insert en base
  Future<void> _runMarketScan() async {
    setState(() => _scanning = true);
    final client = ref.read(supabaseClientProvider);
    final code = widget.projectCode;
    final collected = <Map<String, dynamic>>[];

    try {
      // 1) Edge function
      try {
        final res = await client.functions.invoke(
          'thix-ia-orchestrator',
          body: {
            'project_code': code,
            'action': 'market_radar',
          },
        );
        final data = res.data;
        if (data is Map && data['signals'] is List) {
          for (final s in data['signals'] as List) {
            if (s is Map) {
              collected.add(Map<String, dynamic>.from(s));
            }
          }
        }
      } catch (_) {
        // continue fallback
      }

      // 2) Fallback : analyses THIX existantes
      if (collected.isEmpty) {
        try {
          final analyses = await client
              .from('thix_analyses')
              .select('type, summary, created_at, confidence')
              .eq('project_code', code)
              .order('created_at', ascending: false)
              .limit(15);
          for (final a in analyses as List) {
            collected.add({
              'type': 'Tendance',
              'title': '${a['type'] ?? 'Analyse'} — mise à jour',
              'description': a['summary']?.toString(),
              'impact': 'Moyen',
              'source': 'THIX Analyses',
              'confidence': a['confidence'] ?? 0.6,
              'date': a['created_at'],
            });
          }
        } catch (_) {}
      }

      // 3) Fallback : risques marché / concurrent
      if (collected.isEmpty) {
        try {
          final risks = await client
              .from('thix_execution_risks')
              .select('title, category, probability, impact, status')
              .eq('project_code', code)
              .order('created_at', ascending: false)
              .limit(10);
          for (final r in risks as List) {
            final cat = (r['category'] ?? '').toString().toLowerCase();
            if (cat.contains('marché') ||
                cat.contains('concurr') ||
                cat.contains('market') ||
                cat.contains('prix')) {
              final p = (r['probability'] as num?)?.toInt() ?? 1;
              final i = (r['impact'] as num?)?.toInt() ?? 1;
              final level = p * i;
              collected.add({
                'type': cat.contains('prix') ? 'Prix' : 'Menace',
                'title': r['title']?.toString() ?? 'Risque marché',
                'description': 'Issu du module Risques',
                'impact': level >= 12
                    ? 'Critique'
                    : level >= 8
                        ? 'Élevé'
                        : 'Moyen',
                'source': 'Risques projet',
                'confidence': 0.75,
              });
            }
          }
        } catch (_) {}
      }

      // 4) Persist dans Supabase (évite doublons titre récents)
      final existing = await client
          .from('thix_execution_market_signals')
          .select('title')
          .eq('project_code', code)
          .order('created_at', ascending: false)
          .limit(30);
      final existingTitles = (existing as List)
          .map((e) => e['title']?.toString().toLowerCase() ?? '')
          .toSet();

      int inserted = 0;
      for (final s in collected) {
        final title = (s['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        if (existingTitles.contains(title.toLowerCase())) continue;

        await client.from('thix_execution_market_signals').insert({
          'project_code': code,
          'type': s['type']?.toString() ?? 'Tendance',
          'title': title,
          'description': s['description']?.toString(),
          'impact': s['impact']?.toString() ?? 'Moyen',
          'source': s['source']?.toString() ?? 'Scan IA',
          'url': s['url']?.toString(),
          'confidence': s['confidence'] ?? 0.7,
          'status': 'new',
        });
        inserted++;
      }

      ref.invalidate(marketSignalsProvider(widget.projectCode));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inserted > 0
                  ? '$inserted nouveau(x) signal(aux) enregistré(s)'
                  : collected.isEmpty
                      ? 'Aucun signal détecté — ajoutez manuellement ou vérifiez l’edge function'
                      : 'Signaux déjà à jour',
            ),
            backgroundColor:
                inserted > 0 ? Colors.green.shade700 : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur scan : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _updateStatus(
      Map<String, dynamic> signal, String status) async {
    try {
      await ref.read(supabaseClientProvider)
          .from('thix_execution_market_signals')
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', signal['id']);
      ref.invalidate(marketSignalsProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSignal(Map<String, dynamic> signal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(signal['title']?.toString() ?? ''),
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
          .from('thix_execution_market_signals')
          .delete()
          .eq('id', signal['id']);
      ref.invalidate(marketSignalsProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSignalDetail(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TypeChip(s['type']?.toString() ?? ''),
                const SizedBox(width: 8),
                _ImpactBadge(s['impact']?.toString() ?? 'Moyen'),
              ],
            ),
            const SizedBox(height: 12),
            Text(s['title']?.toString() ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            if (s['description'] != null) ...[
              const SizedBox(height: 8),
              Text(s['description'].toString(),
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
            ],
            const SizedBox(height: 12),
            Text('Source : ${s['source'] ?? '—'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (s['created_at'] != null)
              Text(
                'Date : ${s['created_at'].toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Marquer vu'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStatus(s, 'reviewed');
                  },
                ),
                ActionChip(
                  label: const Text('Action prise'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStatus(s, 'actioned');
                  },
                ),
                ActionChip(
                  label: const Text('Archiver'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStatus(s, 'archived');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSignalSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final sourceCtrl = TextEditingController(text: 'Manuel');
    String type = 'Tendance';
    String impact = 'Moyen';

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
                const Text('Nouveau signal marché',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
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
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _types
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setModal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: impact,
                  decoration: InputDecoration(
                    labelText: 'Impact',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _impacts
                      .map((i) =>
                          DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setModal(() => impact = v ?? impact),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sourceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Source',
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
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Titre obligatoire'),
                              backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      try {
                        await ref
                            .read(supabaseClientProvider)
                            .from('thix_execution_market_signals')
                            .insert({
                          'project_code': widget.projectCode,
                          'type': type,
                          'title': title,
                          'description': descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          'impact': impact,
                          'source': sourceCtrl.text.trim().isEmpty
                              ? 'Manuel'
                              : sourceCtrl.text.trim(),
                          'status': 'new',
                          'confidence': 1.0,
                        });
                        if (mounted) Navigator.pop(context);
                        ref.invalidate(
                            marketSignalsProvider(widget.projectCode));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Enregistrer dans Supabase',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
// WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.onTap,
    required this.onStatus,
    required this.onDelete,
  });
  final Map<String, dynamic> signal;
  final VoidCallback onTap;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final impact = signal['impact']?.toString() ?? 'Moyen';
    final status = signal['status']?.toString() ?? 'new';
    final date = signal['created_at']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: status == 'new'
              ? Border.all(color: Colors.indigo.shade100)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeChip(signal['type']?.toString() ?? ''),
                const SizedBox(width: 8),
                _ImpactBadge(impact),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                    if (v.startsWith('status:')) {
                      onStatus(v.replaceFirst('status:', ''));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'status:reviewed', child: Text('Marquer vu')),
                    PopupMenuItem(
                        value: 'status:actioned',
                        child: Text('Action prise')),
                    PopupMenuItem(
                        value: 'status:archived', child: Text('Archiver')),
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
            const SizedBox(height: 8),
            Text(
              signal['title']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            if (signal['description'] != null) ...[
              const SizedBox(height: 4),
              Text(
                signal['description'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(signal['source']?.toString() ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                if (status != 'new')
                  Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                if (date != null && date.length >= 10) ...[
                  const SizedBox(width: 8),
                  Text(date.substring(0, 10),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(type,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.indigo)),
    );
  }
}

class _ImpactBadge extends StatelessWidget {
  const _ImpactBadge(this.impact);
  final String impact;

  Color get _color {
    switch (impact) {
      case 'Critique':
        return Colors.red.shade800;
      case 'Élevé':
        return Colors.red;
      case 'Moyen':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(impact,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: _color));
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
                    fontWeight: FontWeight.w800, fontSize: 16, color: color)),
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
