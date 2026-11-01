// lib/presentation/thix_weeding/pages/staff/paiements/add_payment_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD PAYMENT (PRODUCTION v2 — USD + ÉQUILIBRÉ)
// ✅ Devise USD ($) avec saisie décimale
// ✅ Liaison dépense : affiche le reste à payer + raccourcis (Reste/50%/25%)
// ✅ Si le paiement solde la dépense → is_paid = true automatiquement
// ✅ Statut completed (comptabilisé) / pending (hors comptabilité)
// ✅ Invalidation balancedSummaryProvider → dashboard & budget synchronisés
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/budget/budget_page.dart'
    show balancedSummaryProvider;

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

/// Méthodes de paiement (clés stockées en base)
const List<_Method> _METHODS = [
  _Method('mobile_money', 'Mobile Money', Icons.phone_android),
  _Method('cash', 'Espèces', Icons.payments_outlined),
  _Method('bank_transfer', 'Virement bancaire', Icons.account_balance),
  _Method('card', 'Carte bancaire', Icons.credit_card),
  _Method('check', 'Chèque', Icons.receipt_long_outlined),
];

class _Method {
  final String key;
  final String label;
  final IconData icon;
  const _Method(this.key, this.label, this.icon);

  static String labelOf(String key) =>
      _METHODS.firstWhere((m) => m.key == key, orElse: () => _METHODS.first).label;
}

/// Formatter décimal USD : chiffres + 1 point + 2 décimales max
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
// PAGE
// ============================================================================
class AddPaymentPage extends ConsumerStatefulWidget {
  final String weddingId;
  const AddPaymentPage({super.key, required this.weddingId});

  @override
  ConsumerState<AddPaymentPage> createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends ConsumerState<AddPaymentPage> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  String? _vendorId;
  String? _expenseId;
  String _method = 'mobile_money';
  String _status = 'completed';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Calculs liés à la dépense sélectionnée ────────────────────────────────
  double? _expenseTotal() {
    final expenses = ref.watch(expensesProvider(widget.weddingId)).valueOrNull;
    if (expenses == null || _expenseId == null) return null;
    final match = expenses.where((e) => e.id == _expenseId);
    return match.isEmpty ? null : match.first.amount;
  }

  double? _expenseAlreadyPaid() {
    final payments = ref.watch(paymentsProvider(widget.weddingId)).valueOrNull;
    if (payments == null || _expenseId == null) return null;
    return payments
        .where((p) => p.expenseId == _expenseId && p.status == 'completed')
        .fold<double>(0, (s, p) => s + p.amount);
  }

  double? _expenseRemaining() {
    final total = _expenseTotal();
    final paid = _expenseAlreadyPaid();
    if (total == null || paid == null) return null;
    return (total - paid).clamp(0.0, double.infinity);
  }

  // ── Enregistrement ────────────────────────────────────────────────────────
  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _toast('Montant invalide', error: true);
      return;
    }

    final remaining = _expenseRemaining();
    if (_expenseId != null && remaining != null && amount > remaining + 0.001) {
      final ok = await _confirmOverpay(amount, remaining);
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      // Titre : dépense liée > prestataire lié > saisie libre
      String title = _titleCtrl.text.trim();
      if (title.isEmpty) {
        if (_expenseId != null) {
          final expenses = ref.watch(expensesProvider(widget.weddingId)).valueOrNull ?? const [];
          final e = expenses.where((x) => x.id == _expenseId);
          title = e.isEmpty ? 'Paiement' : 'Paiement : ${e.first.title}';
        } else if (_vendorId != null) {
          final vendors = ref.watch(vendorsProvider(widget.weddingId)).valueOrNull ?? const [];
          final v = vendors.where((x) => x.id == _vendorId);
          title = v.isEmpty ? 'Paiement' : 'Acompte : ${v.first.name}';
        } else {
          title = 'Paiement ${_Method.labelOf(_method)}';
        }
      }

      await Supabase.instance.client.from('thix_weeding_payments').insert({
        'wedding_id': widget.weddingId,
        'title': title,
        'amount': amount,
        'status': _status,
        'method': _method,
        'vendor_id': _vendorId,
        'expense_id': _expenseId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Si dépense liée et paiement complété → ressolde automatiquement
      if (_expenseId != null && _status == 'completed') {
        final expenses = ref.watch(expensesProvider(widget.weddingId)).valueOrNull ?? const [];
        final e = expenses.where((x) => x.id == _expenseId);
        if (e.isNotEmpty) {
          final paidBefore = _expenseAlreadyPaid() ?? 0;
          if (paidBefore + amount >= e.first.amount - 0.001) {
            await Supabase.instance.client
                .from('thix_weeding_expenses')
                .update({'is_paid': true}).eq('id', _expenseId!);
          }
        }
      }

      // Synchronisation globale (dashboard + budget + détail)
      ref.invalidate(paymentsProvider(widget.weddingId));
      ref.invalidate(expensesProvider(widget.weddingId));
      ref.invalidate(budgetProvider(widget.weddingId));
      ref.invalidate(paymentsSummaryProvider(widget.weddingId));
      ref.invalidate(balancedSummaryProvider(widget.weddingId));

      if (mounted) {
        _toast('Paiement de ${_fmtUsd(amount)} enregistré ✓');
        context.pop();
      }
    } catch (e) {
      if (mounted) _toast('Erreur: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmOverpay(double amount, double remaining) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Paiement supérieur au reste',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Reste à payer : ${_fmtUsd(remaining)}\nMontant saisi : ${_fmtUsd(amount)}\n\nContinuer quand même ?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _R.amber),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: error ? _R.rose : _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ));
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));
    final expensesAsync = ref.watch(expensesProvider(widget.weddingId));
    final remaining = _expenseRemaining();

    return Scaffold(
      backgroundColor: _R.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: _R.text,
            title: Text('Nouveau paiement',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.blue, fontSize: 20)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => context.pop(),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  color: _saving ? _R.border : _R.green,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('Créer',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── MONTANT (USD) ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _R.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        title: 'Montant du paiement',
                        icon: Icons.payments_outlined,
                        gradient: _R.greenG,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _R.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _R.green.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Text('\$',
                                style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: _R.green)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [_UsdInputFormatter()],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: _R.green),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            Text('USD',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _R.text2)),
                          ],
                        ),
                      ),
                      // Raccourcis si dépense liée
                      if (remaining != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickChip(
                              label: 'Reste (${_fmtUsd(remaining)})',
                              onTap: () =>
                                  _amountCtrl.text = remaining.toStringAsFixed(2),
                            ),
                            _QuickChip(
                              label: '50%',
                              onTap: () => _amountCtrl.text =
                                  (remaining / 2).toStringAsFixed(2),
                            ),
                            _QuickChip(
                              label: '25%',
                              onTap: () => _amountCtrl.text =
                                  (remaining / 4).toStringAsFixed(2),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── LIAISONS ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _R.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        title: 'Liaisons (optionnel)',
                        icon: Icons.link_rounded,
                        gradient: _R.royal,
                      ),
                      const SizedBox(height: 16),
                      vendorsAsync.when(
                        loading: () => const _MiniLoader(),
                        error: (e, _) => Text('$e',
                            style: const TextStyle(color: _R.rose, fontSize: 12)),
                        data: (vendors) => DropdownButtonFormField<String>(
                          value: _vendorId,
                          decoration: InputDecoration(
                            labelText: 'Prestataire lié (optionnel)',
                            labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                            prefixIcon: const Icon(Icons.storefront_outlined, color: _R.purple),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.blue, width: 2)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          dropdownColor: Colors.white,
                          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Aucun prestataire'),
                            ),
                            ...vendors.map((v) => DropdownMenuItem<String>(
                                  value: v.id,
                                  child: Text(v.name, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) => setState(() => _vendorId = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      expensesAsync.when(
                        loading: () => const _MiniLoader(),
                        error: (e, _) => Text('$e',
                            style: const TextStyle(color: _R.rose, fontSize: 12)),
                        data: (expenses) => DropdownButtonFormField<String>(
                          value: _expenseId,
                          decoration: InputDecoration(
                            labelText: 'Dépense liée (optionnel)',
                            labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                            prefixIcon: const Icon(Icons.receipt_long_outlined, color: _R.amber),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _R.blue, width: 2)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          dropdownColor: Colors.white,
                          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Aucune dépense'),
                            ),
                            ...expenses.map((e) => DropdownMenuItem<String>(
                                  value: e.id,
                                  child: Text(
                                    '${e.title} — ${_fmtUsd(e.amount)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() {
                            _expenseId = v;
                            // Pré-remplit le reste à payer
                            if (v != null) {
                              final r = _expenseRemaining();
                              if (r != null && _amountCtrl.text.isEmpty) {
                                _amountCtrl.text = r.toStringAsFixed(2);
                              }
                            }
                          }),
                        ),
                      ),
                      // Reste à payer de la dépense liée
                      if (remaining != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: remaining > 0
                                ? _R.amber.withOpacity(0.1)
                                : _R.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: (remaining > 0 ? _R.amber : _R.green).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                remaining > 0
                                    ? Icons.hourglass_bottom_rounded
                                    : Icons.verified_rounded,
                                size: 16,
                                color: remaining > 0 ? _R.amber : _R.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  remaining > 0
                                      ? 'Reste à payer sur cette dépense : ${_fmtUsd(remaining)}'
                                      : 'Cette dépense est déjà soldée ✓',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: remaining > 0 ? _R.amber : _R.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── MÉTHODE ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _R.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        title: 'Méthode de paiement',
                        icon: Icons.account_balance_wallet_outlined,
                        gradient: _R.goldG,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _METHODS.map((m) {
                          final selected = _method == m.key;
                          final color = m.key == 'mobile_money'
                              ? _R.amber
                              : (m.key == 'cash'
                                  ? _R.green
                                  : (m.key == 'bank_transfer'
                                      ? _R.blue
                                      : (m.key == 'card' ? _R.purple : _R.text2)));
                          return Material(
                            color: selected ? color : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => setState(() => _method = m.key),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: selected ? color : _R.border,
                                      width: selected ? 1.5 : 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(m.icon,
                                        size: 18,
                                        color: selected ? Colors.white : color),
                                    const SizedBox(width: 8),
                                    Text(m.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: selected ? Colors.white : _R.text,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── STATUT ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _R.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        title: 'Statut',
                        icon: Icons.verified_outlined,
                        gradient: _R.greenG,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatusChip(
                              label: 'Réglé',
                              sub: 'Compté dans le Payé',
                              icon: Icons.check_circle_outline,
                              selected: _status == 'completed',
                              color: _R.green,
                              onTap: () => setState(() => _status = 'completed'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatusChip(
                              label: 'En attente',
                              sub: 'Hors comptabilité',
                              icon: Icons.schedule_outlined,
                              selected: _status == 'pending',
                              color: _R.amber,
                              onTap: () => setState(() => _status = 'pending'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── LIBELLÉ LIBRE ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _R.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        title: 'Libellé (optionnel)',
                        icon: Icons.edit_note_outlined,
                        gradient: _R.royal,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ex: Acompte photographe',
                          hintStyle:
                              GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _R.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _R.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _R.blue, width: 2)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── BOUTON CRÉER ────────────────────────────────────────────
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _saving ? null : _R.greenG,
                    color: _saving ? _R.border : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _saving
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
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text('Enregistrer le paiement',
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS UI
// ============================================================================
class _CardTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  const _CardTitle({required this.title, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text)),
        ),
      ],
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
                  fontSize: 11, fontWeight: FontWeight.w700, color: _R.green)),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.sub,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : _R.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : _R.text2),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : _R.text)),
                  Text(sub,
                      style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _R.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue)),
      );
}

// ============================================================================
// UTILITAIRE USD
// ============================================================================
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
  final c = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}\$$buf$c';
}
