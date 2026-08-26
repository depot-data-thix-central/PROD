// lib/presentation/thix_ia/pages/execution/investors_crm_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/investor_crm.dart';
import '../../providers/execution_provider.dart'; // supabaseClientProvider

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
final investorsProvider =
    FutureProvider.family<List<Investor>, String>((ref, projectCode) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_investors')
      .select()
      .eq('project_code', projectCode)
      .order('next_follow_up_at', ascending: true);
  return (rows as List).map((e) => Investor.fromJson(e)).toList();
});

final investorActivitiesProvider =
    FutureProvider.family<List<InvestorActivity>, String>((ref, investorId) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('thix_investor_activities')
      .select()
      .eq('investor_id', investorId)
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List).map((e) => InvestorActivity.fromJson(e)).toList();
});

// ─────────────────────────────────────────────────────────────
// PAGE PRINCIPALE
// ─────────────────────────────────────────────────────────────
class InvestorsCrmPage extends ConsumerStatefulWidget {
  const InvestorsCrmPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<InvestorsCrmPage> createState() => _InvestorsCrmPageState();
}

class _InvestorsCrmPageState extends ConsumerState<InvestorsCrmPage> {
  String _filter = 'all';
  String _search = '';
  bool _saving = false;

  static const stages = InvestorStage.values;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(investorsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Investisseurs CRM',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(investorsProvider(widget.projectCode)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (investors) {
          final filtered = investors.where((i) {
            final matchFilter = _filter == 'all' || i.stage.name == _filter;
            final q = _search.toLowerCase();
            final matchSearch = q.isEmpty ||
                i.name.toLowerCase().contains(q) ||
                i.firm.toLowerCase().contains(q) ||
                (i.email.toLowerCase().contains(q));
            return matchFilter && matchSearch;
          }).toList();

          final overdue = investors.where((i) => i.isOverdue).length;
          final pipelineValue = investors
              .where((i) =>
                  i.stage != InvestorStage.passed &&
                  i.stage != InvestorStage.committed)
              .fold<double>(0, (s, i) => s + (i.checkSizeMax ?? i.checkSizeMin ?? 0));
          final committed = investors
              .where((i) => i.stage == InvestorStage.committed)
              .fold<double>(0, (s, i) => s + (i.checkSizeMax ?? i.checkSizeMin ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPIs
              Row(children: [
                Expanded(child: _Kpi('Total', '${investors.length}', Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(child: _Kpi('Retards', '$overdue', Colors.red)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Kpi(
                        'Pipeline',
                        '\$${(pipelineValue / 1000).toStringAsFixed(0)}k',
                        Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Kpi(
                        'Engagé',
                        '\$${(committed / 1000).toStringAsFixed(0)}k',
                        Colors.green)),
              ]),
              const SizedBox(height: 14),

              // Search
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher nom, firm, email…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip('Tous', _filter == 'all',
                        () => setState(() => _filter = 'all')),
                    ...stages.map((s) => _Chip(
                          s.label,
                          _filter == s.name,
                          () => setState(() => _filter = s.name),
                          color: s.color,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Icon(Icons.handshake_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Aucun investisseur',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _showInvestorSheet(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Ajouter le premier'),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((inv) => _InvestorCard(
                      investor: inv,
                      onTap: () => _openDetail(inv),
                      onStage: (stage) => _setStage(inv, stage),
                      onFollowUp: () => _logFollowUp(inv),
                    )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showInvestorSheet(),
        backgroundColor: Colors.brown.shade700,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Nouvel investisseur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _setStage(Investor inv, InvestorStage stage) async {
    final client = ref.read(supabaseClientProvider);
    final updates = <String, dynamic>{
      'stage': stage.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (stage == InvestorStage.deckSent) {
      updates['deck_sent_at'] = DateTime.now().toIso8601String();
    }
    if (stage == InvestorStage.contacted || stage == InvestorStage.meeting) {
      updates['last_contact_at'] = DateTime.now().toIso8601String();
    }
    await client.from('thix_investors').update(updates).eq('id', inv.id);
    await _addActivity(inv.id, 'stage', 'Stage → ${stage.label}');
    ref.invalidate(investorsProvider(widget.projectCode));
  }

  Future<void> _logFollowUp(Investor inv) async {
    final next = DateTime.now().add(const Duration(days: 5));
    final client = ref.read(supabaseClientProvider);
    await client.from('thix_investors').update({
      'last_contact_at': DateTime.now().toIso8601String(),
      'next_follow_up_at': next.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', inv.id);
    await _addActivity(inv.id, 'followup', 'Follow-up enregistré');
    ref.invalidate(investorsProvider(widget.projectCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow-up noté · prochain le ${_fmt(next)}')),
      );
    }
  }

  Future<void> _addActivity(String investorId, String type, String title,
      {String? body}) async {
    final client = ref.read(supabaseClientProvider);
    await client.from('thix_investor_activities').insert({
      'investor_id': investorId,
      'project_code': widget.projectCode,
      'type': type,
      'title': title,
      'body': body,
    });
  }

  void _openDetail(Investor inv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvestorDetailPage(
          investor: inv,
          projectCode: widget.projectCode,
          onUpdated: () =>
              ref.invalidate(investorsProvider(widget.projectCode)),
        ),
      ),
    );
  }

  void _showInvestorSheet({Investor? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final firmCtrl = TextEditingController(text: existing?.firm ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final thesisCtrl = TextEditingController(text: existing?.thesis ?? '');
    final minCtrl = TextEditingController(
        text: existing?.checkSizeMin?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(
        text: existing?.checkSizeMax?.toStringAsFixed(0) ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    InvestorType type = existing?.type ?? InvestorType.vc;
    InvestorStage stage = existing?.stage ?? InvestorStage.identified;
    InvestorPriority priority = existing?.priority ?? InvestorPriority.medium;

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
                Text(existing == null ? 'Nouvel investisseur' : 'Modifier',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),
                _field(nameCtrl, 'Nom du contact *'),
                _field(firmCtrl, 'Firm / Fonds *'),
                _field(emailCtrl, 'Email *', keyboard: TextInputType.emailAddress),
                _field(phoneCtrl, 'Téléphone'),
                _field(thesisCtrl, 'Thèse d’investissement'),
                Row(children: [
                  Expanded(child: _field(minCtrl, 'Check min (\$)', keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(maxCtrl, 'Check max (\$)', keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 8),
                DropdownButtonFormField<InvestorType>(
                  value: type,
                  decoration: const InputDecoration(
                      labelText: 'Type', border: OutlineInputBorder()),
                  items: InvestorType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.name.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setModal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InvestorStage>(
                  value: stage,
                  decoration: const InputDecoration(
                      labelText: 'Stage', border: OutlineInputBorder()),
                  items: InvestorStage.values
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setModal(() => stage = v ?? stage),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InvestorPriority>(
                  value: priority,
                  decoration: const InputDecoration(
                      labelText: 'Priorité', border: OutlineInputBorder()),
                  items: InvestorPriority.values
                      .map((p) => DropdownMenuItem(
                          value: p, child: Text(p.name.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setModal(() => priority = v ?? priority),
                ),
                const SizedBox(height: 12),
                _field(notesCtrl, 'Notes', maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.brown.shade700),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          firmCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nom, firm et email obligatoires')));
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        final client = ref.read(supabaseClientProvider);
                        final payload = {
                          'project_code': widget.projectCode,
                          'name': nameCtrl.text.trim(),
                          'firm': firmCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          'type': type.name,
                          'stage': stage.name,
                          'priority': priority.name,
                          'check_size_min':
                              double.tryParse(minCtrl.text.trim()),
                          'check_size_max':
                              double.tryParse(maxCtrl.text.trim()),
                          'thesis': thesisCtrl.text.trim().isEmpty
                              ? null
                              : thesisCtrl.text.trim(),
                          'notes': notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          'next_follow_up_at': DateTime.now()
                              .add(const Duration(days: 3))
                              .toIso8601String(),
                          'updated_at': DateTime.now().toIso8601String(),
                        };
                        if (existing == null) {
                          await client.from('thix_investors').insert(payload);
                        } else {
                          await client
                              .from('thix_investors')
                              .update(payload)
                              .eq('id', existing.id);
                        }
                        ref.invalidate(
                            investorsProvider(widget.projectCode));
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
                    child: Text(
                        existing == null ? 'Créer' : 'Enregistrer',
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

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────
// CARD INVESTISSEUR
// ─────────────────────────────────────────────────────────────
class _InvestorCard extends StatelessWidget {
  const _InvestorCard({
    required this.investor,
    required this.onTap,
    required this.onStage,
    required this.onFollowUp,
  });
  final Investor investor;
  final VoidCallback onTap;
  final void Function(InvestorStage) onStage;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final inv = investor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inv.isOverdue ? Colors.red.shade200 : Colors.grey.shade200,
            width: inv.isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: inv.stage.color.withOpacity(0.15),
                  child: Text(
                    inv.name.isNotEmpty ? inv.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: inv.stage.color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${inv.firm} · ${inv.type.name.toUpperCase()}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: inv.stage.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(inv.stage.label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: inv.stage.color)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(inv.checkSizeLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (inv.nextFollowUpAt != null) ...[
                  Icon(
                    inv.isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.event_outlined,
                    size: 14,
                    color: inv.isOverdue ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${inv.nextFollowUpAt!.day}/${inv.nextFollowUpAt!.month}',
                    style: TextStyle(
                        fontSize: 11,
                        color: inv.isOverdue ? Colors.red : Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onFollowUp,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Follow-up', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.brown.shade700,
                      padding: EdgeInsets.zero),
                ),
                const Spacer(),
                PopupMenuButton<InvestorStage>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: onStage,
                  itemBuilder: (_) => InvestorStage.values
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL PAGE
// ─────────────────────────────────────────────────────────────
class InvestorDetailPage extends ConsumerWidget {
  const InvestorDetailPage({
    super.key,
    required this.investor,
    required this.projectCode,
    required this.onUpdated,
  });
  final Investor investor;
  final String projectCode;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actsAsync = ref.watch(investorActivitiesProvider(investor.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(investor.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // Ouvre le même sheet d’édition (passer existing)
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investor.firm,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(investor.email, style: TextStyle(color: Colors.grey.shade700)),
                if (investor.phone != null)
                  Text(investor.phone!, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(investor.stage.label),
                      backgroundColor: investor.stage.color.withOpacity(0.15),
                      labelStyle: TextStyle(
                          color: investor.stage.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                    Chip(
                      label: Text(investor.checkSizeLabel),
                      backgroundColor: Colors.green.shade50,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                    Chip(
                      label: Text(investor.priority.name.toUpperCase()),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                if (investor.thesis != null && investor.thesis!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Thèse', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(investor.thesis!, style: const TextStyle(fontSize: 13)),
                ],
                if (investor.notes != null && investor.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Notes', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(investor.notes!, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Timeline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          actsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (acts) {
              if (acts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                      child: Text('Aucune activité',
                          style: TextStyle(color: Colors.grey))),
                );
              }
              return Column(
                children: acts
                    .map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(_iconFor(a.type),
                                  size: 18, color: Colors.brown),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    if (a.body != null)
                                      Text(a.body!,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (a.createdAt != null)
                                Text(
                                  '${a.createdAt!.day}/${a.createdAt!.month}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown.shade700,
        onPressed: () async {
          final client = ref.read(supabaseClientProvider);
          await client.from('thix_investor_activities').insert({
            'investor_id': investor.id,
            'project_code': projectCode,
            'type': 'note',
            'title': 'Note manuelle',
            'body': 'Ajoutée depuis le détail',
          });
          ref.invalidate(investorActivitiesProvider(investor.id));
        },
        child: const Icon(Icons.note_add, color: Colors.white),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'email': return Icons.email_outlined;
      case 'call': return Icons.phone_outlined;
      case 'meeting': return Icons.event;
      case 'deck': return Icons.slideshow;
      case 'followup': return Icons.replay;
      case 'stage': return Icons.flag_outlined;
      default: return Icons.note_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────────────────────────
class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap, {this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: (color ?? Colors.brown).withOpacity(0.2),
        checkmarkColor: color ?? Colors.brown,
      ),
    );
  }
}
