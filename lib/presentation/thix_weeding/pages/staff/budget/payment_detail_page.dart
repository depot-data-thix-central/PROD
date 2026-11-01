// lib/presentation/thix_weeding/pages/staff/budget/payment_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PAYMENT DETAIL (PRODUCTION v2 — USD + ÉQUILIBRÉ)
// ✅ Devise USD ($) partout (centimes si nécessaires)
// ✅ Timeline réelle : liste des PaymentModel liés à la dépense
// ✅ Hero équilibré : Total / Payé / Reste à payer
// ✅ Bouton "Ajouter un paiement" → crée PaymentModel → équilibre le budget
// ✅ Invalidation de balancedSummaryProvider (comptabilité temps réel)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';
import 'budget_page.dart' show balancedSummaryProvider;

// ============================================================================
// PROVIDERS LOCAUX
// ============================================================================
final expenseDetailProvider =
    FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_expenses')
      .select()
      .eq('id', expenseId)
      .single();
  return ExpenseModel.fromJson(data);
});

/// Paiements liés à cette dépense (triés par date décroissante)
final paymentsForExpenseProvider =
    FutureProvider.family<List<PaymentModel>, String>((ref, expenseId) async {
  final rows = await Supabase.instance.client
      .from('thix_weeding_payments')
      .select()
      .eq('expense_id', expenseId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows)
      .map(PaymentModel.fromJson)
      .toList();
});

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
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
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

// 12 catégories
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
  _Cat('general', 'Général', Icons.category_outlined, Color(0xFF64748B)),
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
// PAGE
// ============================================================================
class PaymentDetailPage extends ConsumerWidget {
  final String weddingId;
  final String expenseId;

  const PaymentDetailPage({
    super.key,
    required this.weddingId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final vendorsAsync = ref.watch(vendorsProvider(weddingId));
    final paymentsAsync = ref.watch(paymentsForExpenseProvider(expenseId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: expenseAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(expenseDetailProvider(expenseId)),
        ),
        data: (expense) {
          final vendorName = vendorsAsync.maybeWhen(
            data: (vendors) {
              final match = vendors.where((v) => v.id == expense.vendorId);
              return match.isEmpty ? null : match.first;
            },
            orElse: () => null,
          );

          final payments = paymentsAsync.valueOrNull ?? const [];
          final paid = payments
              .where((p) => p.status == 'completed')
              .fold<double>(0, (s, p) => s + p.amount);
          final remaining = (expense.amount - paid).clamp(0.0, double.infinity);
          final isPaid = remaining <= 0.001;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _RoyalAppBar(
                expense: expense,
                onEdit: () => context.push(
                    '/thix-weeding/staff/$weddingId/budget/add?edit=$expenseId'),
                onDelete: () => _confirmDelete(context, ref),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── HERO ÉQUILIBRÉ (USD) ──────────────────────────────
                    _HeroCard(
                      expense: expense,
                      vendor: vendorName,
                      paidAmount: paid,
                      remainingAmount: remaining,
                    ),
                    const SizedBox(height: 16),

                    // ── STATUT BADGE ──────────────────────────────────────
                    _StatusBanner(isPaid: isPaid, paid: paid, total: expense.amount),
                    const SizedBox(height: 16),

                    // ── INFORMATIONS ─────────────────────────────────────
                    _InfoSection(expense: expense, vendor: vendorName),
                    const SizedBox(height: 16),

                    // ── JUSTIFICATIF ─────────────────────────────────────
                    _ReceiptSection(expense: expense),
                    const SizedBox(height: 16),

                    // ── PAIEMENTS (TIMELINE RÉELLE) ──────────────────────
                    _PaymentsTimelineSection(
                      paymentsAsync: paymentsAsync,
                      expense: expense,
                      paidAmount: paid,
                      onAddPayment: () => _showAddPaymentSheet(context, ref, expense, remaining),
                    ),
                    const SizedBox(height: 24),

                    // ── ACTIONS ──────────────────────────────────────────
                    _ActionsSection(
                      expense: expense,
                      remaining: remaining,
                      onEdit: () => context.push(
                          '/thix-weeding/staff/$weddingId/budget/add?edit=$expenseId'),
                      onMarkPaid: () =>
                          _markAsPaid(context, ref, expense, remaining),
                      onAddPayment: () =>
                          _showAddPaymentSheet(context, ref, expense, remaining),
                      onDelete: () => _confirmDelete(context, ref),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // ACTIONS — CRÉER PaymentModel (équilibrage comptable)
  // ============================================================================
  Future<void> _markAsPaid(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
    double remaining,
  ) async {
    if (remaining <= 0.001) {
      _showSuccess(context, 'Déjà entièrement payé ✓');
      return;
    }
    try {
      // Créer un PaymentModel pour le montant restant
      await Supabase.instance.client.from('thix_weeding_payments').insert({
        'wedding_id': weddingId,
        'title': 'Solde : ${expense.title}',
        'amount': remaining,
        'status': 'completed',
        'method': 'cash',
        'expense_id': expenseId,
        'vendor_id': expense.vendorId,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Marquer la dépense comme payée
      await Supabase.instance.client
          .from('thix_weeding_expenses')
          .update({'is_paid': true})
          .eq('id', expenseId);

      _invalidateAll(ref);
      if (context.mounted) {
        _showSuccess(context, '${_fmtUsd(remaining)} réglé ✓');
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur: $e');
    }
  }

  Future<void> _addPayment(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
    double amount,
    String method,
  ) async {
    try {
      await Supabase.instance.client.from('thix_weeding_payments').insert({
        'wedding_id': weddingId,
        'title': 'Paiement : ${expense.title}',
        'amount': amount,
        'status': 'completed',
        'method': method,
        'expense_id': expenseId,
        'vendor_id': expense.vendorId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Vérifier si maintenant entièrement payé
      final allPayments = await Supabase.instance.client
          .from('thix_weeding_payments')
          .select('amount, status')
          .eq('expense_id', expenseId);
      final totalPaid = List<Map<String, dynamic>>.from(allPayments)
          .where((p) => p['status'] == 'completed')
          .fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble());
      if (totalPaid >= expense.amount) {
        await Supabase.instance.client
            .from('thix_weeding_expenses')
            .update({'is_paid': true})
            .eq('id', expenseId);
      }

      _invalidateAll(ref);
      if (context.mounted) {
        _showSuccess(context, 'Paiement de ${_fmtUsd(amount)} enregistré');
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur: $e');
    }
  }

  Future<void> _deletePayment(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_payments')
          .delete()
          .eq('id', paymentId);
      // Revenir à is_paid=false si plus entièrement payé
      await Supabase.instance.client
          .from('thix_weeding_expenses')
          .update({'is_paid': false})
          .eq('id', expenseId);
      _invalidateAll(ref);
      if (context.mounted) _showSuccess(context, 'Paiement supprimé');
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur: $e');
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(paymentsForExpenseProvider(expenseId));
    ref.invalidate(expenseDetailProvider(expenseId));
    ref.invalidate(expensesProvider(weddingId));
    ref.invalidate(paymentsProvider(weddingId));
    ref.invalidate(budgetProvider(weddingId));
    ref.invalidate(balancedSummaryProvider(weddingId));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => const _RoyalDeleteDialog(),
    );
    if (ok != true) return;

    try {
      // Supprimer paiements liés + dépense
      await Supabase.instance.client
          .from('thix_weeding_payments')
          .delete()
          .eq('expense_id', expenseId);
      await ref.read(budgetServiceProvider).deleteExpense(expenseId);
      _invalidateAll(ref);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur: $e');
    }
  }

  void _showAddPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
    double remaining,
  ) {
    if (remaining <= 0.001) {
      _showSuccess(context, 'Dépense déjà entièrement payée ✓');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentSheet(
        expense: expense,
        remaining: remaining,
        onSubmit: (amount, method) {
          Navigator.pop(context);
          _addPayment(context, ref, expense, amount, method);
        },
      ),
    );
  }

  void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }
}

// ============================================================================
// APP BAR
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoyalAppBar({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = _Cat.find(expense.category);
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(60, 60, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Icon(cat.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'DÉPENSE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        _AppBarButton(icon: Icons.edit_outlined, onTap: onEdit),
        const SizedBox(width: 6),
        _AppBarButton(icon: Icons.delete_outline, onTap: onDelete, danger: true),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _AppBarButton({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: danger ? _R.rose : _R.blue, size: 20),
        ),
      ),
    );
  }
}

// ============================================================================
// HERO CARD ÉQUILIBRÉ (USD)
// ============================================================================
class _HeroCard extends StatelessWidget {
  final ExpenseModel expense;
  final VendorModel? vendor;
  final double paidAmount;
  final double remainingAmount;

  const _HeroCard({
    required this.expense,
    required this.vendor,
    required this.paidAmount,
    required this.remainingAmount,
  });

  @override
  Widget build(BuildContext context) {
    final cat = _Cat.find(expense.category);
    final ratio = expense.amount > 0
        ? (paidAmount / expense.amount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _R.royal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _R.blue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(cat.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'ID: ${expense.id.substring(0, 8)}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Montant total
          Text(
            _fmtUsd(expense.amount),
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text('Montant total (USD)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              )),
          const SizedBox(height: 16),

          // Barre de progression payée
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(ratio * 100).toStringAsFixed(1)}% payé',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              Text('Reste : ${_fmtUsd(remainingAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  )),
            ],
          ),
          const SizedBox(height: 14),

          // 3 stats équilibrées
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Total',
                  value: expense.amount,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  label: 'Payé',
                  value: paidAmount,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  label: 'Restant',
                  value: remainingAmount,
                  icon: Icons.hourglass_bottom_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Prestataire (si lié)
          if (vendor != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prestataire',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 1,
                            )),
                        Text(vendor!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  const _HeroStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(height: 4),
          Text(_fmtUsd(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS BANNER
// ============================================================================
class _StatusBanner extends StatelessWidget {
  final bool isPaid;
  final double paid;
  final double total;

  const _StatusBanner(
      {required this.isPaid, required this.paid, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final isPartial = paid > 0 && !isPaid;

    final gradient = isPaid
        ? _R.greenG
        : (isPartial ? _R.amberG : _R.amberG);
    final title = isPaid
        ? 'Entièrement payée'
        : (isPartial ? 'Paiement en cours' : 'En attente de paiement');
    final subtitle = isPaid
        ? 'Dépense soldée et comptabilisée'
        : (isPartial
            ? '${_fmtUsd(paid)} réglé sur ${_fmtUsd(total)}'
            : 'Reste à payer au prestataire');
    final icon = isPaid
        ? Icons.verified
        : (isPartial ? Icons.payments_outlined : Icons.schedule);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPaid ? _R.green : _R.amber).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                    ),
                    Text('${(ratio * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                  ],
                ),
                Text(subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION INFORMATIONS
// ============================================================================
class _InfoSection extends StatelessWidget {
  final ExpenseModel expense;
  final VendorModel? vendor;

  const _InfoSection({required this.expense, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final cat = _Cat.find(expense.category);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Informations',
            icon: Icons.info_outline,
            color: _R.blue,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Catégorie',
            value: cat.label,
            valueColor: cat.color,
            iconBg: cat.color.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Montant total',
            value: _fmtUsd(expense.amount),
            valueColor: _R.text,
            iconBg: _R.blue.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Prestataire',
            value: vendor?.name ?? 'Non lié',
            valueColor: vendor != null ? _R.purple : _R.text2,
            iconBg: _R.purple.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Créée le',
            value: _fmtDateTime(expense.createdAt),
            valueColor: _R.text,
            iconBg: _R.gold.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.fingerprint_outlined,
            label: 'Identifiant',
            value: expense.id,
            valueColor: _R.text2,
            iconBg: Colors.grey.withOpacity(0.12),
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color iconBg;
  final bool monospace;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.iconBg,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _R.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                      fontFamily: monospace ? 'monospace' : null,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// JUSTIFICATIF
// ============================================================================
class _ReceiptSection extends StatelessWidget {
  final ExpenseModel expense;
  const _ReceiptSection({required this.expense});

  @override
  Widget build(BuildContext context) {
    final receiptUrl = _getReceiptUrl(expense);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Justificatif',
            icon: Icons.receipt_long_outlined,
            color: _R.rose,
          ),
          const SizedBox(height: 14),
          if (receiptUrl != null)
            GestureDetector(
              onTap: () => _showReceipt(context, receiptUrl),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_R.rose.withOpacity(0.08), _R.rose.withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _R.rose.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _R.rose,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Facture disponible',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _R.rose,
                              )),
                          Text('Appuyer pour voir en plein écran',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _R.text2)),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: _R.rose, size: 18),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _R.border, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_outlined, color: _R.text2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Aucun justificatif attaché',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _R.text2)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _getReceiptUrl(ExpenseModel expense) => null;

  void _showReceipt(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Justificatif'),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TIMELINE DES PAIEMENTS (réelle — basée sur PaymentModel)
// ============================================================================
class _PaymentsTimelineSection extends StatelessWidget {
  final AsyncValue<List<PaymentModel>> paymentsAsync;
  final ExpenseModel expense;
  final double paidAmount;
  final VoidCallback onAddPayment;

  const _PaymentsTimelineSection({
    required this.paymentsAsync,
    required this.expense,
    required this.paidAmount,
    required this.onAddPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  title: 'Paiements',
                  icon: Icons.payments_outlined,
                  color: _R.green,
                ),
              ),
              Material(
                color: _R.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onAddPayment,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14, color: _R.green),
                        const SizedBox(width: 4),
                        Text('Paiement',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _R.green,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          paymentsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2, color: _R.green),
              ),
            ),
            error: (e, _) => Text('Erreur: $e',
                style: const TextStyle(color: _R.rose)),
            data: (payments) {
              if (payments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _R.border, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_bottom_outlined,
                          color: _R.amber, size: 32),
                      const SizedBox(height: 8),
                      Text('Aucun paiement enregistré',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _R.text,
                          )),
                      const SizedBox(height: 4),
                      Text('Ajoutez un premier versement',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _R.text2)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onAddPayment,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter un paiement'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _R.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...payments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final isLast = i == payments.length - 1;
                    return _PaymentItem(
                      payment: p,
                      isLast: isLast,
                      onDelete: () => onAddPayment, // placeholder
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final PaymentModel payment;
  final bool isLast;
  final VoidCallback onDelete;
  const _PaymentItem(
      {required this.payment, required this.isLast, required this.onDelete});

  IconData _methodIcon(String? m) {
    switch (m) {
      case 'card':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'check':
        return Icons.money;
      case 'cash':
      default:
        return Icons.attach_money;
    }
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'card':
        return 'Carte bancaire';
      case 'bank_transfer':
        return 'Virement bancaire';
      case 'check':
        return 'Chèque';
      case 'cash':
      default:
        return 'Espèces';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = payment.status == 'completed';
    final color = isCompleted ? _R.green : _R.amber;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.hourglass_bottom,
                    size: 14,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_methodIcon(payment.method),
                          color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmtUsd(payment.amount),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color,
                              )),
                          const SizedBox(height: 2),
                          Text(_methodLabel(payment.method),
                              style: GoogleFonts.inter(
                                  fontSize: 10.5, color: _R.text2)),
                        ],
                      ),
                    ),
                    Text(_fmtDateTime(payment.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: _R.text2,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIONS
// ============================================================================
class _ActionsSection extends StatelessWidget {
  final ExpenseModel expense;
  final double remaining;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onAddPayment;
  final VoidCallback onDelete;

  const _ActionsSection({
    required this.expense,
    required this.remaining,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onAddPayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyPaid = remaining <= 0.001;

    return Column(
      children: [
        // Action principale
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isFullyPaid ? null : _R.greenG,
            color: isFullyPaid ? _R.green.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(16),
            border: isFullyPaid
                ? Border.all(color: _R.green, width: 2)
                : null,
            boxShadow: isFullyPaid
                ? null
                : [
                    BoxShadow(
                      color: _R.green.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isFullyPaid ? null : onAddPayment,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFullyPaid
                        ? Icons.verified
                        : Icons.add_card_outlined,
                    color: isFullyPaid ? _R.green : Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isFullyPaid
                        ? 'Entièrement payée ✓'
                        : 'Ajouter un paiement (${_fmtUsd(remaining)} restant)',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isFullyPaid ? _R.green : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Actions secondaires
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Modifier',
                color: _R.blue,
                onTap: onEdit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.delete_outline,
                label: 'Supprimer',
                color: _R.rose,
                onTap: onDelete,
                danger: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: danger ? color.withOpacity(0.3) : _R.border),
            color: danger ? color.withOpacity(0.05) : Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SHEET AJOUT PAIEMENT (USD)
// ============================================================================
class _AddPaymentSheet extends StatefulWidget {
  final ExpenseModel expense;
  final double remaining;
  final void Function(double amount, String method) onSubmit;

  const _AddPaymentSheet({
    required this.expense,
    required this.remaining,
    required this.onSubmit,
  });

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';

  static const _methods = [
    ('cash', 'Espèces', Icons.attach_money),
    ('card', 'Carte', Icons.credit_card),
    ('bank_transfer', 'Virement', Icons.account_balance),
    ('check', 'Chèque', Icons.money),
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.remaining.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

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
              decoration: BoxDecoration(
                color: _R.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: _R.greenG,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.add_card_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouveau paiement',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Reste à payer : ${_fmtUsd(widget.remaining)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _R.amber,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_UsdInputFormatter()],
            style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Montant (USD)',
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.inter(
                  color: _R.green, fontWeight: FontWeight.w800, fontSize: 22),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _R.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _R.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _R.green, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
          const SizedBox(height: 8),
          // Raccourcis
          Row(
            children: [
              _QuickChip(
                label: 'Reste (${_fmtUsd(widget.remaining)})',
                onTap: () => _amountCtrl.text =
                    widget.remaining.toStringAsFixed(2),
              ),
              const SizedBox(width: 6),
              _QuickChip(
                label: '50%',
                onTap: () => _amountCtrl.text =
                    (widget.remaining / 2).toStringAsFixed(2),
              ),
              const SizedBox(width: 6),
              _QuickChip(
                label: '25%',
                onTap: () => _amountCtrl.text =
                    (widget.remaining / 4).toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Méthode de paiement',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _R.text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _methods.map((m) {
              final selected = _method == m.$1;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.$3, size: 14),
                    const SizedBox(width: 6),
                    Text(m.$2,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? Colors.white : _R.text)),
                  ],
                ),
                selected: selected,
                selectedColor: _R.green,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: selected ? _R.green : _R.border)),
                onSelected: (_) => setState(() => _method = m.$1),
              );
            }).toList(),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    final v = double.tryParse(
                        _amountCtrl.text.replaceAll(',', '.'));
                    if (v == null || v <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Montant invalide')),
                      );
                      return;
                    }
                    if (v > widget.expense.amount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Montant supérieur au total')),
                      );
                      return;
                    }
                    widget.onSubmit(v, _method);
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Enregistrer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _R.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _R.green.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _R.green,
              )),
        ),
      ),
    );
  }
}

/// Formatter décimal USD
class _UsdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text.replaceAll(',', '.');
    if (t.isEmpty) return newValue.copyWith(text: t);
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(t)) return oldValue;
    return newValue.copyWith(text: t);
  }
}

// ============================================================================
// DIALOG SUPPRESSION
// ============================================================================
class _RoyalDeleteDialog extends StatelessWidget {
  const _RoyalDeleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text('Supprimer cette dépense ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _R.text,
                )),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible. Tous les paiements liés seront également supprimés.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.rose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER DE SECTION
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Chargement...',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _R.text2)),
          ],
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
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Impossible de charger',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _R.text2)),
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
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES — USD
// ============================================================================

/// Format USD : $2,000,000 ou $1,234.56 (centimes si nécessaires)
String _fmtUsd(double v) {
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

String _fmtDateTime(DateTime dt) {
  final months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $month $year à $h:$m';
}
