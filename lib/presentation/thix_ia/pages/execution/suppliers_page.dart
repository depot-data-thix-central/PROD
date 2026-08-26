// lib/presentation/thix_ia/pages/execution/suppliers_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_support.dart';
import '../../models/execution_task.dart';
import '../../models/execution_finance.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  bool _saving = false;
  String _search = '';
  String _filterStatus = 'all';
  String? _filterCategory;

  static const _statuses = ['Recherche', 'Négociation', 'Validé', 'Inactif'];
  static const _categories = [
    'Tech', 'Légal', 'Logistique', 'Équipement', 'Matière première',
    'Marketing', 'Finance', 'RH', 'Général', 'Autre'
  ];

  @override
  Widget build(BuildContext context) {
    final suppliersAsync =
        ref.watch(executionSuppliersProvider(widget.projectCode));
    final risksAsync = ref.watch(executionRisksProvider(widget.projectCode));
    final tasksAsync = ref.watch(executionTasksFutureProvider(widget.projectCode));
    final txsAsync =
        ref.watch(executionTransactionsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Fournisseurs & Partenaires',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(executionSuppliersProvider(widget.projectCode));
              ref.invalidate(executionRisksProvider(widget.projectCode));
              ref.invalidate(executionTasksFutureProvider(widget.projectCode));
              ref.invalidate(
                  executionTransactionsProvider(widget.projectCode));
            },
          ),
        ],
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(executionSuppliersProvider(widget.projectCode)),
        ),
        data: (suppliers) {
          final risks = risksAsync.valueOrNull ?? [];
          final tasks = tasksAsync.valueOrNull ?? [];
          final txs = txsAsync.valueOrNull ?? [];

          final filtered = _applyFilters(suppliers);
          final validated =
              suppliers.where((s) => s.status == 'Validé').length;
          final negotiating =
              suppliers.where((s) => s.status == 'Négociation').length;
          final avgScore = suppliers.isEmpty
              ? 0.0
              : suppliers.fold<double>(0, (a, s) => a + s.calculatedScore) /
                  suppliers.length;
          final supplierRisks = risks
              .where((r) =>
                  r.category.toLowerCase().contains('fourniss') ||
                  r.title.toLowerCase().contains('fourniss') ||
                  r.title.toLowerCase().contains('prestataire'))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(executionSuppliersProvider(widget.projectCode));
            },
            child: CustomScrollView(
              slivers: [
                // KPIs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      children: [
                        _Kpi('Total', '${suppliers.length}', Colors.indigo),
                        const SizedBox(width: 8),
                        _Kpi('Validés', '$validated', Colors.green),
                        const SizedBox(width: 8),
                        _Kpi('Négoc.', '$negotiating', Colors.orange),
                        const SizedBox(width: 8),
                        _Kpi('Score moy.', avgScore.toStringAsFixed(0),
                            avgScore >= 70 ? Colors.green : Colors.orange),
                      ],
                    ),
                  ),
                ),

                // Intersection alertes
                if (supplierRisks.isNotEmpty)
                  (SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${supplierRisks.length} risque(s) liés aux fournisseurs (module Risques)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ) as Widget),

                // Search + filtres
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Rechercher nom, catégorie, contact…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _Chip('Tous', _filterStatus == 'all',
                                  () => setState(() => _filterStatus = 'all')),
                              ..._statuses.map((s) => _Chip(
                                    s,
                                    _filterStatus == s,
                                    () => setState(() => _filterStatus = s),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Liste
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('Aucun fournisseur',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    sliver: (SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        // Intersection : tâches / finance / risques liés
                        final relatedTasks = tasks
                            .where((t) =>
                                (t.title.toLowerCase().contains(s.name.toLowerCase()) ||
                                    (t.description
                                            ?.toLowerCase()
                                            .contains(s.name.toLowerCase()) ??
                                        false) ||
                                    t.category.toLowerCase() ==
                                        s.category.toLowerCase()))
                            .toList();
                        final relatedTxs = txs
                            .where((tx) =>
                                (tx.category
                                        .toLowerCase()
                                        .contains(s.name.toLowerCase()) ||
                                    (tx.description
                                            ?.toLowerCase()
                                            .contains(s.name.toLowerCase()) ??
                                        false) ||
                                    tx.category.toLowerCase() ==
                                        s.category.toLowerCase()))
                            .toList();
                        final relatedRisks = risks
                            .where((r) =>
                                r.title
                                    .toLowerCase()
                                    .contains(s.name.toLowerCase()) ||
                                (r.category
                                    .toLowerCase()
                                    .contains('fourniss')))
                            .toList();

                        return _SupplierCard(
                          supplier: s,
                          relatedTasksCount: relatedTasks.length,
                          relatedTxsCount: relatedTxs.length,
                          relatedRisksCount: relatedRisks.length,
                          onTap: () => _openDetail(
                            s,
                            relatedTasks: relatedTasks,
                            relatedTxs: relatedTxs,
                            relatedRisks: relatedRisks,
                          ),
                          onEdit: () => _showSupplierSheet(existing: s),
                          onDelete: () => _confirmDelete(s),
                          onStatusChange: (status) =>
                              _updateStatus(s, status),
                        );
                      },
                    ) as Widget),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showSupplierSheet(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Ajouter fournisseur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  List<Supplier> _applyFilters(List<Supplier> list) {
    return list.where((s) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          (s.contact?.toLowerCase().contains(q) ?? false) ||
          (s.email?.toLowerCase().contains(q) ?? false);
      final matchStatus =
          _filterStatus == 'all' || s.status == _filterStatus;
      final matchCat =
          _filterCategory == null || s.category == _filterCategory;
      return matchSearch && matchStatus && matchCat;
    }).toList()
      ..sort((a, b) => b.calculatedScore.compareTo(a.calculatedScore));
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${s.name} » de Supabase ?'),
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
      await ref.read(executionRepositoryProvider).deleteSupplier(s.id);
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
              content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStatus(Supplier s, String status) async {
    try {
      await ref
          .read(executionRepositoryProvider)
          .updateSupplierStatus(s.id, status);
      ref.invalidate(executionSuppliersProvider(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur statut : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDetail(
    Supplier s, {
    required List<ExecutionTask> relatedTasks,
    required List<FinanceTransaction> relatedTxs,
    required List<RiskItem> relatedRisks,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierDetailPage(
          supplier: s,
          projectCode: widget.projectCode,
          relatedTasks: relatedTasks,
          relatedTxs: relatedTxs,
          relatedRisks: relatedRisks,
          onUpdated: () =>
              ref.invalidate(executionSuppliersProvider(widget.projectCode)),
        ),
      ),
    );
  }

  void _showSupplierSheet({Supplier? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categoryCtrl =
        TextEditingController(text: existing?.category ?? 'Équipement');
    final contactCtrl =
        TextEditingController(text: existing?.contact ?? existing?.email ?? '');
    final productCtrl = TextEditingController(text: existing?.product ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.price?.toStringAsFixed(0) ?? '');
    final leadCtrl = TextEditingController(
        text: existing?.leadTimeDays?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    double priceScore = existing?.priceScore ?? 70;
    double qualityScore = existing?.qualityScore ?? 70;
    double delayScore = existing?.delayScore ?? 70;
    double reliabilityScore = existing?.reliabilityScore ?? 70;
    String status = existing?.status ?? 'Recherche';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                        fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom société *',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _categories.contains(categoryCtrl.text)
                        ? categoryCtrl.text
                        : 'Général',
                    decoration: InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      categoryCtrl.text = v ?? 'Général';
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    items: _statuses
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setModal(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contact (email / téléphone)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: productCtrl,
                    decoration: InputDecoration(
                      labelText: 'Produit / Service',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Prix (USD)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: leadCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Délai (jours)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Scores (0–100)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  _SliderScore(
                      label: 'Prix',
                      value: priceScore,
                      onChanged: (v) => setModal(() => priceScore = v)),
                  _SliderScore(
                      label: 'Qualité',
                      value: qualityScore,
                      onChanged: (v) => setModal(() => qualityScore = v)),
                  _SliderScore(
                      label: 'Délai',
                      value: delayScore,
                      onChanged: (v) => setModal(() => delayScore = v)),
                  _SliderScore(
                      label: 'Fiabilité',
                      value: reliabilityScore,
                      onChanged: (v) =>
                          setModal(() => reliabilityScore = v)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo),
                      onPressed: _saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Le nom est obligatoire'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setState(() => _saving = true);
                              try {
                                final supplier = Supplier(
                                  id: existing?.id ?? '',
                                  projectCode: widget.projectCode,
                                  name: name,
                                  category: categoryCtrl.text.trim().isEmpty
                                      ? 'Général'
                                      : categoryCtrl.text.trim(),
                                  contact: contactCtrl.text.trim().isEmpty
                                      ? null
                                      : contactCtrl.text.trim(),
                                  product: productCtrl.text.trim().isEmpty
                                      ? null
                                      : productCtrl.text.trim(),
                                  price: double.tryParse(priceCtrl.text.trim()),
                                  leadTimeDays:
                                      int.tryParse(leadCtrl.text.trim()),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                  status: status,
                                  priceScore: priceScore,
                                  qualityScore: qualityScore,
                                  delayScore: delayScore,
                                  reliabilityScore: reliabilityScore,
                                  score: (priceScore +
                                          qualityScore +
                                          delayScore +
                                          reliabilityScore) /
                                      4,
                                );
                                await ref
                                    .read(executionRepositoryProvider)
                                    .upsertSupplier(supplier);
                                if (mounted) Navigator.pop(context);
                                ref.invalidate(executionSuppliersProvider(
                                    widget.projectCode));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit
                                          ? 'Fournisseur mis à jour'
                                          : 'Fournisseur ajouté dans Supabase'),
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
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEdit ? 'Enregistrer' : 'Ajouter',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
// DETAIL + INTERSECTION
// ═══════════════════════════════════════════════════════════════

class SupplierDetailPage extends ConsumerWidget {
  const SupplierDetailPage({
    super.key,
    required this.supplier,
    required this.projectCode,
    required this.relatedTasks,
    required this.relatedTxs,
    required this.relatedRisks,
    required this.onUpdated,
  });

  final Supplier supplier;
  final String projectCode;
  final List<ExecutionTask> relatedTasks;
  final List<FinanceTransaction> relatedTxs;
  final List<RiskItem> relatedRisks;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = supplier;
    final score = s.calculatedScore;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header scores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business,
                          color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.category,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          Text(s.status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ),
                    Text('${score.toStringAsFixed(0)}/100',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: score >= 75
                              ? Colors.green
                              : score >= 50
                                  ? Colors.orange
                                  : Colors.red,
                        )),
                  ],
                ),
                if (s.contact != null) ...[
                  const SizedBox(height: 12),
                  Text('Contact : ${s.contact}',
                      style: const TextStyle(fontSize: 13)),
                ],
                if (s.product != null) ...[
                  const SizedBox(height: 4),
                  Text('Produit : ${s.product}',
                      style: const TextStyle(fontSize: 13)),
                ],
                if (s.price != null) ...[
                  const SizedBox(height: 4),
                  Text('Prix : \\[ {s.price!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13)),
                ],
                if (s.leadTimeDays != null) ...[
                  const SizedBox(height: 4),
                  Text('Délai : ${s.leadTimeDays} jours',
                      style: const TextStyle(fontSize: 13)),
                ],
                if (s.notes != null && s.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(s.notes!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScoreBar('Prix', s.priceScore),
                    _ScoreBar('Qualité', s.qualityScore),
                    _ScoreBar('Délai', s.delayScore),
                    _ScoreBar('Fiabilité', s.reliabilityScore),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text('Intersection des données',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),

          // Tâches liées
          _IntersectionSection(
            title: 'Tâches liées (${relatedTasks.length})',
            icon: Icons.task_alt,
            color: Colors.indigo,
            empty: 'Aucune tâche liée (titre / catégorie)',
            children: relatedTasks
                .take(5)
                .map((t) => ListTile(
                      dense: true,
                      leading: Icon(
                        t.status == 'done'
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: t.status == 'done' ? Colors.green : Colors.grey,
                      ),
                      title: Text(t.title, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${t.category} · ${t.status}',
                          style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),

          // Transactions liées
          _IntersectionSection(
            title: 'Dépenses liées (${relatedTxs.length})',
            icon: Icons.payments_outlined,
            color: Colors.green,
            empty: 'Aucune transaction liée',
            children: relatedTxs
                .take(5)
                .map((tx) => ListTile(
                      dense: true,
                      leading: Icon(
                        tx.type == FinanceTransactionType.expense
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                        color: tx.type == FinanceTransactionType.expense
                            ? Colors.red
                            : Colors.green,
                      ),
                      title: Text(
                          '${tx.category} · \ \]{tx.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(tx.description ?? '',
                          style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),

          // Risques liés
          _IntersectionSection(
            title: 'Risques fournisseurs (${relatedRisks.length})',
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            empty: 'Aucun risque fournisseur ouvert',
            children: relatedRisks
                .take(5)
                .map((r) => ListTile(
                      dense: true,
                      leading: Icon(Icons.flag,
                          size: 18,
                          color: r.isCritical
                              ? Colors.red
                              : r.isHigh
                                  ? Colors.orange
                                  : Colors.grey),
                      title: Text(r.title, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                          '${r.levelLabel} · ${r.category} · ${r.status}',
                          style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _IntersectionSection extends StatelessWidget {
  const _IntersectionSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.empty,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(empty,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD + WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.relatedTasksCount,
    required this.relatedTxsCount,
    required this.relatedRisksCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final Supplier supplier;
  final int relatedTasksCount;
  final int relatedTxsCount;
  final int relatedRisksCount;
  final VoidCallback onTap;
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
    final s = supplier;
    final score = s.calculatedScore;
    final statusColor = _statusColor(s.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business,
                      size: 20, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(s.category,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
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
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                        value: 'status:Recherche', child: Text('→ Recherche')),
                    PopupMenuItem(
                        value: 'status:Négociation',
                        child: Text('→ Négociation')),
                    PopupMenuItem(
                        value: 'status:Validé', child: Text('→ Validé')),
                    PopupMenuItem(
                        value: 'status:Inactif', child: Text('→ Inactif')),
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
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
                const Spacer(),
                Text('Score ${score.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
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
                _ScoreChip(label: 'Prix', value: s.priceScore),
                _ScoreChip(label: 'Qualité', value: s.qualityScore),
                _ScoreChip(label: 'Délai', value: s.delayScore),
                _ScoreChip(label: 'Fiabilité', value: s.reliabilityScore),
              ],
            ),
            // Badges intersection
            if (relatedTasksCount > 0 ||
                relatedTxsCount > 0 ||
                relatedRisksCount > 0) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  if (relatedTasksCount > 0)
                    _LinkBadge(
                        Icons.task_alt, '$relatedTasksCount tâches', Colors.indigo),
                  if (relatedTxsCount > 0)
                    _LinkBadge(Icons.payments_outlined,
                        '$relatedTxsCount tx', Colors.green),
                  if (relatedRisksCount > 0)
                    _LinkBadge(Icons.warning_amber_rounded,
                        '$relatedRisksCount risques', Colors.red),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  const _LinkBadge(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
        Text('${value.toInt()}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  value >= 75
                      ? Colors.green
                      : value >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
              Text('${value.toInt()}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
            width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
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
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.indigo.withOpacity(0.15),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
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
            Text('Erreur : $error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
