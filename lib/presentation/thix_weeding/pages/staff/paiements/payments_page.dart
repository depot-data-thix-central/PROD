// lib/presentation/thix_weeding/pages/staff/paiements/payments_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PAYMENTS PAGE (PRODUCTION)
// Design royal + Résumé financier + Filtres statut + Navigation corrigée
// ⚠️ ROUTE CORRIGÉE : '/thix-weeding/staff/$weddingId/paiements/${p.id}'
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

// ============================================================================
// STATUTS PAIEMENT
// ============================================================================
const Map<String, _PayStatus> _PAY_STATUS = {
  'completed': _PayStatus('Complété', Icons.check_circle, Color(0xFF059669)),
  'pending': _PayStatus('En attente', Icons.pending, Color(0xFFD97706)),
  'failed': _PayStatus('Échoué', Icons.error_outline, Color(0xFFE31C4E)),
  'refunded': _PayStatus('Remboursé', Icons.undo, Color(0xFF6B7280)),
};

class _PayStatus {
  final String label;
  final IconData icon;
  final Color color;
  const _PayStatus(this.label, this.icon, this.color);
}

_PayStatus _getPayStatus(String? s) =>
    _PAY_STATUS[s ?? ''] ?? _PAY_STATUS['pending']!;

// ============================================================================
// MÉTHODES DE PAIEMENT
// ============================================================================
const Map<String, _PayMethod> _PAY_METHODS = {
  'cash': _PayMethod('Espèces', Icons.money, Color(0xFF059669)),
  'card': _PayMethod('Carte', Icons.credit_card, Color(0xFF0B3B8F)),
  'transfer': _PayMethod('Virement', Icons.account_balance, Color(0xFF6B46C1)),
  'mobile': _PayMethod('Mobile Money', Icons.phone_android, Color(0xFFD97706)),
  'check': _PayMethod('Chèque', Icons.receipt_long, Color(0xFF78716C)),
};

class _PayMethod {
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.label, this.icon, this.color);
}

_PayMethod _getPayMethod(String? m) =>
    _PAY_METHODS[m ?? ''] ?? _PayMethod(m ?? 'Autre', Icons.payments_outlined, _R.text2);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PaymentsPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PaymentsPage({super.key, required this.weddingId});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider(widget.weddingId));
    final summaryAsync = ref.watch(paymentsSummaryProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: paymentsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(paymentsProvider(widget.weddingId)),
        ),
        data: (payments) => FadeTransition(
          opacity: _fadeAnim,
          child: _PaymentsContent(
            weddingId: widget.weddingId,
            payments: payments,
            summaryAsync: summaryAsync,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            onRefresh: () async => ref.invalidate(paymentsProvider(widget.weddingId)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/paiements/add'),
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: Text('Nouveau paiement', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: _R.blue,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _PaymentsContent extends StatelessWidget {
  final String weddingId;
  final List<PaymentModel> payments;
  final AsyncValue<Map<String, double>> summaryAsync;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onRefresh;

  const _PaymentsContent({
    required this.weddingId,
    required this.payments,
    required this.summaryAsync,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Filtrage
    final filtered = payments.where((p) {
      if (filter == 'all') return true;
      return p.status == filter;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Stats locales pour les filtres
    final completedCount = payments.where((p) => p.status == 'completed').length;
    final pendingCount = payments.where((p) => p.status == 'pending').length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ───────────────────────────────────────────────────
        _PaymentsAppBar(weddingId: weddingId, paymentCount: payments.length),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── RÉSUMÉ FINANCIER ───────────────────────────────────
              summaryAsync.when(
                loading: () => const _SummaryShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => _FinancialSummary(summary: summary),
              ),
              const SizedBox(height: 16),

              // ── FILTRES ────────────────────────────────────────────
              _FilterRow(
                filter: filter,
                onChanged: onFilterChanged,
                completedCount: completedCount,
                pendingCount: pendingCount,
              ),
              const SizedBox(height: 16),

              // ── HEADER LISTE ───────────────────────────────────────
              _ListHeader(count: filtered.length, total: payments.length, filter: filter),
              const SizedBox(height: 10),

              // ── LISTE / EMPTY ──────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(filter: filter, weddingId: weddingId)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PaymentCard(payment: p, weddingId: weddingId),
                            ))
                        .toList(),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _PaymentsAppBar extends StatelessWidget {
  final String weddingId;
  final int paymentCount;

  const _PaymentsAppBar({required this.weddingId, required this.paymentCount});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/thix-weeding/staff/$weddingId/paiements/add'),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.add_card_outlined, color: _R.blue, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.greenG,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -60, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Positioned(right: 30, bottom: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: _R.gold.withOpacity(0.15)))),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.payments_outlined, color: Colors.white, size: 16)),
                        const SizedBox(width: 8),
                        Text('PAIEMENTS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 8),
                      Text('Suivi des transactions', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$paymentCount paiement${paymentCount > 1 ? 's' : ''} enregistré${paymentCount > 1 ? 's' : ''}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FINANCIAL SUMMARY HERO
// ============================================================================
class _FinancialSummary extends StatelessWidget {
  final Map<String, double> summary;

  const _FinancialSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final budget = summary['budget'] ?? 0.0;
    final spent = summary['spent'] ?? 0.0;
    final paid = summary['paid'] ?? 0.0;
    final remaining = summary['remaining'] ?? 0.0;
    final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final over = spent > budget && budget > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: over ? _R.roseG : _R.goldG,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (over ? _R.rose : _R.gold).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
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
                    Text('Résumé financier', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9), letterSpacing: 1)),
                    Text('${_fmtMoney(paid)} FCFA payés', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                child: Text('${(ratio * 100).toInt()}%', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 16),

          // 4 stats
          Row(
            children: [
              _SummaryStat(label: 'Budget', value: budget, icon: Icons.savings_outlined),
              const SizedBox(width: 8),
              _SummaryStat(label: 'Dépensé', value: spent, icon: Icons.shopping_cart_outlined),
              const SizedBox(width: 8),
              _SummaryStat(label: 'Payé', value: paid, icon: Icons.check_circle_outline),
              const SizedBox(width: 8),
              _SummaryStat(label: over ? 'Dépassement' : 'Restant', value: remaining.abs(), icon: over ? Icons.warning_amber : Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;

  const _SummaryStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 4),
            Text(_fmtMoneyShort(value), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white.withOpacity(0.85))),
          ],
        ),
      ),
    );
  }
}

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: _R.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

// ============================================================================
// FILTER ROW
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;
  final int completedCount;
  final int pendingCount;

  const _FilterRow({required this.filter, required this.onChanged, required this.completedCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(label: 'Tous', icon: Icons.all_inbox, color: _R.blue, isSelected: filter == 'all', onTap: () => onChanged('all')),
        const SizedBox(width: 8),
        _FilterChip(label: 'Complétés', icon: Icons.check_circle, color: _R.green, isSelected: filter == 'completed', badge: completedCount, onTap: () => onChanged('completed')),
        const SizedBox(width: 8),
        _FilterChip(label: 'En attente', icon: Icons.pending, color: _R.amber, isSelected: filter == 'pending', badge: pendingCount, onTap: () => onChanged('pending')),
        const SizedBox(width: 8),
        _FilterChip(label: 'Échoués', icon: Icons.error_outline, color: _R.rose, isSelected: filter == 'failed', onTap: () => onChanged('failed')),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final int badge;

  const _FilterChip({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : _R.border, width: isSelected ? 1.5 : 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
              ]),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Text('$badge', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// LIST HEADER
// ============================================================================
class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String filter;

  const _ListHeader({required this.count, required this.total, required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'completed' => 'Paiements complétés',
      'pending' => 'Paiements en attente',
      'failed' => 'Paiements échoués',
      _ => 'Tous les paiements',
    };

    return Row(children: [
      Icon(Icons.receipt_long_outlined, size: 16, color: _R.green),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _R.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(filter == 'all' ? '$total' : '$count / $total', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.green)),
      ),
    ]);
  }
}

// ============================================================================
// PAYMENT CARD
// ============================================================================
class _PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final String weddingId;

  const _PaymentCard({required this.payment, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    final status = _getPayStatus(payment.status);
    final method = _getPayMethod(payment.method);
    final displayName = payment.vendorName ?? payment.expenseTitle ?? 'Paiement';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // ✅ ROUTE CORRIGÉE — plus de \( \) illégal
        onTap: () => context.push('/thix-weeding/staff/$weddingId/paiements/${payment.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: status.color.withOpacity(0.3), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Icône méthode de paiement
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [method.color, method.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(method.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.text)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(_fmtMoney(payment.amount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: status.color)),
                      const SizedBox(width: 6),
                      Text('FCFA', style: GoogleFonts.inter(fontSize: 10, color: _R.text2)),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      // Badge statut
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: status.color.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(status.icon, size: 10, color: status.color),
                          const SizedBox(width: 3),
                          Text(status.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: status.color)),
                        ]),
                      ),
                      // Badge méthode
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: method.color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                        child: Text(method.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: method.color)),
                      ),
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _R.text2.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                        child: Text(_fmtDate(payment.createdAt), style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
                      ),
                      // Référence
                      if (payment.referenceCode != null && payment.referenceCode!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _R.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text('Ref: ${payment.referenceCode}', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: _R.blue, fontFamily: 'monospace')),
                        ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _R.text2, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String filter;
  final String weddingId;

  const _EmptyState({required this.filter, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      'completed' => 'Aucun paiement complété',
      'pending' => 'Aucun paiement en attente',
      'failed' => 'Aucun paiement échoué',
      _ => 'Aucun paiement enregistré',
    };

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_R.green.withOpacity(0.15), _R.blue.withOpacity(0.1)]), shape: BoxShape.circle),
          child: const Icon(Icons.payments_outlined, size: 40, color: _R.green),
        ),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Ajoutez un paiement pour suivre vos dépenses', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
        if (filter == 'all') ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/staff/$weddingId/paiements/add'),
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('Ajouter un paiement'),
            style: FilledButton.styleFrom(backgroundColor: _R.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ]),
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
    return Scaffold(backgroundColor: _R.surface, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: _R.greenG, shape: BoxShape.circle), child: const Icon(Icons.payments_outlined, color: Colors.white, size: 36)),
      const SizedBox(height: 16),
      Text('Chargement des paiements...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
    ])));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _R.surface, body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _R.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
      const SizedBox(height: 16),
      Text('Impossible de charger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _R.blue)),
    ]))));
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
  return buf.toString().split('').reversed.join();
}

String _fmtMoneyShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.round().toString();
}

String _fmtDate(DateTime dt) {
  const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
