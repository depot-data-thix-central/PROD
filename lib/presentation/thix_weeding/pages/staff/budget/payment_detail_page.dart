// lib/presentation/thix_weeding/pages/staff/budget/payment_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PAYMENT DETAIL (PRODUCTION)
// Design royal + timeline paiements + justificatif + actions premium
// Branché sur providers EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// PROVIDER LOCAL POUR DÉTAIL DÉPENSE
// ============================================================================
final expenseDetailProvider = FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_expenses')
      .select()
      .eq('id', expenseId)
      .single();
  return ExpenseModel.fromJson(data);
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

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── APP BAR ROYALE ────────────────────────────────────────────
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
                    // ── HERO CARD ──────────────────────────────────────────
                    _HeroCard(expense: expense, vendor: vendorName),
                    const SizedBox(height: 16),

                    // ── STATUT BADEGE ──────────────────────────────────────
                    _StatusBanner(expense: expense),
                    const SizedBox(height: 16),

                    // ── INFORMATIONS DÉTAILLÉES ────────────────────────────
                    _InfoSection(expense: expense, vendor: vendorName),
                    const SizedBox(height: 16),

                    // ── JUSTIFICATIF ───────────────────────────────────────
                    // (si receipt_url existe dans les données Supabase)
                    _ReceiptSection(expense: expense),
                    const SizedBox(height: 16),

                    // ── TIMELINE ───────────────────────────────────────────
                    _TimelineSection(expense: expense),
                    const SizedBox(height: 24),

                    // ── ACTIONS ────────────────────────────────────────────
                    _ActionsSection(
                      expense: expense,
                      onEdit: () => context.push(
                          '/thix-weeding/staff/$weddingId/budget/add?edit=$expenseId'),
                      onMarkPaid: () => _markAsPaid(context, ref),
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
  // ACTIONS
  // ============================================================================
  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_expenses')
          .update({
            'is_paid': true,
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', expenseId);

      ref.invalidate(expenseDetailProvider(expenseId));
      ref.invalidate(expensesProvider(weddingId));
      ref.invalidate(budgetProvider(weddingId));
      ref.invalidate(paymentsSummaryProvider(weddingId));

      if (context.mounted) {
        _showSuccess(context, 'Marqué comme payé ✓');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur: $e');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => const _RoyalDeleteDialog(),
    );
    if (ok != true) return;

    try {
      await ref.read(budgetServiceProvider).deleteExpense(expenseId);
      ref.invalidate(expensesProvider(weddingId));
      ref.invalidate(budgetProvider(weddingId));
      ref.invalidate(paymentsSummaryProvider(weddingId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur: $e');
      }
    }
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
              child: Text(
                msg,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
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
              child: Text(
                msg,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
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
          gradient: expense.isPaid ? _R.greenG : _R.amberG,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            // Motif décoratif
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
// HERO CARD
// ============================================================================
class _HeroCard extends StatelessWidget {
  final ExpenseModel expense;
  final VendorModel? vendor;

  const _HeroCard({required this.expense, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final cat = _Cat.find(expense.category);
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
          // Top : catégorie + ID
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
                    Text(
                      cat.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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

          // Montant royal
          Text(
            _fmtMoney(expense.amount),
            style: GoogleFonts.inter(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Montant total',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),

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
                    child: const Icon(Icons.storefront, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prestataire',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          vendor!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vendor!.phone != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // TODO: call vendor.phone
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_outlined, color: Colors.white, size: 16),
                        ),
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

// ============================================================================
// STATUS BANNER
// ============================================================================
class _StatusBanner extends StatelessWidget {
  final ExpenseModel expense;
  const _StatusBanner({required this.expense});

  @override
  Widget build(BuildContext context) {
    final paid = expense.isPaid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: paid ? _R.greenG : _R.amberG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (paid ? _R.green : _R.amber).withOpacity(0.25),
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
            child: Icon(
              paid ? Icons.verified : Icons.schedule,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid ? 'Dépense payée' : 'En attente de paiement',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  paid
                      ? 'Comptabilisée dans le budget dépensé'
                      : 'Reste à payer au prestataire (dette)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
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
            label: 'Montant',
            value: _fmtMoney(expense.amount),
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
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    fontFamily: monospace ? 'monospace' : null,
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

// ============================================================================
// JUSTIFICATIF
// ============================================================================
class _ReceiptSection extends StatelessWidget {
  final ExpenseModel expense;
  const _ReceiptSection({required this.expense});

  @override
  Widget build(BuildContext context) {
    // On récupère receipt_url via la map dynamique (non dans ExpenseModel)
    // Si non disponible, on affiche "Aucun justificatif"
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
                      child: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Facture disponible',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _R.rose,
                            ),
                          ),
                          Text(
                            'Appuyer pour voir en plein écran',
                            style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                          ),
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
                    child: Text(
                      'Aucun justificatif attaché',
                      style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Récupération dynamique (champ non modélisé)
  String? _getReceiptUrl(ExpenseModel expense) {
    try {
      // Reflection impossible en Flutter, donc on renvoie null
      // Si vous ajoutez receiptUrl au modèle, remplacer par : return expense.receiptUrl;
      return null;
    } catch (_) {
      return null;
    }
  }

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
            child: Center(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TIMELINE
// ============================================================================
class _TimelineSection extends StatelessWidget {
  final ExpenseModel expense;
  const _TimelineSection({required this.expense});

  @override
  Widget build(BuildContext context) {
    final events = <_TimelineEvent>[
      _TimelineEvent(
        title: 'Dépense créée',
        date: expense.createdAt,
        icon: Icons.add_circle_outline,
        color: _R.blue,
        description: 'Dépense ajoutée au budget',
      ),
      if (expense.isPaid)
        _TimelineEvent(
          title: 'Paiement effectué',
          date: DateTime.now(), // En réalité paid_at si dispo
          icon: Icons.check_circle,
          color: _R.green,
          description: 'Montant réglé au prestataire',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Historique',
            icon: Icons.history_outlined,
            color: _R.purple,
          ),
          const SizedBox(height: 14),
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            final isLast = i == events.length - 1;
            return _TimelineItem(event: event, isLast: isLast);
          }),
          if (!expense.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _R.amber.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _R.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.hourglass_bottom, size: 14, color: _R.amber),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'En attente de paiement...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: _R.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String title;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String description;

  _TimelineEvent({
    required this.title,
    required this.date,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
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
                    color: event.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: event.color, width: 2),
                  ),
                  child: Icon(event.icon, size: 14, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.color.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: event.color,
                    ),
                  ),
                  Text(
                    event.description,
                    style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDateTime(event.date),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _R.text2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _ActionsSection({
    required this.expense,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action principale : Marquer comme payé (si non payé)
        if (!expense.isPaid)
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _R.greenG,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
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
                onTap: onMarkPaid,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Marquer comme payé',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (!expense.isPaid) const SizedBox(height: 12),

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
            border: Border.all(color: danger ? color.withOpacity(0.3) : _R.border),
            color: danger ? color.withOpacity(0.05) : Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
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
              decoration: BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer cette dépense ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _R.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible. La dépense sera définitivement supprimée du budget.',
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
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
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
            ),
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
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
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
// UTILITAIRES
// ============================================================================
String _fmtMoney(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    c++;
    if (c % 3 == 0 && i > 0) buf.write(' ');
  }
  return '${buf.toString().split('').reversed.join()} FCFA';
}

String _fmtDateTime(DateTime dt) {
  final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $month $year à $h:$m';
}
