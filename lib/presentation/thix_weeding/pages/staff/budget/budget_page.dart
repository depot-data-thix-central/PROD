// lib/presentation/thix_weeding/pages/staff/budget/budget_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — BUDGET PAGE (PRODUCTION v2 — USD + ÉQUILIBRÉ)
// ✅ Devise USD ($) partout
// ✅ Restant = Budget − Payé (l'indicateur s'équilibre dès un décaissement)
// ✅ % hero = Payé / Budget ; barre secondaire = Engagé / Budget
// ✅ Paiements partiels appliqués aux dépenses (filtres + badges réels)
// ✅ Dette prestataires = Dépensé − Payé
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// 12 catégories du cahier des charges
const List<_Cat> _CATEGORIES = [
  _Cat('salle', 'Salle', Icons.place_outlined, Color(0xFF0B3B8F)),
  _Cat('decoration', 'Décoration', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _Cat('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _Cat('boissons', 'Boissons', Icons.local_bar, Color(0xFF7C3AED)),
  _Cat('photographie', 'Photographie', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _Cat('videographie', 'Vidéographie', Icons.videocam_outlined, Color(0xFF059669)),
  _Cat('musique', 'Musique & DJ', Icons.music_note, Color(0xFFDB2777)),
  _Cat('tenues', 'Tenues', Icons.checkroom, Color(0xFF0891B2)),
  _Cat('maquillage', 'Maquillage', Icons.auto_fix_high, Color(0xFFBE185D)),
  _Cat('transport', 'Transport', Icons.directions_car, Color(0xFF4338CA)),
  _Cat('hebergement', 'Hébergement', Icons.hotel, Color(0xFF92400E)),
  _Cat('divers', 'Divers', Icons.category_outlined, Color(0xFF64748B)),
];

class _Cat {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.key, this.label, this.icon, this.color);

  static _Cat find(String key) =>
      _CATEGORIES.firstWhere((c) => c.key == key, orElse: () => _CATEGORIES.last);
}

// ============================================================================
// RÉSUMÉ ÉQUILIBRÉ (calcul central — USD)
// ============================================================================
class BalancedSummary {
  final double spent;            // Engagé : somme des dépenses
  final double paid;             // Décaissé : paiements complétés (ou dépenses payées)
  final double remaining;        // Trésorerie : budget − paid
  final double toCommit;         // Capacité d'engagement : budget − spent
  final double debt;             // Dette : spent − paid (si > 0)
  final Map<String, double> paidByExpense; // paiements complétés par dépense

  const BalancedSummary({
    required this.spent,
    required this.paid,
    required this.remaining,
    required this.toCommit,
    required this.debt,
    required this.paidByExpense,
  });

  double paidFor(String expenseId) => paidByExpense[expenseId] ?? 0;
}

/// Calcule l'état réel du budget : dès qu'un paiement part, le restant baisse.
final balancedSummaryProvider =
    FutureProvider.family<BalancedSummary, String>((ref, weddingId) async {
  final expenses = await ref.watch(expensesProvider(weddingId).future);
  final payments = await ref.watch(paymentsProvider(weddingId).future);
  final budget = await ref.watch(budgetProvider(weddingId).future);

  final totalBudget = budget?.totalBudget ?? 0.0;

  final spent = expenses.fold<double>(0, (s, e) => s + e.amount);

  // Décaissements : paiements complétés
  final completed = payments.where((p) => p.status == 'completed');
  final paidFromPayments = completed.fold<double>(0, (s, p) => s + p.amount);

  // Filet de sécurité : dépenses marquées payées sans paiement enregistré
  final paidFromExpenses =
      expenses.where((e) => e.isPaid).fold<double>(0, (s, e) => s + e.amount);

  final paid = paidFromPayments > paidFromExpenses ? paidFromPayments : paidFromExpenses;

  // Paiements complétés ventilés par dépense (pour partiels & badges)
  final paidByExpense = <String, double>{};
  for (final p in completed) {
    final eid = p.expenseId;
    if (eid != null) paidByExpense[eid] = (paidByExpense[eid] ?? 0) + p.amount;
  }

  return BalancedSummary(
    spent: spent,
    paid: paid,
    remaining: totalBudget - paid,
    toCommit: totalBudget - spent,
    debt: (spent - paid).clamp(0, double.infinity),
    paidByExpense: paidByExpense,
  );
});

// ============================================================================
// PAGE
// ============================================================================
class BudgetPage extends ConsumerStatefulWidget {
  final String weddingId;
  const BudgetPage({super.key, required this.weddingId});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = widget.weddingId;
    ref.invalidate(budgetProvider(id));
    ref.invalidate(expensesProvider(id));
    ref.invalidate(paymentsProvider(id));
    ref.invalidate(balancedSummaryProvider(id));
    ref.invalidate(vendorsProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.weddingId;
    final budgetAsync = ref.watch(budgetProvider(id));

    return Scaffold(
      backgroundColor: _R.surface,
      body: budgetAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: '$e', onRetry: _refresh),
        data: (BudgetModel? budget) {
          if (budget == null) {
            return _EmptyBudgetView(
              onCreate: () async {
                // Budget par défaut en USD
                await ref.read(budgetServiceProvider).upsert(id, 5000);
                ref.invalidate(budgetProvider(id));
              },
            );
          }
          return _BudgetContent(
            weddingId: id,
            budget: budget,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            onEditBudget: () => _editTotalBudget(),
          );
        },
      ),
      floatingActionButton: _RoyalFab(
        icon: Icons.add,
        label: 'Dépense',
        onTap: () => context.push('/thix-weeding/staff/$id/budget/add'),
      ),
    );
  }

  // ── MODAL ÉDITION BUDGET TOTAL (USD) ─────────────────────────────────────
  void _editTotalBudget() {
    final id = widget.weddingId;
    final current = ref.read(budgetProvider(id)).valueOrNull?.totalBudget ?? 0;
    final controller = TextEditingController(text: _plainNumber(current));
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoyalEditBudgetSheet(
        controller: controller,
        formKey: formKey,
        onSave: () async {
          final val = double.tryParse(
              controller.text.replaceAll(' ', '').replaceAll(',', '.'));
          if (val == null || val <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Montant invalide')),
            );
            return;
          }
          await ref.read(budgetServiceProvider).upsert(id, val);
          ref.invalidate(budgetProvider(id));
          ref.invalidate(balancedSummaryProvider(id));
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ============================================================================
// CONTENU BUDGET (quand budget existe)
// ============================================================================
class _BudgetContent extends ConsumerWidget {
  final String weddingId;
  final BudgetModel budget;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onEditBudget;

  const _BudgetContent({
    required this.weddingId,
    required this.budget,
    required this.filter,
    required this.onFilterChanged,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(balancedSummaryProvider(weddingId));
    final expensesAsync = ref.watch(expensesProvider(weddingId));
    final vendorsAsync = ref.watch(vendorsProvider(weddingId));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _BudgetAppBar(onEdit: onEditBudget),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── HERO ÉQUILIBRÉ ──────────────────────────────────────────
              summaryAsync.when(
                loading: () => const _SummaryShimmer(),
                error: (e, _) => Text('$e', style: const TextStyle(color: _R.rose)),
                data: (summary) => _BudgetHero(
                  totalBudget: budget.totalBudget,
                  summary: summary,
                ),
              ),
              const SizedBox(height: 20),

              // ── BREAKDOWN PAR CATÉGORIE ─────────────────────────────────
              expensesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (expenses) => _CategoryBreakdown(expenses: expenses),
              ),
              const SizedBox(height: 20),

              // ── FILTRES ─────────────────────────────────────────────────
              _FilterRow(current: filter, onChanged: onFilterChanged),
              const SizedBox(height: 16),

              // ── SECTION TITRE ───────────────────────────────────────────
              _SectionHeader(
                title: 'Dépenses',
                icon: Icons.receipt_long_outlined,
                actionLabel: 'Exporter',
                onAction: () => _showExportOptions(context),
              ),
              const SizedBox(height: 12),

              // ── LISTE DES DÉPENSES (filtres réels, partiels inclus) ─────
              summaryAsync.when(
                loading: () => const _ListShimmer(),
                error: (e, _) => _ErrorInline(message: '$e'),
                data: (summary) => expensesAsync.when(
                  loading: () => const _ListShimmer(),
                  error: (e, _) => _ErrorInline(message: '$e'),
                  data: (expenses) {
                    double paidOf(ExpenseModel e) =>
                        e.isPaid ? e.amount : summary.paidFor(e.id);

                    final filtered = expenses.where((e) {
                      final p = paidOf(e);
                      switch (filter) {
                        case 'paid':
                          return e.isPaid || p >= e.amount && e.amount > 0;
                        case 'unpaid':
                          return p <= 0 && !e.isPaid;
                        case 'partial':
                          return p > 0 && p < e.amount;
                        default:
                          return true;
                      }
                    }).toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    if (filtered.isEmpty) return _EmptyList(filter: filter);

                    return RefreshIndicator(
                      color: _R.blue,
                      onRefresh: () async {
                        ref.invalidate(expensesProvider(weddingId));
                        ref.invalidate(paymentsProvider(weddingId));
                        ref.invalidate(balancedSummaryProvider(weddingId));
                        ref.invalidate(budgetProvider(weddingId));
                      },
                      child: Column(
                        children: filtered
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ExpenseTile(
                                    expense: e,
                                    paidAmount: paidOf(e),
                                    vendors: vendorsAsync.valueOrNull ?? const [],
                                    onTap: () => context.push(
                                        '/thix-weeding/staff/$weddingId/budget/${e.id}'),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSheet(),
    );
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _BudgetAppBar extends StatelessWidget {
  final VoidCallback onEdit;
  const _BudgetAppBar({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _R.text,
      title: Text(
        'Budget',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.blue, fontSize: 20),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => context.pop(),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: _R.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, size: 14, color: _R.goldDark),
                    const SizedBox(width: 4),
                    Text(
                      'Modifier',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _R.goldDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ============================================================================
// HERO BUDGET — ÉQUILIBRÉ (USD)
// ============================================================================
class _BudgetHero extends StatelessWidget {
  final double totalBudget;
  final BalancedSummary summary;

  const _BudgetHero({required this.totalBudget, required this.summary});

  @override
  Widget build(BuildContext context) {
    final spent = summary.spent;
    final paid = summary.paid;
    final remaining = summary.remaining;
    final over = totalBudget > 0 && (paid > totalBudget || spent > totalBudget);

    // % réel : décaissé / budget (l'indicateur bouge dès qu'un paiement part)
    final cashRatio = totalBudget > 0 ? (paid / totalBudget).clamp(0.0, 1.5) : 0.0;
    final commitRatio = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.5) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: over ? _R.roseG : _R.goldG,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (over ? _R.rose : _R.gold).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget global (USD)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      _fmtMoney(totalBudget),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Text(
                  '${(cashRatio * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barre principale : décaissé (trésorerie sortie)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: cashRatio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          // Barre secondaire : engagé
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: commitRatio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.65)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Décaissé ${(cashRatio * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(width: 12),
              Text(
                'Engagé ${(commitRatio * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white.withOpacity(0.75)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 stats équilibrées
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Dépensé',
                  value: spent,
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: 'Payé',
                  value: paid,
                  icon: Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: over ? 'Dépassement' : 'Restant',
                  value: remaining.abs(),
                  icon: over ? Icons.warning_amber : Icons.savings_outlined,
                ),
              ),
            ],
          ),

          // Capacité d'engagement restante
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.trending_up, size: 14, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                'Capacité d\'engagement : ${_fmtMoney(summary.toCommit)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),

          // Dette prestataires
          if (summary.debt > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dette prestataires : ${_fmtMoney(summary.debt)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 6),
          Text(
            _fmtMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BREAKDOWN PAR CATÉGORIE
// ============================================================================
class _CategoryBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final Map<String, double> totals = {};
    for (final e in expenses) {
      final key = (e.category != null && e.category!.isNotEmpty) ? e.category! : 'divers';
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    final grandTotal = totals.values.fold<double>(0, (a, b) => a + b);
    if (grandTotal <= 0) return const SizedBox.shrink();

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: _R.blue),
              const SizedBox(width: 8),
              Text(
                'Répartition par catégorie',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: sorted.map((entry) {
                  final cat = _Cat.find(entry.key);
                  return Expanded(
                    flex: (entry.value * 1000 / grandTotal).round(),
                    child: Container(color: cat.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.take(5).map((entry) {
            final cat = _Cat.find(entry.key);
            final percent = (entry.value / grandTotal * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, size: 16, color: cat.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat.label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(0)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cat.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: percent / 100,
                            backgroundColor: cat.color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation(cat.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _fmtMoney(entry.value),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _R.text,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTRES
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(label: 'Toutes', icon: Icons.all_inbox, selected: current == 'all',
              onTap: () => onChanged('all')),
          const SizedBox(width: 8),
          _Chip(label: 'Payées', icon: Icons.check_circle_outline, selected: current == 'paid',
              onTap: () => onChanged('paid'), activeColor: _R.green),
          const SizedBox(width: 8),
          _Chip(label: 'Impayées', icon: Icons.schedule_outlined, selected: current == 'unpaid',
              onTap: () => onChanged('unpaid'), activeColor: _R.rose),
          const SizedBox(width: 8),
          _Chip(label: 'Partiels', icon: Icons.payments_outlined, selected: current == 'partial',
              onTap: () => onChanged('partial'), activeColor: _R.amber),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.activeColor = _R.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? activeColor : _R.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : activeColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _R.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _R.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _R.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.file_download_outlined, size: 12, color: _R.blue),
                  const SizedBox(width: 4),
                  Text(
                    actionLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _R.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// TILE DÉPENSE (USD + statut partiel réel)
// ============================================================================
class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final double paidAmount;
  final List<VendorModel> vendors;
  final VoidCallback onTap;
  const _ExpenseTile({
    required this.expense,
    required this.paidAmount,
    required this.vendors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = _Cat.find(expense.category ?? 'divers');
    final vendor = expense.vendorId != null
        ? vendors.where((v) => v.id == expense.vendorId).firstOrNull
        : null;
    final vendorName = vendor?.name ?? 'Sans prestataire';

    final bool isPaid = expense.isPaid || (expense.amount > 0 && paidAmount >= expense.amount);
    final bool isPartial = !isPaid && paidAmount > 0;

    final Color statusColor = isPaid ? _R.green : (isPartial ? _R.amber : _R.rose);
    final String statusLabel = isPaid ? 'Payée' : (isPartial ? 'Partiel' : 'Impayée');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _R.card(r: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cat.color, cat.color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _R.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.store_outlined, size: 11, color: _R.text2),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            vendorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(color: _R.text2, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${expense.createdAt.day.toString().padLeft(2, '0')}/${expense.createdAt.month.toString().padLeft(2, '0')}',
                          style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                        ),
                      ],
                    ),
                    if (isPartial) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: (paidAmount / expense.amount).clamp(0.0, 1.0),
                          backgroundColor: _R.amber.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation(_R.amber),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_fmtMoney(paidAmount)} / ${_fmtMoney(expense.amount)}',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _R.amber),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtMoney(expense.amount),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FAB ROYAL
// ============================================================================
class _RoyalFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoyalFab({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
      backgroundColor: _R.blue,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ============================================================================
// VUE BUDGET VIDE (premier usage — USD)
// ============================================================================
class _EmptyBudgetView extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBudgetView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _BudgetAppBar(onEdit: _noop),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Aucun budget défini',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Définissez votre budget global (USD) pour suivre vos dépenses',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: _R.text2),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer budget 5 000 \$'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SHEET ÉDITION BUDGET (USD)
// ============================================================================
class _RoyalEditBudgetSheet extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSave;

  const _RoyalEditBudgetSheet({
    required this.controller,
    required this.formKey,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(gradient: _R.goldG, borderRadius: BorderRadius.all(Radius.circular(10))),
                child: const Icon(Icons.edit, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Modifier le budget (USD)',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Budget total (USD \$)',
              hintText: 'Ex : 5000 ou 2500.50',
              labelStyle: GoogleFonts.inter(color: _R.text2),
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.inter(color: _R.green, fontWeight: FontWeight.w800, fontSize: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _R.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _R.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _R.blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _R.text,
                    side: const BorderSide(color: _R.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Enregistrer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _R.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHEET EXPORT
// ============================================================================
class _ExportSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Exporter le budget',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _ExportOption(icon: Icons.picture_as_pdf, label: 'Rapport PDF',
              subtitle: 'Rapport complet avec graphiques (USD)',
              color: _R.rose,
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          _ExportOption(icon: Icons.table_chart, label: 'Excel (.xlsx)',
              subtitle: 'Pour analyse détaillée',
              color: _R.green,
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          _ExportOption(icon: Icons.share, label: 'Partager',
              subtitle: 'Via THIX Chat ou autre',
              color: _R.blue,
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExportOption({
    required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ÉTATS VIDES / ERREURS / LOADING
// ============================================================================
class _EmptyList extends StatelessWidget {
  final String filter;
  const _EmptyList({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      'paid' => 'Aucune dépense payée',
      'unpaid' => 'Aucune dépense impayée',
      'partial' => 'Aucun paiement partiel',
      _ => 'Aucune dépense enregistrée',
    };
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _R.border.withOpacity(0.3), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: _R.text2),
          ),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Ajoutez une dépense avec le bouton +',
              style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: _R.blue),
      );
}

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();
  @override
  Widget build(BuildContext context) => Container(
        height: 240,
        decoration: BoxDecoration(
          color: _R.gold.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
        ),
      );
}

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 70,
            decoration: _R.card(r: 14),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _R.rose, size: 48),
            const SizedBox(height: 12),
            Text('Erreur', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(backgroundColor: _R.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorInline extends StatelessWidget {
  final String message;
  const _ErrorInline({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _R.rose.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _R.rose),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: _R.rose))),
          ],
        ),
      );
}

// ============================================================================
// UTILITAIRES
// ============================================================================
void _noop() {}

/// Format USD : $2,000,000 ou $1,234.56 (centimes seulement si nécessaires)
String _fmtMoney(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.floor();
  final cents = ((abs - whole) * 100).round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final centsStr = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}\$$buf$centsStr';
}

/// Valeur brute sans séparateurs pour le champ d'édition
String _plainNumber(double v) {
  final cents = ((v - v.floor()) * 100).round();
  return cents > 0 ? '${v.floor()}.$cents' : '${v.floor()}';
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
