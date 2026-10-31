// lib/presentation/thix_weeding/pages/staff/paiements/payment_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PAYMENT DETAIL (PRODUCTION)
// Design royal + Actions contextuelles + Timeline + Suppression sécurisée
// Branché sur providers EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
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
// MÉTHODES & STATUTS
// ============================================================================
const Map<String, _PayMethod> _METHODS = {
  'mobile_money': _PayMethod('Mobile Money', Icons.phone_android, Color(0xFFD97706)),
  'cash': _PayMethod('Espèces', Icons.money, Color(0xFF059669)),
  'bank': _PayMethod('Virement bancaire', Icons.account_balance, Color(0xFF0B3B8F)),
  'card': _PayMethod('Carte bancaire', Icons.credit_card, Color(0xFF6B46C1)),
  'check': _PayMethod('Chèque', Icons.receipt_long, Color(0xFF78716C)),
};

class _PayMethod {
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.label, this.icon, this.color);
}

_PayMethod _getMethod(String? m) =>
    _METHODS[m ?? ''] ?? _PayMethod(m ?? 'Autre', Icons.payments_outlined, _R.text2);

const Map<String, _PayStatus> _STATUSES = {
  'pending': _PayStatus('En attente', Icons.pending, Color(0xFFD97706)),
  'completed': _PayStatus('Complété', Icons.check_circle, Color(0xFF059669)),
  'failed': _PayStatus('Échoué', Icons.error_outline, Color(0xFFE31C4E)),
  'refunded': _PayStatus('Remboursé', Icons.undo, Color(0xFF6B7280)),
};

class _PayStatus {
  final String label;
  final IconData icon;
  final Color color;
  const _PayStatus(this.label, this.icon, this.color);
}

_PayStatus _getStatus(String? s) =>
    _STATUSES[s ?? ''] ?? _PayStatus(s ?? 'Inconnu', Icons.info_outline, _R.text2);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PaymentDetailPage extends ConsumerWidget {
  final String weddingId;
  final String paymentId;

  const PaymentDetailPage({
    super.key,
    required this.weddingId,
    required this.paymentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentDetailProvider(paymentId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: paymentAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(paymentDetailProvider(paymentId)),
        ),
        data: (payment) => _PaymentDetailContent(
          weddingId: weddingId,
          paymentId: paymentId,
          payment: payment,
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU DÉTAIL
// ============================================================================
class _PaymentDetailContent extends StatelessWidget {
  final String weddingId;
  final String paymentId;
  final PaymentModel payment;

  const _PaymentDetailContent({
    required this.weddingId,
    required this.paymentId,
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    final method = _getMethod(payment.method);
    final status = _getStatus(payment.status);
    final isCompleted = payment.status == 'completed';
    final isFailed = payment.status == 'failed';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ROYALE ────────────────────────────────────────────
        _DetailAppBar(
          payment: payment,
          status: status,
          method: method,
          weddingId: weddingId,
          paymentId: paymentId,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── HERO MONTANT ───────────────────────────────────────
              _AmountHero(payment: payment, status: status, method: method),
              const SizedBox(height: 16),

              // ── ACTIONS RAPIDES ────────────────────────────────────
              _ActionButtons(
                payment: payment,
                weddingId: weddingId,
                paymentId: paymentId,
              ),
              const SizedBox(height: 16),

              // ── INFORMATIONS ───────────────────────────────────────
              _InfoSection(payment: payment, method: method, status: status),
              const SizedBox(height: 16),

              // ── LIAISONS ───────────────────────────────────────────
              _LinksSection(payment: payment),
              const SizedBox(height: 16),

              // ── TIMELINE ───────────────────────────────────────────
              _TimelineSection(payment: payment, status: status),
              const SizedBox(height: 16),

              // ── MÉTADONNÉES ────────────────────────────────────────
              _MetaCard(payment: payment),
              const SizedBox(height: 16),

              // ── ZONE DANGER ────────────────────────────────────────
              _DangerZone(
                weddingId: weddingId,
                paymentId: paymentId,
                payment: payment,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// APP BAR DÉTAIL
// ============================================================================
class _DetailAppBar extends StatelessWidget {
  final PaymentModel payment;
  final _PayStatus status;
  final _PayMethod method;
  final String weddingId;
  final String paymentId;

  const _DetailAppBar({
    required this.payment,
    required this.status,
    required this.method,
    required this.weddingId,
    required this.paymentId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
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
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [status.color, status.color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -60, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Positioned(right: 30, bottom: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1))),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(method.icon, color: Colors.white, size: 16)),
                        const SizedBox(width: 8),
                        Text('PAIEMENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(status.icon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(status.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '${_fmtMoney(payment.amount)} FCFA',
                        style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        payment.vendorName ?? payment.expenseTitle ?? 'Paiement sans liaison',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                      ),
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
// AMOUNT HERO CARD
// ============================================================================
class _AmountHero extends StatelessWidget {
  final PaymentModel payment;
  final _PayStatus status;
  final _PayMethod method;

  const _AmountHero({required this.payment, required this.status, required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [method.color, method.color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: method.color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(16)),
            child: Icon(method.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                const SizedBox(height: 4),
                Text(_fmtMoney(payment.amount), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('FCFA', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            child: Icon(status.icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTION BUTTONS
// ============================================================================
class _ActionButtons extends ConsumerWidget {
  final PaymentModel payment;
  final String weddingId;
  final String paymentId;

  const _ActionButtons({required this.payment, required this.weddingId, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = payment.status == 'completed';
    final isFailed = payment.status == 'failed';

    return Row(
      children: [
        // Bouton Marquer complété
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: isCompleted ? null : _R.greenG,
              color: isCompleted ? _R.green.withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(14),
              border: isCompleted ? Border.all(color: _R.green.withOpacity(0.3)) : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: isCompleted ? null : () => _markCompleted(context, ref),
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isCompleted ? Icons.verified : Icons.check_circle_outline, size: 18, color: isCompleted ? _R.green : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isCompleted ? 'Déjà complété' : 'Marquer complété',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isCompleted ? _R.green : Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Bouton Copier référence
        if (payment.referenceCode != null && payment.referenceCode!.isNotEmpty)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _R.border),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: payment.referenceCode!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Référence copiée ✓'),
                    backgroundColor: _R.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                },
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.copy, size: 18, color: _R.blue),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _markCompleted(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_payments')
          .update({'status': 'completed'})
          .eq('id', paymentId);
      ref.invalidate(paymentDetailProvider(paymentId));
      ref.invalidate(paymentsProvider(weddingId));
      ref.invalidate(paymentsSummaryProvider(weddingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            const Text('Paiement marqué comme complété ✓'),
          ]),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose, behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ============================================================================
// INFO SECTION
// ============================================================================
class _InfoSection extends StatelessWidget {
  final PaymentModel payment;
  final _PayMethod method;
  final _PayStatus status;

  const _InfoSection({required this.payment, required this.method, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Informations', icon: Icons.info_outline, color: _R.blue),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.fingerprint_outlined, label: 'ID Paiement', value: payment.id.substring(0, 12), mono: true, color: _R.blue),
          _InfoRow(icon: method.icon, label: 'Méthode', value: method.label, color: method.color),
          _InfoRow(icon: status.icon, label: 'Statut', value: status.label, color: status.color, badge: true),
          _InfoRow(
            icon: Icons.tag_outlined,
            label: 'Référence',
            value: payment.referenceCode ?? 'Non renseignée',
            color: payment.referenceCode != null ? _R.purple : _R.text2,
            mono: payment.referenceCode != null,
            copyable: payment.referenceCode,
          ),
          _InfoRow(icon: Icons.calendar_today_outlined, label: 'Date de création', value: _fmtDateTime(payment.createdAt), color: _R.gold),
        ],
      ),
    );
  }
}

// ============================================================================
// LINKS SECTION
// ============================================================================
class _LinksSection extends StatelessWidget {
  final PaymentModel payment;

  const _LinksSection({required this.payment});

  @override
  Widget build(BuildContext context) {
    final hasVendor = payment.vendorName != null || payment.vendorId != null;
    final hasExpense = payment.expenseTitle != null || payment.expenseId != null;

    if (!hasVendor && !hasExpense) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Liaisons', icon: Icons.link_outlined, color: _R.purple),
          const SizedBox(height: 14),
          if (hasVendor)
            _LinkTile(
              icon: Icons.storefront_outlined,
              label: 'Prestataire',
              value: payment.vendorName ?? payment.vendorId!,
              color: _R.purple,
            ),
          if (hasVendor && hasExpense) const SizedBox(height: 10),
          if (hasExpense)
            _LinkTile(
              icon: Icons.receipt_long_outlined,
              label: 'Dépense liée',
              value: payment.expenseTitle ?? payment.expenseId!,
              color: _R.amber,
            ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _LinkTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: _R.text2)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================================
// TIMELINE SECTION
// ============================================================================
class _TimelineSection extends StatelessWidget {
  final PaymentModel payment;
  final _PayStatus status;

  const _TimelineSection({required this.payment, required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = payment.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Historique', icon: Icons.history_outlined, color: _R.gold),
          const SizedBox(height: 14),
          // Étape 1 : Création
          _TimelineStep(
            icon: Icons.add_circle_outline,
            title: 'Paiement créé',
            subtitle: _fmtDateTime(payment.createdAt),
            color: _R.blue,
            isActive: true,
            showConnector: true,
          ),
          // Étape 2 : Complétion
          _TimelineStep(
            icon: isCompleted ? Icons.check_circle : Icons.hourglass_empty,
            title: isCompleted ? 'Paiement complété' : 'En attente de confirmation',
            subtitle: isCompleted ? 'Le montant a été réglé' : 'En attente de validation',
            color: isCompleted ? _R.green : _R.amber,
            isActive: isCompleted,
            showConnector: false,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isActive;
  final bool showConnector;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isActive,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.15) : _R.border.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: isActive ? color : _R.border, width: 2),
                ),
                child: Icon(icon, size: 14, color: isActive ? color : _R.text2),
              ),
              if (showConnector) Expanded(child: Container(width: 2, color: isActive ? color.withOpacity(0.25) : _R.border)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? color : _R.text2)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// META CARD
// ============================================================================
class _MetaCard extends StatelessWidget {
  final PaymentModel payment;

  const _MetaCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _R.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _R.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _R.text2.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.data_object, size: 14, color: _R.text2)),
            const SizedBox(width: 8),
            Text('Données techniques', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _R.text2)),
          ]),
          const SizedBox(height: 12),
          _MetaRow(label: 'UUID complet', value: payment.id),
          _MetaRow(label: 'Wedding ID', value: payment.weddingId),
          if (payment.vendorId != null) _MetaRow(label: 'Vendor ID', value: payment.vendorId!),
          if (payment.expenseId != null) _MetaRow(label: 'Expense ID', value: payment.expenseId!),
        ],
      ),
    );
  }
}

// ============================================================================
// DANGER ZONE
// ============================================================================
class _DangerZone extends ConsumerWidget {
  final String weddingId;
  final String paymentId;
  final PaymentModel payment;

  const _DangerZone({required this.weddingId, required this.paymentId, required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _R.rose.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.rose.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: _R.roseG, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.warning_amber_outlined, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            Text('Zone de danger', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _R.rose)),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _R.rose.withOpacity(0.3))),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _confirmDelete(context, ref),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.delete_forever_outlined, color: _R.rose, size: 20),
                    const SizedBox(width: 8),
                    Text('Supprimer ce paiement', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _R.rose)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(gradient: _R.roseG, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36)),
            const SizedBox(height: 18),
            Text('Supprimer ce paiement ?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Le paiement de ${_fmtMoney(payment.amount)} FCFA sera définitivement supprimé. Cette action est irréversible.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), style: OutlinedButton.styleFrom(foregroundColor: _R.text, side: const BorderSide(color: _R.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Annuler'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Supprimer'), style: FilledButton.styleFrom(backgroundColor: _R.rose, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;

    try {
      await Supabase.instance.client.from('thix_weeding_payments').delete().eq('id', paymentId);
      ref.invalidate(paymentsProvider(weddingId));
      ref.invalidate(paymentsSummaryProvider(weddingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 10), const Text('Paiement supprimé ✓')]),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose, behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ============================================================================
// WIDGETS UTILITAIRES
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool badge;
  final bool mono;
  final String? copyable;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.color, this.badge = false, this.mono = false, this.copyable});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
            const SizedBox(height: 2),
            badge
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
                    child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: value == 'Non renseignée' ? _R.text2 : _R.text, fontFamily: mono ? 'monospace' : null),
                  ),
          ]),
        ),
        if (copyable != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyable!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Copié ✓'), backgroundColor: _R.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.copy, size: 14, color: _R.text2)),
            ),
          ),
      ]),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: _R.text2))),
        Expanded(
          child: SelectableText(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _R.text, fontFamily: 'monospace')),
        ),
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
      Text('Chargement...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
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

String _fmtDateTime(DateTime dt) {
  const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
